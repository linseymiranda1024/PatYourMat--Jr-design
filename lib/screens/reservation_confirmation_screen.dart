import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/gym_class.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../widgets/navigation/widget_app_outline.dart';

class ReservationConfirmationScreen extends ConsumerWidget {
  static const String routeName = '/reservation_confirmed';

  final GymClass gymClass;
  final Reservation reservation;

  const ReservationConfirmationScreen({
    super.key,
    required this.gymClass,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final liveReservation = _findReservation(
      ref.watch(reservationsProvider).reservations,
      reservation.id,
    );
    final currentReservation = liveReservation ?? reservation;
    final assignmentLabel = switch (gymClass.bookingMode) {
      BookingMode.open =>
        normalizeGymClassType(gymClass.type) == 'Dance'
            ? 'Your Floor Spot'
            : 'Your Field Spot',
      BookingMode.zone => 'Your Zone Spot',
      BookingMode.spot => 'Your Spot',
    };
    final confirmationSubtitle = switch (gymClass.bookingMode) {
      BookingMode.open =>
        normalizeGymClassType(gymClass.type) == 'Dance'
            ? 'Your place on the studio floor is confirmed'
            : 'Your place on the field is confirmed',
      BookingMode.zone => 'Your zone booking has been confirmed',
      BookingMode.spot => 'Your spot has been reserved',
    };
    final arrivalReminder = switch (gymClass.bookingMode) {
      BookingMode.open =>
        '• Check the roster and join the floor when you arrive',
      BookingMode.zone => '• Head to the zone shown above when you arrive',
      BookingMode.spot => '• Head to the spot shown above when you arrive',
    };

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
            child: Column(
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
                  confirmationSubtitle,
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
                    value: currentReservation.className,
                  ),
                  _DetailRow(
                    icon: Icons.access_time,
                    label: 'Date & Time',
                    value: currentReservation.dateTime,
                  ),
                  _DetailRow(
                    icon: Icons.place,
                    label: assignmentLabel,
                    value: currentReservation.matNumber,
                  ),
                  if (currentReservation.bookingRole.trim().isNotEmpty)
                    _DetailRow(
                      icon: Icons.tune_rounded,
                      label: 'Role',
                      value: currentReservation.bookingRole,
                    ),
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: gymClass.type,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Important Reminders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• Arrive at least 5 minutes early'),
                          const SizedBox(height: 8),
                          Text(arrivalReminder),
                          const SizedBox(height: 8),
                          const Text(
                            '• Cancel at least 2 hours in advance to avoid penalty',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.home_outlined,
                        color: colorScheme.primary,
                      ),
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

    for (final current in reservations) {
      if (current.id == reservationId) {
        return current;
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
