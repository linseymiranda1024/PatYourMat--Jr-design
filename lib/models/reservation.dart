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
    this.status = ReservationStatus.confirmed,
    required this.date,
    this.durationMinutes = 60,
  });

  factory Reservation.fromMap(Map<String, dynamic> data, {String? id}) {
    return Reservation(
      id: id,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      className: data['className']?.toString() ?? '',
      instructor: data['instructor']?.toString() ?? '',
      dateTime: data['dateTime']?.toString() ?? '',
      matNumber: data['matNumber']?.toString() ?? '',
      status: normalizeReservationStatus(data['status']?.toString()),
      date: data['date'] is DateTime
          ? data['date'] as DateTime
          : DateTime.now(),
      durationMinutes: data['durationMinutes'] is num
          ? (data['durationMinutes'] as num).toInt()
          : 60,
    );
  }
}
