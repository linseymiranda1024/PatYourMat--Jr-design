import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/db_helpers/db_reservations.dart';
import 'package:pat_your_mat/models/gym_class.dart';
import 'package:pat_your_mat/models/reservation.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  GymClass buildClass({
    required String id,
    required DateTime dateTime,
    int capacity = 12,
    int filled = 0,
    String type = 'Cardio',
  }) {
    return GymClass(
      id: id,
      title: 'Lunch Ride',
      description: 'Intervals and endurance work',
      type: type,
      instructor: 'Jordan',
      dateTime: dateTime,
      durationMinutes: 60,
      location: 'Studio B',
      capacity: capacity,
      filled: filled,
    );
  }

  Future<void> seedUserProfile(
    String userId, {
    String firstName = 'Pat',
    String lastName = 'Member',
    String email = 'pat@example.com',
    int noShowCount = 0,
    DateTime? noShowPenaltyUntil,
  }) async {
    await firestore.collection('user_profiles').doc(userId).set({
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': 'Member',
      'no_show_count': noShowCount,
      if (noShowPenaltyUntil != null)
        'no_show_penalty_until': Timestamp.fromDate(noShowPenaltyUntil),
    });
  }

  Future<void> seedClass(
    GymClass gymClass, {
    List<String> reservedMats = const <String>[],
    Map<String, dynamic> roster = const <String, dynamic>{},
  }) async {
    await firestore.collection('classes').doc(gymClass.id).set({
      ...gymClass.toFirestore(),
      'reservedMats': reservedMats,
      'roster': roster,
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    DBReservations.useFirestoreInstance(firestore);
  });

  tearDown(() {
    DBReservations.resetFirestoreInstance();
  });

  test('registerForClass still creates mirrored reservation records', () async {
    final gymClass = buildClass(
      id: 'class-1',
      dateTime: DateTime(2026, 5, 20, 13),
    );
    await seedUserProfile('member-1');
    await seedClass(gymClass);

    final matNumber = await DBReservations.registerForClass(
      'member-1',
      gymClass,
      matNumber: 'Mat #3',
    );

    final userRegistration = await firestore
        .collection('user_profiles')
        .doc('member-1')
        .collection('registrations')
        .doc('class-1')
        .get();
    final classRegistration = await firestore
        .collection('classes')
        .doc('class-1')
        .collection('registrations')
        .doc('member-1')
        .get();
    final classDoc = await firestore.collection('classes').doc('class-1').get();
    final classData = classDoc.data()!;
    final rosterEntry =
        (classData['roster'] as Map<String, dynamic>)['member-1']
            as Map<String, dynamic>;

    expect(matNumber, 'Mat #3');
    expect(userRegistration.exists, isTrue);
    expect(classRegistration.exists, isTrue);
    expect(userRegistration.data()?['status'], ReservationStatus.confirmed);
    expect(classRegistration.data()?['status'], ReservationStatus.confirmed);
    expect(userRegistration.data()?['matNumber'], 'Mat #3');
    expect(classRegistration.data()?['matNumber'], 'Mat #3');
    expect(classData['filled'], 1);
    expect(classData['registeredCount'], 1);
    expect(classData['reservedMats'], ['Mat #3']);
    expect(rosterEntry['status'], ReservationStatus.confirmed);
    expect(rosterEntry['matNumber'], 'Mat #3');
  });

  test(
    'registerForClass is blocked while a no-show penalty is active',
    () async {
      final gymClass = buildClass(
        id: 'class-2',
        dateTime: DateTime(2026, 5, 20, 15),
      );
      await seedUserProfile(
        'member-2',
        noShowPenaltyUntil: DateTime(2100, 1, 1),
      );
      await seedClass(gymClass);

      await expectLater(
        DBReservations.registerForClass('member-2', gymClass),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('You cannot sign up for classes until'),
          ),
        ),
      );

      final userRegistration = await firestore
          .collection('user_profiles')
          .doc('member-2')
          .collection('registrations')
          .doc('class-2')
          .get();

      expect(userRegistration.exists, isFalse);
    },
  );

  test(
    'syncMemberNoShows updates user, class registration, and roster mirrors',
    () async {
      final gymClass = buildClass(
        id: 'class-3',
        dateTime: DateTime(2026, 4, 1, 9),
      );
      await seedUserProfile('member-3', noShowCount: 2);
      await seedClass(
        gymClass,
        reservedMats: const ['Mat #1'],
        roster: <String, dynamic>{
          'member-3': <String, dynamic>{
            'userId': 'member-3',
            'userName': 'Pat Member',
            'userEmail': 'pat@example.com',
            'matNumber': 'Mat #1',
            'status': ReservationStatus.confirmed,
          },
        },
      );
      await firestore
          .collection('user_profiles')
          .doc('member-3')
          .collection('registrations')
          .doc('class-3')
          .set({
            'classId': 'class-3',
            'status': ReservationStatus.confirmed,
            'date': Timestamp.fromDate(gymClass.dateTime),
            'durationMinutes': 60,
          });
      await firestore
          .collection('classes')
          .doc('class-3')
          .collection('registrations')
          .doc('member-3')
          .set({
            'classId': 'class-3',
            'status': ReservationStatus.confirmed,
            'date': Timestamp.fromDate(gymClass.dateTime),
            'durationMinutes': 60,
          });

      final penaltyState = await DBReservations.syncMemberNoShows(
        'member-3',
        now: DateTime(2026, 4, 2, 12),
      );

      final userRegistration = await firestore
          .collection('user_profiles')
          .doc('member-3')
          .collection('registrations')
          .doc('class-3')
          .get();
      final classRegistration = await firestore
          .collection('classes')
          .doc('class-3')
          .collection('registrations')
          .doc('member-3')
          .get();
      final classDoc = await firestore
          .collection('classes')
          .doc('class-3')
          .get();
      final profileDoc = await firestore
          .collection('user_profiles')
          .doc('member-3')
          .get();
      final profileData = profileDoc.data()!;
      final rosterEntry =
          (classDoc.data()!['roster'] as Map<String, dynamic>)['member-3']
              as Map<String, dynamic>;

      expect(penaltyState.noShowCount, 0);
      expect(penaltyState.penaltyUntil, DateTime(2026, 5, 1, 10));
      expect(userRegistration.data()?['status'], ReservationStatus.noShow);
      expect(classRegistration.data()?['status'], ReservationStatus.noShow);
      expect(rosterEntry['status'], ReservationStatus.noShow);
      expect(profileData['no_show_count'], 0);
      expect(
        (profileData['no_show_penalty_until'] as Timestamp).toDate(),
        DateTime(2026, 5, 1, 10),
      );
    },
  );

  test(
    'joinStandbyQueue still adds the user to the full class queue',
    () async {
      final gymClass = buildClass(
        id: 'class-4',
        dateTime: DateTime(2026, 5, 21, 18),
        capacity: 1,
        filled: 1,
      );
      await seedUserProfile('member-4');
      await seedClass(gymClass, reservedMats: const ['Mat #1']);

      await DBReservations.joinStandbyQueue('member-4', gymClass);

      final standbyDoc = await firestore
          .collection('classes')
          .doc('class-4')
          .collection('standby_queue')
          .doc('member-4')
          .get();
      final classDoc = await firestore
          .collection('classes')
          .doc('class-4')
          .get();

      expect(standbyDoc.exists, isTrue);
      expect(standbyDoc.data()?['userName'], 'Pat Member');
      expect(classDoc.data()?['standbyCount'], 1);
    },
  );

  test(
    'checkInUser updates mirrored reservation records and member progress',
    () async {
      final classStart = DateTime.now().add(const Duration(minutes: 10));
      final gymClass = buildClass(
        id: 'class-5',
        dateTime: classStart,
        type: 'Cardio',
      );
      await seedUserProfile('member-5');
      await seedClass(
        gymClass,
        reservedMats: const ['Mat #2'],
        roster: <String, dynamic>{
          'member-5': <String, dynamic>{
            'userId': 'member-5',
            'userName': 'Pat Member',
            'userEmail': 'pat@example.com',
            'matNumber': 'Mat #2',
            'status': ReservationStatus.confirmed,
          },
        },
      );
      await firestore
          .collection('user_profiles')
          .doc('member-5')
          .collection('registrations')
          .doc('class-5')
          .set({
            'classId': 'class-5',
            'className': gymClass.title,
            'instructor': gymClass.instructor,
            'date': Timestamp.fromDate(gymClass.dateTime),
            'durationMinutes': gymClass.durationMinutes,
            'matNumber': 'Mat #2',
            'status': ReservationStatus.confirmed,
          });
      await firestore
          .collection('classes')
          .doc('class-5')
          .collection('registrations')
          .doc('member-5')
          .set({
            'classId': 'class-5',
            'className': gymClass.title,
            'instructor': gymClass.instructor,
            'date': Timestamp.fromDate(gymClass.dateTime),
            'durationMinutes': gymClass.durationMinutes,
            'matNumber': 'Mat #2',
            'status': ReservationStatus.confirmed,
          });

      final result = await DBReservations.checkInUser(
        'member-5',
        Reservation(
          id: 'class-5',
          className: gymClass.title,
          instructor: gymClass.instructor,
          dateTime: '${gymClass.dateText} at ${gymClass.timeText}',
          matNumber: 'Mat #2',
          date: gymClass.dateTime,
          durationMinutes: gymClass.durationMinutes,
        ),
        gymClass,
      );

      final userRegistration = await firestore
          .collection('user_profiles')
          .doc('member-5')
          .collection('registrations')
          .doc('class-5')
          .get();
      final classRegistration = await firestore
          .collection('classes')
          .doc('class-5')
          .collection('registrations')
          .doc('member-5')
          .get();
      final classDoc = await firestore
          .collection('classes')
          .doc('class-5')
          .get();
      final profileDoc = await firestore
          .collection('user_profiles')
          .doc('member-5')
          .get();
      final profileData = profileDoc.data()!;
      final rosterEntry =
          (classDoc.data()!['roster'] as Map<String, dynamic>)['member-5']
              as Map<String, dynamic>;

      expect(result.categoryAttendance, {'Cardio': 1});
      expect(result.achievements, containsAll(const ['demo_day', 'starter']));
      expect(
        result.newlyUnlockedAchievementIds,
        containsAll(const ['demo_day', 'starter']),
      );
      expect(userRegistration.data()?['status'], ReservationStatus.attended);
      expect(classRegistration.data()?['status'], ReservationStatus.attended);
      expect(rosterEntry['status'], ReservationStatus.attended);
      expect(profileData['category_attendance'], {'Cardio': 1});
      expect(
        profileData['achievements'],
        containsAll(const ['demo_day', 'starter']),
      );
    },
  );
}
