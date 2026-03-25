import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../models/gym_class.dart' as model;
import 'class_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const routeName = "/home";

  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const List<String> _filterTypes = [
    'All',
    'Yoga',
    'Sport',
    'Pilates',
    'HIIT',
    'Strength',
    'Cardio',
    'Dance',
    'Mobility',
    'Meditation',
    'Recovery',
  ];

  String _selectedType = 'All';

  @override
  Widget build(BuildContext context) {
    final gymClassProvider = ref.watch(providerGymClass);
    final classes = gymClassProvider.classes;

    final filteredClasses = _selectedType == 'All'
        ? classes
        : classes.where((c) => c.type == _selectedType).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8A2BFF), Color(0xFF2F7BFF)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: Offset(0, 10),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Pat Your Mat!',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Find your perfect class',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xE6FFFFFF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 18),
                    _SearchBar(hintText: 'Search classes...'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filterTypes
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _FilterChip(
                            selected: _selectedType == type,
                            icon: type == 'All' ? Icons.tune : null,
                            label: type,
                            onTap: () => setState(() => _selectedType = type),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: gymClassProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : classes.isEmpty
                      ? const Center(child: Text('No classes available yet.'))
                      : filteredClasses.isEmpty
                          ? Center(
                              child: Text(
                                'No $_selectedType classes available right now.',
                              ),
                            )
                          : Column(
                              children: filteredClasses
                                  .map(
                                    (c) => Column(
                                      children: [
                                        ClassCard(
                                          title: c.title,
                                          type: c.type,
                                          instructor: c.instructor,
                                          dateText: c.dateText,
                                          timeText: c.timeText,
                                          durationText: c.durationText,
                                          status: c.status,
                                          filled: c.filled,
                                          capacity: c.capacity,
                                          onTap: () => context.push(
                                            ClassDetailScreen.routeName,
                                            extra: c,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;

  const _SearchBar({required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white.withOpacity(0.75)),
          const SizedBox(width: 10),
          Text(
            hintText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final bool selected;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  const _FilterChip({
    this.selected = false,
    this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final purple = const Color(0xFF7A2CFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? purple : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: selected ? purple : const Color(0xFFE3E6EF),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      blurRadius: 12,
                      offset: Offset(0, 6),
                      color: Color(0x22000000),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassCard extends StatelessWidget {
  final String title;
  final String type;
  final String instructor;
  final String dateText;
  final String timeText;
  final String durationText;
  final model.ClassStatus status;
  final int filled;
  final int capacity;
  final VoidCallback? onTap;

  const ClassCard({
    super.key,
    required this.title,
    required this.type,
    required this.instructor,
    required this.dateText,
    required this.timeText,
    required this.durationText,
    required this.status,
    required this.filled,
    required this.capacity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusUi = _statusUi(status);
    final progress = capacity == 0 ? 0.0 : (filled / capacity).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x14000000),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0EBFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B39D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusPill(
                    text: statusUi.label,
                    bg: statusUi.bg,
                    fg: statusUi.fg,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                instructor,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    timeText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    '•',
                    style: TextStyle(color: Colors.black45, fontSize: 16),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    durationText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE9ECF3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          status == model.ClassStatus.full
                              ? const Color(0xFFB00020)
                              : const Color(0xFF7A2CFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$filled/$capacity',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusStyle _statusUi(model.ClassStatus s) {
    switch (s) {
      case model.ClassStatus.open:
        return const _StatusStyle('Open', Color(0xFFDFF8E8), Color(0xFF0A7A2A));
      case model.ClassStatus.full:
        return const _StatusStyle('Full', Color(0xFFFBE2E2), Color(0xFFB00020));
      case model.ClassStatus.standby:
        return const _StatusStyle(
          'Standby',
          Color(0xFFFFE9D6),
          Color(0xFFB85A00),
        );
    }
  }
}

class _StatusStyle {
  final String label;
  final Color bg;
  final Color fg;

  const _StatusStyle(this.label, this.bg, this.fg);
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _StatusPill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}
