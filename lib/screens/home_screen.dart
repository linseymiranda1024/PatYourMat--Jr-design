import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../models/gym_class.dart' as model;
import '../theme/app_colors.dart';
import 'class_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  static const routeName = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymClassProvider = ref.watch(providerGymClass);
    final classes = gymClassProvider.classes;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final headerGradient = theme.brightness == Brightness.dark
        ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
        : const [AppColors.gradientStart, AppColors.gradientEnd];

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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: 0.14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pat Your Mat!',
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headerOnBrand,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Find your perfect class',
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        color: AppColors.headerOnBrandMuted,
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
              child: gymClassProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : classes.isEmpty
                  ? const Center(child: Text('No classes available yet.'))
                  : Column(
                      children: classes
                          .map(
                            (c) => Column(
                              children: [
                                ClassCard(
                                  title: c.title,
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.headerOnBrand.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.headerOnBrand.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: AppColors.headerOnBrand.withValues(alpha: 0.76),
          ),
          const SizedBox(width: 10),
          Text(
            hintText,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.headerOnBrand.withValues(alpha: 0.76),
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

  const _FilterChip({this.selected = false, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fillColor = selected
        ? colorScheme.primary
        : colorScheme.surfaceContainer;
    final outlineColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final foregroundColor = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: outlineColor),
        boxShadow: selected
            ? [
                BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class ClassCard extends StatelessWidget {
  final String title;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.08),
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
                      style: textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusPill(text: statusUi.label, accent: statusUi.accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                instructor,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dateText,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    timeText,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '•',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    durationText,
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
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
                        backgroundColor: colorScheme.outlineVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          status == model.ClassStatus.full
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$filled/$capacity',
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
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
    const open = AppColors.success;
    const full = AppColors.error;
    const standby = AppColors.warning;
    switch (s) {
      case model.ClassStatus.open:
        return const _StatusStyle('Open', open);
      case model.ClassStatus.full:
        return const _StatusStyle('Full', full);
      case model.ClassStatus.standby:
        return const _StatusStyle('Standby', standby);
    }
  }
}

class _StatusStyle {
  final String label;
  final Color accent;
  const _StatusStyle(this.label, this.accent);
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color accent;

  const _StatusPill({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
