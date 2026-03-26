import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../models/gym_class.dart';
import '../providers/provider_reservations.dart';
import '../db_helpers/db_gym_class.dart';
import '../models/reservation.dart';
import '../theme/app_colors.dart';
import 'mat_selection_screen.dart';
import 'reservation_confirmation_screen.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/class_detail';
  final GymClass gymClass;

  const ClassDetailScreen({super.key, required this.gymClass});

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
        ref.read(providerGymClass).applyLocalRegistrationDelta(gClass.id, 1);
        if (mounted) {
          final reservation = Reservation(
            id: gClass.id,
            className: gClass.title,
            instructor: gClass.instructor,
            dateTime: '${gClass.dateText} at ${gClass.timeText}',
            matNumber: matNumber,
            status: 'CONFIRMED',
            date: gClass.dateTime,
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
      stream: DBGymClass.getClassStream(widget.gymClass.id),
      initialData: widget.gymClass,
      builder: (context, snapshot) {
        final gClass = snapshot.data ?? widget.gymClass;
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final reservations = ref.watch(reservationsProvider).reservations;
        final isRegistered = reservations.any((r) => r.id == gClass.id);

        final spotsLeft = gClass.capacity - gClass.filled;
        final progress = gClass.capacity == 0
            ? 0.0
            : (gClass.filled / gClass.capacity).clamp(0.0, 1.0);

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
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
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
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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
                                    isRegistered
                                        ? 'You are registered'
                                        : '$spotsLeft Spots Left',
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
                                          ? colorScheme.primaryContainer
                                          : (gClass.status == ClassStatus.open
                                                ? AppColors.success.withValues(
                                                    alpha: isDark ? 0.24 : 0.14,
                                                  )
                                                : AppColors.error.withValues(
                                                    alpha: isDark ? 0.24 : 0.14,
                                                  )),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isRegistered
                                          ? 'REGISTERED'
                                          : gClass.status.name.toUpperCase(),
                                      style: textTheme.labelMedium?.copyWith(
                                        color: isRegistered
                                            ? colorScheme.onPrimaryContainer
                                            : (gClass.status == ClassStatus.open
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
                                  backgroundColor: colorScheme.outlineVariant,
                                  valueColor: AlwaysStoppedAnimation(
                                    gClass.status == ClassStatus.full
                                        ? colorScheme.error
                                        : AppColors.success,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                              Text(
                                '${gClass.filled} / ${gClass.capacity} registered',
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
                                      (_isLoading ||
                                          isRegistered ||
                                          gClass.status != ClassStatus.open)
                                      ? null
                                      : () => _registerForClass(gClass),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
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
                                      (_isLoading ||
                                          isRegistered ||
                                          gClass.status != ClassStatus.open)
                                      ? null
                                      : () {
                                          context.push(
                                            MatSelectionScreen.routeName,
                                            extra: gClass,
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
                                      borderRadius: BorderRadius.circular(28),
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
