import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/reservation.dart';

// Simple in-memory provider (later → Firestore stream)
final reservationsProvider =
    StateNotifierProvider<ReservationsNotifier, List<Reservation>>((ref) {
      return ReservationsNotifier();
    });

class ReservationsNotifier extends StateNotifier<List<Reservation>> {
  ReservationsNotifier() : super([]);

  void addReservation(Reservation reservation) {
    state = [...state, reservation]..sort((a, b) => a.date.compareTo(b.date));
  }

  // For demo: generate random mat 1–30
  int _getRandomAvailableMat() {
    final random = Random();
    return random.nextInt(30) + 1; // 1 to 30
  }

  void reserveClass({
    required String className,
    required String instructor,
    required String dateTime,
    required DateTime date,
  }) {
    final mat = _getRandomAvailableMat();
    final newRes = Reservation(
      className: className,
      instructor: instructor,
      dateTime: dateTime,
      matNumber: 'Mat #$mat',
      date: date,
      checkInCode: 'CHECKIN-${Random().nextInt(900000) + 100000}', // fake code
    );
    addReservation(newRes);
  }

  // Later: cancel, check-in, etc.
  void cancelReservation(Reservation reservation) {
    state = state.where((r) => r != reservation).toList();
  }
}
