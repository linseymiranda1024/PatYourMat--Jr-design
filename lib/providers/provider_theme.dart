import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Use StateProvider for simple state like a boolean
final themeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});
