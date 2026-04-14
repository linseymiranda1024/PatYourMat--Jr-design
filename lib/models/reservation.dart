import 'package:cloud_firestore/cloud_firestore.dart';

import 'gym_class.dart';

class ReservationStatus {
  static const String confirmed = 'CONFIRMED';
  static const String attended = 'ATTENDED';
  static const String noShow = 'NO-SHOW';

  const ReservationStatus._();
}

String normalizeReservationStatus(String? rawStatus) {
  final normalized = (rawStatus ?? '').trim().toUpperCase();
  switch (normalized) {
    case ReservationStatus.attended:
      return ReservationStatus.attended;
    case 'NO SHOW':
    case 'NO_SHOW':
    case ReservationStatus.noShow:
      return ReservationStatus.noShow;
    case ReservationStatus.confirmed:
    default:
      return ReservationStatus.confirmed;
  }
}

class Reservation {
  final String? id;
  final String userId;
  final String userName;
  final String userEmail;
  final String className;
  final String instructor;
  final String dateTime;
  final String matNumber;
  final String bookingRole;
  final String status;
  final DateTime date;
  final int durationMinutes;

  Reservation({
    this.id,
    this.userId = '',
    this.userName = '',
    this.userEmail = '',
    required this.className,
    required this.instructor,
    required this.dateTime,
    required this.matNumber,
    this.bookingRole = '',
    this.status = ReservationStatus.confirmed,
    required this.date,
    this.durationMinutes = 60,
  });

  factory Reservation.fromMap(
    Map<String, dynamic> data, {
    String? id,
    GymClass? resolvedClass,
  }) {
    final resolvedDate = _resolveReservationDate(
      data['date'],
      fallback: resolvedClass?.dateTime,
    );

    return Reservation(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      className: resolvedClass?.title ?? data['className']?.toString() ?? '',
      instructor:
          resolvedClass?.instructor ?? data['instructor']?.toString() ?? '',
      dateTime: resolvedClass != null
          ? '${resolvedClass.dateText} at ${resolvedClass.timeText}'
          : data['dateTime']?.toString() ?? '',
      matNumber: data['matNumber']?.toString() ?? '',
      bookingRole: data['bookingRole']?.toString() ?? '',
      status: normalizeReservationStatus(data['status']?.toString()),
      date: resolvedDate,
      durationMinutes: resolvedClass != null
          ? _resolveDurationMinutes(resolvedClass.durationMinutes)
          : _resolveDurationMinutes(data['durationMinutes']),
    );
  }
}

DateTime _resolveReservationDate(dynamic rawValue, {DateTime? fallback}) {
  if (rawValue is DateTime) {
    return rawValue;
  }
  if (rawValue is Timestamp) {
    return rawValue.toDate();
  }
  if (rawValue is String) {
    final parsed = DateTime.tryParse(rawValue);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback ?? DateTime.now();
}

int _resolveDurationMinutes(dynamic rawValue) {
  final resolvedValue = switch (rawValue) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };
  return resolvedValue > 0 ? resolvedValue : 60;
}
