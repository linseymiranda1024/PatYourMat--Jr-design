class Reservation {
  final String? id;
  final String className;
  final String instructor;
  final String dateTime;
  final String matNumber;
  final String status;
  final DateTime date;

  Reservation({
    this.id,
    required this.className,
    required this.instructor,
    required this.dateTime,
    required this.matNumber,
    this.status = 'CONFIRMED',
    required this.date,
  });
}
