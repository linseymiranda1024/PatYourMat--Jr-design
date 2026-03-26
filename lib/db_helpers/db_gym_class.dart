import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/gym_class.dart';

class DBGymClass {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'classes';
  static const String _userProfilesCollection = 'user_profiles';

  static Future<void> createClass(GymClass gymClass) async {
    await _db.collection(_collection).add(gymClass.toFirestore());
  }

  static Stream<List<GymClass>> getClassesStream() {
    return _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .asyncMap(
          (snapshot) =>
              Future.wait(snapshot.docs.map((doc) => _hydrateGymClass(doc))),
        );
  }

  static Future<List<GymClass>> getClassesOnce() async {
    final snapshot = await _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .get();
    return Future.wait(snapshot.docs.map((doc) => _hydrateGymClass(doc)));
  }

  static Stream<GymClass?> getClassStream(String id) {
    return _db.collection(_collection).doc(id).snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return null;
      return _hydrateGymClass(doc);
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

  static Future<GymClass> _hydrateGymClass(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final gymClass = GymClass.fromFirestore(doc);
    final resolvedFilled = await _resolveFilledCount(
      doc.reference,
      gymClass,
      doc.data() ?? <String, dynamic>{},
    );

    return GymClass(
      id: gymClass.id,
      title: gymClass.title,
      description: gymClass.description,
      type: gymClass.type,
      instructor: gymClass.instructor,
      dateTime: gymClass.dateTime,
      durationMinutes: gymClass.durationMinutes,
      location: gymClass.location,
      capacity: gymClass.capacity,
      filled: resolvedFilled,
      status: _resolveStatus(gymClass, resolvedFilled),
    );
  }

  static Future<int> _resolveFilledCount(
    DocumentReference<Map<String, dynamic>> classRef,
    GymClass gymClass,
    Map<String, dynamic> classData,
  ) async {
    try {
      final snapshot = await _db
          .collectionGroup('registrations')
          .where('classId', isEqualTo: gymClass.id)
          .get();
      final activeReservationCount = snapshot.docs
          .where((doc) => _isUserProfileRegistrationDoc(doc.reference))
          .length;
      return activeReservationCount.clamp(0, gymClass.capacity);
    } catch (_) {
      final reservedMats = _parseReservedMats(classData['reservedMats']);
      if (classData.containsKey('reservedMats')) {
        return reservedMats.length.clamp(0, gymClass.capacity);
      }
      return gymClass.filled.clamp(0, gymClass.capacity);
    }
  }

  static Set<String> _parseReservedMats(dynamic rawValue) {
    if (rawValue is! List) {
      return <String>{};
    }

    return rawValue
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  static bool _isUserProfileRegistrationDoc(DocumentReference ref) {
    final parentDoc = ref.parent.parent;
    if (parentDoc == null) {
      return false;
    }
    return parentDoc.parent.id == _userProfilesCollection;
  }

  static ClassStatus _resolveStatus(GymClass gymClass, int filled) {
    if (gymClass.capacity > 0 && filled >= gymClass.capacity) {
      return ClassStatus.full;
    }
    if (gymClass.status == ClassStatus.standby) {
      return ClassStatus.standby;
    }
    return ClassStatus.open;
  }
}
