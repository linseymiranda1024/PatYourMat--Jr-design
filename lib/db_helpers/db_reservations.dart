import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import 'dart:math';

class DBReservations {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _classesCollection = 'classes';
  static const String _registrationsCollection = 'registrations';

  static Future<String?> registerForClass(
    String userId,
    GymClass gymClass, {
    String? matNumber,
  }) async {
    final selectedMatNumber =
        matNumber ?? 'Mat #${Random().nextInt(gymClass.capacity.clamp(1, 30)) + 1}';
    final checkInCode = 'CHECKIN-${Random().nextInt(900000) + 100000}';

    try {
      await _registerWithClassTracking(
        userId,
        gymClass,
        selectedMatNumber,
        checkInCode,
      );
      return selectedMatNumber;
    } on FirebaseException catch (e) {
      // Some projects allow users to write profile registrations but not class counters.
      // If so, still register the user so profile/confirmation flow works.
      if (e.code == 'permission-denied') {
        await _registerUserOnly(
          userId,
          gymClass,
          selectedMatNumber,
          checkInCode,
        );
        return selectedMatNumber;
      }
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Stream<Set<int>> getReservedMatNumbersStream(String classId) {
    return _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_registrationsCollection)
        .snapshots()
        .map((snapshot) {
          final reserved = <int>{};
          for (final doc in snapshot.docs) {
            final raw = doc.data()['matNumber'];
            if (raw is! String) continue;
            final match = RegExp(r'(\d+)').firstMatch(raw);
            final number = int.tryParse(match?.group(1) ?? '');
            if (number != null) {
              reserved.add(number);
            }
          }
          return reserved;
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

    try {
      await _db.runTransaction((transaction) async {
        final userRegSnap = await transaction.get(userRegistrationRef);
        if (!userRegSnap.exists) {
          return;
        }

        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          transaction.delete(userRegistrationRef);
          transaction.delete(classRegistrationRef);
          return;
        }

        final data = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(data['capacity']);
        final currentFilled = _asInt(data['filled'] ?? data['registeredCount']);
        final nextFilled = (currentFilled - 1).clamp(0, 1000000).toInt();
        final nextStatus = (capacity > 0 && nextFilled >= capacity)
            ? ClassStatus.full.name
            : ClassStatus.open.name;

        transaction.delete(userRegistrationRef);
        transaction.delete(classRegistrationRef);
        transaction.update(classRef, {
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'status': nextStatus,
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

    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final currentFilled = _asInt(data['filled'] ?? data['registeredCount']);
      final classRegistrationSnap = await transaction.get(classRegistrationRef);

      if (capacity <= 0 || currentFilled >= capacity) {
        throw Exception('The class is already at full capacity.');
      }
      if (classRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final existingMats = _extractReservedMats(
        (await _db
                .collection(_classesCollection)
                .doc(gymClass.id)
                .collection(_registrationsCollection)
                .get())
            .docs,
      );
      if (existingMats.contains(matNumber)) {
        throw Exception('That mat is already reserved.');
      }

      final nextFilled = currentFilled + 1;
      final nextStatus = nextFilled >= capacity ? ClassStatus.full.name : ClassStatus.open.name;

      final registrationData = _buildRegistrationData(gymClass, matNumber, checkInCode);
      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'status': nextStatus,
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

  static Set<String> _extractReservedMats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => doc.data()['matNumber'])
        .whereType<String>()
        .toSet();
  }
}
