// -----------------------------------------------------------------------
// Filename: provider_user_profile.dart
// Original Author: Emily Ehrenberg
// Creation Date: 5/22/2024
// Copyright: (c) 2024 Pat Your Mat!
// Description: This file checks contains the provider class which manages
//              the user profile state of the user.

//////////////////////////////////////////////////////////////////////////
// Imports
//////////////////////////////////////////////////////////////////////////
// Dart imports
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

// Flutter external package imports
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

// App relative file imports
import '../db_helpers/db_user_profile.dart';
import '../models/user_profile.dart';
import 'provider_auth.dart';

//////////////////////////////////////////////////////////////////////////
// State class that manages order variables; extends ChangeNotifier
// ChangeNotifier so it can be accessed in multiple files.
//////////////////////////////////////////////////////////////////////////
class ProviderUserProfile extends ChangeNotifier {
  // The "instance variables" managed in this state
  UserProfile _userProfile = UserProfile.empty();
  ImageProvider? _userImage;
  bool _dataLoaded = false;
  bool _imageLoaded = false;
  bool _internetIssues = false;
  bool _userChangeInProgress = false;
  late ProviderAuth _providerAuth; // Needed to update signin status

  ////////////////////////////////////////////////////////////////////////
  // GETTERS/SETTERS
  ////////////////////////////////////////////////////////////////////////
  bool get dataLoaded => _dataLoaded;

  UserProfile get userProfile => _userProfile;

  PermissionLevel get permissionLevel => _userProfile.permissionLevel;

  UserRole get role => _userProfile.role;
  set role(UserRole value) {
    _userProfile.role = value;
    notifyListeners();
  }

  String get uid => _userProfile.uid;
  set uid(String value) {
    _userProfile.uid = value;
    notifyListeners();
  }

  String get firstName => _userProfile.firstName;
  set firstName(String value) {
    _userProfile.firstName = value;
    notifyListeners();
  }

  String get lastName => _userProfile.lastName;
  set lastName(String value) {
    _userProfile.lastName = value;
    notifyListeners();
  }

  String get wholeName => "${_userProfile.firstName} ${_userProfile.lastName}";

  String get email => _userProfile.email;
  set email(String value) {
    _userProfile.email = value;
    notifyListeners();
  }

  String get phoneNumber => _userProfile.phoneNumber;
  set phoneNumber(String value) {
    _userProfile.phoneNumber = value;
    notifyListeners();
  }

  String get bio => _userProfile.bio;
  set bio(String value) {
    _userProfile.bio = value;
    notifyListeners();
  }

  List<String> get achievements => _userProfile.achievements;
  set achievements(List<String> value) {
    _userProfile.achievements = value;
    notifyListeners();
  }

  List<String> get favoriteClassIds => _userProfile.favoriteClassIds;

  Future<void> toggleFavoriteClass(String classId) async {
    final favorites = List<String>.from(_userProfile.favoriteClassIds);
    if (favorites.contains(classId)) {
      favorites.remove(classId);
    } else {
      favorites.add(classId);
    }

    _userProfile.favoriteClassIds = favorites;
    await writeUserProfileToDb();
  }

  Map<String, int> get categoryAttendance => _userProfile.categoryAttendance;
  set categoryAttendance(Map<String, int> value) {
    _userProfile.categoryAttendance = value;
    notifyListeners();
  }

  List<String> get specialties => _userProfile.specialties;
  set specialties(List<String> value) {
    _userProfile.specialties = value;
    notifyListeners();
  }

  int get yearsTeaching => _userProfile.yearsTeaching;
  set yearsTeaching(int value) {
    _userProfile.yearsTeaching = value;
    notifyListeners();
  }

  bool get isActiveInstructor => _userProfile.isActiveInstructor;
  set isActiveInstructor(bool value) {
    _userProfile.isActiveInstructor = value;
    notifyListeners();
  }

  bool get allowClassCreation => _userProfile.allowClassCreation;
  set allowClassCreation(bool value) {
    _userProfile.allowClassCreation = value;
    notifyListeners();
  }

  bool get pushNotificationsEnabled => _userProfile.pushNotificationsEnabled;
  set pushNotificationsEnabled(bool value) {
    _userProfile.pushNotificationsEnabled = value;
    notifyListeners();
  }

  bool get standbyAlertsEnabled => _userProfile.standbyAlertsEnabled;
  set standbyAlertsEnabled(bool value) {
    _userProfile.standbyAlertsEnabled = value;
    notifyListeners();
  }

  bool get darkModeEnabled => _userProfile.darkModeEnabled;
  set darkModeEnabled(bool value) {
    _userProfile.darkModeEnabled = value;
    notifyListeners();
  }

  int get accountCreationTime => _userProfile.accountCreationTime;
  set accountCreation(int value) {
    _userProfile.accountCreationTime = value;
    notifyListeners();
  }

  ImageProvider? get userImage => _userImage;
  set userImage(ImageProvider? value) {
    _userImage = value;
    notifyListeners();
  }

  bool get userChangeInProgress => _userChangeInProgress;
  set userChangeInProgress(bool value) {
    _userChangeInProgress = value;
    notifyListeners();
  }

  DateTime get dateLastPasswordChange => _userProfile.dateLastPasswordChange;
  set dateLastPasswordChange(DateTime value) {
    _userProfile.dateLastPasswordChange = value;
    writeUserProfileToDb();
  }

  bool get internetIssues => _internetIssues;
  set internetIssues(bool value) {
    _internetIssues = value;
    notifyListeners();
  }

