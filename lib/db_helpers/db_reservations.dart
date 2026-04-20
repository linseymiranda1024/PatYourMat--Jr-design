import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

import '../models/achievement.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../util/date_time/util_attendance.dart';
import '../util/date_time/util_no_show_penalty.dart';

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

class GroupReservationResult {
  final String hostMatNumber;
  final List<String> reservedMatNumbers;
  final int invitesSent;
  final List<String> skippedInviteeUids;

  const GroupReservationResult({
    required this.hostMatNumber,
    required this.reservedMatNumbers,
    required this.invitesSent,
    this.skippedInviteeUids = const <String>[],
  });
}

class _StandbyQueueSnapshot {
  final String? frontUserId;
  final int count;

  const _StandbyQueueSnapshot({required this.frontUserId, required this.count});

  bool get hasEntries => count > 0 && frontUserId != null;

  int get countAfterFrontRemoval => count > 0 ? count - 1 : 0;
}

class _OverdueNoShowCandidate {
  final String classId;
  final DocumentReference<Map<String, dynamic>> userRegistrationRef;
  final DocumentReference<Map<String, dynamic>> classRegistrationRef;
  final DocumentReference<Map<String, dynamic>> classRef;
  final DateTime classEnd;
  final bool hasRosterEntry;

  const _OverdueNoShowCandidate({
    required this.classId,
    required this.userRegistrationRef,
    required this.classRegistrationRef,
    required this.classRef,
    required this.classEnd,
    required this.hasRosterEntry,
  });
}

