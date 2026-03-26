import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/gym_class.dart';
import 'package:pat_your_mat/screens/home_screen.dart';

void main() {
  final now = DateTime(2026, 3, 24, 9);
  final classes = [
    GymClass(
      id: '0',
      title: 'Early Strength',
      description: 'A completed morning class.',
      type: 'Strength',
      instructor: 'Casey',
      dateTime: DateTime(2026, 3, 24, 7),
      durationMinutes: 45,
      location: 'Studio D',
      capacity: 12,
      filled: 10,
      status: ClassStatus.open,
    ),
    GymClass(
      id: '1',
      title: 'Morning Yoga Flow',
      description: 'A smooth yoga class.',
      type: 'Yoga',
      instructor: 'Taylor',
      dateTime: DateTime(2026, 3, 24, 10),
      durationMinutes: 60,
      location: 'Studio A',
      capacity: 20,
      filled: 8,
      status: ClassStatus.open,
    ),
    GymClass(
      id: '2',
      title: 'Power Cardio Blast',
      description: 'A cardio conditioning class.',
      type: 'Cardio',
      instructor: 'Jordan',
      dateTime: DateTime(2026, 3, 24, 12),
      durationMinutes: 45,
      location: 'Studio B',
      capacity: 18,
      filled: 18,
      status: ClassStatus.full,
    ),
    GymClass(
      id: '3',
      title: 'Pilates Reset',
      description: 'A focused pilates session.',
      type: 'Pilates',
      instructor: 'Morgan',
      dateTime: DateTime(2026, 3, 25, 8),
      durationMinutes: 50,
      location: 'Studio C',
      capacity: 16,
      filled: 6,
      status: ClassStatus.open,
    ),
  ];

  test('today filter only returns classes on the current date', () {
    final filtered = filterHomeClasses(
      classes: classes,
      searchQuery: '',
      selectedFilterKey: homeTodayFilterKey,
      now: now,
    );

    expect(filtered.map((gymClass) => gymClass.id), ['1', '2']);
  });

  test('type filters come from model types on upcoming classes', () {
    expect(homeFilterTypeKeys(classes, now: now), [
      'Yoga',
      'Cardio',
      'Pilates',
    ]);
  });

  test('smart filters infer useful browse tags from title and description', () {
    final smartClasses = [
      GymClass(
        id: 'a',
        title: 'Sunrise Yoga Flow',
        description: 'Wake up with breath and movement.',
        type: 'Recovery',
        instructor: 'Alex',
        dateTime: DateTime(2026, 3, 24, 10),
        durationMinutes: 50,
        location: 'Studio A',
        capacity: 20,
        filled: 6,
        status: ClassStatus.open,
      ),
      GymClass(
        id: 'b',
        title: 'Pilates Reset',
        description: 'Core stability and alignment.',
        type: 'Recovery',
        instructor: 'Jordan',
        dateTime: DateTime(2026, 3, 24, 11),
        durationMinutes: 45,
        location: 'Studio B',
        capacity: 18,
        filled: 7,
        status: ClassStatus.open,
      ),
      GymClass(
        id: 'c',
        title: 'Dance Cardio Party',
        description: 'High-energy movement.',
        type: 'Recovery',
        instructor: 'Morgan',
        dateTime: DateTime(2026, 3, 24, 12),
        durationMinutes: 45,
        location: 'Studio C',
        capacity: 18,
        filled: 10,
        status: ClassStatus.open,
      ),
    ];

    expect(homeFilterTypeKeys(smartClasses, now: now), [
      'Yoga',
      'Pilates',
      'Cardio',
      'Dance',
    ]);

    final pilatesOnly = filterHomeClasses(
      classes: smartClasses,
      searchQuery: '',
      selectedFilterKey: 'Pilates',
      now: now,
    );

    expect(pilatesOnly.map((gymClass) => gymClass.id), ['b']);
  });

  test('type filter and search query combine correctly', () {
    final filtered = filterHomeClasses(
      classes: classes,
      searchQuery: 'taylor',
      selectedFilterKey: 'Yoga',
      now: now,
    );

    expect(filtered.map((gymClass) => gymClass.id), ['1']);
  });

  test('past classes are excluded from browse results', () {
    final filtered = filterHomeClasses(
      classes: classes,
      searchQuery: '',
      selectedFilterKey: null,
      now: now,
    );

    expect(filtered.map((gymClass) => gymClass.id), ['1', '2', '3']);
    expect(filtered.any((gymClass) => gymClass.id == '0'), isFalse);
  });
}
