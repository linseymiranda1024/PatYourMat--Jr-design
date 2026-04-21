import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus { open, full, standby }

enum BookingMode { spot, open, zone }

const List<String> gymClassTypes = <String>[
  'Yoga',
  'Soccer',
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

const List<String> gymClassIconKeys = <String>[
  'lotus',
  'soccer',
  'flame',
  'dumbbell',
  'heart',
  'dance',
  'stretch',
  'meditate',
  'spark',
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
    'kickboxing': 'Sport',
    'soccer': 'Soccer',
    'football': 'Soccer',
    'futsal': 'Soccer',
  };

  final legacyMatch = legacyAliases[trimmed.toLowerCase()];
  if (legacyMatch != null) {
    return legacyMatch;
  }

  return 'Recovery';
}

String defaultGymClassIconKeyForType(String? type) {
  switch (normalizeGymClassType(type)) {
    case 'Yoga':
    case 'Pilates':
      return 'lotus';
    case 'Soccer':
    case 'Sport':
      return 'soccer';
    case 'HIIT':
      return 'flame';
    case 'Strength':
      return 'dumbbell';
    case 'Cardio':
      return 'heart';
    case 'Dance':
      return 'dance';
    case 'Mobility':
      return 'stretch';
    case 'Meditation':
      return 'meditate';
    case 'Recovery':
      return 'spark';
  }
  return 'spark';
}

String normalizeGymClassIconKey(String? key, {String? classType}) {
  final trimmed = key?.trim() ?? '';
  if (trimmed.isEmpty) {
    return defaultGymClassIconKeyForType(classType);
  }

  for (final option in gymClassIconKeys) {
    if (option.toLowerCase() == trimmed.toLowerCase()) {
      return option;
    }
  }

  return defaultGymClassIconKeyForType(classType);
}

List<String> normalizeGymClassImageUrls(dynamic rawValue) {
  if (rawValue is! List) {
    return const <String>[];
  }

  final urls = rawValue
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList();
  return urls.toSet().toList();
}

BookingMode inferBookingModeFromType(String? type) {
  switch (normalizeGymClassType(type)) {
    case 'Dance':
    case 'Sport':
    case 'Soccer':
      return BookingMode.open;
    case 'HIIT':
    case 'Strength':
    case 'Cardio':
      return BookingMode.zone;
    case 'Yoga':
    case 'Pilates':
    case 'Mobility':
    case 'Meditation':
    case 'Recovery':
      return BookingMode.spot;
  }
  return BookingMode.spot;
}

BookingMode bookingModeFromRaw(String? rawValue, {String? classType}) {
  switch ((rawValue ?? '').trim().toLowerCase()) {
    case 'spot':
      return BookingMode.spot;
    case 'open':
    case 'roster':
      return BookingMode.open;
    case 'zone':
      return BookingMode.zone;
    default:
      return inferBookingModeFromType(classType);
  }
}

extension BookingModeX on BookingMode {
  String get storageValue {
    switch (this) {
      case BookingMode.spot:
        return 'SPOT';
      case BookingMode.open:
        return 'OPEN';
      case BookingMode.zone:
        return 'ZONE';
    }
  }
}

class GymClass {
  final String id;
  final String title;
  final String description;
  final String type;
  final String iconKey;
  final List<String> imageUrls;
  final BookingMode bookingMode;
  final String instructor;
  final DateTime dateTime;
  final int durationMinutes;
  final String location;
  final int capacity;
  final int filled;
  final int standbyCount;
  final String recurrenceSeriesId;
  final int recurrenceCount;
  final int recurrenceIntervalWeeks;
  final int recurrenceIndex;

  GymClass({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    String? iconKey,
    List<String>? imageUrls,
    BookingMode? bookingMode,
    required this.instructor,
    required this.dateTime,
    required this.durationMinutes,
    required this.location,
    required this.capacity,
    required this.filled,
    this.standbyCount = 0,
    String? recurrenceSeriesId,
    this.recurrenceCount = 1,
    this.recurrenceIntervalWeeks = 1,
    this.recurrenceIndex = 0,
    ClassStatus? status,
  }) : iconKey = normalizeGymClassIconKey(iconKey, classType: type),
       imageUrls = List<String>.unmodifiable(
         normalizeGymClassImageUrls(imageUrls),
       ),
       bookingMode = bookingMode ?? inferBookingModeFromType(type),
       recurrenceSeriesId =
           (recurrenceSeriesId == null || recurrenceSeriesId.trim().isEmpty)
           ? id
           : recurrenceSeriesId.trim();

  factory GymClass.fromMap(Map<String, dynamic> data, String id) {
    final recurrenceSeriesId =
        (data['recurrenceSeriesId'] as String?)?.trim() ?? '';
    return GymClass(
      id: id,
      title: data['title'] ?? 'Untitled Class',
      description: data['description'] ?? '',
      type: normalizeGymClassType(
        data['type'] as String? ?? data['category'] as String?,
      ),
      iconKey: normalizeGymClassIconKey(
        data['iconKey'] as String?,
        classType: data['type'] as String? ?? data['category'] as String?,
      ),
      imageUrls: normalizeGymClassImageUrls(data['imageUrls']),
      bookingMode: bookingModeFromRaw(
        data['bookingMode']?.toString(),
        classType: data['type'] as String? ?? data['category'] as String?,
      ),
      instructor: data['instructor'] ?? 'Unknown Instructor',
      dateTime: data['dateTime'] is Timestamp
          ? (data['dateTime'] as Timestamp).toDate()
          : (data['dateTime'] is DateTime
              ? data['dateTime'] as DateTime
              : DateTime.now()),
      durationMinutes: _asInt(data['durationMinutes']),
      location: data['location'] ?? 'No Location',
      capacity: _asInt(data['capacity']),
      filled: _resolvedFilledCount(data),
      standbyCount: _asInt(data['standbyCount']),
      recurrenceSeriesId: recurrenceSeriesId.isEmpty ? id : recurrenceSeriesId,
      recurrenceCount: _normalizedPositiveInt(data['recurrenceCount']),
      recurrenceIntervalWeeks: _normalizedPositiveInt(
        data['recurrenceIntervalWeeks'],
      ),
      recurrenceIndex: _asInt(data['recurrenceIndex']),
    );
  }

