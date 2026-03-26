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
          notifyListeners();
          unawaited(
            DBReservations.ensureClassTrackingForUserReservations(
              user.uid,
              reservations,
            ),
          );
        },
        onError: (error) {
          _reservations = [];
          notifyListeners();
        },
      );
      return;
    }

    // No authenticated user: clear stale reservations from previous account.
    _reservations = [];
    notifyListeners();
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
    if (user == null) {
      throw Exception('You must be logged in to register for a class.');
    }
    if (_reservations.any((reservation) => reservation.id == gymClass.id)) {
      throw Exception('You are already registered for this class.');
    }

    final reservedMat = await DBReservations.registerForClass(
      user.uid,
      gymClass,
      matNumber: matNumber,
    );

    if (reservedMat != null) {
      _upsertLocalReservation(
        Reservation(
          id: gymClass.id,
          className: gymClass.title,
          instructor: gymClass.instructor,
          dateTime: '${gymClass.dateText} at ${gymClass.timeText}',
          matNumber: reservedMat,
          status: 'CONFIRMED',
          date: gymClass.dateTime,
        ),
      );
    }

    return reservedMat;
  }

  Future<void> cancelReservation(Reservation reservation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to cancel a reservation.');
    }
    if (reservation.id == null) {
      throw Exception('Reservation is missing an id.');
    }

    await DBReservations.cancelReservation(user.uid, reservation.id!);
    _removeLocalReservation(reservation.id!);
  }

  // Backward compatibility
  void reserveClass({
    required String className,
    required String instructor,
    required String dateTime,
    required DateTime date,
  }) {}

  void _upsertLocalReservation(Reservation reservation) {
    _reservations = [
      ..._reservations.where((existing) => existing.id != reservation.id),
      reservation,
    ]..sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  void _removeLocalReservation(String reservationId) {
    _reservations = _reservations
        .where((reservation) => reservation.id != reservationId)
        .toList();
    notifyListeners();
  }
}
