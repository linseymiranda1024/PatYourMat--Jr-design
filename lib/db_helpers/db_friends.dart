import 'package:cloud_firestore/cloud_firestore.dart';

class DBFriends {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _friendsSubcollection = 'friends';

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
