import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/gym_class.dart';
import '../models/reservation.dart';

class DBReservations {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _classesCollection = 'classes';
  static const String _registrationsCollection = 'registrations';
  static const String _standbyQueueCollection = 'standby_queue';

  static Future<String?> registerForClass(String userId, GymClass gymClass) async {
    final matNumber = _buildMatNumber();
    final checkInCode = _buildCheckInCode();

    try {
      await _registerWithClassTracking(userId, gymClass, matNumber, checkInCode);
      return matNumber;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _registerUserOnly(userId, gymClass, matNumber, checkInCode);
        return matNumber;
      }
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<int> joinStandbyQueue(String userId, GymClass gymClass) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);
    final standbyQueueRef = classRef.collection(_standbyQueueCollection).doc(userId);

    return _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        final existingStatus = (userRegistrationSnap.data() ?? const {})['status'];
        if (existingStatus == 'STANDBY') {
          throw Exception('You are already in the standby queue for this class.');
        }
        throw Exception('You are already registered for this class.');
      }

      final standbySnap = await transaction.get(standbyQueueRef);
      if (standbySnap.exists) {
        throw Exception('You are already in the standby queue for this class.');
      }

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final currentFilled = _asInt(data['filled'] ?? data['registeredCount']);
      final currentStandbyCount = _asInt(data['standbyCount']);

      if (capacity <= 0 || currentFilled < capacity) {
        throw Exception('This class has room available. Please reserve directly.');
      }

      final joinedAtEpochMicros = DateTime.now().toUtc().microsecondsSinceEpoch;
      final nextStandbyCount = currentStandbyCount + 1;

      transaction.set(standbyQueueRef, {
        'userId': userId,
        'classId': gymClass.id,
        'joinedAtEpochMicros': joinedAtEpochMicros,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        userRegistrationRef,
        _buildStandbyRegistrationData(
          gymClass: gymClass,
          joinedAtEpochMicros: joinedAtEpochMicros,
        ),
      );

      transaction.update(classRef, {
        'standbyCount': nextStandbyCount,
        'status': _resolveClassStatus(
          capacity: capacity,
          filled: currentFilled,
          standbyCount: nextStandbyCount,
        ).name,
      });

      return nextStandbyCount;
    });
  }

  static Stream<List<Reservation>> getReservationsStream(String userId) {
    return _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Reservation(
                id: doc.id,
                className: data['className'] ?? '',
                instructor: data['instructor'] ?? '',
                dateTime: data['dateTime'] ?? '',
                matNumber: data['matNumber'] ?? '',
                status: data['status'] ?? 'CONFIRMED',
                date: data['date'] is Timestamp
                    ? (data['date'] as Timestamp).toDate()
                    : DateTime.now(),
                checkInCode: data['checkInCode'],
              );
            }).toList());
  }

  static Stream<int?> getStandbyPositionStream(String classId, String userId) {
    return _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_standbyQueueCollection)
        .orderBy('joinedAtEpochMicros')
        .snapshots()
        .map((snapshot) {
          for (var index = 0; index < snapshot.docs.length; index++) {
            if (snapshot.docs[index].id == userId) {
              return index + 1;
            }
          }
          return null;
        });
  }

  static Future<void> cancelReservation(String userId, String classId) async {
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);
    final classRef = _db.collection(_classesCollection).doc(classId);
    final classRegistrationRef = _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_registrationsCollection)
        .doc(userId);
    final standbyQueueRef = _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_standbyQueueCollection)
        .doc(userId);

    try {
      await _db.runTransaction((transaction) async {
        final userRegSnap = await transaction.get(userRegistrationRef);
        if (!userRegSnap.exists) {
          return;
        }

        final userData = userRegSnap.data() ?? const {};
        final reservationStatus = userData['status'] ?? 'CONFIRMED';
        final classSnap = await transaction.get(classRef);

        if (!classSnap.exists) {
          transaction.delete(userRegistrationRef);
          transaction.delete(classRegistrationRef);
          transaction.delete(standbyQueueRef);
          return;
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final currentFilled = _asInt(classData['filled'] ?? classData['registeredCount']);
        final currentStandbyCount = _asInt(classData['standbyCount']);

        if (reservationStatus == 'STANDBY') {
          final nextStandbyCount = (currentStandbyCount - 1).clamp(0, 1000000).toInt();
          transaction.delete(userRegistrationRef);
          transaction.delete(standbyQueueRef);
          transaction.update(classRef, {
            'standbyCount': nextStandbyCount,
            'status': _resolveClassStatus(
              capacity: capacity,
              filled: currentFilled,
              standbyCount: nextStandbyCount,
            ).name,
          });
          return;
        }

        final nextFilled = (currentFilled - 1).clamp(0, 1000000).toInt();

        transaction.delete(userRegistrationRef);
        transaction.delete(classRegistrationRef);

        final promotedEntry = await _getFirstStandbyEntry(transaction, classId);
        if (promotedEntry != null) {
          final promotedUserId = promotedEntry.id;
          final promotedStandbyRef = _db
              .collection(_classesCollection)
              .doc(classId)
              .collection(_standbyQueueCollection)
              .doc(promotedUserId);
          final promotedUserRegistrationRef = _db
              .collection(_userProfilesCollection)
              .doc(promotedUserId)
              .collection(_registrationsCollection)
              .doc(classId);
          final promotedClassRegistrationRef = _db
              .collection(_classesCollection)
              .doc(classId)
              .collection(_registrationsCollection)
              .doc(promotedUserId);

          final promotedMat = _buildMatNumber();
          final promotedCheckInCode = _buildCheckInCode();
          final promotedFilled = nextFilled + 1;
          final promotedStandbyCount =
              (currentStandbyCount - 1).clamp(0, 1000000).toInt();

          transaction.delete(promotedStandbyRef);
          transaction.set(
            promotedUserRegistrationRef,
            _buildRegistrationDataFromClassMap(
              classId: classId,
              classData: classData,
              matNumber: promotedMat,
              checkInCode: promotedCheckInCode,
            ),
          );
          transaction.set(promotedClassRegistrationRef, {
            'userId': promotedUserId,
            'classId': classId,
            'createdAt': FieldValue.serverTimestamp(),
            'promotionSource': 'standby_queue',
          });
          transaction.update(classRef, {
            'filled': promotedFilled,
            'registeredCount': promotedFilled,
            'standbyCount': promotedStandbyCount,
            'status': _resolveClassStatus(
              capacity: capacity,
              filled: promotedFilled,
              standbyCount: promotedStandbyCount,
            ).name,
          });
          return;
        }

        transaction.update(classRef, {
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'status': _resolveClassStatus(
            capacity: capacity,
            filled: nextFilled,
            standbyCount: currentStandbyCount,
          ).name,
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await userRegistrationRef.delete();
        return;
      }
      throw Exception(_friendlyFirestoreError(e));
    } catch (e) {
      rethrow;
    }
  }

  static String _friendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to register right now.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again.';
      default:
        return e.message ?? 'Unable to complete request right now.';
    }
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String _buildMatNumber() {
    final mat = Random().nextInt(30) + 1;
    return 'Mat #$mat';
  }

  static String _buildCheckInCode() {
    return 'CHECKIN-${Random().nextInt(900000) + 100000}';
  }

  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _getFirstStandbyEntry(
    Transaction transaction,
    String classId,
  ) async {
    final queueQuery = await _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_standbyQueueCollection)
        .orderBy('joinedAtEpochMicros')
        .limit(1)
        .get();

    if (queueQuery.docs.isEmpty) {
      return null;
    }

    final headRef = queueQuery.docs.first.reference;
    final headSnap = await transaction.get(headRef);
    if (!headSnap.exists) {
      return null;
    }

    return queueQuery.docs.first;
  }

  static Future<void> _registerWithClassTracking(
    String userId,
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);
    final classRegistrationRef = _db
        .collection(_classesCollection)
        .doc(gymClass.id)
        .collection(_registrationsCollection)
        .doc(userId);
    final standbyQueueRef = _db
        .collection(_classesCollection)
        .doc(gymClass.id)
        .collection(_standbyQueueCollection)
        .doc(userId);

    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final standbySnap = await transaction.get(standbyQueueRef);
      if (standbySnap.exists) {
        throw Exception('You are already in the standby queue for this class.');
      }

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final currentFilled = _asInt(data['filled'] ?? data['registeredCount']);
      final currentStandbyCount = _asInt(data['standbyCount']);

      if (capacity <= 0 || currentFilled >= capacity) {
        throw Exception('The class is already at full capacity.');
      }

      final nextFilled = currentFilled + 1;
      transaction.set(userRegistrationRef, _buildRegistrationData(gymClass, matNumber, checkInCode));
      transaction.set(classRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'status': _resolveClassStatus(
          capacity: capacity,
          filled: nextFilled,
          standbyCount: currentStandbyCount,
        ).name,
      });
    });
  }

  static Future<void> _registerUserOnly(
    String userId,
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) async {
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);

    await _db.runTransaction((transaction) async {
      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      transaction.set(userRegistrationRef, _buildRegistrationData(gymClass, matNumber, checkInCode));
    });
  }

  static ClassStatus _resolveClassStatus({
    required int capacity,
    required int filled,
    required int standbyCount,
  }) {
    if (capacity > 0 && filled >= capacity) {
      return standbyCount > 0 ? ClassStatus.standby : ClassStatus.full;
    }
    return ClassStatus.open;
  }

  static Map<String, dynamic> _buildRegistrationData(
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) {
    return {
      'className': gymClass.title,
      'instructor': gymClass.instructor,
      'dateTime': '${gymClass.dateText} at ${gymClass.timeText}',
      'date': Timestamp.fromDate(gymClass.dateTime),
      'matNumber': matNumber,
      'status': 'CONFIRMED',
      'checkInCode': checkInCode,
      'classId': gymClass.id,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _buildStandbyRegistrationData({
    required GymClass gymClass,
    required int joinedAtEpochMicros,
  }) {
    return {
      'className': gymClass.title,
      'instructor': gymClass.instructor,
      'dateTime': '${gymClass.dateText} at ${gymClass.timeText}',
      'date': Timestamp.fromDate(gymClass.dateTime),
      'matNumber': 'Standby Queue',
      'status': 'STANDBY',
      'classId': gymClass.id,
      'joinedAtEpochMicros': joinedAtEpochMicros,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _buildRegistrationDataFromClassMap({
    required String classId,
    required Map<String, dynamic> classData,
    required String matNumber,
    required String checkInCode,
  }) {
    final classDateTime = classData['dateTime'] is Timestamp
        ? (classData['dateTime'] as Timestamp).toDate()
        : DateTime.now();

    final gymClass = GymClass(
      id: classId,
      title: classData['title'] ?? 'Untitled Class',
      instructor: classData['instructor'] ?? 'Unknown Instructor',
      dateTime: classDateTime,
      durationMinutes: _asInt(classData['durationMinutes']),
      location: classData['location'] ?? 'No Location',
      capacity: _asInt(classData['capacity']),
      filled: _asInt(classData['filled'] ?? classData['registeredCount']),
      standbyCount: _asInt(classData['standbyCount']),
      status: _resolveClassStatus(
        capacity: _asInt(classData['capacity']),
        filled: _asInt(classData['filled'] ?? classData['registeredCount']),
        standbyCount: _asInt(classData['standbyCount']),
      ),
    );

    return _buildRegistrationData(gymClass, matNumber, checkInCode);
  }
}