class DBReservations {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _userProfilesCollection = 'user_profiles';
  static const String _classesCollection = 'classes';
  static const String _registrationsCollection = 'registrations';
  static const String _standbyQueueCollection = 'standby_queue';
  static const String _rosterField = 'roster';
  static const int _whereInChunkSize = 10;

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
    String? bookingRole,
  }) async {
    try {
      final penaltyState = await syncMemberNoShows(userId);
      _throwIfRegistrationBlocked(penaltyState);

      final standbyQueue = await _loadStandbyQueueSnapshot(gymClass.id);
      if (standbyQueue.hasEntries && standbyQueue.frontUserId != userId) {
        throw Exception('Standby queue has priority for the next open spot.');
      }

      return await _registerForClassTransaction(
        userId,
        gymClass,
        requestedMatNumber: matNumber,
        bookingRole: bookingRole,
        standbyQueue: standbyQueue,
      );
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<GroupReservationResult> registerForClassWithGroupInvites({
    required String hostUserId,
    required String hostName,
    required GymClass gymClass,
    required List<String> selectedMatNumbers,
    required List<String> inviteeUids,
    String? hostBookingRole,
  }) async {
    try {
      final penaltyState = await syncMemberNoShows(hostUserId);
      _throwIfRegistrationBlocked(penaltyState);

      final standbyQueue = await _loadStandbyQueueSnapshot(gymClass.id);
      if (standbyQueue.hasEntries) {
        throw Exception('Standby queue has priority for the next open spot.');
      }

      return await _db.runTransaction<GroupReservationResult>((
        transaction,
      ) async {
        final classRef = _classRef(gymClass.id);
        final hostProfileRef = _db
            .collection(_userProfilesCollection)
            .doc(hostUserId);
        final hostRegistrationRef = _userRegistrationRef(
          hostUserId,
          gymClass.id,
        );
        final hostClassRegistrationRef = _classRegistrationRef(
          gymClass.id,
          hostUserId,
        );

        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          throw Exception('This class no longer exists.');
        }

        final hostRegistrationSnap = await transaction.get(hostRegistrationRef);
        if (hostRegistrationSnap.exists) {
          throw Exception('You are already registered for this class.');
        }
        final hostClassRegistrationSnap = await transaction.get(
          hostClassRegistrationRef,
        );
        if (hostClassRegistrationSnap.exists) {
          throw Exception('You are already registered for this class.');
        }

        final hostProfileSnap = await transaction.get(hostProfileRef);
        final hostProfileData = hostProfileSnap.data() ?? <String, dynamic>{};
        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final reservedMats = _parseReservedMats(classData['reservedMats']);
        final currentStandbyCount = _asInt(classData['standbyCount']);
        if (currentStandbyCount > 0 && !standbyQueue.hasEntries) {
          throw Exception('Standby queue changed. Try again.');
        }
        final uniqueInvitees = inviteeUids
            .where((uid) => uid.trim().isNotEmpty && uid != hostUserId)
            .toSet()
            .toList();

        final eligibleInvitees = <String>[];
        final skippedInvitees = <String>[];
        for (final inviteeUid in uniqueInvitees) {
          final inviteeRegistrationSnap = await transaction.get(
            _classRegistrationRef(gymClass.id, inviteeUid),
          );
          if (inviteeRegistrationSnap.exists) {
            skippedInvitees.add(inviteeUid);
          } else {
            eligibleInvitees.add(inviteeUid);
          }
        }

        final assignedMats = _normalizeGroupMatNumbers(
          selectedMatNumbers: selectedMatNumbers,
          expectedCount: eligibleInvitees.length + 1,
          capacity: capacity,
          reservedMats: reservedMats,
        );
        final normalizedHostMat = assignedMats.first;

        final hostRegistrationData = _buildRegistrationData(
          userId: hostUserId,
          userName: _buildUserName(hostProfileData),
          userEmail: hostProfileData['email']?.toString() ?? '',
          gymClass: gymClass,
          matNumber: normalizedHostMat,
          bookingRole: hostBookingRole,
        );
        final hostRosterData = _buildRosterData(
          userId: hostUserId,
          userName: _buildUserName(hostProfileData),
          userEmail: hostProfileData['email']?.toString() ?? '',
          matNumber: normalizedHostMat,
          bookingRole: hostBookingRole,
        );

        transaction.set(hostRegistrationRef, hostRegistrationData);
        transaction.set(hostClassRegistrationRef, hostRegistrationData);

        for (var i = 0; i < eligibleInvitees.length; i++) {
          final inviteeUid = eligibleInvitees[i];
          final inviteeMatNumber = assignedMats[i + 1];
          final notificationRef = _db
              .collection(_userProfilesCollection)
              .doc(inviteeUid)
              .collection('notifications')
              .doc();

          transaction.set(notificationRef, <String, dynamic>{
            'title': 'Group class invite',
            'message':
                '$hostName invited you to join ${gymClass.title} on ${gymClass.dateText} at ${gymClass.timeText}.',
            'type': 'group_invite',
            'is_read': false,
            'from_uid': hostUserId,
            'from_name': hostName,
            'class_id': gymClass.id,
            'class_name': gymClass.title,
            'instructor': gymClass.instructor,
            'class_time': Timestamp.fromDate(gymClass.dateTime),
            'host_mat_number': normalizedHostMat,
            'reserved_mat_number': inviteeMatNumber,
            'invite_status': 'pending',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        final nextReservedMats = <String>{...reservedMats, ...assignedMats};
        final nextFilled = _normalizedFilledCount(capacity, nextReservedMats);
        transaction.update(classRef, <String, dynamic>{
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'standbyCount': standbyQueue.count,
          'status': _classStatusName(
            filled: nextFilled,
            capacity: capacity,
            standbyCount: standbyQueue.count,
          ),
          'reservedMats': _sortedReservedMats(nextReservedMats),
          _rosterEntryField(hostUserId): hostRosterData,
        });

        return GroupReservationResult(
          hostMatNumber: normalizedHostMat,
          reservedMatNumbers: assignedMats,
          invitesSent: eligibleInvitees.length,
          skippedInviteeUids: skippedInvitees,
        );
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<String?> acceptGroupInvite({
    required String userId,
    required String notificationId,
  }) async {
    final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);

    try {
      final penaltyState = await syncMemberNoShows(userId);
      _throwIfRegistrationBlocked(penaltyState);

      final notificationSnap = await notificationRef.get();
      if (!notificationSnap.exists) {
        throw Exception('Invite not found.');
      }

      final notificationData = notificationSnap.data() ?? <String, dynamic>{};
      final inviteStatus =
          notificationData['invite_status']?.toString() ?? 'pending';
      if (inviteStatus != 'pending') {
        throw Exception('This invite has already been answered.');
      }

      final classId = notificationData['class_id']?.toString() ?? '';
      if (classId.isEmpty) {
        throw Exception('This invite is missing class details.');
      }
      final reservedMatNumber =
          notificationData['reserved_mat_number']?.toString() ?? '';

      final existingRegistration = await _userRegistrationRef(
        userId,
        classId,
      ).get();
      final existingClassRegistration = await _classRegistrationRef(
        classId,
        userId,
      ).get();
      if (existingRegistration.exists || existingClassRegistration.exists) {
        await _releaseHeldInviteSpot(
          classId: classId,
          reservedMatNumber: reservedMatNumber,
        );
        await notificationRef.set(<String, dynamic>{
          'invite_status': 'accepted',
          'is_read': true,
          'responded_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _sendGroupInviteResponseNotification(
          inviterUid: notificationData['from_uid']?.toString() ?? '',
          inviteeUid: userId,
          className: notificationData['class_name']?.toString() ?? 'the class',
          accepted: true,
        );

        final existingData =
            existingRegistration.data() ??
            existingClassRegistration.data() ??
            <String, dynamic>{};
        return existingData['matNumber']?.toString();
      }

      final classSnap = await _classRef(classId).get();
      if (!classSnap.exists) {
        throw Exception('This class is no longer available.');
      }

      final gymClass = GymClass.fromFirestore(classSnap);
      final reservedMat = reservedMatNumber.trim().isEmpty
          ? await registerForClass(userId, gymClass)
          : await _claimHeldInviteSpot(
              userId: userId,
              gymClass: gymClass,
              reservedMatNumber: reservedMatNumber,
            );

      await notificationRef.set(<String, dynamic>{
        'invite_status': 'accepted',
        'is_read': true,
        'responded_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _sendGroupInviteResponseNotification(
        inviterUid: notificationData['from_uid']?.toString() ?? '',
        inviteeUid: userId,
        className: notificationData['class_name']?.toString() ?? gymClass.title,
        accepted: true,
      );

      return reservedMat;
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<void> declineGroupInvite({
    required String userId,
    required String notificationId,
  }) async {
    final notificationRef = _db
        .collection(_userProfilesCollection)
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);

    try {
      final notificationSnap = await notificationRef.get();
      if (!notificationSnap.exists) {
        throw Exception('Invite not found.');
      }

      final notificationData = notificationSnap.data() ?? <String, dynamic>{};
      final inviteStatus =
          notificationData['invite_status']?.toString() ?? 'pending';
      if (inviteStatus != 'pending') {
        throw Exception('This invite has already been answered.');
      }

      final classId = notificationData['class_id']?.toString() ?? '';
      final reservedMatNumber =
          notificationData['reserved_mat_number']?.toString() ?? '';

      if (classId.isNotEmpty && reservedMatNumber.trim().isNotEmpty) {
        await _releaseHeldInviteSpot(
          classId: classId,
          reservedMatNumber: reservedMatNumber,
        );
      }

      await notificationRef.set(<String, dynamic>{
        'invite_status': 'declined',
        'is_read': true,
        'responded_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _sendGroupInviteResponseNotification(
        inviterUid: notificationData['from_uid']?.toString() ?? '',
        inviteeUid: userId,
        className: notificationData['class_name']?.toString() ?? 'the class',
        accepted: false,
      );
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static CollectionReference<Map<String, dynamic>> _getStandbyQueueCollection(
    String classId,
  ) {
    return _db
        .collection(_classesCollection)
        .doc(classId)
        .collection(_standbyQueueCollection);
  }

  static DocumentReference<Map<String, dynamic>> _standbyQueueRef(
    String classId,
    String userId,
  ) {
    return _getStandbyQueueCollection(classId).doc(userId);
  }

  static Future<void> joinStandbyQueue(String userId, GymClass gymClass) async {
    try {
      final penaltyState = await syncMemberNoShows(userId);
      _throwIfRegistrationBlocked(penaltyState);

      final userProfileRef = _db
          .collection(_userProfilesCollection)
          .doc(userId);
      final userProfileSnap = await userProfileRef.get();
      final userProfileData = userProfileSnap.data() ?? <String, dynamic>{};
      final standbyQueue = await _loadStandbyQueueSnapshot(gymClass.id);

      final standbyRef = _standbyQueueRef(gymClass.id, userId);
      final classRef = _classRef(gymClass.id);

      await _db.runTransaction((transaction) async {
        final standbySnap = await transaction.get(standbyRef);
        if (standbySnap.exists) {
          throw Exception(
            'You are already in the standby queue for this class.',
          );
        }

        final userRegistrationSnap = await transaction.get(
          _userRegistrationRef(userId, gymClass.id),
        );
        if (userRegistrationSnap.exists) {
          throw Exception('You are already registered for this class.');
        }
        final classRegistrationSnap = await transaction.get(
          _classRegistrationRef(gymClass.id, userId),
        );
        if (classRegistrationSnap.exists) {
          throw Exception('You are already registered for this class.');
        }

        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) {
          throw Exception('This class no longer exists.');
        }

        final classData = classSnap.data() as Map<String, dynamic>;
        final capacity = _asInt(classData['capacity']);
        final reservedMats = _parseReservedMats(classData['reservedMats']);
        final currentStandbyCount = _asInt(classData['standbyCount']);
        final hasExistingStandbyQueue =
            currentStandbyCount > 0 || standbyQueue.hasEntries;
        if (!hasExistingStandbyQueue &&
            capacity > 0 &&
            reservedMats.length < capacity) {
          throw Exception('This class still has open spots.');
        }
        final nextStandbyCount = standbyQueue.count + 1;

        transaction.set(standbyRef, {
          'userId': userId,
          'userName': _buildUserName(userProfileData),
          'userEmail': userProfileData['email']?.toString() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(classRef, {
          'standbyCount': nextStandbyCount,
          'status': _classStatusName(
            filled: _normalizedFilledCount(capacity, reservedMats),
            capacity: capacity,
            standbyCount: nextStandbyCount,
          ),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<NoShowPenaltyState> syncMemberNoShows(
    String userId, {
    DateTime? now,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const NoShowPenaltyState(noShowCount: 0, penaltyUntil: null);
    }

    final referenceNow = now ?? DateTime.now();
    final userProfileRef = _db
        .collection(_userProfilesCollection)
        .doc(normalizedUserId);

    try {
      final profileSnap = await userProfileRef.get();
      final profileData = profileSnap.data() ?? <String, dynamic>{};
      final currentPenaltyState = NoShowPenaltyState(
        noShowCount: _asInt(profileData['no_show_count']),
        penaltyUntil: _resolveOptionalDateTime(
          profileData['no_show_penalty_until'],
        ),
      );

      final registrationsSnapshot = await userProfileRef
          .collection(_registrationsCollection)
          .get();
      final overdueCandidates = await _loadOverdueNoShowCandidates(
        normalizedUserId,
        registrationsSnapshot.docs,
        now: referenceNow,
      );

      final nextPenaltyState = resolveNoShowPenaltyState(
        currentNoShowCount: currentPenaltyState.noShowCount,
        currentPenaltyUntil: currentPenaltyState.penaltyUntil,
        newlyRecordedNoShowTimes: overdueCandidates.map(
          (candidate) => candidate.classEnd,
        ),
        now: referenceNow,
      );

      final shouldUpdateProfile =
          overdueCandidates.isNotEmpty ||
          currentPenaltyState.noShowCount != nextPenaltyState.noShowCount ||
          !_sameDateTime(
            currentPenaltyState.penaltyUntil,
            nextPenaltyState.penaltyUntil,
          );
      if (!shouldUpdateProfile) {
        return nextPenaltyState;
      }

      final batch = _db.batch();
      for (final candidate in overdueCandidates) {
        batch.set(candidate.userRegistrationRef, <String, dynamic>{
          'status': ReservationStatus.noShow,
          'noShowAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(candidate.classRegistrationRef, <String, dynamic>{
          'status': ReservationStatus.noShow,
          'noShowAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (candidate.hasRosterEntry) {
          batch.update(candidate.classRef, <String, dynamic>{
            _rosterStatusField(normalizedUserId): ReservationStatus.noShow,
            _rosterNoShowAtField(normalizedUserId):
                FieldValue.serverTimestamp(),
          });
        }
      }

      final profileUpdates = <String, dynamic>{
        'no_show_count': nextPenaltyState.noShowCount,
      };
      if (nextPenaltyState.penaltyUntil != null) {
        profileUpdates['no_show_penalty_until'] = Timestamp.fromDate(
          nextPenaltyState.penaltyUntil!,
        );
      } else {
        profileUpdates['no_show_penalty_until'] = FieldValue.delete();
      }
      batch.set(userProfileRef, profileUpdates, SetOptions(merge: true));

      await batch.commit();
      return nextPenaltyState;
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Stream<bool> isUserInStandby(String userId, String classId) {
    return _standbyQueueRef(
      classId,
      userId,
    ).snapshots().map((doc) => doc.exists);
  }

  static Stream<int?> getStandbyQueuePositionStream(
    String classId,
    String userId,
  ) {
    if (userId.trim().isEmpty) {
      return Stream<int?>.value(null);
    }

    return _getStandbyQueueCollection(
      classId,
    ).orderBy('createdAt').snapshots().map((snapshot) {
      for (var index = 0; index < snapshot.docs.length; index++) {
        if (snapshot.docs[index].id == userId) {
          return index + 1;
        }
      }
      return null;
    });
  }

  static Stream<Set<String>> getStandbyClassIdsStream(String userId) {
    if (userId.trim().isEmpty) {
      return Stream<Set<String>>.value(const <String>{});
    }

    return _db
        .collection(_classesCollection)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
          final classIds = <String>{};
          final classDocs = snapshot.docs;
          final standbyChecks = await Future.wait(
            classDocs.map((doc) => _standbyQueueRef(doc.id, userId).get()),
          );

          for (var index = 0; index < classDocs.length; index++) {
            if (standbyChecks[index].exists) {
              classIds.add(classDocs[index].id);
            }
          }

          return classIds;
        });
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
        .snapshots()
        .switchMap((snapshot) {
          final registrationDocs = snapshot.docs;
          if (registrationDocs.isEmpty) {
            return Stream.value(const <Reservation>[]);
          }

          final classIds = registrationDocs
              .map((doc) => _reservationClassId(doc.data(), fallbackId: doc.id))
              .where((classId) => classId.isNotEmpty)
              .toSet();

          return _watchClassesByIds(classIds).map((classesById) {
            final reservations = registrationDocs.map((doc) {
              final data = doc.data();
              final classId = _reservationClassId(data, fallbackId: doc.id);
              return Reservation.fromMap(
                {
                  ...data,
                  'userId': data['userId'] ?? userId,
                  'classId': classId,
                },
                id: classId.isEmpty ? doc.id : classId,
                resolvedClass: classesById[classId],
              );
            }).toList();

            reservations.sort((left, right) {
              final dateCompare = left.date.compareTo(right.date);
              if (dateCompare != 0) {
                return dateCompare;
              }

              return _matSortValue(
                left.matNumber,
              ).compareTo(_matSortValue(right.matNumber));
            });

            return reservations;
          });
        });
  }

  static Stream<List<Reservation>> getReservationsForClassStream(
    String classId,
  ) {
    return _classRef(classId).snapshots().asyncMap((doc) async {
      final classData = doc.data() ?? <String, dynamic>{};
      final resolvedClass = doc.exists ? GymClass.fromFirestore(doc) : null;

      final rosterReservations = _reservationsFromRoster(
        classId,
        classData[_rosterField],
        resolvedClass: resolvedClass,
      );
      if (rosterReservations.isNotEmpty) {
        return _sortReservations(rosterReservations);
      }

      final legacyReservations = await _loadLegacyClassReservations(
        classId,
        resolvedClass: resolvedClass,
      );
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
      final rosterCount = roster is Map ? roster.length : 0;
      final reservedMats = classData['reservedMats'];
      final reservedMatCount = reservedMats is List
          ? reservedMats
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .length
          : 0;
      final persistedCount = _asInt(
        classData['filled'] ?? classData['registeredCount'],
      );
      return max(rosterCount, max(reservedMatCount, persistedCount));
    });
  }

  static Future<void> leaveStandbyQueue(String userId, String classId) async {
    try {
      final standbyRef = _standbyQueueRef(classId, userId);
      final classRef = _classRef(classId);
      final standbyQueue = await _loadStandbyQueueSnapshot(classId);

      await _db.runTransaction((transaction) async {
        final standbySnap = await transaction.get(standbyRef);
        if (!standbySnap.exists) {
          return; // Already not in queue
        }

        final classSnap = await transaction.get(classRef);
        if (classSnap.exists) {
          final classData = classSnap.data() as Map<String, dynamic>;
          final capacity = _asInt(classData['capacity']);
          final reservedMats = _parseReservedMats(classData['reservedMats']);
          final actualRemainingCount = standbyQueue.count > 0
              ? standbyQueue.count - 1
              : 0;
          final nextStandbyCount = actualRemainingCount;
          transaction.update(classRef, {
            'standbyCount': nextStandbyCount,
            'status': _classStatusName(
              filled: _normalizedFilledCount(capacity, reservedMats),
              capacity: capacity,
              standbyCount: nextStandbyCount,
            ),
          });
        }

        transaction.delete(standbyRef);
      });
    } on FirebaseException catch (e) {
      throw Exception(_friendlyFirestoreError(e));
    }
  }

  static Future<void> cancelReservation(String userId, String classId) async {
    final userRegistrationRef = _userRegistrationRef(userId, classId);
    final classRegistrationRef = _classRegistrationRef(classId, userId);
    final classRef = _classRef(classId);

    try {
      final standbyQueue = await _loadStandbyQueueSnapshot(classId);
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
        final nextReservedMats = Set<String>.from(reservedMats);
        if (matNumber.isNotEmpty) {
          nextReservedMats.remove(matNumber);
        }
        final nextFilled = _normalizedFilledCount(capacity, nextReservedMats);
        final nextStandbyCount = standbyQueue.count;

        final classUpdates = <String, dynamic>{
          'filled': nextFilled,
          'registeredCount': nextFilled,
          'standbyCount': nextStandbyCount,
          'status': _classStatusName(
            filled: nextFilled,
            capacity: capacity,
            standbyCount: nextStandbyCount,
          ),
          'reservedMats': _sortedReservedMats(nextReservedMats),
          _rosterEntryField(userId): FieldValue.delete(),
        };

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
    String? bookingRole,
    _StandbyQueueSnapshot? standbyQueue,
  }) {
    final classRef = _classRef(gymClass.id);
    final userProfileRef = _db.collection(_userProfilesCollection).doc(userId);
    final userRegistrationRef = _userRegistrationRef(userId, gymClass.id);
    final classRegistrationRef = _classRegistrationRef(gymClass.id, userId);
    final userStandbyRef = _standbyQueueRef(gymClass.id, userId);

    return _db.runTransaction<String>((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        throw Exception('This class no longer exists.');
      }

      final userRegistrationSnap = await transaction.get(userRegistrationRef);
      if (userRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }
      final classRegistrationSnap = await transaction.get(classRegistrationRef);
      if (classRegistrationSnap.exists) {
        throw Exception('You are already registered for this class.');
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final userProfileSnap = await transaction.get(userProfileRef);
      final userProfileData = userProfileSnap.data() ?? <String, dynamic>{};
      final capacity = _asInt(classData['capacity']);
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      final occupiedCount = reservedMats.length;
      final currentStandbyCount = _asInt(classData['standbyCount']);
      final resolvedStandbyQueue =
          standbyQueue ??
          const _StandbyQueueSnapshot(frontUserId: null, count: 0);

      if (currentStandbyCount > 0 && !resolvedStandbyQueue.hasEntries) {
        throw Exception('Standby queue changed. Try again.');
      }

      if (resolvedStandbyQueue.hasEntries) {
        if (resolvedStandbyQueue.frontUserId != userId) {
          throw Exception('Standby queue has priority for the next open spot.');
        }

        final userStandbySnap = await transaction.get(userStandbyRef);
        if (!userStandbySnap.exists) {
          throw Exception('Standby queue changed. Try again.');
        }
      }

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
        bookingRole: bookingRole,
      );
      final rosterData = _buildRosterData(
        userId: userId,
        userName: _buildUserName(userProfileData),
        userEmail: userProfileData['email']?.toString() ?? '',
        matNumber: selectedMatNumber,
        bookingRole: bookingRole,
      );
      final nextReservedMats = <String>{...reservedMats, selectedMatNumber};
      final nextFilled = _normalizedFilledCount(capacity, nextReservedMats);
      final nextStandbyCount = resolvedStandbyQueue.hasEntries
          ? resolvedStandbyQueue.countAfterFrontRemoval
          : 0;
      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, registrationData);
      if (resolvedStandbyQueue.hasEntries) {
        transaction.delete(userStandbyRef);
      }
      transaction.update(classRef, {
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'standbyCount': nextStandbyCount,
        'status': _classStatusName(
          filled: nextFilled,
          capacity: capacity,
          standbyCount: nextStandbyCount,
        ),
        'reservedMats': _sortedReservedMats(nextReservedMats),
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
    String? bookingRole,
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
      'type': gymClass.type,
      'durationMinutes': gymClass.durationMinutes,
      'location': gymClass.location,
      'matNumber': matNumber,
      if (bookingRole != null && bookingRole.trim().isNotEmpty)
        'bookingRole': bookingRole.trim(),
      'status': ReservationStatus.confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _buildRosterData({
    required String userId,
    required String userName,
    required String userEmail,
    required String matNumber,
    String? bookingRole,
  }) {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'matNumber': matNumber,
      if (bookingRole != null && bookingRole.trim().isNotEmpty)
        'bookingRole': bookingRole.trim(),
      'status': ReservationStatus.confirmed,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static Reservation _reservationFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String reservationId,
    String fallbackUserId = '',
    GymClass? resolvedClass,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final classId = _reservationClassId(data, fallbackId: reservationId);
    final resolvedUserId =
        data['userId']?.toString() ??
        (fallbackUserId.isNotEmpty
            ? fallbackUserId
            : doc.reference.parent.parent?.id ?? '');

    return Reservation.fromMap(
      {...data, 'userId': resolvedUserId, 'classId': classId},
      id: reservationId,
      resolvedClass: resolvedClass,
    );
  }

  static Future<List<Reservation>> _loadLegacyClassReservations(
    String classId, {
    GymClass? resolvedClass,
  }) async {
    final classDocs = await _classRegistrationsCollection(classId).get();
    if (classDocs.docs.isNotEmpty) {
      return classDocs.docs
          .map(
            (doc) => _reservationFromDocument(
              doc,
              reservationId: classId,
              fallbackUserId: doc.id,
              resolvedClass: resolvedClass,
            ),
          )
          .toList();
    }

    // Do not scan every user's private registration subcollection here.
    // Members are not permitted to read other users' user_profiles/*/registrations
    // documents under current Firestore rules, so that fallback breaks the invite
    // sheet and social occupancy streams for classes without a roster mirror.
    return const <Reservation>[];
  }

  static Future<void> _sendGroupInviteResponseNotification({
    required String inviterUid,
    required String inviteeUid,
    required String className,
    required bool accepted,
  }) async {
    if (inviterUid.isEmpty) {
      return;
    }

    final inviteeProfile = await _db
        .collection(_userProfilesCollection)
        .doc(inviteeUid)
        .get();
    final inviteeData = inviteeProfile.data() ?? <String, dynamic>{};
    final inviteeName = resolveUserDisplayName(
      inviteeData,
      fallback: 'A friend',
    );

    await _db
        .collection(_userProfilesCollection)
        .doc(inviterUid)
        .collection('notifications')
        .add(<String, dynamic>{
          'title': accepted ? 'Invite accepted' : 'Invite declined',
          'message': accepted
              ? '$inviteeName joined $className.'
              : '$inviteeName declined your invite to $className.',
          'type': 'group_invite_response',
          'is_read': false,
          'from_uid': inviteeUid,
          'from_name': inviteeName,
          'class_name': className,
          'created_at': FieldValue.serverTimestamp(),
        });
  }

  static Future<String> _claimHeldInviteSpot({
    required String userId,
    required GymClass gymClass,
    required String reservedMatNumber,
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
        final existingData = userRegistrationSnap.data() ?? <String, dynamic>{};
        return existingData['matNumber']?.toString() ?? reservedMatNumber;
      }
      final classRegistrationSnap = await transaction.get(classRegistrationRef);
      if (classRegistrationSnap.exists) {
        final existingData =
            classRegistrationSnap.data() ?? <String, dynamic>{};
        return existingData['matNumber']?.toString() ?? reservedMatNumber;
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      if (!reservedMats.contains(reservedMatNumber)) {
        throw Exception('Your reserved group mat is no longer available.');
      }

      final userProfileSnap = await transaction.get(userProfileRef);
      final userProfileData = userProfileSnap.data() ?? <String, dynamic>{};

      final registrationData = _buildRegistrationData(
        userId: userId,
        userName: _buildUserName(userProfileData),
        userEmail: userProfileData['email']?.toString() ?? '',
        gymClass: gymClass,
        matNumber: reservedMatNumber,
      );
      final rosterData = _buildRosterData(
        userId: userId,
        userName: _buildUserName(userProfileData),
        userEmail: userProfileData['email']?.toString() ?? '',
        matNumber: reservedMatNumber,
      );

      transaction.set(userRegistrationRef, registrationData);
      transaction.set(classRegistrationRef, registrationData);
      transaction.update(classRef, <String, dynamic>{
        _rosterEntryField(userId): rosterData,
      });

      return reservedMatNumber;
    });
  }

  static Future<void> _releaseHeldInviteSpot({
    required String classId,
    required String reservedMatNumber,
  }) async {
    if (reservedMatNumber.trim().isEmpty) {
      return;
    }

    final classRef = _classRef(classId);
    final standbyQueue = await _loadStandbyQueueSnapshot(classId);
    await _db.runTransaction((transaction) async {
      final classSnap = await transaction.get(classRef);
      if (!classSnap.exists) {
        return;
      }

      final classData = classSnap.data() as Map<String, dynamic>;
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      if (!reservedMats.contains(reservedMatNumber)) {
        return;
      }

      final capacity = _asInt(classData['capacity']);
      final nextReservedMats = Set<String>.from(reservedMats)
        ..remove(reservedMatNumber);
      final nextFilled = _normalizedFilledCount(capacity, nextReservedMats);
      transaction.update(classRef, <String, dynamic>{
        'filled': nextFilled,
        'registeredCount': nextFilled,
        'standbyCount': standbyQueue.count,
        'status': _classStatusName(
          filled: nextFilled,
          capacity: capacity,
          standbyCount: standbyQueue.count,
        ),
        'reservedMats': _sortedReservedMats(nextReservedMats),
      });
    });
  }

  static List<String> _normalizeGroupMatNumbers({
    required List<String> selectedMatNumbers,
    required int expectedCount,
    required int capacity,
    required Set<String> reservedMats,
  }) {
    final normalized = selectedMatNumbers
        .map((matNumber) => _normalizeMatNumber(matNumber, capacity))
        .toList();

    if (normalized.length != expectedCount) {
      throw Exception(
        'Select exactly $expectedCount mat${expectedCount == 1 ? '' : 's'} for your group.',
      );
    }

    final unique = normalized.toSet().toList()
      ..sort((a, b) => _matSortValue(a).compareTo(_matSortValue(b)));
    if (unique.length != normalized.length) {
      throw Exception('Choose different mats for each person in your group.');
    }

    for (final matNumber in unique) {
      if (reservedMats.contains(matNumber)) {
        throw Exception('$matNumber is already reserved.');
      }
    }

    return normalized;
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

  static Future<_StandbyQueueSnapshot> _loadStandbyQueueSnapshot(
    String classId,
  ) async {
    final queueCollection = _getStandbyQueueCollection(classId);
    final results = await Future.wait<dynamic>([
      queueCollection.orderBy('createdAt').limit(1).get(),
      queueCollection.count().get(),
    ]);
    final frontSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final countSnapshot = results[1] as AggregateQuerySnapshot;
    final count = countSnapshot.count ?? frontSnapshot.docs.length;
    return _StandbyQueueSnapshot(
      frontUserId: frontSnapshot.docs.isEmpty
          ? null
          : frontSnapshot.docs.first.id,
      count: count,
    );
  }

  static int _normalizedFilledCount(int capacity, Set<String> reservedMats) {
    return reservedMats.length.clamp(0, capacity);
  }

  static String _classStatusName({
    required int filled,
    required int capacity,
    required int standbyCount,
  }) {
    return filled < capacity && standbyCount == 0
        ? ClassStatus.open.name
        : ClassStatus.full.name;
  }

  static List<String> _sortedReservedMats(Iterable<String> reservedMats) {
    final sorted =
        reservedMats
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (left, right) =>
                _matSortValue(left).compareTo(_matSortValue(right)),
          );
    return sorted;
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

  static String resolveUserDisplayName(
    Map<String, dynamic> userProfileData, {
    String fallback = 'Member',
  }) {
    final firstName = userProfileData['first_name']?.toString().trim() ?? '';
    final lastName = userProfileData['last_name']?.toString().trim() ?? '';
    final fullName = [
      firstName,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ').trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final email = userProfileData['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) {
      return email;
    }

    return fallback;
  }

  static String _buildUserName(Map<String, dynamic> userProfileData) {
    return resolveUserDisplayName(userProfileData);
  }

  static List<Reservation> _reservationsFromRoster(
    String classId,
    dynamic rawRoster, {
    GymClass? resolvedClass,
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

      reservations.add(
        Reservation.fromMap(
          {
            ...data,
            'userId': userId,
            'userName': userName,
            'userEmail': userEmail,
            'classId': classId,
            'matNumber': matNumber,
            'status': status,
          },
          id: classId,
          resolvedClass: resolvedClass,
        ),
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

  static String _rosterNoShowAtField(String userId) =>
      '${_rosterEntryField(userId)}.noShowAt';

  static Future<List<_OverdueNoShowCandidate>> _loadOverdueNoShowCandidates(
    String userId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> registrationDocs, {
    required DateTime now,
  }) async {
    if (registrationDocs.isEmpty) {
      return const <_OverdueNoShowCandidate>[];
    }

    final classIds = registrationDocs
        .map((doc) => _reservationClassId(doc.data(), fallbackId: doc.id))
        .where((classId) => classId.isNotEmpty)
        .toSet()
        .toList();
    final classSnapshots = await Future.wait(
      classIds.map((classId) => _classRef(classId).get()),
    );
    final classDocsById = <String, DocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in classSnapshots) doc.id: doc,
    };

    final overdueCandidates = <_OverdueNoShowCandidate>[];
    for (final doc in registrationDocs) {
      final data = doc.data();
      if (normalizeReservationStatus(data['status']?.toString()) !=
          ReservationStatus.confirmed) {
        continue;
      }

      final classId = _reservationClassId(data, fallbackId: doc.id);
      final classDoc = classDocsById[classId];
      final classData = classDoc?.data() ?? <String, dynamic>{};
      final classStart =
          _resolveOptionalDateTime(classData['dateTime']) ??
          _resolveOptionalDateTime(data['date']) ??
          _resolveOptionalDateTime(data['dateTime']);
      if (classStart == null) {
        continue;
      }

      final classEnd = attendanceWindowCloses(
        classStart,
        durationMinutes: _asInt(
          classData['durationMinutes'] ?? data['durationMinutes'],
        ),
      );
      if (!now.isAfter(classEnd)) {
        continue;
      }

      final roster = classData[_rosterField];
      final hasRosterEntry = roster is Map && roster.containsKey(userId);
      overdueCandidates.add(
        _OverdueNoShowCandidate(
          classId: classId,
          userRegistrationRef: doc.reference,
          classRegistrationRef: _classRegistrationRef(classId, userId),
          classRef: _classRef(classId),
          classEnd: classEnd,
          hasRosterEntry: hasRosterEntry,
        ),
      );
    }

    overdueCandidates.sort(
      (left, right) => left.classEnd.compareTo(right.classEnd),
    );
    return overdueCandidates;
  }

  static DateTime? _resolveOptionalDateTime(dynamic rawValue) {
    if (rawValue is Timestamp) {
      return rawValue.toDate();
    }
    if (rawValue is DateTime) {
      return rawValue;
    }
    if (rawValue is String) {
      return DateTime.tryParse(rawValue);
    }
    return null;
  }

  static bool _sameDateTime(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return left.isAtSameMomentAs(right);
  }

  static void _throwIfRegistrationBlocked(NoShowPenaltyState penaltyState) {
    if (!penaltyState.isBlocked()) {
      return;
    }

    throw Exception(_registrationBlockedMessage(penaltyState.penaltyUntil!));
  }

  static String _registrationBlockedMessage(DateTime penaltyUntil) {
    final formattedDate = DateFormat.yMMMMd().format(penaltyUntil.toLocal());
    return 'You cannot sign up for classes until $formattedDate because you reached 3 no-shows.';
  }

  static Stream<Map<String, GymClass>> _watchClassesByIds(
    Iterable<String> classIds,
  ) {
    final normalizedIds =
        classIds
            .map((classId) => classId.trim())
            .where((classId) => classId.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (normalizedIds.isEmpty) {
      return Stream.value(const <String, GymClass>{});
    }

    final classQueryStreams = _chunkedIds(normalizedIds, _whereInChunkSize)
        .map(
          (chunk) => _db
              .collection(_classesCollection)
              .where(FieldPath.documentId, whereIn: chunk)
              .snapshots(),
        )
        .toList();

    if (classQueryStreams.length == 1) {
      return classQueryStreams.first.map(
        (snapshot) => _classMapFromSnapshots([snapshot]),
      );
    }

    return Rx.combineLatestList<QuerySnapshot<Map<String, dynamic>>>(
      classQueryStreams,
    ).map(_classMapFromSnapshots);
  }

  static Map<String, GymClass> _classMapFromSnapshots(
    Iterable<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final classesById = <String, GymClass>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        classesById[doc.id] = GymClass.fromFirestore(doc);
      }
    }
    return classesById;
  }

  static List<List<String>> _chunkedIds(List<String> ids, int chunkSize) {
    final chunks = <List<String>>[];
    for (var index = 0; index < ids.length; index += chunkSize) {
      final end = min(index + chunkSize, ids.length);
      chunks.add(ids.sublist(index, end));
    }
    return chunks;
  }

  static String _reservationClassId(
    Map<String, dynamic> data, {
    required String fallbackId,
  }) {
    final classId = data['classId']?.toString().trim() ?? '';
    if (classId.isNotEmpty) {
      return classId;
    }
    return fallbackId.trim();
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

  static int? parseMatNumber(String rawMatNumber) {
    final match = RegExp(r'(\d+)').firstMatch(rawMatNumber);
    return int.tryParse(match?.group(1) ?? '');
  }

  static String _normalizeMatNumber(String rawValue, int capacity) {
    final matNumber = parseMatNumber(rawValue);
    if (matNumber == null || matNumber <= 0 || matNumber > capacity) {
      throw Exception('Invalid mat selection.');
    }
    return 'Mat #$matNumber';
  }

  static int _matSortValue(String matNumber) {
    return parseMatNumber(matNumber) ?? 999999;
  }
}
