import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/db_helpers/db_friends.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    DBFriends.useFirestoreInstance(firestore);
  });

  tearDown(() {
    DBFriends.resetFirestoreInstance();
  });

  test(
    'sendFriendRequest creates sent, received, and notification records',
    () async {
      await DBFriends.sendFriendRequest(
        fromUid: 'user-a',
        fromName: 'Alex',
        toUid: 'user-b',
      );

      final sentRequest = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('sent_friend_requests')
          .doc('user-b')
          .get();
      final receivedRequest = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('received_friend_requests')
          .doc('user-a')
          .get();
      final notifications = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('notifications')
          .get();

      expect(sentRequest.exists, isTrue);
      expect(receivedRequest.exists, isTrue);
      expect(notifications.docs, hasLength(1));
      expect(notifications.docs.single.data()['type'], 'friend_request');
      expect(notifications.docs.single.data()['from_uid'], 'user-a');
      expect(notifications.docs.single.data()['from_name'], 'Alex');
    },
  );

  test(
    'acceptFriendRequest creates friendship and clears request records',
    () async {
      await DBFriends.sendFriendRequest(
        fromUid: 'user-a',
        fromName: 'Alex',
        toUid: 'user-b',
      );
      final notificationId =
          (await firestore
                  .collection('user_profiles')
                  .doc('user-b')
                  .collection('notifications')
                  .get())
              .docs
              .single
              .id;

      await DBFriends.acceptFriendRequest(
        currentUid: 'user-b',
        targetUid: 'user-a',
        currentName: 'Blair',
        notificationId: notificationId,
      );

      final friendA = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('friends')
          .doc('user-b')
          .get();
      final friendB = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('friends')
          .doc('user-a')
          .get();
      final sentRequest = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('sent_friend_requests')
          .doc('user-b')
          .get();
      final receivedRequest = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('received_friend_requests')
          .doc('user-a')
          .get();
      final recipientNotification = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('notifications')
          .doc(notificationId)
          .get();
      final senderNotifications = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('notifications')
          .get();

      expect(friendA.exists, isTrue);
      expect(friendB.exists, isTrue);
      expect(sentRequest.exists, isFalse);
      expect(receivedRequest.exists, isFalse);
      expect(recipientNotification.data()?['type'], 'friend_request_response');
      expect(senderNotifications.docs, hasLength(1));
      expect(
        senderNotifications.docs.single.data()['type'],
        'friend_request_response',
      );
      expect(senderNotifications.docs.single.data()['from_name'], 'Blair');
    },
  );

  test(
    'declineFriendRequest clears request docs and notifies sender',
    () async {
      await DBFriends.sendFriendRequest(
        fromUid: 'user-a',
        fromName: 'Alex',
        toUid: 'user-b',
      );
      final notificationId =
          (await firestore
                  .collection('user_profiles')
                  .doc('user-b')
                  .collection('notifications')
                  .get())
              .docs
              .single
              .id;

      await DBFriends.declineFriendRequest(
        currentUid: 'user-b',
        targetUid: 'user-a',
        currentName: 'Blair',
        notificationId: notificationId,
      );

      final sentRequest = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('sent_friend_requests')
          .doc('user-b')
          .get();
      final receivedRequest = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('received_friend_requests')
          .doc('user-a')
          .get();
      final recipientNotification = await firestore
          .collection('user_profiles')
          .doc('user-b')
          .collection('notifications')
          .doc(notificationId)
          .get();
      final senderNotifications = await firestore
          .collection('user_profiles')
          .doc('user-a')
          .collection('notifications')
          .get();

      expect(sentRequest.exists, isFalse);
      expect(receivedRequest.exists, isFalse);
      expect(recipientNotification.data()?['type'], 'friend_request_response');
      expect(senderNotifications.docs, hasLength(1));
      expect(
        senderNotifications.docs.single.data()['message'],
        contains('declined'),
      );
    },
  );
}
