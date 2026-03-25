import 'dart:async';

import 'package:flutter/material.dart';

import '../db_helpers/db_gym_class.dart';
import '../models/gym_class.dart';

class ProviderGymClass extends ChangeNotifier {
  List<GymClass> _classes = [];
  bool _isLoading = false;
  StreamSubscription<List<GymClass>>? _classesSubscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  List<GymClass> get classes => _classes;
  bool get isLoading => _isLoading;

  ProviderGymClass() {
    _init();
  }

  void _init() {
    _isLoading = true;
    notifyListeners();
    _startStream();
  }

  void _startStream() {
    _reconnectTimer?.cancel();
    _classesSubscription?.cancel();
    print('DEBUG: Initializing GymClass Stream...');
    _classesSubscription = DBGymClass.getClassesStream().listen(
      (updatedClasses) {
        print(
          'DEBUG: Received ${updatedClasses.length} classes from Firestore',
        );
        _classes = updatedClasses;
        _isLoading = false;
        if (!_isDisposed) {
          notifyListeners();
        }
      },
      onError: (error) {
        print('DEBUG: Firestore Stream Error: $error');
        _isLoading = false;
        if (!_isDisposed) {
          notifyListeners();
          _scheduleReconnect();
        }
      },
      onDone: () {
        if (!_isDisposed) {
          _scheduleReconnect();
        }
      },
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!_isDisposed) {
        _startStream();
      }
    });
  }

  Future<void> refreshClasses() async {
    final latestClasses = await DBGymClass.getClassesOnce();
    _classes = latestClasses;
    _isLoading = false;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> addClass(GymClass gymClass) async {
    await DBGymClass.createClass(gymClass);
    await refreshClasses();
  }

  Future<void> updateClass(GymClass gymClass) async {
    await DBGymClass.updateClass(gymClass);
    await refreshClasses();
  }

  Future<void> deleteClass(String id) async {
    await DBGymClass.deleteClass(id);
    await refreshClasses();
  }

  void applyLocalRegistrationDelta(String classId, int delta) {
    final index = _classes.indexWhere((c) => c.id == classId);
    if (index == -1) return;

    final existing = _classes[index];
    final nextFilled = (existing.filled + delta).clamp(0, existing.capacity);
    final nextStatus = nextFilled >= existing.capacity
        ? ClassStatus.full
        : ClassStatus.open;

    _classes[index] = GymClass(
      id: existing.id,
      title: existing.title,
      type: existing.type,
      description: existing.description,
      instructor: existing.instructor,
      dateTime: existing.dateTime,
      durationMinutes: existing.durationMinutes,
      location: existing.location,
      capacity: existing.capacity,
      filled: nextFilled,
      status: nextStatus,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }
}
