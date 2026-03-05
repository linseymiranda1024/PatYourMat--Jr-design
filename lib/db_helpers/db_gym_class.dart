import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym_class.dart';

class DBGymClass {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'classes';

  static Future<void> createClass(GymClass gymClass) async {
    await _db.collection(_collection).add(gymClass.toFirestore());
  }

  static Stream<List<GymClass>> getClassesStream() {
    return _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => GymClass.fromFirestore(doc)).toList(),
        );
  }

  static Future<List<GymClass>> getClassesOnce() async {
    final snapshot = await _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .get();
    return snapshot.docs.map((doc) => GymClass.fromFirestore(doc)).toList();
  }

  static Stream<GymClass?> getClassStream(String id) {
    return _db.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GymClass.fromFirestore(doc);
    });
  }

  static Future<void> updateClass(GymClass gymClass) async {
    await _db
        .collection(_collection)
        .doc(gymClass.id)
        .update(gymClass.toFirestore());
  }

  static Future<void> deleteClass(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}
