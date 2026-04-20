import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/models/gym_class.dart';

void main() {
  test('gym class serializes iconKey and imageUrls for Firestore', () {
    final gymClass = GymClass(
      id: 'class-visual',
      title: 'Sunrise Flow',
      description: 'Balance and core',
      type: 'Yoga',
      iconKey: 'lotus',
      imageUrls: const [
        'https://img.one/photo.jpg',
        'https://img.two/photo.jpg',
      ],
      instructor: 'Taylor',
      dateTime: DateTime(2026, 6, 10, 8),
      durationMinutes: 60,
      location: 'Studio A',
      capacity: 18,
      filled: 3,
    );

    final data = gymClass.toFirestore();

    expect(data['iconKey'], 'lotus');
    expect(data['imageUrls'], const [
      'https://img.one/photo.jpg',
      'https://img.two/photo.jpg',
    ]);
  });

  test(
    'legacy Firestore classes restore default visuals when fields are absent',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('classes').doc('legacy-class').set({
        'title': 'Evening Flow',
        'description': 'Stretch and release',
        'type': 'Yoga',
        'instructor': 'Morgan',
        'dateTime': Timestamp.fromDate(DateTime(2026, 6, 10, 18)),
        'durationMinutes': 45,
        'location': 'Studio B',
        'capacity': 16,
        'filled': 5,
      });

      final snapshot = await firestore
          .collection('classes')
          .doc('legacy-class')
          .get();
      final gymClass = GymClass.fromFirestore(snapshot);

      expect(gymClass.iconKey, defaultGymClassIconKeyForType('Yoga'));
      expect(gymClass.imageUrls, isEmpty);
    },
  );
}
