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
      category: 'Strength',
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
      category: 'Yoga',
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
      category: 'Other',
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
      category: 'Other',
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

  test('category filters come from model categories on upcoming classes', () {
    expect(homeFilterCategoryKeys(classes, now: now), ['Yoga', 'Other']);
  });

  test('category filter and search query combine correctly', () {
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
