import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus { open, full, standby }

const List<String> gymClassTypes = <String>[
  'Yoga',
  'Sport',
  'Pilates',
  'HIIT',
  'Strength',
  'Cardio',
  'Dance',
  'Mobility',
  'Meditation',
  'Recovery',
];

String normalizeGymClassType(String? type) {
  final trimmed = type?.trim() ?? '';
  if (trimmed.isEmpty) {
    return 'Recovery';
  }

  for (final option in gymClassTypes) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  const legacyAliases = <String, String>{
    'bike': 'Cardio',
    'cycling': 'Cardio',
    'spin': 'Cardio',
    'other': 'Recovery',
    'boxing': 'Sport',
    'soccer': 'Sport',
  };

  final legacyMatch = legacyAliases[trimmed.toLowerCase()];
  if (legacyMatch != null) {
    return legacyMatch;
  }

  return 'Recovery';
}

class GymClass {
  final String id;
  final String title;
  final String description;
  final String type;
  final String instructor;
  final DateTime dateTime;
  final int durationMinutes;
  final String location;
  final int capacity;
  final int filled;

  GymClass({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.instructor,
    required this.dateTime,
    required this.durationMinutes,
    required this.location,
    required this.capacity,
    required this.filled,
    ClassStatus? status,
  });

  factory GymClass.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      return GymClass(
        id: doc.id,
        title: data['title'] ?? 'Untitled Class',
        description: data['description'] ?? '',
        type: normalizeGymClassType(
          data['type'] as String? ?? data['category'] as String?,
        ),
        instructor: data['instructor'] ?? 'Unknown Instructor',
        dateTime: data['dateTime'] is Timestamp
            ? (data['dateTime'] as Timestamp).toDate()
            : DateTime.now(),
        durationMinutes: _asInt(data['durationMinutes']),
        location: data['location'] ?? 'No Location',
        capacity: _asInt(data['capacity']),
        filled: _resolvedFilledCount(data),
      );
    } catch (e) {
      print('ERROR parsing GymClass from Firestore: $e');
      // Return a fallback object so the stream doesn't crash
      return GymClass(
        id: doc.id,
        title: 'Error Loading Class',
        description: '',
        type: 'Recovery',
        instructor: '',
        dateTime: DateTime.now(),
        durationMinutes: 0,
        location: '',
        capacity: 0,
        filled: 0,
      );
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': normalizeGymClassType(type),
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

  ClassStatus get status {
    return filled >= capacity ? ClassStatus.full : ClassStatus.open;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static int _resolvedFilledCount(Map<String, dynamic> data) {
    final reservedMatCount = _reservedMatCount(data['reservedMats']);
    if (reservedMatCount != null) {
      return reservedMatCount;
    }

    return _asInt(data['filled'] ?? data['registeredCount']);
  }

  static int? _reservedMatCount(dynamic rawValue) {
    if (rawValue is! List) {
      return null;
    }

    return rawValue
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
  }

  String get dateText {
    // Basic formatting, can be improved with intl package
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

  String get durationText {
    return '$durationMinutes min';
  }
}
