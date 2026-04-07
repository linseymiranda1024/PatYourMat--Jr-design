import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../providers/provider_reservations.dart';
import '../db_helpers/db_gym_class.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import '../util/date_time/util_attendance.dart';
import 'mat_selection_screen.dart';
import 'reservation_confirmation_screen.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/class_detail';
  final String classId;
  final GymClass? initialGymClass;

  const ClassDetailScreen({
    super.key,
    required this.classId,
    this.initialGymClass,
  });

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _isLoading = false;

  Future<void> _registerForClass(GymClass gClass) async {
    setState(() => _isLoading = true);

    try {
      final matNumber = await ref
          .read(reservationsProvider)
          .registerForClass(gClass);

      if (matNumber != null) {
        if (mounted) {
          final reservation = Reservation(
            id: gClass.id,
            className: gClass.title,
            instructor: gClass.instructor,
            dateTime: '${gClass.dateText} at ${gClass.timeText}',
            matNumber: matNumber,
            status: 'CONFIRMED',
            date: gClass.dateTime,
            durationMinutes: gClass.durationMinutes,
          );
          context.pushNamed(
            ReservationConfirmationScreen.routeName,
            extra: {'gymClass': gClass, 'reservation': reservation},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GymClass?>(
      stream: DBGymClass.getClassStream(widget.classId),
      initialData: widget.initialGymClass,
      builder: (context, snapshot) {
        final gClass = snapshot.data;
        if (gClass == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('This class is no longer available.'),
            ),
          );
        }
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final reservations = ref.watch(reservationsProvider).reservations;
        Reservation? currentReservation;
        for (final reservation in reservations) {
          if (reservation.id == gClass.id) {
            currentReservation = reservation;
            break;
          }
        }

        final isRegistered = currentReservation != null;
        final statusPresentation = _statusPresentationForReservation(
          currentReservation,
          gClass,
          context,
        );

        return StreamBuilder<int>(
          stream: DBReservations.getReservationCountForClassStream(gClass.id),
          builder: (context, countSnapshot) {
            final liveFilled = countSnapshot.data ?? gClass.filled;
            final isFull = liveFilled >= gClass.capacity;
            final spotsLeft = (gClass.capacity - liveFilled).clamp(
              0,
              gClass.capacity,
            );
            final progress = gClass.capacity == 0
                ? 0.0
                : (liveFilled / gClass.capacity).clamp(0.0, 1.0);

            return Scaffold(
              body: Stack(
                children: [
                  // Purple gradient header background
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.gradientStart,
                          AppColors.gradientEnd,
                        ],
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        // Back button + title
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.headerOnBrand,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  gClass.title,
                                  style: const TextStyle(
                                    color: AppColors.headerOnBrand,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // White content area
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Class Status ────────────────────────────────────────
                                  Text(
                                    'Class Status',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        statusPresentation.headline ??
                                            '$spotsLeft Spots Left',
                                        style: textTheme.titleLarge?.copyWith(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isRegistered
                                              ? statusPresentation
                                                    .backgroundColor
                                              : (gClass.status ==
                                                        ClassStatus.open
                                                    ? AppColors.success
                                                          .withValues(
                                                            alpha: isDark
                                                                ? 0.24
                                                                : 0.14,
                                                          )
                                                    : AppColors.error
                                                          .withValues(
                                                            alpha: isDark
                                                                ? 0.24
                                                                : 0.14,
                                                          )),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          isRegistered
                                              ? statusPresentation.label
                                              : gClass.status.name
                                                    .toUpperCase(),
                                          style: textTheme.labelMedium
                                              ?.copyWith(
                                                color: isRegistered
                                                    ? statusPresentation.color
                                                    : (gClass.status ==
                                                              ClassStatus.open
                                                          ? AppColors.success
                                                          : AppColors.error),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 12,
                                      backgroundColor:
                                          colorScheme.outlineVariant,
                                      valueColor: AlwaysStoppedAnimation(
                                        gClass.status == ClassStatus.full
                                            ? colorScheme.error
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 8),
                                  Text(
                                    '$liveFilled / ${gClass.capacity} registered',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),

                                  const SizedBox(height: 32),

                                  // ── Class Information ───────────────────────────────────
                                  Text(
                                    'Class Information',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildInfoRow(
                                    Icons.category_outlined,
                                    'Type',
                                    gClass.type,
                                  ),
                                  _buildInfoRow(
                                    Icons.person_outline,
                                    'Instructor',
                                    gClass.instructor,
                                  ),
                                  _buildInfoRow(
                                    Icons.calendar_today_outlined,
                                    'Date & Time',
                                    '${gClass.dateText} at ${gClass.timeText}',
                                  ),
                                  _buildInfoRow(
                                    Icons.timer_outlined,
                                    'Duration',
                                    gClass.durationText,
                                  ),
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    'Location',
                                    gClass.location,
                                  ),
                                  _buildInfoRow(
                                    Icons.group_outlined,
                                    'Capacity',
                                    '${gClass.capacity} mats',
                                  ),

                                  const SizedBox(height: 32),

                                  // ── About This Class ────────────────────────────────────
                                  Text(
                                    'About This Class',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Text(
                                    gClass.description.trim().isEmpty
                                        ? 'No description provided yet.'
                                        : gClass.description,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      height: 1.45,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),

                                  const SizedBox(height: 48),

                                  // ── Reserve Button ──────────────────────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed:
                                          (_isLoading || isRegistered || isFull)
                                          ? null
                                          : () => _registerForClass(gClass),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: _isLoading
                                          ? CircularProgressIndicator(
                                              color: colorScheme.onPrimary,
                                            )
                                          : Text(
                                              isRegistered
                                                  ? 'Registered'
                                                  : 'Reserve Your Spot',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          (_isLoading || isRegistered || isFull)
                                          ? null
                                          : () {
                                              if (gClass.filled >=
                                                  gClass.capacity) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Class just filled up',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              context.push(
                                                MatSelectionScreen.routeName,
                                                extra: gClass.id,
                                              );
                                            },
                                      icon: const Icon(Icons.grid_view_rounded),
                                      label: const Text('Choose Your Mat'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: colorScheme.primary,
                                        side: BorderSide(
                                          color: colorScheme.primary,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationStatusPresentation {
  final String? headline;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _ReservationStatusPresentation({
    required this.headline,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });
}

_ReservationStatusPresentation _statusPresentationForReservation(
  Reservation? reservation,
  GymClass gymClass,
  BuildContext context,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (reservation == null) {
    return _ReservationStatusPresentation(
      headline: null,
      label: gClassStatusLabel(gymClass),
      color: colorScheme.onSurface,
      backgroundColor: colorScheme.primaryContainer,
    );
  }

  final status = effectiveReservationStatus(
    rawStatus: reservation.status,
    classStart: gymClass.dateTime,
    durationMinutes: gymClass.durationMinutes,
  );
  if (status == ReservationStatus.attended) {
    return _ReservationStatusPresentation(
      headline: 'You checked in',
      label: 'ATTENDED',
      color: AppColors.success,
      backgroundColor: AppColors.success.withValues(
        alpha: isDark ? 0.24 : 0.14,
      ),
    );
  }

  if (status == ReservationStatus.noShow) {
    return _ReservationStatusPresentation(
      headline: 'No show recorded',
      label: 'NO-SHOW',
      color: AppColors.error,
      backgroundColor: colorScheme.outlineVariant,
    );
  }

  return _ReservationStatusPresentation(
    headline: 'You are registered',
    label: 'CONFIRMED',
    color: colorScheme.onPrimaryContainer,
    backgroundColor: colorScheme.primaryContainer,
  );
}

String gClassStatusLabel(GymClass gymClass) {
  return gymClass.status.name.toUpperCase();
}
