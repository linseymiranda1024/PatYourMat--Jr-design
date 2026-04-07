import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';
import '../util/date_time/util_attendance.dart';
import 'profile_screen.dart';

class ScreenMemberPreviousClasses extends ConsumerWidget {
  static const routeName = '/member/previous-classes';

  const ScreenMemberPreviousClasses({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = previousMemberReservations(
      ref.watch(reservationsProvider).reservations,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Previous Classes')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Past reservations are grouped here for quick reference.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (reservations.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    'No previous classes yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                )
              else
                Column(
                  children: reservations
                      .map(
                        (reservation) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PreviousClassCard(reservation: reservation),
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
}

class _PreviousClassCard extends StatelessWidget {
  final Reservation reservation;

  const _PreviousClassCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusStyle = _statusStyleForReservation(reservation, context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
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
                      reservation.className,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.instructor,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _AttendanceBadge(statusStyle: statusStyle),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.schedule, text: reservation.dateTime),
              _InfoPill(
                icon: Icons.place_outlined,
                text: reservation.matNumber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  final _AttendanceStatusStyle statusStyle;

  const _AttendanceBadge({required this.statusStyle});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusStyle.backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusStyle.icon, size: 14, color: statusStyle.color),
          const SizedBox(width: 6),
          Text(
            statusStyle.label,
            style: textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: statusStyle.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AttendanceStatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _AttendanceStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

_AttendanceStatusStyle _statusStyleForReservation(
  Reservation reservation,
  BuildContext context,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final normalizedStatus = effectiveReservationStatus(
    rawStatus: reservation.status,
    classStart: reservation.date,
    durationMinutes: reservation.durationMinutes,
  );

  if (normalizedStatus == ReservationStatus.attended) {
    return _AttendanceStatusStyle(
      label: 'Attended',
      icon: Icons.check_circle,
      color: AppColors.success,
      backgroundColor: AppColors.success.withValues(
        alpha: isDark ? 0.24 : 0.12,
      ),
    );
  }

  if (normalizedStatus == ReservationStatus.noShow) {
    return _AttendanceStatusStyle(
      label: 'No Show',
      icon: Icons.cancel_outlined,
      color: AppColors.error,
      backgroundColor: colorScheme.outlineVariant,
    );
  }

  return _AttendanceStatusStyle(
    label: 'Scheduled',
    icon: Icons.check_circle_outline,
    color: AppColors.deepPurple,
    backgroundColor: AppColors.deepPurple.withValues(
      alpha: isDark ? 0.24 : 0.12,
    ),
  );
}
