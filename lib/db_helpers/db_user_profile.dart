// -----------------------------------------------------------------------
// Filename: db_user_profile.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/22/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file contains the database helper functions for user
//              profiles.

////////////////////////////////////////////////////////////////////////////////////////////
// Imports
////////////////////////////////////////////////////////////////////////////////////////////
// Dart imports
import 'dart:async';
import 'dart:typed_data';

// Flutter external package imports
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// App relative file imports
import '../providers/provider_user_profile.dart';
import '../util/logging/app_logger.dart';
import '../../models/user_profile.dart';
import 'firestore_keys.dart';

////////////////////////////////////////////////////////////////////////////////////////////
// Class definition for DB Helper
////////////////////////////////////////////////////////////////////////////////////////////
class DBUserProfile {
  // Static variables
  static StreamSubscription? _profileUpdateStream;
  static final Map<String, ImageProvider?> _profileImageCache =
      <String, ImageProvider?>{};
  static final Map<String, Future<ImageProvider?>> _pendingProfileImageFetches =
      <String, Future<ImageProvider?>>{};
  static bool _hasLoggedCrossUserAvatarPermissionWarning = false;

  ////////////////////////////////////////////////////////////////////////////////////////////
  // This method cancels the subscription to the DB that was initiated to update value in
  // realtime. This MUST be called before the user logs off.
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<void> cancelProfileUpdateStream() async {
    if (_profileUpdateStream != null) {
      await _profileUpdateStream!.cancel();
    }
    _profileUpdateStream = null;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Pulls the Firebase user's user profile from Firestore and uses the passed in provider
  // to update displays througout the app.
  //
  // Returns true if data was fetched and set in provider; false otherwise
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> fetchUserProfileAndSyncProvider(
    ProviderUserProfile providerUserProfile,
  ) async {
    // Initialize success variable
    var db = FirebaseFirestore.instance;
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;

    // If no user logged in, return; otherwise continue
    if (user == null) {
      return false;
    }

    final uid = user.uid;
    final profileDocRef = db.collection(FS_COL_IC_USER_PROFILES).doc(uid);

    // Ensure only one live profile subscription exists at a time.
    await cancelProfileUpdateStream();

    try {
      final initialDoc = await profileDocRef.get();
      if (!initialDoc.exists) {
        AppLogger.warning('No user profile document found for uid $uid.');
        return false;
      }

      await _syncProviderWithUserDoc(
        providerUserProfile: providerUserProfile,
        user: user,
        docRef: initialDoc,
      );

      _profileUpdateStream = profileDocRef
          .snapshots()
          .skip(1)
          .listen(
            (docRef) async {
              if (!docRef.exists) {
                return;
              }

              try {
                await _syncProviderWithUserDoc(
                  providerUserProfile: providerUserProfile,
                  user: user,
                  docRef: docRef,
                );
              } catch (e) {
                AppLogger.error('Failed to sync updated user profile: $e');
              }
            },
            onError: (error) {
              if (_isBenignProfileReadError(error, expectedUid: uid)) {
                AppLogger.debug(
                  'Profile stream closed during auth transition for uid $uid.',
                );
                return;
              }

              AppLogger.error(
                'Encountered problem loading user profile from firestore: $error',
              );
            },
            cancelOnError: false,
          );

      return true;
    } catch (e) {
      if (_isBenignProfileReadError(e, expectedUid: uid)) {
        AppLogger.debug(
          'Profile fetch interrupted during auth transition for uid $uid.',
        );
        return false;
      }

      AppLogger.error(
        'Encountered problem loading user profile from firestore: $e',
      );
      return false;
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Writes the provided user profile to the database
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> writeUserProfile(
    UserProfile userProfile, {
    merge = true,
  }) async {
    // Initialize success variable
    bool success = false;

    // Get Firebase instance
    var db = FirebaseFirestore.instance;
    if (FirebaseAuth.instance.currentUser != null) {
      // Get the authenticated firebase user
      final FirebaseAuth auth = FirebaseAuth.instance;
      final User? user = auth.currentUser;

      // If no user logged in, return; otherwise continue
      if (user == null) {
        return false;
      }
      String uid = user.uid;

      // Try to get the user's data from firestore
      try {
        // Attempt to write data
        await db
            .collection(FS_COL_IC_USER_PROFILES)
            .doc(uid)
            .set(userProfile.toJsonForDb(), SetOptions(merge: merge));
        success = true;
      } catch (e) {
        AppLogger.error(
          "Encountered problem writing user profile to firestore.$e",
        );

        success = false;
      }
    }

    // Return status
    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Pulls the Firebase user's user profile image from Cloud Storage and uses the passed in
  // provider to update displays througout the app.
  //
  // Returns true if image data was fetched and set in provider; false otherwise
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> fetchUserProfileImageAndSyncProvider(
    ProviderUserProfile providerUserProfile,
  ) async {
    // Initialize success variable
    bool success = false;

    // Get a Google Storage reference to the profile picture
    final ref = FirebaseStorage.instance.ref().child(
      'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg',
    );

    // Try to download the image
    try {
      Uint8List? imageData = await ref.getData();
      if (imageData == null) {
        providerUserProfile.userImage = null;
        _profileImageCache[providerUserProfile.uid.trim()] = null;
      } else {
        final image = MemoryImage(imageData);
        providerUserProfile.userImage = image;
        _profileImageCache[providerUserProfile.uid.trim()] = image;
      }
      //var url = await ref.getDownloadURL();
      //userProfileProvider.userImage = NetworkImage(url);
      success = true;
    } catch (e) {
      // If ref is bad/incomplete, set to local image
      providerUserProfile.userImage = null;
      _profileImageCache[providerUserProfile.uid.trim()] = null;
    }

    // Return status
    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Attempts to pull a profile picture from Cloud Storage using a UID that is passed in. Only
  // attempts fetch if the attemptFetch parameter is true; otherwise, returns default icon.
  //
  // Returns an image (MIC logo if no image retreived)
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<ImageProvider?> fetchUserProfileImageFromUid(
    String uid,
    bool attemptFetch, {
    bool forceRefresh = false,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty || !attemptFetch) {
      return null;
    }

    if (forceRefresh) {
      _profileImageCache.remove(cleanUid);
      _pendingProfileImageFetches.remove(cleanUid);
    }

    if (_profileImageCache.containsKey(cleanUid)) {
      return _profileImageCache[cleanUid];
    }

    return _pendingProfileImageFetches.putIfAbsent(cleanUid, () async {
      final ref = FirebaseStorage.instance.ref().child(
        'users/$cleanUid/profile_picture/userProfilePicture.jpg',
      );

      try {
        final imageData = await ref.getData();
        final image = imageData == null ? null : MemoryImage(imageData);
        _profileImageCache[cleanUid] = image;
        return image;
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          _profileImageCache[cleanUid] = null;
          return null;
        }

        if (e.code == 'unauthorized') {
          if (!_hasLoggedCrossUserAvatarPermissionWarning) {
            AppLogger.warning(
              'Profile image reads are being denied by Firebase Storage. Deploy the updated Storage rules to allow cross-user avatar reads.',
            );
            _hasLoggedCrossUserAvatarPermissionWarning = true;
          }
          _profileImageCache[cleanUid] = null;
          return null;
        }

        AppLogger.error("Failed to fetch user profile image from uid: $e");
        _profileImageCache[cleanUid] = null;
        return null;
      } catch (e) {
        AppLogger.error("Failed to fetch user profile image from uid: $e");
        _profileImageCache[cleanUid] = null;
        return null;
      } finally {
        _pendingProfileImageFetches.remove(cleanUid);
      }
    });
  }

  static ImageProvider? getCachedUserProfileImage(String uid) {
    return _profileImageCache[uid.trim()];
  }

  static void clearCachedUserProfileImage(String uid) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      return;
    }
    _profileImageCache.remove(cleanUid);
    _pendingProfileImageFetches.remove(cleanUid);
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Uplads the user profile image to Google Cloud Storage
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> uploadNewUserProfileImage(
    Uint8List imageBytes,
    ProviderUserProfile providerUserProfile,
  ) async {
    // Initialize success variable
    bool success = false;

    try {
      // Get a reference to the logged-in user's profile pic and upload the new picture
      final gcsPath =
          'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg';
      final ref = FirebaseStorage.instance.ref().child(gcsPath);

      // Get existing metadata, upload the file, and then re-upload the metadata
      try {
        final existingMetadata = await ref.getMetadata();
        await ref.putData(
          imageBytes,
          SettableMetadata(
            customMetadata:
                existingMetadata.customMetadata ?? <String, String>{},
          ),
        );
      } catch (e) {
        await ref.putData(
          imageBytes,
          SettableMetadata(customMetadata: const <String, String>{}),
        );
      }
      _profileImageCache[providerUserProfile.uid.trim()] = MemoryImage(
        imageBytes,
      );
      _pendingProfileImageFetches.remove(providerUserProfile.uid.trim());
      success = true;
    } catch (e) {
      AppLogger.error("Failed To Upload: $e");

      success = false;
    }

    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Deletes the user profile image from Google Cloud Storage
  ////////////////////////////////////////////////////////////////////////////////////////////
  static Future<bool> deleteUserProfileImage(
    ProviderUserProfile providerUserProfile,
  ) async {
    // Initialize success variable
    bool success = false;

    try {
      // Get a reference to the logged-in user's profile pic and upload the new picture
      final gcsPath =
          'users/${providerUserProfile.uid}/profile_picture/userProfilePicture.jpg';
      final ref = FirebaseStorage.instance.ref().child(gcsPath);
      await ref.delete();
      clearCachedUserProfileImage(providerUserProfile.uid);
      success = true;
    } catch (e) {
      success = false;
    }

    return success;
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Deletes the account data associated with the current user.
  //
  // Returns: A Future that completes when the account data is successfully deleted.
  ////////////////////////////////////////////////////////////////////////////////
  static Future<void> deleteAccountData() async {
    try {
      User? currentUser = FirebaseAuth
          .instance
          .currentUser; // Retrieve the currently authenticated user
      if (currentUser == null) {
        return; // Exit the method if the user is null
      }
      String userID = currentUser.uid; // User ID
      await FirebaseFirestore.instance
          .collection(FS_COL_IC_USER_PROFILES)
          .doc(userID)
          .delete(); // Delete the document associated with the user ID from the "FS_COL_MIC_USER_PROFILES" collection

      AppLogger.print('Document deleted successfully!');
    } catch (e) {
      AppLogger.error('Error deleting document: $e');
    }
  }

  static Future<void> _syncProviderWithUserDoc({
    required ProviderUserProfile providerUserProfile,
    required User user,
    required DocumentSnapshot<Map<String, dynamic>> docRef,
  }) async {
    final data = Map<String, dynamic>.from(
      docRef.data() ?? const <String, dynamic>{},
    );
    data['email'] = user.email;

    final userProfile = UserProfile.defFromJsonDbObject(data, user.uid);
    userProfile.uid = user.uid;
    await providerUserProfile.updateUserProfile(userProfile);
  }

  static bool _isBenignProfileReadError(
    Object error, {
    required String expectedUid,
  }) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return currentUid == null || currentUid != expectedUid;
  }
}
