import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData iconData;
  final Color color;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconData,
    required this.color,
  });

  static const Achievement starter = Achievement(
    id: 'starter',
    title: 'First Step',
    description: 'Attend 1 class.',
    iconData: Icons.stars,
    color: Color(0xFFF59E0B),
  );

  static const Achievement regular = Achievement(
    id: 'regular',
    title: 'The Regular',
    description: 'Attend 10 classes.',
    iconData: Icons.workspace_premium,
    color: Color(0xFF7C3AED),
  );

  static const Achievement dedicated = Achievement(
    id: 'dedicated',
    title: 'Dedication',
    description: 'Attend 50 classes.',
    iconData: Icons.military_tech,
    color: Color(0xFFDC2626),
  );

  static const Achievement zenMaster = Achievement(
    id: 'zen_master',
    title: 'Zen Master',
    description: 'Attend 5 Yoga classes.',
    iconData: Icons.self_improvement,
    color: Color(0xFF0F766E),
  );

  static const Achievement grooveMachine = Achievement(
    id: 'groove_machine',
    title: 'Groove Machine',
    description: 'Attend 5 Dance classes.',
    iconData: Icons.music_note,
    color: Color(0xFFDB2777),
  );

  static const Achievement roadWarrior = Achievement(
    id: 'road_warrior',
    title: 'Road Warrior',
    description: 'Attend 5 Bike classes.',
    iconData: Icons.directions_run,
    color: Color(0xFF2563EB),
  );

  static const Achievement earlyBird = Achievement(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Attend any class before 9:00 AM.',
    iconData: Icons.wb_sunny,
    color: Color(0xFFF97316),
  );

  static const Achievement nightOwl = Achievement(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Attend any class after 7:00 PM.',
    iconData: Icons.nightlight_round,
    color: Color(0xFF4338CA),
  );

  static const List<Achievement> all = <Achievement>[
    starter,
    regular,
    dedicated,
    zenMaster,
    grooveMachine,
    roadWarrior,
    earlyBird,
    nightOwl,
  ];

  static Achievement? byId(String id) {
    for (final achievement in all) {
      if (achievement.id == id) {
        return achievement;
      }
    }
    return null;
  }

  static List<String> sortAchievementIds(Iterable<String> ids) {
    final idSet = ids.toSet();
    return all
        .where((achievement) => idSet.contains(achievement.id))
        .map((achievement) => achievement.id)
        .toList();
  }

  static List<String> evaluateUnlocks({
    required int totalAttended,
    required Map<String, int> categoryAttendance,
    required DateTime classDateTime,
  }) {
    final unlockedIds = <String>{};

    if (totalAttended >= 1) {
      unlockedIds.add(starter.id);
    }
    if (totalAttended >= 10) {
      unlockedIds.add(regular.id);
    }
    if (totalAttended >= 50) {
      unlockedIds.add(dedicated.id);
    }
    if ((categoryAttendance['Yoga'] ?? 0) >= 5) {
      unlockedIds.add(zenMaster.id);
    }
    if ((categoryAttendance['Dance'] ?? 0) >= 5) {
      unlockedIds.add(grooveMachine.id);
    }
    if ((categoryAttendance['Bike'] ?? 0) >= 5) {
      unlockedIds.add(roadWarrior.id);
    }
    if (classDateTime.hour < 9) {
      unlockedIds.add(earlyBird.id);
    }
    if (classDateTime.hour >= 19) {
      unlockedIds.add(nightOwl.id);
    }

    return sortAchievementIds(unlockedIds);
  }
}
