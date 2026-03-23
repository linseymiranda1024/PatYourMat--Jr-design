import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/user_profile.dart';

/// This provider manages the state of the current user's profile.
/// It starts with an empty profile using the named constructor from your model.
final userProvider = StateProvider<UserProfile>((ref) {
  return UserProfile.empty();
});
