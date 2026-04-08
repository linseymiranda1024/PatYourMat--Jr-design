import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/achievement.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';

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

class StandbyQueueResult {
  final int position;
  final bool joinedNow;

  const StandbyQueueResult({required this.position, required this.joinedNow});
}

class DBReservations {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _classesCollection = 'classes';
  static const String _registrationsCollection = 'registrations';
  static const String _standbyQueueField = 'standbyQueue';

  static Future<String?> registerForClass(
    String userId,
    GymClass gymClass, {
    String? matNumber,
  }) async {
    try {
      return await _registerForClassTransaction(
        userId,
        gymClass,
        requestedMatNumber: matNumber,
      );
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Stream<Set<int>> getReservedMatNumbersStream(String classId) {
    return _db.collection(_classesCollection).doc(classId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) return <int>{};

      final rawMats = data['reservedMats'] as List<dynamic>? ?? [];
      final reserved = <int>{};
      for (final raw in rawMats) {
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
            );
          }).toList(),
        );
  }

  static Stream<int?> getStandbyQueuePositionStream(
    String classId,
    String userId,
  ) {
    return _db.collection(_classesCollection).doc(classId).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (data == null) {
        return null;
      }

      final queue = _parseStandbyQueue(data[_standbyQueueField]);
      final index = queue.indexWhere((entry) => entry.userId == userId);
      return index == -1 ? null : index + 1;
    });
  }

  static Future<StandbyQueueResult> joinStandbyQueue(
    String userId,
    GymClass gymClass,
  ) async {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);

    try {
      return await _db.runTransaction<StandbyQueueResult>((transaction) async {
        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          throw Exception('This class no longer exists.');
        }

        final userRegistrationSnap = await transaction.get(userRegistrationRef);
        if (userRegistrationSnap.exists) {
          throw Exception('You are already registered for this class.');
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final reservedMats = _parseReservedMats(classData['reservedMats']);
        final occupiedCount = reservedMats.length;
        if (capacity <= 0) {
          throw Exception('This class cannot accept standby requests.');
        }
        if (occupiedCount < capacity) {
          throw Exception('This class still has open spots.');
        }

        final queue = _parseStandbyQueue(classData[_standbyQueueField]);
        final existingIndex = queue.indexWhere(
          (entry) => entry.userId == userId,
        );
        if (existingIndex != -1) {
          return StandbyQueueResult(
            position: existingIndex + 1,
            joinedNow: false,
          );
        }

        final updatedQueue = <StandbyQueueEntry>[
          ...queue,
          StandbyQueueEntry(userId: userId, joinedAt: DateTime.now()),
        ];

        transaction.update(classRef, {
          _standbyQueueField: updatedQueue
              .map((entry) => entry.toMap())
              .toList(),
          'status': ClassStatus.standby.name,
        });
        transaction.set(
          userRegistrationRef,
          _buildStandbyRegistrationData(gymClass),
        );

        return StandbyQueueResult(
          position: updatedQueue.length,
          joinedNow: true,
        );
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<void> cancelReservation(String userId, String classId) async {
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);
    final classRef = _db.collection(_classesCollection).doc(classId);

    try {
      await _db.runTransaction((transaction) async {
        final userRegSnap = await transaction.get(userRegistrationRef);
        if (!userRegSnap.exists) {
          return;
        }

        final userRegData = userRegSnap.data() as Map<String, dynamic>;
        final matNumber = userRegData['matNumber'] as String? ?? '';
        final currentStatus = (userRegData['status'] ?? 'CONFIRMED')
            .toString()
            .toUpperCase();

        final classSnap = await transaction.get(classRef);
        transaction.delete(userRegistrationRef);

        if (!classSnap.exists) {
          return;
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final reservedMats = _parseReservedMats(classData['reservedMats']);
        final standbyQueue = _parseStandbyQueue(classData[_standbyQueueField]);
        final queueAfterRemoval = standbyQueue
            .where((entry) => entry.userId != userId)
            .toList();

        if (currentStatus == 'STANDBY') {
          transaction.update(classRef, {
            _standbyQueueField: queueAfterRemoval
                .map((entry) => entry.toMap())
                .toList(),
            'status': _resolveClassStatus(
              filled: reservedMats.length,
              capacity: capacity,
              standbyCount: queueAfterRemoval.length,
            ).name,
          });
          return;
        }

        final nextReservedMats = {...reservedMats};
        if (matNumber.isNotEmpty) {
          nextReservedMats.remove(matNumber);
        }

        final nextQueue = [...queueAfterRemoval];
        if (capacity > 0 &&
            nextReservedMats.length < capacity &&
            nextQueue.isNotEmpty) {
          final promoted = nextQueue.removeAt(0);
          final promotedMatNumber = matNumber.isNotEmpty
              ? matNumber
              : _pickRandomAvailableMat(capacity, nextReservedMats);
          if (promotedMatNumber != null) {
            nextReservedMats.add(promotedMatNumber);
            final promotedRegistrationRef = _db
                .collection(_userProfilesCollection)
                .doc(promoted.userId)
                .collection(_registrationsCollection)
                .doc(classId);
            transaction.set(
              promotedRegistrationRef,
              _buildRegistrationDataFromClassData(
                classId,
                classData,
                promotedMatNumber,
                promotedFromStandby: true,
              ),
            );
          }
        }

        final nextFilled = nextReservedMats.length.clamp(0, capacity);

        final classUpdates = <String, dynamic>{
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'status': _resolveClassStatus(
            filled: nextFilled,
            capacity: capacity,
            standbyCount: nextQueue.length,
          ).name,
          _standbyQueueField: nextQueue.map((entry) => entry.toMap()).toList(),
          'reservedMats': nextReservedMats.toList(),
        };

        transaction.update(classRef, classUpdates);
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<void> leaveStandbyQueue(String userId, String classId) async {
    final classRef = _db.collection(_classesCollection).doc(classId);
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);

    try {
      await _db.runTransaction((transaction) async {
        final userRegistrationSnap = await transaction.get(userRegistrationRef);
        if (userRegistrationSnap.exists) {
          throw Exception(
            'You already have a confirmed reservation for this class.',
          );
        }

        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          return;
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final filled = _parseReservedMats(classData['reservedMats']).length;
        final standbyQueue = _parseStandbyQueue(classData[_standbyQueueField]);
        final updatedQueue = standbyQueue
            .where((entry) => entry.userId != userId)
            .toList();

        if (updatedQueue.length == standbyQueue.length) {
          return;
        }

        transaction.update(classRef, {
          _standbyQueueField: updatedQueue
              .map((entry) => entry.toMap())
              .toList(),
          'status': _resolveClassStatus(
            filled: filled,
            capacity: capacity,
            standbyCount: updatedQueue.length,
          ).name,
        });
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
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

  static Future<String> _registerForClassTransaction(
    String userId,
    GymClass gymClass, {
    String? requestedMatNumber,
  }) {
    final classRef = _db.collection(_classesCollection).doc(gymClass.id);
    final userRegistrationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(gymClass.id);

    return _db.runTransaction<String>((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final capacity = _asInt(classData['capacity']);
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      final occupiedCount = reservedMats.length;
      if (capacity <= 0 || occupiedCount >= capacity) {
        throw Exception('Class is Full');
      }

      final selectedMatNumber = requestedMatNumber == null
          ? _pickRandomAvailableMat(capacity, reservedMats)
          : _normalizeMatNumber(requestedMatNumber, capacity);
      if (selectedMatNumber == null) {
        throw Exception('Class is Full');
      }
      if (reservedMats.contains(selectedMatNumber)) {
        throw Exception('That mat is already reserved.');
      }

      final nextFilled = occupiedCount + 1;
      transaction.set(
        userRegistrationRef,
        _buildRegistrationData(gymClass, selectedMatNumber),
      );
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'status': nextFilled >= capacity
            ? ClassStatus.standby.name
            : ClassStatus.open.name,
        'reservedMats': FieldValue.arrayUnion([selectedMatNumber]),
      });
      return selectedMatNumber;
    });
  }

  static Map<String, dynamic> _buildRegistrationData(
    GymClass gymClass,
    String matNumber,
  ) {
    return _buildRegistrationDataFromClassData(
      gymClass.id,
      gymClass.toFirestore(),
      matNumber,
    );
  }

  static Map<String, dynamic> _buildStandbyRegistrationData(GymClass gymClass) {
    return {
      'classId': gymClass.id,
      'className': gymClass.title,
      'instructor': gymClass.instructor,
      'dateTime': '${gymClass.dateText} at ${gymClass.timeText}',
      'date': Timestamp.fromDate(gymClass.dateTime),
      'type': normalizeGymClassType(gymClass.type),
      'matNumber': 'Standby Queue',
      'status': 'STANDBY',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _buildRegistrationDataFromClassData(
    String classId,
    Map<String, dynamic> classData,
    String matNumber, {
    bool promotedFromStandby = false,
  }) {
    final title = (classData['title'] ?? 'Untitled Class').toString();
    final instructor = (classData['instructor'] ?? 'Unknown Instructor')
        .toString();
    final classDateTime = classData['dateTime'] is Timestamp
        ? (classData['dateTime'] as Timestamp).toDate()
        : DateTime.now();
    final normalizedType = normalizeGymClassType(
      classData['type'] as String? ?? classData['category'] as String?,
    );

    return {
      'classId': classId,
      'className': title,
      'instructor': instructor,
      'dateTime': '${_dateText(classDateTime)} at ${_timeText(classDateTime)}',
      'date': Timestamp.fromDate(classDateTime),
      'type': normalizedType,
      'matNumber': matNumber,
      'status': 'CONFIRMED',
      'promotedFromStandby': promotedFromStandby,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static String _friendlyFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to complete this action.';
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

  static Set<String> _parseReservedMats(dynamic rawValue) {
    if (rawValue is! List) {
      return <String>{};
    }

    return rawValue
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static List<StandbyQueueEntry> _parseStandbyQueue(dynamic rawValue) {
    if (rawValue is! List) {
      return <StandbyQueueEntry>[];
    }

    return rawValue
        .whereType<Map>()
        .map(
          (value) =>
              StandbyQueueEntry.fromMap(Map<String, dynamic>.from(value)),
        )
        .where((entry) => entry.userId.isNotEmpty)
        .toList();
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

  static String? _pickRandomAvailableMat(
    int capacity,
    Set<String> reservedMats,
  ) {
    final availableMatNumbers = List<int>.generate(
      capacity,
      (index) => index + 1,
    ).where((matNumber) => !reservedMats.contains('Mat #$matNumber')).toList();
    if (availableMatNumbers.isEmpty) {
      return null;
    }

    return 'Mat #${availableMatNumbers[Random().nextInt(availableMatNumbers.length)]}';
  }

  static String _normalizeMatNumber(String rawValue, int capacity) {
    final match = RegExp(r'(\d+)').firstMatch(rawValue);
    final matNumber = int.tryParse(match?.group(1) ?? '');
    if (matNumber == null || matNumber <= 0 || matNumber > capacity) {
      throw Exception('Invalid mat selection.');
    }
    return 'Mat #$matNumber';
  }

  static ClassStatus _resolveClassStatus({
    required int filled,
    required int capacity,
    required int standbyCount,
  }) {
    if (filled >= capacity) {
      return ClassStatus.standby;
    }
    return ClassStatus.open;
  }

  static String _dateText(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}';
  }

  static String _timeText(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }
}
