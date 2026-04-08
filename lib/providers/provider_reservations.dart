import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reservation.dart';
import '../models/gym_class.dart';
import '../db_helpers/db_reservations.dart';

final reservationsProvider = ChangeNotifierProvider<ReservationsNotifier>((
  ref,
) {
  return ReservationsNotifier();
});

class ReservationsNotifier extends ChangeNotifier {
  List<Reservation> _reservations = [];
  StreamSubscription? _subscription;

  List<Reservation> get reservations => _reservations;

  ReservationsNotifier() {
    _init();
  }

  void _init() {
    _subscription?.cancel();
    _subscription = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _subscription = DBReservations.getReservationsStream(user.uid).listen(
        (reservations) {
          _reservations = reservations;
          Future.microtask(() => notifyListeners());
        },
        onError: (error) {
          _reservations = [];
          Future.microtask(() => notifyListeners());
        },
      );
      return;
    }

    // No authenticated user: clear stale reservations from previous account.
    _reservations = [];
    Future.microtask(() => notifyListeners());
  }

  void updateUser() {
    _init();
  }

  void clearAndCancelForSignOut() {
    _subscription?.cancel();
    _subscription = null;
    _reservations = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<String?> registerForClass(
    GymClass gymClass, {
    String? matNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return await DBReservations.registerForClass(
      user.uid,
      gymClass,
      matNumber: matNumber,
    );
  }

  Stream<int?> standbyQueuePositionStream(String classId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream<int?>.value(null);
    }

    return DBReservations.getStandbyQueuePositionStream(classId, user.uid);
  }

  Future<StandbyQueueResult?> joinStandbyQueue(GymClass gymClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return await DBReservations.joinStandbyQueue(user.uid, gymClass);
  }

  Future<void> leaveStandbyQueue(String classId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await DBReservations.leaveStandbyQueue(user.uid, classId);
  }

  Future<void> cancelReservation(Reservation reservation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || reservation.id == null) return;

    await DBReservations.cancelReservation(user.uid, reservation.id!);
  }

  // Backward compatibility
  void reserveClass({
    required String className,
    required String instructor,
    required String dateTime,
    required DateTime date,
  }) {}
}
