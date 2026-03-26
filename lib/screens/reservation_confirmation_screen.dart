import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db_helpers/db_reservations.dart';
import '../main.dart';
import '../models/achievement.dart';
import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../widgets/navigation/widget_app_outline.dart';

class ReservationConfirmationScreen extends ConsumerStatefulWidget {
  static const String routeName = '/reservation_confirmed';

  final GymClass gymClass;
  final Reservation reservation;

  const ReservationConfirmationScreen({
    super.key,
    required this.gymClass,
    required this.reservation,
  });

  @override
  ConsumerState<ReservationConfirmationScreen> createState() =>
      _ReservationConfirmationScreenState();
}

class _ReservationConfirmationScreenState
    extends ConsumerState<ReservationConfirmationScreen> {
  bool _isCheckingIn = false;

  Future<void> _checkInUser(Reservation reservation) async {
    if (_isCheckingIn) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be logged in.')));
      return;
    }

    setState(() => _isCheckingIn = true);

    try {
      final result = await DBReservations.checkInUser(
        user.uid,
        reservation,
        widget.gymClass,
      );
      ref
          .read(providerUserProfile)
          .applyAchievementProgress(
            achievements: result.achievements,
            categoryAttendance: result.categoryAttendance,
          );

      if (!mounted) return;

      final unlockedAchievements = result.newlyUnlockedAchievementIds
          .map(Achievement.byId)
          .whereType<Achievement>()
          .toList();

      if (unlockedAchievements.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Check-in recorded.')));
      } else {
        await _showAchievementUnlockAnimation(unlockedAchievements);
      }
    } catch (error) {
      if (!mounted) return;
      var message = error.toString();
      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Check-in failed: $message')));
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  Future<void> _showAchievementUnlockAnimation(
    List<Achievement> achievements,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Achievement unlocked',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AchievementUnlockDialog(achievements: achievements);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final liveReservation = _findReservation(
      ref.watch(reservationsProvider).reservations,
      widget.reservation.id,
    );
    final reservation = liveReservation ?? widget.reservation;
    final isAttended = reservation.status.toUpperCase() == 'ATTENDED';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reservation Confirmed'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, size: 80, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  "You're All Set!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your mat spot has been reserved',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reservation Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.event,
                    label: 'Class Name',
                    value: reservation.className,
                  ),
                  _DetailRow(
                    icon: Icons.access_time,
                    label: 'Date & Time',
                    value: reservation.dateTime,
                  ),
                  _DetailRow(
                    icon: Icons.place,
                    label: 'Your Mat Location',
                    value: reservation.matNumber,
                  ),
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Category',
                    value: widget.gymClass.category,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 140,
                            color: colorScheme.primary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Show this QR code at check-in',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: isAttended || _isCheckingIn
                          ? null
                          : () => _checkInUser(reservation),
                      icon: _isCheckingIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isAttended
                                  ? Icons.verified
                                  : Icons.fact_check_outlined,
                            ),
                      label: Text(
                        isAttended ? 'Checked In' : 'Check In (Dev Only)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Important Reminders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Arrive at least 5 minutes early to check in'),
                          SizedBox(height: 8),
                          Text('• Bring your student ID and water bottle'),
                          SizedBox(height: 8),
                          Text(
                            '• Cancel at least 2 hours in advance to avoid penalty',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Add to Calendar'),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share'),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        context.go('${WidgetAppOutline.routeName}?tab=4');
                      },
                      child: const Text(
                        'View My Reservations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.home_outlined, color: colorScheme.primary),
                      label: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                      onPressed: () {
                        context.go(WidgetAppOutline.routeName);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Reservation? _findReservation(
    List<Reservation> reservations,
    String? reservationId,
  ) {
    if (reservationId == null) {
      return null;
    }

    for (final reservation in reservations) {
      if (reservation.id == reservationId) {
        return reservation;
      }
    }
    return null;
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
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

class _AchievementUnlockDialog extends StatefulWidget {
  final List<Achievement> achievements;

  const _AchievementUnlockDialog({required this.achievements});

  @override
  State<_AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<_AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardFade;
  late final Animation<double> _iconPop;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _cardScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );
    _cardFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
    );
    _iconPop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.72, curve: Curves.easeOutBack),
    );

    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryAchievement = widget.achievements.first;
    final extraCount = widget.achievements.length - 1;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _cardFade,
                child: Transform.scale(
                  scale: 0.92 + (_cardScale.value * 0.08),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ..._buildParticles(primaryAchievement.color),
                      child!,
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.8 + (_iconPop.value * 0.2),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryAchievement.color.withValues(alpha: 0.14),
                        border: Border.all(
                          color: primaryAchievement.color.withValues(
                            alpha: 0.32,
                          ),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        primaryAchievement.iconData,
                        color: primaryAchievement.color,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.achievements.length == 1
                        ? 'Achievement Unlocked'
                        : 'Achievements Unlocked',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    primaryAchievement.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: primaryAchievement.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    primaryAchievement.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (extraCount > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+$extraCount more badge${extraCount == 1 ? '' : 's'} unlocked',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles(Color accent) {
    const particles =
        <({double left, double top, double dx, double dy, double size})>[
          (left: -102, top: -86, dx: -8, dy: -24, size: 16),
          (left: 104, top: -76, dx: 10, dy: -22, size: 14),
          (left: -126, top: 30, dx: -12, dy: -4, size: 12),
          (left: 124, top: 42, dx: 14, dy: -8, size: 18),
          (left: -78, top: 122, dx: -10, dy: 18, size: 14),
          (left: 84, top: 126, dx: 12, dy: 16, size: 16),
        ];

    return particles.map((particle) {
      final progress = Curves.easeOut.transform(_controller.value);
      return Positioned(
        left: particle.left + (particle.dx * progress),
        top: particle.top + (particle.dy * progress),
        child: Opacity(
          opacity: 1 - progress.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: progress * 1.2,
            child: Icon(
              Icons.auto_awesome,
              color: accent.withValues(alpha: 0.88),
              size: particle.size,
            ),
          ),
        ),
      );
    }).toList();
  }
}
