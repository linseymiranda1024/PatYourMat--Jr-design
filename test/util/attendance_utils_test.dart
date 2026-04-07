import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/reservation.dart';
import 'package:pat_your_mat/util/date_time/util_attendance.dart';

void main() {
  group('isAttendanceWindowOpen', () {
    final classStart = DateTime(2026, 4, 6, 10);

    test('stays open through the end of class duration', () {
      expect(
        isAttendanceWindowOpen(
          classStart,
          durationMinutes: 60,
          now: DateTime(2026, 4, 6, 10, 59),
        ),
        isTrue,
      );
    });

    test('closes after class end', () {
      expect(
        isAttendanceWindowOpen(
          classStart,
          durationMinutes: 60,
          now: DateTime(2026, 4, 6, 11, 1),
        ),
        isFalse,
      );
    });
  });

  group('effectiveReservationStatus', () {
    final classStart = DateTime(2026, 4, 6, 10);

    test('returns no-show after class end when not checked in', () {
      expect(
        effectiveReservationStatus(
          rawStatus: ReservationStatus.confirmed,
          classStart: classStart,
          durationMinutes: 45,
          now: DateTime(2026, 4, 6, 10, 46),
        ),
        ReservationStatus.noShow,
      );
    });

    test('preserves attended status', () {
      expect(
        effectiveReservationStatus(
          rawStatus: ReservationStatus.attended,
          classStart: classStart,
          durationMinutes: 45,
          now: DateTime(2026, 4, 6, 12),
        ),
        ReservationStatus.attended,
      );
    });
  });
}
