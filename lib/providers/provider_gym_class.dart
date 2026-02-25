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
    print('DEBUG: Initializing GymClass Stream...');
    DBGymClass.getClassesStream().listen((updatedClasses) {
      print('DEBUG: Received ${updatedClasses.length} classes from Firestore');
      _classes = updatedClasses;
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      print('DEBUG: Firestore Stream Error: $error');
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
