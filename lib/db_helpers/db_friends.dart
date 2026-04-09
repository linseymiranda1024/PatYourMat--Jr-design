import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DBFriends {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _friendsSubcollection = 'friends';
  static const String _sentRequestsSubcollection = 'sent_friend_requests';
  static const String _receivedRequestsSubcollection =
      'received_friend_requests';
  static const String _notificationsSubcollection = 'notifications';

  @visibleForTesting
  static void useFirestoreInstance(FirebaseFirestore firestore) {
    _db = firestore;
  }

  @visibleForTesting
  static void resetFirestoreInstance() {
    try {
      _db = FirebaseFirestore.instance;
    } catch (_) {
      // Tests may override the Firestore instance without initializing Firebase.
    }
  }

  static Future<void> addFriend({
    required String fromUid,
    required String fromName,
    required String toUid,
  }) async {
    final cleanFromUid = fromUid.trim();
    final cleanToUid = toUid.trim();
    if (cleanFromUid.isEmpty ||
        cleanToUid.isEmpty ||
        cleanFromUid == cleanToUid) {
      throw Exception('Invalid friend.');
    }

    final currentUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_friendsSubcollection)
        .doc(cleanToUid);
    final existingFriendship = await currentUserFriendRef.get();
    if (existingFriendship.exists) {
      throw Exception('You are already friends.');
    }

    final otherUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection(_friendsSubcollection)
        .doc(cleanFromUid);
    final batch = _db.batch();
    batch.set(currentUserFriendRef, <String, dynamic>{
      'uid': cleanToUid,
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.set(otherUserFriendRef, <String, dynamic>{
      'uid': cleanFromUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection('notifications')
        .doc();
    batch.set(notificationRef, <String, dynamic>{
      'title': 'New friend',
      'message': '$fromName added you as a friend.',
      'type': 'friend',
      'is_read': false,
      'from_uid': cleanFromUid,
      'from_name': fromName,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
  }) async {
    final cleanFromUid = fromUid.trim();
    final cleanToUid = toUid.trim();
    final cleanFromName = fromName.trim().isEmpty ? 'Someone' : fromName.trim();
    if (cleanFromUid.isEmpty ||
        cleanToUid.isEmpty ||
        cleanFromUid == cleanToUid) {
      throw Exception(
        'Invalid friend request: UIDs cannot be empty or identical.',
      );
    }

    final existingFriendshipDoc = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_friendsSubcollection)
        .doc(cleanToUid)
        .get();
    if (existingFriendshipDoc.exists) {
      throw Exception('You are already friends with this user.');
    }

    final existingSentRequest = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanToUid)
        .get();
    if (existingSentRequest.exists) {
      throw Exception('Friend request already sent.');
    }

    final existingReceivedRequest = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanToUid)
        .get();
    if (existingReceivedRequest.exists) {
      throw Exception(
        'This user has already sent you a friend request. Check your requests.',
      );
    }

    final batch = _db.batch();

    final senderSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanToUid);
    batch.set(senderSentRequestRef, <String, dynamic>{
      'uid': cleanToUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    final receiverReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanFromUid);
    batch.set(receiverReceivedRequestRef, <String, dynamic>{
      'uid': cleanFromUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(notificationRef, <String, dynamic>{
      'title': 'New Friend Request',
      'message': '$cleanFromName wants to be friends with you.',
      'type': 'friend_request',
      'is_read': false,
      'from_uid': cleanFromUid,
      'from_name': cleanFromName,
      'created_at': FieldValue.serverTimestamp(),
      'request_id': receiverReceivedRequestRef.id,
    });

    await batch.commit();
  }

  static Future<void> acceptFriendRequest({
    required String currentUid,
    required String targetUid,
    String? currentName,
    String? notificationId,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanTargetUid = targetUid.trim();
    final displayName = currentName?.trim().isNotEmpty == true
        ? currentName!.trim()
        : 'Someone';
    if (cleanCurrentUid.isEmpty ||
        cleanTargetUid.isEmpty ||
        cleanCurrentUid == cleanTargetUid) {
      throw Exception('Invalid friend request acceptance.');
    }

    final batch = _db.batch();

    final currentUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_friendsSubcollection)
        .doc(cleanTargetUid);
    batch.set(currentUserFriendRef, <String, dynamic>{
      'uid': cleanTargetUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    final targetUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_friendsSubcollection)
        .doc(cleanCurrentUid);
    batch.set(targetUserFriendRef, <String, dynamic>{
      'uid': cleanCurrentUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    final currentUserReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanTargetUid);
    batch.delete(currentUserReceivedRequestRef);

    final targetUserSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanCurrentUid);
    batch.delete(targetUserSentRequestRef);

    if (notificationId != null && notificationId.trim().isNotEmpty) {
      final notificationRef = _db
          .collection(_userProfilesCollection)
          .doc(cleanCurrentUid)
          .collection(_notificationsSubcollection)
          .doc(notificationId.trim());
      batch.update(notificationRef, <String, dynamic>{
        'is_read': true,
        'type': 'friend_request_response',
        'title': 'Friend Request Accepted',
        'message': 'You accepted $displayName\'s friend request.',
        'from_uid': cleanTargetUid,
        'from_name': displayName,
      });
    }

    final targetNotificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(targetNotificationRef, <String, dynamic>{
      'title': 'Friend Request Accepted',
      'message': '$displayName accepted your friend request.',
      'type': 'friend_request_response',
      'is_read': false,
      'from_uid': cleanCurrentUid,
      'from_name': displayName,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> declineFriendRequest({
    required String currentUid,
    required String targetUid,
    String? currentName,
    String? notificationId,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanTargetUid = targetUid.trim();
    final displayName = currentName?.trim().isNotEmpty == true
        ? currentName!.trim()
        : 'Someone';
    if (cleanCurrentUid.isEmpty ||
        cleanTargetUid.isEmpty ||
        cleanCurrentUid == cleanTargetUid) {
      throw Exception('Invalid friend request decline.');
    }

    final batch = _db.batch();

    final currentUserReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanTargetUid);
    batch.delete(currentUserReceivedRequestRef);

    final targetUserSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanCurrentUid);
    batch.delete(targetUserSentRequestRef);

    if (notificationId != null && notificationId.trim().isNotEmpty) {
      final notificationRef = _db
          .collection(_userProfilesCollection)
          .doc(cleanCurrentUid)
          .collection(_notificationsSubcollection)
          .doc(notificationId.trim());
      batch.update(notificationRef, <String, dynamic>{
        'is_read': true,
        'type': 'friend_request_response',
        'title': 'Friend Request Declined',
        'message': 'You declined $displayName\'s friend request.',
        'from_uid': cleanTargetUid,
        'from_name': displayName,
      });
    }

    final targetNotificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(targetNotificationRef, <String, dynamic>{
      'title': 'Friend Request Declined',
      'message': '$displayName declined your friend request.',
      'type': 'friend_request_response',
      'is_read': false,
      'from_uid': cleanCurrentUid,
      'from_name': displayName,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> removeFriend({
    required String currentUid,
    required String friendUid,
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanFriendUid = friendUid.trim();
    if (cleanCurrentUid.isEmpty ||
        cleanFriendUid.isEmpty ||
        cleanCurrentUid == cleanFriendUid) {
      throw Exception('Invalid friend.');
    }

    final currentUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_friendsSubcollection)
        .doc(cleanFriendUid);
    final otherUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanFriendUid)
        .collection(_friendsSubcollection)
        .doc(cleanCurrentUid);

    final batch = _db.batch();
    batch.delete(currentUserFriendRef);
    batch.delete(otherUserFriendRef);
    await batch.commit();
  }
}
