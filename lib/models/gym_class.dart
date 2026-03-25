import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus { open, full, standby }

class GymClass {
  final String id;
  final String title;
  final String type;
  final String description;
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
    required this.type,
    required this.description,
    required this.instructor,
    required this.dateTime,
    required this.durationMinutes,
    required this.location,
    required this.capacity,
    required this.filled,
    required this.status,
  });

  factory GymClass.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      return GymClass(
        id: doc.id,
        title: data['title'] ?? 'Untitled Class',
        type: data['type'] ?? 'Yoga',
        description: data['description'] ?? '',
        instructor: data['instructor'] ?? 'Unknown Instructor',
        dateTime: data['dateTime'] is Timestamp
            ? (data['dateTime'] as Timestamp).toDate()
            : DateTime.now(),
        durationMinutes: (data['durationMinutes'] ?? 0).toInt(),
        location: data['location'] ?? 'No Location',
        capacity: (data['capacity'] ?? 0).toInt(),
        filled: (data['filled'] ?? data['registeredCount'] ?? 0).toInt(),
        status: _parseStatus(data['status']),
      );
    } catch (e) {
      print('ERROR parsing GymClass from Firestore: $e');
      return GymClass(
        id: doc.id,
        title: 'Error Loading Class',
        type: 'Yoga',
        description: '',
        instructor: '',
        dateTime: DateTime.now(),
        durationMinutes: 0,
        location: '',
        capacity: 0,
        filled: 0,
        status: ClassStatus.open,
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'type': type,
      'description': description,
      'instructor': instructor,
      'dateTime': Timestamp.fromDate(dateTime),
      'durationMinutes': durationMinutes,
      'location': location,
      'capacity': capacity,
      'filled': filled,
      'registeredCount': filled,
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[dateTime.weekday - 1]}, ${months[dateTime.month - 1]} ${dateTime.day}';
  }

  String get timeText {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String get durationText => '$durationMinutes min';
}
