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

      final unlockedTitles = result.newlyUnlockedAchievementIds
          .map((id) => Achievement.byId(id)?.title ?? id)
          .toList();
      final message = unlockedTitles.isEmpty
          ? 'Check-in recorded.'
          : 'Check-in recorded. Unlocked: ${unlockedTitles.join(', ')}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.qr_code_2,
                            size: 140,
                            color: Colors.deepPurple,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Show this QR code at check-in',
                            style: TextStyle(
                              color: Colors.deepPurple,
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
                        backgroundColor: const Color(0xFF6200EE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        context.go('${WidgetAppOutline.routeName}?tab=4');
                      },
                      child: const Text(
                        'View My Reservations',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.home_outlined,
                        color: Color(0xFF6200EE),
                      ),
                      label: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6200EE),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
