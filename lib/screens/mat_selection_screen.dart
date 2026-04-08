import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db_helpers/db_gym_class.dart';
import '../db_helpers/db_reservations.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';
import 'reservation_confirmation_screen.dart';

class MatSelectionScreen extends ConsumerStatefulWidget {
  static const String routeName = '/mat_selection';
  final String classId;
  final GymClass? initialGymClass;

  const MatSelectionScreen({
    super.key,
    required this.classId,
    this.initialGymClass,
  });

  @override
  ConsumerState<MatSelectionScreen> createState() => _MatSelectionScreenState();
}

class _MatSelectionScreenState extends ConsumerState<MatSelectionScreen> {
  int? _selectedMat;
  bool _isSubmitting = false;

  List<List<int>> _buildMatRows(int capacity) {
    final safeCapacity = capacity <= 0 ? 1 : capacity;
    final mats = List<int>.generate(safeCapacity, (index) => index + 1);
    final rowSize = safeCapacity <= 8
        ? 4
        : safeCapacity <= 15
        ? 5
        : 6;

    final rows = <List<int>>[];
    for (var i = 0; i < mats.length; i += rowSize) {
      rows.add(
        mats.sublist(
          i,
          (i + rowSize) > mats.length ? mats.length : i + rowSize,
        ),
      );
    }
    return rows;
  }

  Future<void> _joinStandbyQueue(GymClass gClass) async {
    setState(() => _isSubmitting = true);

    try {
      await DBReservations.joinStandbyQueue(
        ref.read(reservationsProvider).userId ?? '',
        gClass,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined standby queue successfully!')),
        );
        // Maybe pop back to class detail
        Navigator.pop(context);
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GymClass?>(
      stream: DBGymClass.getClassStream(widget.classId),
      initialData: widget.initialGymClass,
      builder: (context, classSnapshot) {
        final gClass = classSnapshot.data;
        if (gClass == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Choose Your Spot')),
            body: const Center(
              child: Text('This class is no longer available.'),
            ),
          );
        }

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final matRows = _buildMatRows(gClass.capacity);
        final selectedLabel = _selectedMat == null
            ? 'No mat selected'
            : 'Mat ${_selectedMat! + 1} selected';
        final isFull = gClass.filled >= gClass.capacity;

        return StreamBuilder<bool>(
          stream: DBReservations.isUserInStandby(
            ref.read(reservationsProvider).userId ?? '',
            gClass.id,
          ),
          builder: (context, standbySnapshot) {
            final isInStandby = standbySnapshot.data ?? false;

            return Scaffold(
          appBar: AppBar(title: const Text('Choose Your Spot')),
          body: Container(
            color: colorScheme.surface,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [
                                AppColors.gradientStartDark,
                                AppColors.gradientEndDark,
                              ]
                            : const [
                                AppColors.gradientStart,
                                AppColors.gradientEnd,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gClass.title,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.headerOnBrand,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<Set<int>>(
                          stream: DBReservations.getReservedMatNumbersStream(
                            gClass.id,
                          ),
                          initialData: const <int>{},
                          builder: (context, snapshot) {
                            final reservedCount =
                                (snapshot.data ?? const <int>{}).length;
                            return Text(
                              'Choose the mat spot you want before confirming. $reservedCount/${gClass.capacity} are already taken.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.headerOnBrand.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.4,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            const _LegendPill(
                              label: 'Available',
                              color: AppColors.success,
                            ),
                            _LegendPill(
                              label: 'Selected',
                              color: colorScheme.primary,
                            ),
                            _LegendPill(
                              label: 'Reserved',
                              color: colorScheme.outline,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.self_improvement,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'INSTRUCTOR FRONT',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  StreamBuilder<Set<int>>(
                    stream: DBReservations.getReservedMatNumbersStream(
                      gClass.id,
                    ),
                    initialData: const <int>{},
                    builder: (context, snapshot) {
                      final reservedMats = snapshot.data ?? <int>{};
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: matRows
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: entry.key.isEven ? 16 : 28,
                                      vertical: 10,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final rowCount = entry.value.length;
                                        const horizontalPaddingPerMat = 8.0;
                                        final availableWidth =
                                            constraints.maxWidth -
                                            (rowCount *
                                                horizontalPaddingPerMat);
                                        final maxTileWidth =
                                            availableWidth / rowCount;
                                        final tileWidth = maxTileWidth.clamp(
                                          32.0,
                                          54.0,
                                        );

                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: entry.value.map((
                                            matNumber,
                                          ) {
                                            final index = matNumber - 1;
                                            final isReserved = reservedMats
                                                .contains(matNumber);
                                            final isSelected =
                                                _selectedMat == index;

                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              child: SizedBox(
                                                width: tileWidth,
                                                child: AspectRatio(
                                                  aspectRatio: 0.52,
                                                  child: _YogaMatTile(
                                                    number: matNumber,
                                                    reserved: isReserved,
                                                    selected: isSelected,
                                                    onTap: isReserved
                                                        ? null
                                                        : () {
                                                            setState(() {
                                                              _selectedMat =
                                                                  index;
                                                            });
                                                          },
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              selectedLabel,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isFull
                                  ? (_isSubmitting || isInStandby
                                      ? null
                                      : () => _joinStandbyQueue(gClass))
                                  : (_selectedMat == null || _isSubmitting)
                                      ? null
                                      : () async {
                                      if (gClass.filled >= gClass.capacity) {
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

                                      final matNumber =
                                          'Mat #${_selectedMat! + 1}';
                                      setState(() => _isSubmitting = true);
                                      try {
                                        final reservedMat = await ref
                                            .read(reservationsProvider)
                                            .registerForClass(
                                              gClass,
                                              matNumber: matNumber,
                                            );
                                        if (!mounted || reservedMat == null) {
                                          return;
                                        }

                                        final reservation = Reservation(
                                          id: gClass.id,
                                          className: gClass.title,
                                          instructor: gClass.instructor,
                                          dateTime:
                                              '${gClass.dateText} at ${gClass.timeText}',
                                          matNumber: reservedMat,
                                          status: 'CONFIRMED',
                                          date: gClass.dateTime,
                                          durationMinutes:
                                              gClass.durationMinutes,
                                        );

                                        context.pushNamed(
                                          ReservationConfirmationScreen
                                              .routeName,
                                          extra: {
                                            'gymClass': gClass,
                                            'reservation': reservation,
                                          },
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        var message = e.toString();
                                        if (message.startsWith('Exception: ')) {
                                          message = message.replaceFirst(
                                            'Exception: ',
                                            '',
                                          );
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      isFull
                                          ? (isInStandby
                                              ? "You're on Standby"
                                              : 'Join Standby Queue')
                                          : _selectedMat == null
                                          ? 'Select a Mat'
                                          : 'Reserve Mat ${_selectedMat! + 1}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            );
          },
        );
      },
    );
  }
}

class _YogaMatTile extends StatelessWidget {
  final int number;
  final bool reserved;
  final bool selected;
  final VoidCallback? onTap;

  const _YogaMatTile({
    required this.number,
    required this.reserved,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = reserved
        ? colorScheme.outline
        : selected
        ? colorScheme.primary
        : AppColors.success;
    final border = reserved
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
        : selected
        ? colorScheme.primary.withValues(alpha: 0.88)
        : AppColors.success.withValues(alpha: 0.88);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(fill, Colors.white, 0.10)!,
                      fill,
                      Color.lerp(fill, Colors.black, 0.12)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border, width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 16,
              right: 16,
              child: Container(
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Center(
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.check_circle, color: Colors.white, size: 18),
              ),
            if (reserved)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.headerOnBrand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
