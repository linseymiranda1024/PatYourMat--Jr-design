import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/reservation.dart';
import 'package:pat_your_mat/screens/profile_screen.dart';

void main() {
  final now = DateTime(2026, 3, 24, 12);
  final reservations = [
    Reservation(
      id: 'past-1',
      className: 'Sunrise Yoga',
      instructor: 'Taylor',
      dateTime: 'Mon, Mar 24 at 8:00 AM',
      matNumber: 'Mat #1',
      date: DateTime(2026, 3, 24, 8),
    ),
    Reservation(
      id: 'future-1',
      className: 'Lunch Ride',
      instructor: 'Jordan',
      dateTime: 'Mon, Mar 24 at 1:00 PM',
      matNumber: 'Mat #2',
      date: DateTime(2026, 3, 24, 13),
    ),
    Reservation(
      id: 'future-2',
      className: 'Evening Dance',
      instructor: 'Morgan',
      dateTime: 'Tue, Mar 25 at 6:00 PM',
      matNumber: 'Mat #3',
      date: DateTime(2026, 3, 25, 18),
    ),
  ];

  test('upcoming member reservations only include future classes', () {
    final upcoming = upcomingMemberReservations(reservations, now: now);

    expect(upcoming.map((reservation) => reservation.id), [
      'future-1',
      'future-2',
    ]);
  });

  test('previous member reservations only include past classes', () {
    final previous = previousMemberReservations(reservations, now: now);

    expect(previous.map((reservation) => reservation.id), ['past-1']);
  });
}
