import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pat_your_mat/db_helpers/db_gym_class.dart';
import 'package:pat_your_mat/models/gym_class.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  GymClass buildClassTemplate() {
    return GymClass(
      id: '',
      title: 'Morning Yoga',
      description: 'Mobility and breathwork',
      type: 'Yoga',
      instructor: 'Taylor',
      dateTime: DateTime(2026, 4, 10, 9),
      durationMinutes: 60,
      location: 'Studio A',
      capacity: 18,
      filled: 0,
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    DBGymClass.useFirestoreInstance(firestore);
  });

  tearDown(() {
    DBGymClass.resetFirestoreInstance();
  });

  test(
    'createClass saves a single class document with recurrence metadata',
    () async {
      await DBGymClass.createClass(buildClassTemplate());

      final snapshot = await firestore.collection('classes').get();

      expect(snapshot.docs, hasLength(1));

      final doc = snapshot.docs.single;
      final data = doc.data();

      expect(data['title'], 'Morning Yoga');
      expect(data['recurrenceSeriesId'], doc.id);
      expect(data['recurrenceCount'], 1);
      expect(data['recurrenceIntervalWeeks'], 1);
      expect(data['recurrenceIndex'], 0);
    },
  );

  test(
    'createRecurringClassSeries saves each weekly occurrence separately',
    () async {
      await DBGymClass.createRecurringClassSeries(
        buildClassTemplate(),
        occurrenceCount: 3,
        intervalWeeks: 2,
      );

      final snapshot = await firestore
          .collection('classes')
          .orderBy('dateTime')
          .get();

      expect(snapshot.docs, hasLength(3));

      final docs = snapshot.docs;
      final firstSeriesId = docs.first.data()['recurrenceSeriesId'];

      expect(docs.map((doc) => doc.data()['recurrenceSeriesId']).toSet(), {
        firstSeriesId,
      });
      expect(docs.map((doc) => doc.data()['recurrenceCount']), [3, 3, 3]);
      expect(docs.map((doc) => doc.data()['recurrenceIntervalWeeks']), [
        2,
        2,
        2,
      ]);
      expect(docs.map((doc) => doc.data()['recurrenceIndex']), [0, 1, 2]);

      final dates = docs
          .map((doc) => (doc.data()['dateTime'] as Timestamp).toDate())
          .toList();

      expect(dates[1].difference(dates[0]).inDays, 14);
      expect(dates[2].difference(dates[1]).inDays, 14);
    },
  );
}
