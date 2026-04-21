import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pat_your_mat/main.dart';

import '../models/gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../providers/provider_reservations.dart';
import '../db_helpers/db_gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_user_profile.dart';
import '../theme/app_colors.dart';
import '../util/date_time/util_attendance.dart';
import '../util/classes/class_visuals.dart';
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
  int _heroPageIndex = 0;

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

  Future<void> _joinStandbyQueue(GymClass gClass) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(reservationsProvider).joinStandbyQueue(gClass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined standby queue successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join standby: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveStandbyQueue(GymClass gClass) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(reservationsProvider).leaveStandbyQueue(gClass.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Left standby queue')));
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave standby: $message')),
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
        final visual = gymClassVisualForKey(
          gClass.iconKey,
          classType: gClass.type,
        );

        final reservations = ref.watch(reservationsProvider).reservations;
        Reservation? currentReservation;
        for (final reservation in reservations) {
          if (reservation.id == gClass.id) {
            currentReservation = reservation;
            break;
          }
        }

        final isRegistered = currentReservation != null;
        final isFavorite = ref.watch(
          providerUserProfile.select(
            (ProviderUserProfile profile) =>
                profile.favoriteClassIds.contains(gClass.favoriteKey),
          ),
        );
        final statusPresentation = _statusPresentationForReservation(
          currentReservation,
          gClass,
          context,
        );

        return StreamBuilder<int>(
          stream: DBReservations.getReservationCountForClassStream(gClass.id),
          builder: (context, countSnapshot) {
            final liveFilled = countSnapshot.data ?? gClass.filled;
            final liveStatus = _classAvailabilityStatus(
              filled: liveFilled,
              capacity: gClass.capacity,
              standbyCount: gClass.standbyCount,
            );
            final isFull = liveStatus != ClassStatus.open;
            final spotsLeft = (gClass.capacity - liveFilled).clamp(
              0,
              gClass.capacity,
            );
            final progress = gClass.capacity == 0
                ? 0.0
                : (liveFilled / gClass.capacity).clamp(0.0, 1.0);

            return StreamBuilder<int?>(
              stream: ref
                  .read(reservationsProvider)
                  .standbyQueuePositionStream(gClass.id),
              builder: (context, queueSnapshot) {
                final queuePosition = queueSnapshot.data;
                final isQueued = queuePosition != null;
                final statusHeadline = isRegistered
                    ? (statusPresentation.headline ?? 'You are registered')
                    : isQueued
                    ? 'Standby Position #$queuePosition'
                    : '$spotsLeft Spots Left';
                final statusLabel = isRegistered
                    ? statusPresentation.label
                    : isQueued
                    ? 'STANDBY'
                    : _classStatusLabel(liveStatus);
                final queueStatusAccent = _availabilityAccent(
                  ClassStatus.standby,
                );
                final statusColor = isRegistered
                    ? statusPresentation.color
                    : isQueued
                    ? queueStatusAccent
                    : _availabilityAccent(liveStatus);
                final statusBackgroundColor = isRegistered
                    ? statusPresentation.backgroundColor
                    : isQueued
                    ? queueStatusAccent.withValues(alpha: isDark ? 0.24 : 0.14)
                    : statusColor.withValues(alpha: isDark ? 0.24 : 0.14);

                return Scaffold(
                  body: Stack(
                    children: [
                      _ClassHeroHeader(
                        gymClass: gClass,
                        visual: visual,
                        currentPage: _heroPageIndex,
                        onPageChanged: (page) {
                          if (_heroPageIndex == page) {
                            return;
                          }
                          setState(() {
                            _heroPageIndex = page;
                          });
                        },
                      ),
                      Container(
                        height: 300,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Column(
                          children: [
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
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: visual.colors,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      visual.icon,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFavorite
                                          ? Colors.redAccent
                                          : AppColors.headerOnBrand,
                                      size: 28,
                                    ),
                                    onPressed: () => ref
                                        .read(providerUserProfile)
                                        .toggleFavoriteClass(
                                          gClass.favoriteKey,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(32),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    28,
                                    20,
                                    40,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                          Expanded(
                                            child: Text(
                                              statusHeadline,
                                              style: textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        colorScheme.onSurface,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusBackgroundColor,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: statusColor,
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
                                            _availabilityAccent(liveStatus),
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
                                      if (gClass.standbyCount > 0) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '${gClass.standbyCount} in standby queue',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                      if (isQueued) ...[
                                        const SizedBox(height: 20),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: colorScheme
                                                .surfaceContainerHigh,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: colorScheme.outlineVariant,
                                            ),
                                          ),
                                          child: Text(
                                            'You are in the standby queue at position #$queuePosition. When a spot opens, the next person in line is promoted automatically.',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme.onSurface,
                                                  height: 1.4,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () => _leaveStandbyQueue(
                                                    gClass,
                                                  ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  colorScheme.error,
                                            ),
                                            child: const Text(
                                              'Leave Standby Queue',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 32),
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
                                      if (gClass.isRecurring)
                                        _buildInfoRow(
                                          Icons.repeat_rounded,
                                          'Repeats',
                                          gClass.recurrenceSummary,
                                        ),
                                      const SizedBox(height: 32),
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
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed:
                                              (_isLoading ||
                                                  isRegistered ||
                                                  isQueued ||
                                                  isFull)
                                              ? null
                                              : () {
                                                  if (gClass.bookingMode ==
                                                      BookingMode.spot) {
                                                    _registerForClass(gClass);
                                                    return;
                                                  }
                                                  if (liveFilled >=
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
                                                    MatSelectionScreen
                                                        .routeName,
                                                    extra: gClass.id,
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                colorScheme.primary,
                                            foregroundColor:
                                                colorScheme.onPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(28),
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
                                                      : isQueued
                                                      ? 'In Standby Queue'
                                                      : switch (gClass
                                                            .bookingMode) {
                                                          BookingMode.open =>
                                                            normalizeGymClassType(
                                                                      gClass
                                                                          .type,
                                                                    ) ==
                                                                    'Dance'
                                                                ? 'Join The Floor'
                                                                : 'Join The Field',
                                                          BookingMode.zone =>
                                                            'Choose Your Zone',
                                                          BookingMode.spot =>
                                                            'Reserve Your Spot',
                                                        },
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      if (isFull && !isRegistered) ...[
                                        SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: OutlinedButton.icon(
                                            onPressed: _isLoading
                                                ? null
                                                : isQueued
                                                ? () =>
                                                      _leaveStandbyQueue(gClass)
                                                : () =>
                                                      _joinStandbyQueue(gClass),
                                            icon: Icon(
                                              isQueued
                                                  ? Icons.exit_to_app_rounded
                                                  : Icons.playlist_add_rounded,
                                            ),
                                            label: Text(
                                              isQueued
                                                  ? 'Leave Standby Queue'
                                                  : 'Join Standby Queue',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  colorScheme.primary,
                                              side: BorderSide(
                                                color: colorScheme.primary,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      if (gClass.bookingMode ==
                                          BookingMode.spot)
                                        SizedBox(
                                          width: double.infinity,
                                          height: 54,
                                          child: OutlinedButton.icon(
                                            onPressed:
                                                (_isLoading ||
                                                    isRegistered ||
                                                    isFull ||
                                                    isQueued)
                                                ? null
                                                : () {
                                                    if (liveFilled >=
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
                                                      MatSelectionScreen
                                                          .routeName,
                                                      extra: gClass.id,
                                                    );
                                                  },
                                            icon: const Icon(
                                              Icons.grid_view_rounded,
                                            ),
                                            label: const Text(
                                              'Choose Your Spot',
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  colorScheme.primary,
                                              side: BorderSide(
                                                color: colorScheme.primary,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
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

class _ClassHeroHeader extends StatelessWidget {
  final GymClass gymClass;
  final GymClassVisualOption visual;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _ClassHeroHeader({
    required this.gymClass,
    required this.visual,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrls = gymClass.imageUrls;
    final safePage = imageUrls.isEmpty
        ? 0
        : currentPage.clamp(0, imageUrls.length - 1);

    if (imageUrls.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: visual.colors,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                visual.icon,
                color: Colors.white.withValues(alpha: 0.9),
                size: 80,
              ),
              const SizedBox(height: 12),
              Text(
                gymClass.type,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: imageUrls.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: visual.colors),
                        ),
                        child: Icon(visual.icon, color: Colors.white, size: 72),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.14),
                          Colors.black.withValues(alpha: 0.32),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                imageUrls.length == 1
                    ? 'Class preview'
                    : 'Photo ${safePage + 1} of ${imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (imageUrls.length > 1)
            Positioned(
              right: 20,
              bottom: 22,
              child: Row(
                children: List<Widget>.generate(imageUrls.length, (index) {
                  final isActive = index == safePage;
                  return Container(
                    width: isActive ? 18 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
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
  return _classStatusLabel(gymClass.status);
}

ClassStatus _classAvailabilityStatus({
  required int filled,
  required int capacity,
  required int standbyCount,
}) {
  return filled < capacity && standbyCount == 0
      ? ClassStatus.open
      : ClassStatus.full;
}

String _classStatusLabel(ClassStatus status) {
  switch (status) {
    case ClassStatus.open:
      return 'OPEN';
    case ClassStatus.full:
      return 'FULL';
    case ClassStatus.standby:
      return 'STANDBY';
  }
}

Color _availabilityAccent(ClassStatus status) {
  switch (status) {
    case ClassStatus.open:
      return AppColors.success;
    case ClassStatus.full:
      return AppColors.error;
    case ClassStatus.standby:
      return AppColors.warning;
  }
}
