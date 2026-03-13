import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/reservation.dart';
import '../providers/provider_reservations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(reservationsProvider).reservations;
    final notifications = _buildNotifications(reservations);

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF7ED), Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF97316), Color(0xFFFB7185)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notifications.isEmpty
                          ? 'You are all caught up.'
                          : '${notifications.length} active update${notifications.length == 1 ? '' : 's'} for your schedule.',
                      style: const TextStyle(
                        color: Color(0xF2FFFFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: _NotificationEmptyState(),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return _NotificationCard(notification: notification);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final _NotificationItem notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: notification.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(notification.icon, color: notification.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      notification.timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Color(0xFF475569),
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

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFE7D6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.notifications_off_outlined,
            size: 40,
            color: Color(0xFF9A3412),
          ),
          SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Reserve a class and upcoming reminders will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String message;
  final String timeLabel;
  final IconData icon;
  final Color color;

  const _NotificationItem({
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.icon,
    required this.color,
  });
}

List<_NotificationItem> _buildNotifications(List<Reservation> reservations) {
  final now = DateTime.now();
  final items = <_NotificationItem>[];
  final sorted = [...reservations]..sort((a, b) => a.date.compareTo(b.date));

  for (final reservation in sorted) {
    final difference = reservation.date.difference(now);
    if (difference.inMinutes >= 0 && difference.inHours < 3) {
      items.add(
        _NotificationItem(
          title: 'Class starts soon',
          message:
              '${reservation.className} with ${reservation.instructor} starts at ${DateFormat.jm().format(reservation.date)}. Your spot is ${reservation.matNumber}.',
          timeLabel: 'Soon',
          icon: Icons.alarm,
          color: const Color(0xFFDC2626),
        ),
      );
      continue;
    }

    if (_isTomorrow(reservation.date, now)) {
      items.add(
        _NotificationItem(
          title: 'Tomorrow\'s reservation',
          message:
              'You are booked for ${reservation.className} tomorrow at ${DateFormat.jm().format(reservation.date)}.',
          timeLabel: 'Tomorrow',
          icon: Icons.event_available,
          color: const Color(0xFF2563EB),
        ),
      );
      continue;
    }

    if (difference.inDays >= 0) {
      items.add(
        _NotificationItem(
          title: 'Reservation confirmed',
          message:
              '${reservation.className} is confirmed for ${DateFormat.MMMd().add_jm().format(reservation.date)}.',
          timeLabel: DateFormat.MMMd().format(reservation.date),
          icon: Icons.check_circle,
          color: const Color(0xFF16A34A),
        ),
      );
      continue;
    }

    if (difference.inDays > -2) {
      items.add(
        _NotificationItem(
          title: 'Class completed',
          message:
              'You attended ${reservation.className}. Rebook a new session when you are ready.',
          timeLabel: 'Recent',
          icon: Icons.history,
          color: const Color(0xFF7C3AED),
        ),
      );
    }
  }

  return items.reversed.toList();
}

bool _isTomorrow(DateTime date, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return DateTime(date.year, date.month, date.day) == tomorrow;
}
