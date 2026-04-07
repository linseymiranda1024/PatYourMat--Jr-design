import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pat_your_mat/theme/app_colors.dart';

import '../../db_helpers/db_reservations.dart';
import '../../models/gym_class.dart';
import '../../util/date_time/util_attendance.dart';
import '../../widgets/navigation/widget_app_outline.dart';
import 'screen_staff_class_list.dart';
import 'screen_staff_attendance.dart';
import 'screen_create_class.dart';
import '../../main.dart';

class ScreenStaffPortal extends ConsumerWidget {
  static const routeName = '/staff_portal';

  const ScreenStaffPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(providerUserProfile);
    final gymClassProvider = ref.watch(providerGymClass);
    final now = DateTime.now();
    final classes = [...gymClassProvider.classes]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final upcomingClasses = classes
        .where(
          (gymClass) => !attendanceWindowCloses(
            gymClass.dateTime,
            durationMinutes: gymClass.durationMinutes,
          ).isBefore(now),
        )
        .toList();
    final previousClasses =
        classes
            .where(
              (gymClass) => attendanceWindowCloses(
                gymClass.dateTime,
                durationMinutes: gymClass.durationMinutes,
              ).isBefore(now),
            )
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final todayClasses = upcomingClasses
        .where((gymClass) => _isSameDay(gymClass.dateTime, now))
        .toList();
    final nextClass = upcomingClasses.isEmpty ? null : upcomingClasses.first;
    final totalOpenSpotsToday = todayClasses.fold<int>(
      0,
      (total, gymClass) => total + (gymClass.capacity - gymClass.filled),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(
                context,
                userProfile,
                todayCount: todayClasses.length,
                nextClass: nextClass,
              ),
              const SizedBox(height: 20),
              _buildPanel(
                context: context,
                title: 'Today At A Glance',
                subtitle: 'A compact view of what needs attention right now.',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 380;
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    final cardHeight = isNarrow ? 132.0 : 120.0;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildStatCard(
                            context: context,
                            label: 'Classes Today',
                            value: '${todayClasses.length}',
                            icon: Icons.today_outlined,
                            color: AppColors.deepPurple,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildStatCard(
                            context: context,
                            label: 'Next Start',
                            value: nextClass?.timeText ?? 'None',
                            icon: Icons.schedule_outlined,
                            color: const Color(0xFF1F8F71),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildStatCard(
                            context: context,
                            label: 'Open Spots Today',
                            value: '$totalOpenSpotsToday',
                            icon: Icons.event_seat_outlined,
                            color: colorScheme.secondary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _buildStatCard(
                            context: context,
                            label: 'Upcoming Classes',
                            value: '${upcomingClasses.length}',
                            icon: Icons.class_,
                            color: const Color(0xFFC77718),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildPanel(
                context: context,
                title: 'Quick Actions',
                subtitle:
                    'Keep the class schedule moving without extra clutter.',
                child: Column(
                  children: [
                    _buildActionRow(
                      context: context,
                      icon: Icons.add_box_outlined,
                      label: 'Create Class',
                      description: 'Add a new class to the schedule.',
                      accent: AppColors.deepPurple,
                      onTap: () => context.push(ScreenCreateClass.routeName),
                    ),
                    const SizedBox(height: 10),
                    _buildActionRow(
                      context: context,
                      icon: Icons.person_outline,
                      label: 'View Staff Profile',
                      description:
                          'Review teaching details and instructor settings.',
                      accent: const Color(0xFF1F8F71),
                      onTap: () =>
                          context.go('${WidgetAppOutline.routeName}?tab=3'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildPanel(
                context: context,
                title: 'Active Classes',
                subtitle: 'Preview the live schedule, then open the full list.',
                child: gymClassProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : upcomingClasses.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          'No active classes are scheduled yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      )
                    : Column(
                        children: [
                          ...upcomingClasses
                              .take(3)
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildManagementItem(context, ref, c),
                                ),
                              ),
                          _buildViewAllButton(
                            label: 'View all active classes',
                            onTap: () => context.push(
                              ScreenStaffClassList.routeName,
                              extra: {'showPast': false},
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              _buildPanel(
                context: context,
                title: 'Recent Classes',
                subtitle:
                    'A short look at recently completed classes and history.',
                child: gymClassProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : previousClasses.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          'No recent classes yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      )
                    : Column(
                        children: [
                          ...previousClasses
                              .take(3)
                              .map(
                                (c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildManagementItem(context, ref, c),
                                ),
                              ),
                          _buildViewAllButton(
                            label: 'View all recent classes',
                            onTap: () => context.push(
                              ScreenStaffClassList.routeName,
                              extra: {'showPast': true},
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              _buildPanel(
                context: context,
                title: 'Schedule Coverage',
                subtitle: 'High-level support for planning the full roster.',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          height: 120,
                          child: _buildStatCard(
                            context: context,
                            label: 'Total Scheduled',
                            value: '${classes.length}',
                            icon: Icons.calendar_month_outlined,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          height: 120,
                          child: _buildStatCard(
                            context: context,
                            label: 'Listed Instructors',
                            value:
                                '${classes.map((c) => c.instructor).toSet().length}',
                            icon: Icons.groups_2_outlined,
                            color: const Color(0xFFC77718),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    userProfile, {
    required int todayCount,
    required GymClass? nextClass,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
              : const [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff Portal',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headerOnBrand,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userProfile.firstName.trim().isEmpty
                    ? 'Run today’s schedule, check class coverage, and create new sessions.'
                    : 'Welcome back, ${userProfile.firstName}. Run today’s schedule, check class coverage, and create new sessions.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.headerOnBrand.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeaderBadge(
                    context: context,
                    icon: Icons.today_outlined,
                    label: '$todayCount today',
                  ),
                  _buildHeaderBadge(
                    context: context,
                    icon: Icons.schedule_outlined,
                    label: nextClass == null
                        ? 'No next class'
                        : 'Next ${nextClass.timeText}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeaderAction(
                    context: context,
                    label: 'Create Class',
                    icon: Icons.add,
                    filled: true,
                    onTap: () => context.push(ScreenCreateClass.routeName),
                  ),
                  _buildHeaderAction(
                    context: context,
                    label: 'Staff Profile',
                    icon: Icons.person_outline,
                    filled: false,
                    onTap: () =>
                        context.go('${WidgetAppOutline.routeName}?tab=3'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderBadge({
    required BuildContext context,
    required IconData icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.headerOnBrand.withValues(alpha: isDark ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.headerOnBrand.withValues(
            alpha: isDark ? 0.12 : 0.14,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.headerOnBrand),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.headerOnBrand,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.headerOnBrand.withValues(alpha: 0.10)
              : AppColors.headerOnBrand,
          foregroundColor: isDark
              ? AppColors.headerOnBrand
              : AppColors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.headerOnBrand,
        side: BorderSide(
          color: AppColors.headerOnBrand.withValues(
            alpha: isDark ? 0.18 : 0.54,
          ),
        ),
        backgroundColor: isDark
            ? AppColors.headerOnBrand.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: child,
    );
  }

  Widget _buildPanel({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.25,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: isDark ? 0.28 : 0.14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildManagementItem(
    BuildContext context,
    WidgetRef ref,
    GymClass gymClass,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final attendanceEnabled = isAttendanceWindowOpen(
      gymClass.dateTime,
      durationMinutes: gymClass.durationMinutes,
    );
    return StreamBuilder<int>(
      stream: DBReservations.getReservationCountForClassStream(gymClass.id),
      builder: (context, snapshot) {
        final filled = snapshot.data ?? gymClass.filled;
        final occupancy = gymClass.capacity == 0
            ? 0.0
            : filled / gymClass.capacity;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      gymClass.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      gymClass.timeText,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${gymClass.instructor} • ${gymClass.dateText} • ${gymClass.location}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: occupancy,
                  minHeight: 8,
                  backgroundColor: colorScheme.outlineVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$filled/${gymClass.capacity} seats filled',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: attendanceEnabled
                          ? () => context.push(
                              ScreenStaffAttendance.routeName,
                              extra: gymClass,
                            )
                          : null,
                      icon: const Icon(Icons.how_to_reg_outlined),
                      label: const Text('Attendance'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push(
                        ScreenCreateClass.routeName,
                        extra: gymClass,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Class'),
                            content: const Text(
                              'Are you sure you want to delete this class?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(providerGymClass)
                                      .deleteClass(gymClass.id);
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