  AccountCreationStep get accountCreationStep =>
      _userProfile.accountCreationStep;
  set accountCreationStep(AccountCreationStep value) {
    _userProfile.accountCreationStep = value;
    notifyListeners();
  }

  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////
  // UTILITY METHODS
  ////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////
  // This method initializes the UserProfileProvider with the
  // ProviderAuth so that it can be utilized later.
  ////////////////////////////////////////////////////////////////////////
  Future<void> initProviders(ProviderAuth providerAuth) async {
    _providerAuth = providerAuth;
    providerAuth.isSigningOut = false;

    // Ensure the proper permissions are granted
    if (!kIsWeb) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }

      status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
  }

  ////////////////////////////////////////////////////////////////////////
  // Returns true if the user is a developer (examining both the old and
  // new ways to check)
  ////////////////////////////////////////////////////////////////////////
  bool isDeveloper() {
    return permissionLevel == PermissionLevel.DEVELOPER;
  }

  ////////////////////////////////////////////////////////////////////////
  // This function clears all of the information stored in this
  // provider
  ////////////////////////////////////////////////////////////////////////
  Future<void> wipeAndCancelDbStream({
    bool? deletingAccount,
    bool preserveTheme = true,
  }) async {
    final previousDarkModeEnabled = _userProfile.darkModeEnabled;
    _userProfile = UserProfile.empty();
    if (preserveTheme) {
      _userProfile.darkModeEnabled = previousDarkModeEnabled;
    }
    _userImage = null;
    _dataLoaded = false;
    _imageLoaded = false;
    _internetIssues = false;
    await DBUserProfile.cancelProfileUpdateStream();
    notifyListeners();
  }

  ////////////////////////////////////////////////////////////////////////
  // This function updates the entire user profile to the one being
  // passed in.
  ////////////////////////////////////////////////////////////////////////
  Future<void> updateUserProfile(UserProfile userProfile) async {
    // Whenver the user profile is updated from the DB, first check if the
    // user has authed this device since the last known password change
    await _providerAuth.ensurePasswordUpToDate();

    // If the user is authed, ensure that the email in firebase
    // is the same as the one in the user profile (it may be out of
    // sync if it was changed via the app but the user clicked to cancel
    // via a confirmation e-mail to the old e-mail)
    //await _authProvider.ensureEmailInFirebaseMatchesProfile(userProfile);

    // Update primary variables
    _userProfile = userProfile;
    _dataLoaded = true;

    // Update display name and image if needed
    await fetchUserProfileImageIfNeeded();
    notifyListeners();
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // CLOUD ACCESS METHODS
  ////////////////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////////////

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Get the user profile image from the DB helper (in GCS) and notify listeners if it is not
  // already there (notify is triggered by called method, so not done here)
  ////////////////////////////////////////////////////////////////////////////////////////////
  Future<bool> fetchUserProfileImageIfNeeded() async {
    // Ensure profile data (uid) has been loaded first
    if (!dataLoaded) {
      return false;
    }

    // Load image if not already loaded
    if (!_imageLoaded) {
      if (await DBUserProfile.fetchUserProfileImageAndSyncProvider(this)) {
        _imageLoaded = true;
        return true;
      } else {
        return false;
      }
    }

    // If made it here, we already have a profile
    return true;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Takes in a file (to an image) and uploads as new user profile image using the DB helper
  // (in GCS) and notifies listeners (notify is triggered by called method, so not done here)
  ////////////////////////////////////////////////////////////////////////////////////////////
  uploadAndSetNewUserProfileImage(Uint8List imageBytes) async {
    // Convert file to image and set (which notifies listeners) to local profile picture
    userImage = MemoryImage(imageBytes);

    // Upload image to Google Cloud Storage
    await DBUserProfile.uploadNewUserProfileImage(imageBytes, this);
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Removes user profile image using the DB helper (in GCS) and notifies listeners
  // (notify is triggered by called method, so not done here)
  ////////////////////////////////////////////////////////////////////////////////////////////
  removeUserProfileImage() async {
    // Update image
    userImage = null;

    // Remove image from Google Cloud Storage
    await DBUserProfile.deleteUserProfileImage(this);
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Get the user profile from the DB helper and notify listeners if it is not already there
  // (notify is triggered by called method, so not done here)
  ////////////////////////////////////////////////////////////////////////////////////////////
  Future<bool> fetchUserProfileIfNeeded() async {
    // If data is missing (or empty), fetch profile
    if (_userProfile.isMissingKeyData() || !_dataLoaded) {
      bool success = await DBUserProfile.fetchUserProfileAndSyncProvider(this);
      if (success) {
        _dataLoaded = true;
      }
      return success;
    }

    // If made it here, we already have a profile
    return true;
  }

  ////////////////////////////////////////////////////////////////////////////////////////////
  // Writes the user profile to the DB using the DB helper.
  ////////////////////////////////////////////////////////////////////////////////////////////
  Future<bool> writeUserProfileToDb({merge = true}) async {
    bool success = await DBUserProfile.writeUserProfile(
      _userProfile,
      merge: merge,
    );
    _dataLoaded = true;
    notifyListeners();
    return success;
  }

  void applyAchievementProgress({
    required List<String> achievements,
    required Map<String, int> categoryAttendance,
  }) {
    _userProfile.achievements = achievements;
    _userProfile.categoryAttendance = categoryAttendance;
    notifyListeners();
  }

  ////////////////////////////////////////////////////////////////////////////////
  // Deletes the account data associated with the current user.
  //
  // This method deletes the account data by calling the corresponding method in
  // the DBUserProfile class.
  ////////////////////////////////////////////////////////////////////////////////
  Future<void> deleteAccountData() async {
    await DBUserProfile.deleteAccountData(); // Delete the account data associated with the current user
  }
}
