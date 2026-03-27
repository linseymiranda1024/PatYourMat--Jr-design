import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/achievement.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../util/logging/app_logger.dart';
import 'dart:math';

class CheckInResult {
  final List<String> achievements;
  final Map<String, int> categoryAttendance;
  final List<String> newlyUnlockedAchievementIds;

  const CheckInResult({
    required this.achievements,
    required this.categoryAttendance,
    required this.newlyUnlockedAchievementIds,
  });
}

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
        matNumber ?? await _pickAvailableMatNumber(gymClass);
    final checkInCode = 'CHECKIN-${Random().nextInt(900000) + 100000}';

    try {
      await _registerWithClassTracking(
        userId,
        gymClass,
        selectedMatNumber,
        checkInCode,
      );
      await _syncClassTrackingState(gymClass.id);
      return selectedMatNumber;
    } on FirebaseException catch (e) {
      // Some projects allow users to write profile registrations but not class counters.
      // If so, still try to persist a class-level registration doc for accurate
      // seat counts, then fall back to user-only registration if necessary.
      if (e.code == 'permission-denied') {
        try {
          await _registerWithoutClassCounter(
            userId,
            gymClass,
            selectedMatNumber,
            checkInCode,
          );
        } on FirebaseException catch (fallbackError) {
          if (fallbackError.code == 'permission-denied') {
            try {
              await _registerWithBestEffortClassTracking(
                userId,
                gymClass,
                selectedMatNumber,
                checkInCode,
              );
            } on FirebaseException catch (bestEffortError) {
              if (bestEffortError.code == 'permission-denied') {
                AppLogger.error(
                  'Falling back to user-only registration for ${gymClass.id}. '
                  'Class registration writes are denied by Firestore. '
                  'Updating the class document directly instead.',
                );
                await _registerUserOnlyWithClassDocument(
                  userId,
                  gymClass,
                  selectedMatNumber,
                  checkInCode,
                );
              } else {
                throw Exception(_friendlyFirestoreError(bestEffortError));
              }
            }
          } else {
            throw Exception(_friendlyFirestoreError(fallbackError));
          }
        }
        await _syncClassTrackingState(gymClass.id);
        return selectedMatNumber;
      }
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Stream<Set<int>> getReservedMatNumbersStream(String classId) {
    return _db
        .collectionGroup(_registrationsCollection)
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final reserved = <int>{};
          for (final doc in snapshot.docs) {
            if (!_isUserProfileRegistrationDoc(doc.reference)) {
              continue;
            }
            final raw = (doc.data()['matNumber'] ?? '').toString().trim();
            if (raw.isEmpty) {
              continue;
            }
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
        .map(
          (snapshot) => snapshot.docs.map((doc) {
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
          }).toList(),
        );
  }

  static Future<void> ensureClassTrackingForUserReservations(
    String userId,
    List<Reservation> reservations,
  ) async {
    for (final reservation in reservations) {
      final classId = reservation.id;
      if (classId == null || classId.isEmpty || reservation.matNumber.isEmpty) {
        continue;
      }

      final classRegistrationRef = _db
          .collection(_classesCollection)
          .doc(classId)
          .collection(_registrationsCollection)
          .doc(userId);
      final classRef = _db.collection(_classesCollection).doc(classId);

      try {
        final batch = _db.batch();
        batch.set(classRegistrationRef, {
          'userId': userId,
          'classId': classId,
          'matNumber': reservation.matNumber,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batch.set(classRef, {
          'reservedMats': FieldValue.arrayUnion([reservation.matNumber]),
        }, SetOptions(merge: true));
        await batch.commit();
        await _syncClassTrackingState(classId);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
      }
    }
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

        final userRegData = userRegSnap.data() as Map<String, dynamic>;
        final matNumber = (userRegData['matNumber'] ?? '').toString();

        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          transaction.delete(userRegistrationRef);
          transaction.delete(classRegistrationRef);
          if (matNumber.isNotEmpty) {
            transaction.delete(_legacyMatRegistrationRef(classId, matNumber));
          }
          return;
        }

        final data = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(data['capacity']);
        final reservedMats = _parseReservedMats(data['reservedMats']);
        reservedMats.remove(matNumber);
        final nextReservedMats = reservedMats.toList()..sort();
        final nextFilled = nextReservedMats.length.clamp(0, capacity);
        final nextStatus = (capacity > 0 && nextFilled >= capacity)
            ? ClassStatus.full.name
            : ClassStatus.open.name;

        transaction.delete(userRegistrationRef);
        transaction.delete(classRegistrationRef);
        if (matNumber.isNotEmpty) {
          transaction.delete(_legacyMatRegistrationRef(classId, matNumber));
        }
        transaction.update(classRef, {
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'status': nextStatus,
          'reservedMats': nextReservedMats,
        });
      });
      await _syncClassTrackingState(classId);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        try {
          await _cancelWithoutClassCounter(userId, classId);
        } on FirebaseException catch (fallbackError) {
          if (fallbackError.code == 'permission-denied') {
            await _cancelUserOnlyWithClassDocument(userId, classId);
          } else {
            throw Exception(_friendlyFirestoreError(fallbackError));
          }
        }
        await _syncClassTrackingState(classId);
        return;
      }
      throw Exception(_friendlyFirestoreError(e));
    } catch (e) {
      rethrow;
    }
  }

  static Future<CheckInResult> checkInUser(
    String userId,
    Reservation reservation,
    GymClass gymClass,
  ) async {
    final reservationId = reservation.id ?? gymClass.id;
    if (reservationId.isEmpty) {
      throw Exception('Reservation is missing an id.');
    }

    final userProfileRef = _db.collection(_userProfilesCollection).doc(userId);
    final reservationRef = userProfileRef
        .collection(_registrationsCollection)
        .doc(reservationId);

    return _db.runTransaction((transaction) async {
      final reservationSnap = await transaction.get(reservationRef);
      if (!reservationSnap.exists) {
        throw Exception('Reservation not found.');
      }

      final reservationData = reservationSnap.data() as Map<String, dynamic>;
      final currentStatus = (reservationData['status'] ?? reservation.status)
          .toString()
          .toUpperCase();
      final profileSnap = await transaction.get(userProfileRef);
      final profileData = profileSnap.data() ?? <String, dynamic>{};

      final currentAchievements = List<String>.from(
        profileData['achievements'] ?? const <String>[],
      );
      final nextCategoryAttendance = _parseCategoryAttendance(
        profileData['category_attendance'],
      );

      if (currentStatus != 'ATTENDED') {
        final type = normalizeGymClassType(gymClass.type);
        nextCategoryAttendance[type] = (nextCategoryAttendance[type] ?? 0) + 1;

        transaction.set(reservationRef, {
          'status': 'ATTENDED',
          'attendedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final totalAttended = nextCategoryAttendance.values.fold<int>(
        0,
        (sum, count) => sum + count,
      );
      final unlockedAchievementIds = Achievement.evaluateUnlocks(
        totalAttended: totalAttended,
        categoryAttendance: nextCategoryAttendance,
        classDateTime: gymClass.dateTime,
      );
      final updatedAchievements = Achievement.sortAchievementIds(<String>{
        ...currentAchievements,
        ...unlockedAchievementIds,
      });
      final newlyUnlockedAchievementIds = updatedAchievements
          .where((id) => !currentAchievements.contains(id))
          .toList();

      transaction.set(userProfileRef, {
        'achievements': updatedAchievements,
        'category_attendance': nextCategoryAttendance,
      }, SetOptions(merge: true));

      return CheckInResult(
        achievements: updatedAchievements,
        categoryAttendance: nextCategoryAttendance,
        newlyUnlockedAchievementIds: newlyUnlockedAchievementIds,
      );
    });
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

  static Map<String, int> _parseCategoryAttendance(dynamic rawValue) {
    final parsed = <String, int>{};
    if (rawValue is! Map) {
      return parsed;
    }

    rawValue.forEach((key, value) {
      final normalizedKey = normalizeGymClassType('$key');
      parsed[normalizedKey] = (parsed[normalizedKey] ?? 0) + _asInt(value);
    });
    return parsed;
  }

  static Future<void> _registerWithClassTracking(
    String userId,
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final classRegistrationsRef = classRef.collection(_registrationsCollection);
    final initialClassRegistrationsSnap = await classRegistrationsRef.get();
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);
    final classRegistrationRef = classRegistrationsRef.doc(userId);
    final matRegistrationRef = _legacyMatRegistrationRef(gymClass.id, matNumber);

    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }
      final classRegistrationSnap = await transaction.get(classRegistrationRef);
      final matRegistrationSnap = await transaction.get(matRegistrationRef);

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final trackedReservedMats = _extractTrackedReservedMats(
        initialClassRegistrationsSnap.docs,
      );
      final staleMatNumber = classRegistrationSnap.exists
          ? (classRegistrationSnap.data()?['matNumber'] ?? '').toString()
          : '';
      final hasStaleClassTracking =
          classRegistrationSnap.exists && !userRegistrationSnap.exists;

      if (hasStaleClassTracking && staleMatNumber.isNotEmpty) {
        trackedReservedMats.remove(staleMatNumber);
        transaction.delete(
          _legacyMatRegistrationRef(gymClass.id, staleMatNumber),
        );
      } else if (classRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }
      final trackedMatOwnerId = (matRegistrationSnap.data()?['userId'] ?? '')
          .toString()
          .trim();
      if (trackedMatOwnerId.isNotEmpty && trackedMatOwnerId != userId) {
        throw Exception('That mat is already reserved.');
      }

      final currentFilled = trackedReservedMats.length.clamp(0, capacity);
      if (capacity <= 0 || currentFilled >= capacity) {
        throw Exception('The class is already at full capacity.');
      }
      if (trackedReservedMats.contains(matNumber)) {
        throw Exception('That mat is already reserved.');
      }

      final nextReservedMats = [...trackedReservedMats, matNumber]..sort();
      final nextFilled = nextReservedMats.length.clamp(0, capacity);
      final nextStatus = nextFilled >= capacity
          ? ClassStatus.full.name
          : ClassStatus.open.name;

      final registrationData = _buildRegistrationData(
        gymClass,
        matNumber,
        checkInCode,
      );
      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(matRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'status': nextStatus,
        'reservedMats': nextReservedMats,
      });
    });
  }

  static Future<void> _registerUserOnlyWithClassDocument(
    String userId,
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final classRegistrationsRef = classRef.collection(_registrationsCollection);
    final initialClassRegistrationsSnap = await classRegistrationsRef.get();
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);
    final matRegistrationRef = _legacyMatRegistrationRef(gymClass.id, matNumber);

    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }
      final matRegistrationSnap = await transaction.get(matRegistrationRef);

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final trackedReservedMats = _extractTrackedReservedMats(
        initialClassRegistrationsSnap.docs,
      );
      final currentFilled = trackedReservedMats.length.clamp(0, capacity);
      final trackedMatOwnerId = (matRegistrationSnap.data()?['userId'] ?? '')
          .toString()
          .trim();

      if (capacity <= 0 || currentFilled >= capacity) {
        throw Exception('The class is already at full capacity.');
      }
      if (trackedMatOwnerId.isNotEmpty && trackedMatOwnerId != userId) {
        throw Exception('That mat is already reserved.');
      }
      if (trackedReservedMats.contains(matNumber)) {
        throw Exception('That mat is already reserved.');
      }

      final nextReservedMats = [...trackedReservedMats, matNumber]..sort();
      final nextFilled = nextReservedMats.length.clamp(0, capacity);
      final nextStatus = nextFilled >= capacity
          ? ClassStatus.full.name
          : ClassStatus.open.name;

      transaction.set(
        userRegistrationRef,
        _buildRegistrationData(gymClass, matNumber, checkInCode),
      );
      transaction.set(matRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'reservedMats': nextReservedMats,
        'status': nextStatus,
      });
    });
  }

  static Future<void> _registerWithoutClassCounter(
    String userId,
    GymClass gymClass,
    String matNumber,
    String checkInCode,
  ) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final classRegistrationsRef = classRef.collection(_registrationsCollection);
    final initialClassRegistrationsSnap = await classRegistrationsRef.get();
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);
    final classRegistrationRef = classRegistrationsRef.doc(userId);
    final matRegistrationRef = _legacyMatRegistrationRef(gymClass.id, matNumber);

    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final classRegistrationSnap = await transaction.get(classRegistrationRef);
      final matRegistrationSnap = await transaction.get(matRegistrationRef);
      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final trackedReservedMats = _extractTrackedReservedMats(
        initialClassRegistrationsSnap.docs,
      );
      final staleMatNumber = classRegistrationSnap.exists
          ? (classRegistrationSnap.data()?['matNumber'] ?? '').toString()
          : '';
      if (capacity <= 0) {
        throw Exception('The class is already at full capacity.');
      }
      if (classRegistrationSnap.exists) {
        if (staleMatNumber.isNotEmpty) {
          trackedReservedMats.remove(staleMatNumber);
          transaction.delete(
            _legacyMatRegistrationRef(gymClass.id, staleMatNumber),
          );
        } else {
          throw Exception('You are already registered for this class.');
        }
      }
      final trackedMatOwnerId = (matRegistrationSnap.data()?['userId'] ?? '')
          .toString()
          .trim();
      if (trackedMatOwnerId.isNotEmpty && trackedMatOwnerId != userId) {
        throw Exception('That mat is already reserved.');
      }
      if (trackedReservedMats.contains(matNumber)) {
        throw Exception('That mat is already reserved.');
      }

      transaction.set(
        userRegistrationRef,
        _buildRegistrationData(gymClass, matNumber, checkInCode),
      );
      transaction.set(classRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(matRegistrationRef, {
        'userId': userId,
        'classId': gymClass.id,
        'matNumber': matNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(classRef, {
        'reservedMats': [...trackedReservedMats, matNumber]..sort(),
      });
    });
  }

  static Future<void> _registerWithBestEffortClassTracking(
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
    final classRegistrationRef = _db
        .collection(_classesCollection)
        .doc(gymClass.id)
        .collection(_registrationsCollection)
        .doc(userId);

    final batch = _db.batch();
    final registrationData = _buildRegistrationData(
      gymClass,
      matNumber,
      checkInCode,
    );

    // Some Firestore rules block the read phase required by transactions but
    // still allow direct writes to the registration docs. This keeps class
    // occupancy and taken mats in sync for the UI even when class counters
    // cannot be updated directly.
    batch.set(userRegistrationRef, registrationData);
    batch.set(classRegistrationRef, {
      'userId': userId,
      'classId': gymClass.id,
      'matNumber': matNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> _cancelWithoutClassCounter(
    String userId,
    String classId,
  ) async {
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);
    final userRegistrationSnap = await userRegistrationRef.get();
    if (!userRegistrationSnap.exists) {
      return;
    }

    final data = userRegistrationSnap.data() as Map<String, dynamic>;
    final matNumber = (data['matNumber'] ?? '').toString();
    final classRef = _db.collection(_classesCollection).doc(classId);
    final batch = _db.batch();
    batch.delete(userRegistrationRef);
    batch.delete(
      _db
          .collection(_classesCollection)
          .doc(classId)
          .collection(_registrationsCollection)
          .doc(userId),
    );
    if (matNumber.isNotEmpty) {
      batch.delete(_legacyMatRegistrationRef(classId, matNumber));
      batch.update(classRef, {
        'reservedMats': FieldValue.arrayRemove([matNumber]),
      });
    }
    await batch.commit();
  }

  static Future<void> _cancelUserOnlyWithClassDocument(
    String userId,
    String classId,
  ) async {
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);
    final classRef = _db.collection(_classesCollection).doc(classId);

    await _db.runTransaction((transaction) async {
      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (!userRegistrationSnap.exists) {
        return;
      }

      final classSnap = await transaction.get(classRef);
      final userData = userRegistrationSnap.data() as Map<String, dynamic>;
      final matNumber = (userData['matNumber'] ?? '').toString().trim();
      if (!classSnap.exists) {
        transaction.delete(userRegistrationRef);
        return;
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(classData['capacity']);
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      reservedMats.remove(matNumber);

      final nextReservedMats = reservedMats.toList()..sort();
      final nextFilled = nextReservedMats.length.clamp(0, capacity);
      final nextStatus = (capacity > 0 && nextFilled >= capacity)
          ? ClassStatus.full.name
          : ClassStatus.open.name;

      transaction.delete(userRegistrationRef);
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'reservedMats': nextReservedMats,
        'status': nextStatus,
      });
    });
  }

  static Future<void> _syncClassTrackingState(String classId) async {
    final classRef = _db.collection(_classesCollection).doc(classId);

    try {
      final classSnap = await classRef.get();
      if (!classSnap.exists) {
        return;
      }

      final data = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(data['capacity']);
      final reservedMats = await _getReservedMatsFromUserReservations(classId);
      final filled = reservedMats.length.clamp(0, capacity);
      final status = (capacity > 0 && filled >= capacity)
          ? ClassStatus.full.name
          : ClassStatus.open.name;

      await classRef.update({
        'filled': filled,
        'registeredCount': filled,
        'reservedMats': reservedMats,
        'status': status,
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
    }
  }

  static Set<String> _parseReservedMats(dynamic rawValue) {
    if (rawValue is! List) {
      return <String>{};
    }

    return rawValue
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static Set<String> _extractTrackedReservedMats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) => doc.data())
        .where(
          (data) => (data['userId'] ?? '').toString().trim().isNotEmpty,
        )
        .map((data) => (data['matNumber'] ?? '').toString().trim())
        .where((matNumber) => matNumber.isNotEmpty)
        .toSet();
  }

  static Future<List<String>> _getReservedMatsFromUserReservations(
    String classId,
  ) async {
    final snapshot = await _db
        .collectionGroup(_registrationsCollection)
        .where('classId', isEqualTo: classId)
        .get();

    return snapshot.docs
        .where((doc) => _isUserProfileRegistrationDoc(doc.reference))
        .map((doc) => (doc.data()['matNumber'] ?? '').toString().trim())
        .where((matNumber) => matNumber.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  static bool _isUserProfileRegistrationDoc(DocumentReference ref) {
    final parentDoc = ref.parent.parent;
    if (parentDoc == null) {
      return false;
    }
    return parentDoc.parent.id == _userProfilesCollection;
  }

  static DocumentReference<Map<String, dynamic>> _legacyMatRegistrationRef(
    String classId,
    String matNumber,
  ) {
    return _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_registrationsCollection)
        .doc(_matRegistrationDocId(matNumber));
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
      'type': normalizeGymClassType(gymClass.type),
      'matNumber': matNumber,
      'status': 'CONFIRMED',
      'checkInCode': checkInCode,
      'classId': gymClass.id,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Future<String> _pickAvailableMatNumber(GymClass gymClass) async {
    final reservedMats = await getReservedMatNumbersStream(gymClass.id).first;
    final safeCapacity = gymClass.capacity.clamp(1, 1000).toInt();
    final availableMats = List<int>.generate(
      safeCapacity,
      (index) => index + 1,
    ).where((mat) => !reservedMats.contains(mat)).toList();

    if (availableMats.isEmpty) {
      throw Exception('No mats are currently available for this class.');
    }

    final selectedMat = availableMats[Random().nextInt(availableMats.length)];
    return 'Mat #$selectedMat';
  }

  static String _matRegistrationDocId(String matNumber) {
    final match = RegExp(r'(\d+)').firstMatch(matNumber);
    final number = int.tryParse(match?.group(1) ?? '');
    if (number == null) {
      return 'mat_unknown';
    }
    return 'mat_$number';
  }
}
