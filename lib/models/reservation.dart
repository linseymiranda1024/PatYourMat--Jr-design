class Reservation {
  final String? id; // added id field
  final String className;
  final String instructor;
  final String dateTime; // e.g. "Mon, Feb 3 6:00 AM"
  final String matNumber; // "Mat #9"
  final String status; // "CONFIRMED", "STANDBY", etc.
  final DateTime date; // for sorting
  final String? checkInCode; // optional QR-like string or future real code

  Reservation({
    this.id,
    required this.className,
    required this.instructor,
    required this.dateTime,
    required this.matNumber,
    this.status = "CONFIRMED",
    required this.date,
    this.checkInCode,
  });
}
