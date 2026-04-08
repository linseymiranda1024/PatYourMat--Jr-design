import 'package:cloud_firestore/cloud_firestore.dart';

class DBFriends {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _friendsSubcollection = 'friends';
  static const String _sentRequestsSubcollection = 'sent_friend_requests';
  static const String _receivedRequestsSubcollection = 'received_friend_requests';
  static const String _notificationsSubcollection = 'notifications';

  static Future<void> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
  }) async {
    final cleanFromUid = fromUid.trim();
    final cleanToUid = toUid.trim();
    if (cleanFromUid.isEmpty ||
        cleanToUid.isEmpty ||
        cleanFromUid == cleanToUid) {
      throw Exception('Invalid friend request: UIDs cannot be empty or identical.');
    }

    // Check if already friends
    final existingFriendship = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_friendsSubcollection)
        .doc(cleanToUid);
    final existingFriendshipDoc = await existingFriendship.get();
    if (existingFriendshipDoc.exists) {
      throw Exception('You are already friends with this user.');
    }

    // Check if a request has already been sent
    final existingSentRequest = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanToUid)
        .get();
    if (existingSentRequest.exists) {
      throw Exception('Friend request already sent.');
    }

    // Check if a request has already been received from the target user
    final existingReceivedRequest = await _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanToUid)
        .get();
    if (existingReceivedRequest.exists) {
      throw Exception('This user has already sent you a friend request. Please check your requests.');
    }

    final batch = _db.batch();

    // Create a document in the sender's 'sent_friend_requests' subcollection
    final senderSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanFromUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanToUid);
    batch.set(senderSentRequestRef, <String, dynamic>{
      'uid': cleanToUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Create a document in the recipient's 'received_friend_requests' subcollection
    final receiverReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanFromUid);
    batch.set(receiverReceivedRequestRef, <String, dynamic>{
      'uid': cleanFromUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Send a notification to the recipient
    final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanToUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(notificationRef, <String, dynamic>{
      'title': 'New Friend Request',
      'message': '$fromName wants to be friends with you.',
      'type': 'friend_request',
      'is_read': false,
      'from_uid': cleanFromUid,
      'from_name': fromName,
      'created_at': FieldValue.serverTimestamp(),
      'request_id': receiverReceivedRequestRef.id, // Store the ID of the received request document
    });

    await batch.commit();
  }

  static Future<void> acceptFriendRequest({
    required String currentUid,
    required String targetUid,
    String? notificationId, // Made optional
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanTargetUid = targetUid.trim();
    if (cleanCurrentUid.isEmpty || cleanTargetUid.isEmpty || cleanCurrentUid == cleanTargetUid) {
      throw Exception('Invalid friend request acceptance.');
    }

    final batch = _db.batch();

    // Add targetUid to currentUid's friends
    final currentUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_friendsSubcollection)
        .doc(cleanTargetUid);
    batch.set(currentUserFriendRef, <String, dynamic>{
      'uid': cleanTargetUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Add currentUid to targetUid's friends
    final targetUserFriendRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_friendsSubcollection)
        .doc(cleanCurrentUid);
    batch.set(targetUserFriendRef, <String, dynamic>{
      'uid': cleanCurrentUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Delete the received request from currentUid
    final currentUserReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanTargetUid);
    batch.delete(currentUserReceivedRequestRef);

    // Delete the sent request from targetUid
    final targetUserSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanCurrentUid);
    batch.delete(targetUserSentRequestRef);

    // Mark the notification as read or delete it (for the current user)
    if (notificationId != null && notificationId.isNotEmpty) {
      final notificationRef = _db
          .collection(_userProfilesCollection)
          .doc(cleanCurrentUid)
          .collection(_notificationsSubcollection)
          .doc(notificationId);
      batch.update(notificationRef, {'is_read': true, 'type': 'friend_request_accepted'}); // Or delete it
    }

    // Send a notification to the target user that the request was accepted
    final targetNotificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(targetNotificationRef, <String, dynamic>{
      'title': 'Friend Request Accepted',
      'message': 'Your friend request to ${cleanCurrentUid} was accepted.', // Will be replaced by name in UI
      'type': 'friend_request_response',
      'is_read': false,
      'from_uid': cleanCurrentUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  static Future<void> declineFriendRequest({
    required String currentUid,
    required String targetUid,
    String? notificationId, // Made optional
  }) async {
    final cleanCurrentUid = currentUid.trim();
    final cleanTargetUid = targetUid.trim();
    if (cleanCurrentUid.isEmpty || cleanTargetUid.isEmpty || cleanCurrentUid == cleanTargetUid) {
      throw Exception('Invalid friend request decline.');
    }

    final batch = _db.batch();

    // Delete the received request from currentUid
    final currentUserReceivedRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_receivedRequestsSubcollection)
        .doc(cleanTargetUid);
    batch.delete(currentUserReceivedRequestRef);

    // Delete the sent request from targetUid
    final targetUserSentRequestRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_sentRequestsSubcollection)
        .doc(cleanCurrentUid);
    batch.delete(targetUserSentRequestRef);

    // Mark the notification as read or delete it (for the current user)
    if (notificationId != null && notificationId.isNotEmpty) {
      final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanCurrentUid)
        .collection(_notificationsSubcollection)
        .doc(notificationId);
      batch.update(notificationRef, {'is_read': true, 'type': 'friend_request_declined'}); // Or delete it
    }

    // Send a notification to the target user that the request was declined
    final targetNotificationRef = _db
        .collection(_userProfilesCollection)
        .doc(cleanTargetUid)
        .collection(_notificationsSubcollection)
        .doc();
    batch.set(targetNotificationRef, <String, dynamic>{
      'title': 'Friend Request Declined',
      'message': 'Your friend request to ${cleanCurrentUid} was declined.', // Will be replaced by name in UI
      'type': 'friend_request_response',
      'is_read': false,
      'from_uid': cleanCurrentUid,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
