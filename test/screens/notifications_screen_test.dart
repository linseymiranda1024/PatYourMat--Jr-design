import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pat_your_mat/main.dart';
import 'package:pat_your_mat/models/gym_class.dart';
import 'package:pat_your_mat/models/reservation.dart';
import 'package:pat_your_mat/models/user_profile.dart';
import 'package:pat_your_mat/providers/provider_user_profile.dart';
import 'package:pat_your_mat/screens/notifications_screen.dart';

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
  testWidgets(
    'notifications screen renders pending sent group invites when present',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('classes')
          .doc('class-1')
          .collection('pending_group_invites')
          .doc('friend-1')
          .set({
            'invitee_uid': 'friend-1',
            'inviter_uid': 'host-1',
            'invitee_name': 'Jamie',
            'class_name': 'Sunrise Yoga',
            'class_time': Timestamp.fromDate(DateTime(2100, 1, 1, 9)),
            'reserved_mat_number': 'Mat #2',
            'status': 'pending',
            'expires_at': Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 5)),
            ),
            'created_at': Timestamp.fromDate(DateTime.now()),
          });

      final profile = FakeProviderUserProfile(
        uid: 'host-1',
        firstName: 'Pat',
        lastName: 'Host',
        role: UserRole.MEMBER,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [providerUserProfile.overrideWith((ref) => profile)],
          child: MaterialApp(
            home: NotificationsScreen(
              firestore: firestore,
              reservations: const <Reservation>[],
              managedClasses: const <GymClass>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Group Invites'), findsOneWidget);
      expect(find.text('Jamie'), findsOneWidget);
      expect(find.text('Invite sent for Sunrise Yoga'), findsOneWidget);
      expect(find.textContaining('Waiting'), findsOneWidget);
    },
  );
}
