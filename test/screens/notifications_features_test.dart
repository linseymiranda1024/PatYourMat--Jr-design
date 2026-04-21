import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pat_your_mat/models/gym_class.dart';
import 'package:pat_your_mat/models/reservation.dart';
import 'package:pat_your_mat/models/user_profile.dart';
import 'package:pat_your_mat/providers/provider_user_profile.dart';
import 'package:pat_your_mat/screens/notifications_screen.dart';
import 'package:pat_your_mat/main.dart';

class FakeProviderUserProfile extends ProviderUserProfile {
  FakeProviderUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required UserRole role,
  }) {
    this.uid = uid;
    this.firstName = firstName;
    this.lastName = lastName;
    this.role = role;
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeProviderUserProfile profile;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    profile = FakeProviderUserProfile(
      uid: 'user-1',
      firstName: 'Test',
      lastName: 'User',
      role: UserRole.MEMBER,
    );
  });

  testWidgets('Clear All Notifications functionality works', (tester) async {
    // Add some notifications
    await firestore
        .collection('user_profiles')
        .doc('user-1')
        .collection('notifications')
        .add({
      'type': 'friend',
      'title': 'New Friend',
      'message': 'Someone followed you',
      'created_at': Timestamp.now(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: MaterialApp(
          home: Scaffold(
            body: NotificationsScreen(
              firestore: firestore,
              reservations: const <Reservation>[],
              managedClasses: const <GymClass>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify notification is there
    expect(find.text('New Friend'), findsOneWidget);

    // Tap Clear All button
    final clearAllButton = find.byTooltip('Clear All');
    expect(clearAllButton, findsOneWidget);
    await tester.tap(clearAllButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Clear notifications?'), findsOneWidget);
    
    // Tap Clear All in dialog
    await tester.tap(find.text('Clear All').last);
    await tester.pumpAndSettle();

    // Verify notification is gone
    expect(find.text('New Friend'), findsNothing);
    expect(find.text('You are all caught up.'), findsOneWidget);
    
    // Verify Firestore is empty
    final snapshot = await firestore
        .collection('user_profiles')
        .doc('user-1')
        .collection('notifications')
        .get();
    expect(snapshot.docs.length, 0);
  });

  testWidgets('Swipe to delete notification works', (tester) async {
     // Add a notification
    final docRef = await firestore
        .collection('user_profiles')
        .doc('user-1')
        .collection('notifications')
        .add({
      'type': 'friend',
      'title': 'Delete Me',
      'message': 'Swipe me away',
      'created_at': Timestamp.now(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [providerUserProfile.overrideWith((ref) => profile)],
        child: MaterialApp(
          home: Scaffold(
            body: NotificationsScreen(
              firestore: firestore,
              reservations: const <Reservation>[],
              managedClasses: const <GymClass>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify notification is there
    expect(find.text('Delete Me'), findsOneWidget);

    // Swipe to delete
    await tester.drag(find.text('Delete Me'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Verify notification is gone from UI
    expect(find.text('Delete Me'), findsNothing);
    
    // Verify Firestore is empty
    final snapshot = await firestore
        .collection('user_profiles')
        .doc('user-1')
        .collection('notifications')
        .get();
    expect(snapshot.docs.length, 0);
  });
}
