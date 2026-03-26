import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/achievement.dart';

void main() {
  test('unlocks threshold, category, and time-based achievements', () {
    final unlocked = Achievement.evaluateUnlocks(
      totalAttended: 10,
      categoryAttendance: {'Yoga': 5, 'Dance': 2, 'Cardio': 5},
      classDateTime: DateTime(2026, 3, 25, 8, 30),
    );

    expect(unlocked, [
      'demo_day',
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
      'demo_day',
      'starter',
      'dedicated',
    ]);

    expect(sorted, ['demo_day', 'starter', 'dedicated', 'night_owl']);
  });
}
