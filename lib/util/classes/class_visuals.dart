import 'package:flutter/material.dart';

import '../../models/gym_class.dart';

class GymClassVisualOption {
  final String key;
  final String label;
  final IconData icon;
  final List<Color> colors;

  const GymClassVisualOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.colors,
  });
}

const List<GymClassVisualOption> gymClassVisualOptions = <
  GymClassVisualOption
>[
  GymClassVisualOption(
    key: 'lotus',
    label: 'Mindful',
    icon: Icons.self_improvement_rounded,
    colors: <Color>[Color(0xFFB07C5B), Color(0xFFE4BC97)],
  ),
  GymClassVisualOption(
    key: 'soccer',
    label: 'Sport',
    icon: Icons.sports_soccer_rounded,
    colors: <Color>[Color(0xFF216869), Color(0xFF49A078)],
  ),
  GymClassVisualOption(
    key: 'flame',
    label: 'HIIT',
    icon: Icons.local_fire_department_rounded,
    colors: <Color>[Color(0xFFD95D39), Color(0xFFF0A202)],
  ),
  GymClassVisualOption(
    key: 'dumbbell',
    label: 'Strength',
    icon: Icons.fitness_center_rounded,
    colors: <Color>[Color(0xFF2D3142), Color(0xFF4F5D75)],
  ),
  GymClassVisualOption(
    key: 'heart',
    label: 'Cardio',
    icon: Icons.favorite_rounded,
    colors: <Color>[Color(0xFF8E5572), Color(0xFFE56B6F)],
  ),
  GymClassVisualOption(
    key: 'dance',
    label: 'Dance',
    icon: Icons.music_note_rounded,
    colors: <Color>[Color(0xFF355070), Color(0xFF6D597A)],
  ),
  GymClassVisualOption(
    key: 'stretch',
    label: 'Mobility',
    icon: Icons.accessibility_new_rounded,
    colors: <Color>[Color(0xFF5C946E), Color(0xFF9DD9D2)],
  ),
  GymClassVisualOption(
    key: 'meditate',
    label: 'Meditation',
    icon: Icons.spa_rounded,
    colors: <Color>[Color(0xFF5E548E), Color(0xFF9F86C0)],
  ),
  GymClassVisualOption(
    key: 'spark',
    label: 'Recovery',
    icon: Icons.auto_awesome_rounded,
    colors: <Color>[Color(0xFF3D5A80), Color(0xFF98C1D9)],
  ),
];

GymClassVisualOption gymClassVisualForKey(String? key, {String? classType}) {
  final normalizedKey = normalizeGymClassIconKey(key, classType: classType);
  return gymClassVisualOptions.firstWhere(
    (option) => option.key == normalizedKey,
    orElse: () => gymClassVisualOptions.firstWhere(
      (option) => option.key == defaultGymClassIconKeyForType(classType),
      orElse: () => gymClassVisualOptions.last,
    ),
  );
}
