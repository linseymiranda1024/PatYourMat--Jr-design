import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/gym_class.dart';

typedef DeleteClassFully = Future<void> Function(String classId);

class DBGymClass {
  static FirebaseFirestore _db = FirebaseFirestore.instance;
  static FirebaseStorage _storage = FirebaseStorage.instance;
  static DeleteClassFully? _deleteClassFullyOverride;
  static const String _collection = 'classes';

  @visibleForTesting
  static void useFirestoreInstance(FirebaseFirestore firestore) {
    _db = firestore;
  }

  @visibleForTesting
  static void useStorageInstance(FirebaseStorage storage) {
    _storage = storage;
  }

  @visibleForTesting
  static void useDeleteClassFunction(DeleteClassFully deleteClassFully) {
    _deleteClassFullyOverride = deleteClassFully;
  }

  @visibleForTesting
  static void resetFirestoreInstance() {
    _deleteClassFullyOverride = null;
    try {
      _db = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
    } catch (_) {
      // Tests may override the Firestore instance without initializing Firebase.
    }
  }

  static Future<void> createClass(GymClass gymClass) async {
    final docRef = _db.collection(_collection).doc();
    final classes = buildRecurringClassSeries(
      template: gymClass,
      seriesId: docRef.id,
      idBuilder: (_) => docRef.id,
      occurrenceCount: 1,
    );
    await docRef.set(classes.single.toFirestore());
  }

  static Future<void> createRecurringClassSeries(
    GymClass gymClass, {
    required int occurrenceCount,
    int intervalWeeks = 1,
  }) async {
    final batch = _db.batch();
    final seriesId = _db.collection(_collection).doc().id;
    final classes = buildRecurringClassSeries(
      template: gymClass,
      seriesId: seriesId,
      idBuilder: (_) => _db.collection(_collection).doc().id,
      occurrenceCount: occurrenceCount,
      intervalWeeks: intervalWeeks,
    );

    for (final occurrence in classes) {
      final docRef = _db.collection(_collection).doc(occurrence.id);
      batch.set(docRef, occurrence.toFirestore());
    }

    await batch.commit();
  }

  static Stream<List<GymClass>> getClassesStream() {
    return _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(GymClass.fromFirestore).toList());
  }

  static Future<List<GymClass>> getClassesOnce() async {
    final snapshot = await _db
        .collection(_collection)
        .orderBy('dateTime', descending: false)
        .get();
    return snapshot.docs.map(GymClass.fromFirestore).toList();
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
        .update(
          gymClass
              .copyWith(
                recurrenceSeriesId: gymClass.recurrenceSeriesId.isEmpty
                    ? gymClass.id
                    : gymClass.recurrenceSeriesId,
              )
              .toFirestore(),
        );
  }

  static Future<void> deleteClass(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Class id cannot be empty.');
    }

    final deleteClassFully = _deleteClassFullyOverride;
    if (deleteClassFully != null) {
      await deleteClassFully(cleanId);
      return;
    }

    await FirebaseFunctions.instance.httpsCallable('deleteClassFully').call(
      <String, dynamic>{'classId': cleanId},
    );
  }

  static Future<String> uploadClassImage({
    required Uint8List imageBytes,
    required String imageId,
  }) async {
    final cleanImageId = _sanitizeStorageSegment(imageId);
    final ref = _storage.ref().child(
      'classes/images/$cleanImageId-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static String _sanitizeStorageSegment(String value) {
    final sanitized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return sanitized.isEmpty ? 'class-image' : sanitized;
  }
}
