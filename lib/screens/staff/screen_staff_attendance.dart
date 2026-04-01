import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db_helpers/db_reservations.dart';
import '../../models/gym_class.dart';
import '../../models/reservation.dart';
import '../../theme/app_colors.dart';

const Duration _attendanceWindow = Duration(minutes: 30);

bool isAttendanceWindowOpen(DateTime classStart, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  return !currentTime.isBefore(classStart.subtract(_attendanceWindow)) &&
      !currentTime.isAfter(classStart.add(_attendanceWindow));
}

class ScreenStaffAttendance extends ConsumerWidget {
  static const routeName = '/staff/attendance';

  final GymClass gymClass;

  const ScreenStaffAttendance({super.key, required this.gymClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SafeArea(
        child: StreamBuilder<List<Reservation>>(
          stream: DBReservations.getReservationsForClassStream(gymClass.id),
          builder: (context, snapshot) {
            final reservations = snapshot.data ?? const <Reservation>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gymClass.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${gymClass.dateText} at ${gymClass.timeText} • ${gymClass.instructor}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      reservations.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else if (reservations.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'No reservations found for this class yet.',
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
                              child: _AttendeeCard(
                                reservation: reservation,
                                gymClass: gymClass,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AttendeeCard extends ConsumerWidget {
  final Reservation reservation;
  final GymClass gymClass;

  const _AttendeeCard({required this.reservation, required this.gymClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = normalizeReservationStatus(reservation.status);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.userName.isEmpty
                          ? 'Unnamed Member'
                          : reservation.userName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.userEmail.isEmpty
                          ? 'No email on file'
                          : reservation.userEmail,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reservation.matNumber,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (status == ReservationStatus.attended)
            _StatusBadge(
              label: 'Checked In',
              icon: Icons.check_circle,
              color: AppColors.success,
            )
          else if (status == ReservationStatus.noShow)
            _StatusBadge(
              label: 'No Show',
              icon: Icons.cancel_outlined,
              color: colorScheme.onSurfaceVariant,
              backgroundColor: colorScheme.outlineVariant,
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: reservation.userId.isEmpty
                        ? null
                        : () => _checkInUser(context, reservation),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Check In'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: reservation.userId.isEmpty
                        ? null
                        : () => _markNoShow(context),
                    icon: const Icon(Icons.close),
                    label: const Text('No Show'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _checkInUser(
    BuildContext context,
    Reservation reservation,
  ) async {
    try {
      await DBReservations.checkInUser(
        reservation.userId,
        reservation,
        gymClass,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_displayName(reservation)} checked in')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _markNoShow(BuildContext context) async {
    try {
      await DBReservations.markNoShow(reservation.userId, gymClass.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_displayName(reservation)} marked as No Show'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  String _displayName(Reservation reservation) {
    if (reservation.userName.trim().isNotEmpty) {
      return reservation.userName.trim();
    }
    if (reservation.userEmail.trim().isNotEmpty) {
      return reservation.userEmail.trim();
    }
    return 'User';
  }

  String _errorMessage(Object error) {
    var message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.replaceFirst('Exception: ', '');
    }
    return message;
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            color.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.24
                  : 0.12,
            ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
