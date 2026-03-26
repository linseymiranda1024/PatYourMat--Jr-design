import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/achievement.dart';

void main() {
  test('unlocks threshold, category, and time-based achievements', () {
    final unlocked = Achievement.evaluateUnlocks(
      totalAttended: 10,
      categoryAttendance: {'Yoga': 5, 'Dance': 2, 'Bike': 5},
      classDateTime: DateTime(2026, 3, 25, 8, 30),
    );

    expect(unlocked, [
      'starter',
      'regular',
      'zen_master',
      'road_warrior',
      'early_bird',
    ]);
  });

  test('sortAchievementIds preserves catalog order', () {
    final sorted = Achievement.sortAchievementIds([
      'night_owl',
      'starter',
      'dedicated',
    ]);

    expect(sorted, ['starter', 'dedicated', 'night_owl']);
  });
}
