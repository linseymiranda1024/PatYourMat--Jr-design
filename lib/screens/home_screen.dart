import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'class_detail_screen.dart'; // ← Add this import
// Adjust the path above if your folder structure is different, e.g.:
// import '../screens/class_detail_screen.dart';
// or
// import 'package:your_app_name/screens/class_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  static const routeName = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  children: [
                    const Text(
                      'Pat Your Mat!',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Find your perfect class',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xE6FFFFFF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                  children: const [
                    _FilterChip(
                      selected: true,
                      icon: Icons.calendar_month,
                      label: 'Today',
                    ),
                    SizedBox(width: 10),
                    _FilterChip(label: 'Yoga'),
                    SizedBox(width: 10),
                    _FilterChip(label: 'Cardio'),
                    SizedBox(width: 10),
                    _FilterChip(icon: Icons.tune, label: 'More'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ClassCard(
                    title: 'Power Yoga',
                    instructor: 'Sarah Johnson',
                    dateText: 'Mon, Feb 3',
                    timeText: '6:00 AM',
                    durationText: '60 min',
                    status: ClassStatus.open,
                    filled: 12,
                    capacity: 30,
                    onTap: () => context.push(ClassDetailScreen.routeName),
                  ),
                  const SizedBox(height: 16),
                  ClassCard(
                    title: 'HIIT Blast',
                    instructor: 'Mike Chen',
                    dateText: 'Mon, Feb 3',
                    timeText: '7:30 AM',
                    durationText: '45 min',
                    status: ClassStatus.full,
                    filled: 25,
                    capacity: 25,
                    onTap: () => context.push(ClassDetailScreen.routeName),
                  ),
                  const SizedBox(height: 16),
                  ClassCard(
                    title: 'Pilates Core',
                    instructor:
                        'Emma Wilson', // ← completed name (was truncated)
                    dateText: 'Mon, Feb 3',
                    timeText: '8:30 AM',
                    durationText: '45 min',
                    status: ClassStatus.open,
                    filled: 15,
                    capacity: 25,
                    onTap: () => context.push(ClassDetailScreen.routeName),
                  ),
                  // Add more ClassCard widgets here if needed
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Existing helper widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final String hintText;

  const _SearchBar({required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final bool selected;
  final IconData? icon;
  final String label;

  const _FilterChip({this.selected = false, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: (value) {},
      label: Row(
        children: [
          if (icon != null) Icon(icon, size: 18),
          if (icon != null) const SizedBox(width: 6),
          Text(label),
        ],
      ),
      backgroundColor: selected ? const Color(0xFF6200EE) : Colors.white,
      selectedColor: const Color(0xFF6200EE),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: selected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Updated ClassCard – now supports onTap
// ─────────────────────────────────────────────────────────────────────────────

enum ClassStatus { open, full, standby }

class ClassCard extends StatelessWidget {
  final String title;
  final String instructor;
  final String dateText;
  final String timeText;
  final String durationText;
  final ClassStatus status;
  final int filled;
  final int capacity;
  final VoidCallback? onTap; // ← NEW: added callback

  const ClassCard({
    super.key,
    required this.title,
    required this.instructor,
    required this.dateText,
    required this.timeText,
    required this.durationText,
    required this.status,
    required this.filled,
    required this.capacity,
    this.onTap,
  });

  double get progress => filled / capacity;

  @override
  Widget build(BuildContext context) {
    final statusUi = _statusUi(status);

    return InkWell(
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
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
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
                        status == ClassStatus.full
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
    );
  }

  _StatusStyle _statusUi(ClassStatus s) {
    switch (s) {
      case ClassStatus.open:
        return const _StatusStyle('Open', Color(0xFFDFF8E8), Color(0xFF0A7A2A));
      case ClassStatus.full:
        return const _StatusStyle('Full', Color(0xFFFBE2E2), Color(0xFFB00020));
      case ClassStatus.standby:
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
