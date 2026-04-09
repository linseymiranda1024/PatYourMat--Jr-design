import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/user_profile.dart';

void main() {
  test('user profile settings are serialized for Firestore', () {
    final profile = UserProfile.empty()
      ..pushNotificationsEnabled = false
      ..standbyAlertsEnabled = false
      ..darkModeEnabled = true
      ..achievements = ['starter', 'early_bird']
      ..categoryAttendance = {'Yoga': 3, 'Dance': 1};

    final json = profile.toJsonForDb();

    expect(json['push_notifications_enabled'], isFalse);
    expect(json['standby_alerts_enabled'], isFalse);
    expect(json['dark_mode_enabled'], isTrue);
    expect(json['achievements'], ['starter', 'early_bird']);
    expect(json['favorite_class_ids'], isEmpty);
    expect(json['category_attendance'], {'Yoga': 3, 'Dance': 1});
  });

  test('user profile settings are restored from Firestore data', () {
    final profile = UserProfile.defFromJsonDbObject({
      'first_name': 'Pat',
      'last_name': 'Mat',
      'email': 'pat@example.com',
      'push_notifications_enabled': false,
      'standby_alerts_enabled': false,
      'dark_mode_enabled': true,
      'achievements': ['starter', 'night_owl'],
      'favorite_class_ids': ['class-1', 'class-2'],
      'category_attendance': {'Yoga': 4, 'Cardio': 2},
    }, 'uid-123');

    expect(profile.pushNotificationsEnabled, isFalse);
    expect(profile.standbyAlertsEnabled, isFalse);
    expect(profile.darkModeEnabled, isTrue);
    expect(profile.achievements, ['starter', 'night_owl']);
    expect(profile.favoriteClassIds, ['class-1', 'class-2']);
    expect(profile.categoryAttendance, {'Yoga': 4, 'Cardio': 2});
  });
}
