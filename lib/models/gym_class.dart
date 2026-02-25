import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus { open, full, standby }

class GymClass {
  final String id;
  final String title;
  final String instructor;
  final DateTime dateTime;
  final int durationMinutes;
  final String location;
  final int capacity;
  final int filled;
  final ClassStatus status;

  GymClass({
    required this.id,
    required this.title,
    required this.instructor,
    required this.dateTime,
    required this.durationMinutes,
    required this.location,
    required this.capacity,
    required this.filled,
    required this.status,
  });

  factory GymClass.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GymClass(
      id: doc.id,
      title: data['title'] ?? '',
      instructor: data['instructor'] ?? '',
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      durationMinutes: data['durationMinutes'] ?? 0,
      location: data['location'] ?? '',
      capacity: data['capacity'] ?? 0,
      filled: data['filled'] ?? 0,
      status: _parseStatus(data['status']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'instructor': instructor,
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': durationMinutes,
      'location': location,
      'capacity': capacity,
      'filled': filled,
      'status': status.name,
    };
  }

  static ClassStatus _parseStatus(String? status) {
    switch (status) {
      case 'full':
        return ClassStatus.full;
      case 'standby':
        return ClassStatus.standby;
      case 'open':
      default:
        return ClassStatus.open;
    }
  }

  String get dateText {
    // Basic formatting, can be improved with intl package
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String get timeText {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String get durationText {
    return '$durationMinutes min';
  }
}
