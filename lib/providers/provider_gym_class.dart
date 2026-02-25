import 'package:flutter/material.dart';
import '../models/gym_class.dart';
import '../db_helpers/db_gym_class.dart';

class ProviderGymClass extends ChangeNotifier {
  List<GymClass> _classes = [];
  bool _isLoading = false;

  List<GymClass> get classes => _classes;
  bool get isLoading => _isLoading;

  ProviderGymClass() {
    _init();
  }

  void _init() {
    _isLoading = true;
    DBGymClass.getClassesStream().listen((updatedClasses) {
      _classes = updatedClasses;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addClass(GymClass gymClass) async {
    await DBGymClass.createClass(gymClass);
  }

  Future<void> updateClass(GymClass gymClass) async {
    await DBGymClass.updateClass(gymClass);
  }

  Future<void> deleteClass(String id) async {
    await DBGymClass.deleteClass(id);
  }
}
