import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../db_helpers/db_reservations.dart';
import '../../main.dart';
import '../../models/gym_class.dart';
import '../../theme/app_colors.dart';
import 'screen_staff_attendance.dart';
import 'screen_create_class.dart';

class ScreenStaffClassList extends ConsumerWidget {
  static const routeName = '/staff/classes';

  final bool showPast;

  const ScreenStaffClassList({super.key, required this.showPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymClassProvider = ref.watch(providerGymClass);
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final classes = [...gymClassProvider.classes];
    final filteredClasses =
        classes.where((gymClass) {
          return showPast
              ? gymClass.dateTime.isBefore(now)
              : !gymClass.dateTime.isBefore(now);
        }).toList()..sort(
          (a, b) => showPast
              ? b.dateTime.compareTo(a.dateTime)
              : a.dateTime.compareTo(b.dateTime),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(showPast ? 'Recent Classes' : 'Active Classes'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showPast
                    ? 'Completed classes kept here for quick reference.'
                    : 'Current and upcoming classes on the live schedule.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (gymClassProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (filteredClasses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    showPast
                        ? 'No recent classes yet.'
                        : 'No active classes are scheduled yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                )
              else
                Column(
                  children: filteredClasses
                      .map(
                        (gymClass) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildClassCard(context, gymClass),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, GymClass gymClass) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final attendanceEnabled = isAttendanceWindowOpen(gymClass.dateTime);
    return StreamBuilder<int>(
      stream: DBReservations.getReservationCountForClassStream(gymClass.id),
      builder: (context, snapshot) {
        final filled = snapshot.data ?? gymClass.filled;
        final occupancy = gymClass.capacity == 0
            ? 0.0
            : filled / gymClass.capacity;

        return Container(
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
              const SizedBox(height: 10),
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
