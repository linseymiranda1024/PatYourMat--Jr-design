import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/gym_class.dart';
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
      status: ReservationStatus.attended,
      date: DateTime(2026, 3, 24, 8),
      durationMinutes: 60,
    ),
    Reservation(
      id: 'in-progress-1',
      className: 'Lunch Ride',
      instructor: 'Jordan',
      dateTime: 'Mon, Mar 24 at 11:30 AM',
      matNumber: 'Mat #2',
      date: DateTime(2026, 3, 24, 11, 30),
      durationMinutes: 60,
    ),
    Reservation(
      id: 'future-1',
      className: 'Lunch Ride',
      instructor: 'Jordan',
      dateTime: 'Mon, Mar 24 at 1:00 PM',
      matNumber: 'Mat #3',
      date: DateTime(2026, 3, 24, 13),
      durationMinutes: 60,
    ),
    Reservation(
      id: 'future-2',
      className: 'Evening Dance',
      instructor: 'Morgan',
      dateTime: 'Tue, Mar 25 at 6:00 PM',
      matNumber: 'Mat #4',
      date: DateTime(2026, 3, 25, 18),
      durationMinutes: 60,
    ),
  ];

  test('upcoming member reservations only include future classes', () {
    final upcoming = upcomingMemberReservations(reservations, now: now);

    expect(upcoming.map((reservation) => reservation.id), [
      'in-progress-1',
      'future-1',
      'future-2',
    ]);
  });

  test('previous member reservations only include past classes', () {
    final previous = previousMemberReservations(reservations, now: now);

    expect(previous.map((reservation) => reservation.id), ['past-1']);
  });

  test('attendance summary counts attended, no-shows, and categories', () {
    final summary = summarizeAttendance(
      [
        ...reservations,
        Reservation(
          id: 'past-2',
          className: 'Late Ride',
          instructor: 'Jordan',
          dateTime: 'Sun, Mar 23 at 7:00 PM',
          matNumber: 'Mat #5',
          status: ReservationStatus.noShow,
          date: DateTime(2026, 3, 23, 19),
          durationMinutes: 45,
        ),
      ],
      categoryAttendance: const {'Yoga': 4, 'Cardio': 2, 'Dance': 4},
      now: now,
    );

    expect(summary.attendedCount, 1);
    expect(summary.noShowCount, 1);
    expect(summary.totalCompletedCount, 2);
    expect(summary.attendanceRate, 0.5);
    expect(
      summary.categoryBreakdown.map((entry) => '${entry.key}:${entry.value}'),
      ['Dance:4', 'Yoga:4', 'Cardio:2'],
    );
    expect(summary.topCategory, 'Dance');
  });

  test('attendance summary is empty when there is no completed history', () {
    final summary = summarizeAttendance(
      reservations
          .where((reservation) => reservation.id!.startsWith('future'))
          .toList(),
      now: now,
    );

    expect(summary.hasHistory, isFalse);
    expect(summary.attendedCount, 0);
    expect(summary.noShowCount, 0);
    expect(summary.totalCompletedCount, 0);
    expect(summary.attendanceRate, isNull);
    expect(summary.categoryBreakdown, isEmpty);
  });

  test(
    'favorite resolution returns next recurring occurrence when available',
    () {
      final classes = [
        GymClass(
          id: 'class-1',
          title: 'Lunch Ride',
          description: 'Ride hard',
          type: 'Cardio',
          instructor: 'Jordan',
          dateTime: DateTime(2026, 3, 17, 13),
          durationMinutes: 60,
          location: 'Studio A',
          capacity: 20,
          filled: 10,
          recurrenceSeriesId: 'series-1',
          recurrenceCount: 3,
          recurrenceIntervalWeeks: 1,
          recurrenceIndex: 0,
        ),
        GymClass(
          id: 'class-2',
          title: 'Lunch Ride',
          description: 'Ride hard',
          type: 'Cardio',
          instructor: 'Jordan',
          dateTime: DateTime(2026, 3, 24, 13),
          durationMinutes: 60,
          location: 'Studio A',
          capacity: 20,
          filled: 8,
          recurrenceSeriesId: 'series-1',
          recurrenceCount: 3,
          recurrenceIntervalWeeks: 1,
          recurrenceIndex: 1,
        ),
        GymClass(
          id: 'class-3',
          title: 'Lunch Ride',
          description: 'Ride hard',
          type: 'Cardio',
          instructor: 'Jordan',
          dateTime: DateTime(2026, 3, 31, 13),
          durationMinutes: 60,
          location: 'Studio A',
          capacity: 20,
          filled: 6,
          recurrenceSeriesId: 'series-1',
          recurrenceCount: 3,
          recurrenceIntervalWeeks: 1,
          recurrenceIndex: 2,
        ),
      ];

      final favoriteClass = resolveFavoriteClass(
        classes,
        'series-1',
        now: DateTime(2026, 3, 24, 12),
      );

      expect(favoriteClass?.id, 'class-2');
    },
  );
}
