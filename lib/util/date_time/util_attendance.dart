import '../../models/reservation.dart';

const Duration attendanceEarlyAccessWindow = Duration(minutes: 30);
const int defaultClassDurationMinutes = 60;

int resolveClassDurationMinutes(int? durationMinutes) {
  final resolved = durationMinutes ?? defaultClassDurationMinutes;
  return resolved.clamp(1, 1440);
}

DateTime attendanceWindowCloses(
  DateTime classStart, {
  required int durationMinutes,
}) {
  return classStart.add(
    Duration(minutes: resolveClassDurationMinutes(durationMinutes)),
  );
}

bool isAttendanceWindowOpen(
  DateTime classStart, {
  required int durationMinutes,
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final windowClose = attendanceWindowCloses(
    classStart,
    durationMinutes: durationMinutes,
  );
  return !currentTime.isBefore(
        classStart.subtract(attendanceEarlyAccessWindow),
      ) &&
      !currentTime.isAfter(windowClose);
}

String effectiveReservationStatus({
  required String? rawStatus,
  required DateTime classStart,
  required int durationMinutes,
  DateTime? now,
}) {
  final normalizedStatus = normalizeReservationStatus(rawStatus);
  if (normalizedStatus == ReservationStatus.attended ||
      normalizedStatus == ReservationStatus.noShow) {
    return normalizedStatus;
  }

  final currentTime = now ?? DateTime.now();
  final classEnd = attendanceWindowCloses(
    classStart,
    durationMinutes: durationMinutes,
  );
  if (currentTime.isAfter(classEnd)) {
    return ReservationStatus.noShow;
  }

  return ReservationStatus.confirmed;
}