  factory GymClass.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      return GymClass.fromMap(data, doc.id);
    } catch (e) {
      print('ERROR parsing GymClass from Firestore: $e');
      // Return a fallback object so the stream doesn't crash
      return GymClass(
        id: doc.id,
        title: 'Error Loading Class',
        description: '',
        type: 'Recovery',
        iconKey: defaultGymClassIconKeyForType('Recovery'),
        imageUrls: const <String>[],
        bookingMode: BookingMode.spot,
        instructor: '',
        dateTime: DateTime.now(),
        durationMinutes: 0,
        location: '',
        capacity: 0,
        filled: 0,
        recurrenceSeriesId: doc.id,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type,
      'iconKey': iconKey,
      'imageUrls': imageUrls,
      'bookingMode': bookingMode.storageValue,
      'instructor': instructor,
      'dateTime': dateTime,
      'durationMinutes': durationMinutes,
      'location': location,
      'capacity': capacity,
      'filled': filled,
      'standbyCount': standbyCount,
      'recurrenceSeriesId': recurrenceSeriesId,
      'recurrenceCount': recurrenceCount,
      'recurrenceIntervalWeeks': recurrenceIntervalWeeks,
      'recurrenceIndex': recurrenceIndex,
    };
  }

  Map<String, dynamic> toFirestore() {
    final data = toMap();
    data['dateTime'] = Timestamp.fromDate(dateTime);
    data['registeredCount'] = filled;
    data['status'] = status.name;
    return data;
  }

  GymClass copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? iconKey,
    List<String>? imageUrls,
    BookingMode? bookingMode,
    String? instructor,
    DateTime? dateTime,
    int? durationMinutes,
    String? location,
    int? capacity,
    int? filled,
    int? standbyCount,
    String? recurrenceSeriesId,
    int? recurrenceCount,
    int? recurrenceIntervalWeeks,
    int? recurrenceIndex,
  }) {
    return GymClass(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      imageUrls: imageUrls ?? this.imageUrls,
      bookingMode: bookingMode ?? this.bookingMode,
      instructor: instructor ?? this.instructor,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      filled: filled ?? this.filled,
      standbyCount: standbyCount ?? this.standbyCount,
      recurrenceSeriesId: recurrenceSeriesId ?? this.recurrenceSeriesId,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceIntervalWeeks:
          recurrenceIntervalWeeks ?? this.recurrenceIntervalWeeks,
      recurrenceIndex: recurrenceIndex ?? this.recurrenceIndex,
    );
  }

  ClassStatus get status {
    if (filled < capacity) {
      return standbyCount > 0 ? ClassStatus.standby : ClassStatus.open;
    }
    return ClassStatus.full;
  }

  bool get isRecurring => recurrenceCount > 1;

  String get favoriteKey => recurrenceSeriesId;

  String get recurrenceSummary {
    if (!isRecurring) {
      return 'One-time class';
    }

    if (recurrenceIntervalWeeks == 1) {
      return 'Repeats weekly for $recurrenceCount sessions';
    }

    return 'Repeats every $recurrenceIntervalWeeks weeks for $recurrenceCount sessions';
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int _normalizedPositiveInt(dynamic value) {
    final parsed = _asInt(value);
    return parsed < 1 ? 1 : parsed;
  }

  static int _resolvedFilledCount(Map<String, dynamic> data) {
    final rosterCount = _rosterCount(data[_rosterFieldName]);
    final reservedMatCount = _reservedMatCount(data['reservedMats']) ?? 0;
    final persistedCount = _asInt(data['filled'] ?? data['registeredCount']);
    return [rosterCount, reservedMatCount, persistedCount].reduce(maxOf);
  }

  static int _rosterCount(dynamic rawValue) {
    if (rawValue is! Map) {
      return 0;
    }

    return rawValue.length;
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

  static int maxOf(int left, int right) => left >= right ? left : right;

  static const String _rosterFieldName = 'roster';

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

List<GymClass> buildRecurringClassSeries({
  required GymClass template,
  required String seriesId,
  required String Function(int index) idBuilder,
  required int occurrenceCount,
  int intervalWeeks = 1,
}) {
  final normalizedOccurrenceCount = occurrenceCount < 1 ? 1 : occurrenceCount;
  final normalizedIntervalWeeks = intervalWeeks < 1 ? 1 : intervalWeeks;

  return List<GymClass>.generate(normalizedOccurrenceCount, (index) {
    return template.copyWith(
      id: idBuilder(index),
      dateTime: template.dateTime.add(
        Duration(days: 7 * normalizedIntervalWeeks * index),
      ),
      recurrenceSeriesId: seriesId,
      recurrenceCount: normalizedOccurrenceCount,
      recurrenceIntervalWeeks: normalizedIntervalWeeks,
      recurrenceIndex: index,
    );
  });
}
