import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/achievement.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../util/date_time/util_attendance.dart';

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
  static const String _rosterField = 'roster';

  static DocumentReference<Map<String, dynamic>> _userRegistrationRef(
    String userId,
    String classId,
  ) {
    return _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection(_registrationsCollection)
        .doc(classId);
  }

  static CollectionReference<Map<String, dynamic>>
  _classRegistrationsCollection(String classId) {
    return _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_registrationsCollection);
  }

  static DocumentReference<Map<String, dynamic>> _classRegistrationRef(
    String classId,
    String userId,
  ) {
    return _classRegistrationsCollection(classId).doc(userId);
  }

  static DocumentReference<Map<String, dynamic>> _classRef(String classId) {
    return _db.collection(_classesCollection).doc(classId);
  }

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
        .asyncMap((snapshot) async {
          final reservations = <Reservation>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final classId = data['classId'] as String?;
            int durationMinutes = 60;
            
            if (classId != null && classId.isNotEmpty) {
              try {
                final classSnap = await _classRef(classId).get();
                final classData = classSnap.data();
                if (classData != null) {
                  durationMinutes = resolveClassDurationMinutes(
                    _asInt(classData['durationMinutes']),
                  );
                }
              } catch (_) {
                // Fall back to default duration if class not found
              }
            }
            
            reservations.add(
              Reservation.fromMap({
                ...data,
                'userId': data['userId'] ?? userId,
                'durationMinutes': durationMinutes,
                'date': data['date'] is Timestamp
                    ? (data['date'] as Timestamp).toDate()
                    : DateTime.now(),
              }, id: doc.id),
            );
          }
          return reservations;
        });
  }

  static Stream<List<Reservation>> getReservationsForClassStream(
    String classId,
  ) {
    return _classRef(classId).snapshots().asyncMap((doc) async {
      final classData = doc.data() ?? <String, dynamic>{};
      final classDurationMinutes = resolveClassDurationMinutes(
        _asInt(classData['durationMinutes']),
      );
      final classTitle = classData['title']?.toString() ?? '';
      final classInstructor = classData['instructor']?.toString() ?? '';
      final classType = normalizeGymClassType(classData['type']?.toString() ?? '');
      final classDateTime = classData['dateTime'] is Timestamp
          ? (classData['dateTime'] as Timestamp).toDate()
          : DateTime.now();

      // Calculate formatted date and time strings
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final classDateText = '${weekdays[classDateTime.weekday - 1]}, ${months[classDateTime.month - 1]} ${classDateTime.day}';
      final hour = classDateTime.hour > 12 ? classDateTime.hour - 12 : (classDateTime.hour == 0 ? 12 : classDateTime.hour);
      final amPm = classDateTime.hour >= 12 ? 'PM' : 'AM';
      final minute = classDateTime.minute.toString().padLeft(2, '0');
      final classTimeText = '$hour:$minute $amPm';

      final rosterReservations = _reservationsFromRoster(
        classId,
        classData[_rosterField],
        classDurationMinutes: classDurationMinutes,
        classTitle: classTitle,
        classInstructor: classInstructor,
        classType: classType,
        classDateTime: classDateTime,
        classDateText: classDateText,
        classTimeText: classTimeText,
      );
      if (rosterReservations.isNotEmpty) {
        return _sortReservations(rosterReservations);
      }

      final legacyReservations = await _loadLegacyClassReservations(classId);
      if (legacyReservations.isNotEmpty) {
        return _sortReservations(legacyReservations);
      }

      return const <Reservation>[];
    });
  }

  static Stream<int> getReservationCountForClassStream(String classId) {
    return _classRef(classId).snapshots().map((doc) {
      final classData = doc.data() ?? <String, dynamic>{};
      final roster = classData[_rosterField];
      if (roster is Map && roster.isNotEmpty) {
        return roster.length;
      }

      final reservedMats = classData['reservedMats'];
      if (reservedMats is List) {
        return reservedMats
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .length;
      }

      return _asInt(classData['filled'] ?? classData['registeredCount']);
    });
  }

  static Future<void> cancelReservation(String userId, String classId) async {
    final userRegistrationRef = _userRegistrationRef(userId, classId);
    final classRegistrationRef = _classRegistrationRef(classId, userId);
    final classRef = _classRef(classId);

    try {
      await _db.runTransaction((transaction) async {
        final userRegSnap = await transaction.get(userRegistrationRef);
        if (!userRegSnap.exists) {
          return;
        }

        final userRegData = userRegSnap.data() as Map<String, dynamic>;
        final matNumber = userRegData['matNumber'] as String? ?? '';

        final classSnap = await transaction.get(classRef);
        transaction.delete(userRegistrationRef);
        transaction.delete(classRegistrationRef);

        if (!classSnap.exists) {
          return;
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final reservedMats = _parseReservedMats(classData['reservedMats']);
        final hadReservedMat =
            matNumber.isNotEmpty && reservedMats.contains(matNumber);
        final nextFilled =
            (hadReservedMat ? reservedMats.length - 1 : reservedMats.length)
                .clamp(0, capacity);

        final classUpdates = <String, dynamic>{
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'status': nextFilled >= capacity
              ? ClassStatus.full.name
              : ClassStatus.open.name,
          _rosterEntryField(userId): FieldValue.delete(),
        };
        if (matNumber.isNotEmpty) {
          classUpdates['reservedMats'] = FieldValue.arrayRemove([matNumber]);
        }

        transaction.update(classRef, classUpdates);
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
    if (!isAttendanceWindowOpen(
      gymClass.dateTime,
      durationMinutes: gymClass.durationMinutes,
    )) {
      throw Exception(
        'Attendance is only available from 30 minutes before class until class ends.',
      );
    }

    final userProfileRef = _db.collection(_userProfilesCollection).doc(userId);
    final reservationRef = _userRegistrationRef(userId, reservationId);
    final classReservationRef = _classRegistrationRef(reservationId, userId);
    final classRef = _classRef(reservationId);

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

      if (currentStatus != ReservationStatus.attended) {
        final type = normalizeGymClassType(gymClass.type);
        nextCategoryAttendance[type] = (nextCategoryAttendance[type] ?? 0) + 1;

        transaction.set(reservationRef, {
          'status': ReservationStatus.attended,
          'attendedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(classReservationRef, {
          'status': ReservationStatus.attended,
          'attendedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.update(classRef, {
          _rosterStatusField(userId): ReservationStatus.attended,
          _rosterAttendedAtField(userId): FieldValue.serverTimestamp(),
        });
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
    final classRef = _classRef(gymClass.id);
    final userProfileRef = _db.collection(_userProfilesCollection).doc(userId);
    final userRegistrationRef = _userRegistrationRef(userId, gymClass.id);
    final classRegistrationRef = _classRegistrationRef(gymClass.id, userId);

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
      final userProfileSnap = await transaction.get(userProfileRef);
      final userProfileData = userProfileSnap.data() ?? <String, dynamic>{};
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

      final registrationData = _buildRegistrationData(
        userId: userId,
        userName: _buildUserName(userProfileData),
        userEmail: userProfileData['email']?.toString() ?? '',
        gymClass: gymClass,
        matNumber: selectedMatNumber,
      );
      final rosterData = _buildRosterData(
        userId: userId,
        userName: _buildUserName(userProfileData),
        userEmail: userProfileData['email']?.toString() ?? '',
        matNumber: selectedMatNumber,
      );
      final nextFilled = occupiedCount + 1;
      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, registrationData);
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'status': nextFilled >= capacity
            ? ClassStatus.full.name
            : ClassStatus.open.name,
        'reservedMats': FieldValue.arrayUnion([selectedMatNumber]),
        _rosterEntryField(userId): rosterData,
      });
      return selectedMatNumber;
    });
  }

  static Map<String, dynamic> _buildRegistrationData({
    required String userId,
    required String userName,
    required String userEmail,
    required GymClass gymClass,
    required String matNumber,
  }) {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'classId': gymClass.id,
      'className': gymClass.title,
      'instructor': gymClass.instructor,
      'dateTime': '${gymClass.dateText} at ${gymClass.timeText}',
      'date': Timestamp.fromDate(gymClass.dateTime),
      'type': normalizeGymClassType(gymClass.type),
      'matNumber': matNumber,
      'status': ReservationStatus.confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _buildRosterData({
    required String userId,
    required String userName,
    required String userEmail,
    required String matNumber,
  }) {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'matNumber': matNumber,
      'status': ReservationStatus.confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Reservation _reservationFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return Reservation.fromMap({
      ...data,
      'userId': data['userId'] ?? doc.reference.parent.parent?.id ?? '',
      'date': data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
    }, id: doc.id);
  }

  static Future<List<Reservation>> _loadLegacyClassReservations(
    String classId,
  ) async {
    final classDocs = await _classRegistrationsCollection(classId).get();
    if (classDocs.docs.isNotEmpty) {
      return classDocs.docs.map(_reservationFromDocument).toList();
    }

    try {
      final userProfiles = await _db.collection(_userProfilesCollection).get();
      if (userProfiles.docs.isEmpty) {
        return const <Reservation>[];
      }

      final registrationDocs = await Future.wait(
        userProfiles.docs.map(
          (profileDoc) => profileDoc.reference
              .collection(_registrationsCollection)
              .doc(classId)
              .get(),
        ),
      );

      return registrationDocs
          .where((doc) => doc.exists)
          .map(_reservationFromDocument)
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
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

  static String _buildUserName(Map<String, dynamic> userProfileData) {
    final firstName = userProfileData['first_name']?.toString().trim() ?? '';
    final lastName = userProfileData['last_name']?.toString().trim() ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    return userProfileData['email']?.toString() ?? '';
  }

  static List<Reservation> _reservationsFromRoster(
    String classId,
    dynamic rawRoster, {
    int classDurationMinutes = 60,
    String classTitle = '',
    String classInstructor = '',
    String classType = '',
    DateTime? classDateTime,
    String classDateText = '',
    String classTimeText = '',
  }) {
    if (rawRoster is! Map) {
      return const <Reservation>[];
    }

    final reservations = <Reservation>[];
    rawRoster.forEach((key, value) {
      if (value is! Map) {
        return;
      }

      final data = Map<String, dynamic>.from(
        value.map((entryKey, entryValue) => MapEntry('$entryKey', entryValue)),
      );

      // Handle both old (full data) and new (minimal data) roster formats
      final userId = data['userId'] ?? '$key';
      final userName = data['userName']?.toString() ?? '';
      final userEmail = data['userEmail']?.toString() ?? '';
      final matNumber = data['matNumber']?.toString() ?? '';
      final status = data['status']?.toString() ?? ReservationStatus.confirmed;

      // Use class data for fields that were previously duplicated
      final resolvedClassName = data['className'] ?? classTitle;
      final resolvedInstructor = data['instructor'] ?? classInstructor;
      final resolvedType = data['type'] ?? classType;
      // Always use class document's dateTime for consistency
      final resolvedDateTime = '${classDateText} at ${classTimeText}';
      final resolvedDate = classDateTime ?? DateTime.now();

      reservations.add(
        Reservation.fromMap({
          ...data,
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'classId': classId,
          'className': resolvedClassName,
          'instructor': resolvedInstructor,
          'dateTime': resolvedDateTime,
          'date': Timestamp.fromDate(resolvedDate),
          'type': resolvedType,
          'matNumber': matNumber,
          'status': status,
          'durationMinutes': classDurationMinutes,
        }, id: classId),
      );
    });
    return reservations;
  }

  static List<Reservation> _sortReservations(List<Reservation> reservations) {
    reservations.sort((a, b) {
      final matCompare = _matSortValue(
        a.matNumber,
      ).compareTo(_matSortValue(b.matNumber));
      if (matCompare != 0) {
        return matCompare;
      }

      final nameCompare = a.userName.toLowerCase().compareTo(
        b.userName.toLowerCase(),
      );
      if (nameCompare != 0) {
        return nameCompare;
      }

      return a.userEmail.toLowerCase().compareTo(b.userEmail.toLowerCase());
    });
    return reservations;
  }

  static String _rosterEntryField(String userId) => '$_rosterField.$userId';

  static String _rosterStatusField(String userId) =>
      '${_rosterEntryField(userId)}.status';

  static String _rosterAttendedAtField(String userId) =>
      '${_rosterEntryField(userId)}.attendedAt';

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

  static int _matSortValue(String matNumber) {
    final match = RegExp(r'(\d+)').firstMatch(matNumber);
    return int.tryParse(match?.group(1) ?? '') ?? 999999;
  }
}
