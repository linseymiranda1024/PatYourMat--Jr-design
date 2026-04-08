import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db_helpers/db_reservations.dart';
import '../main.dart';
import '../models/reservation.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _busyNotificationIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(reservationsProvider).reservations;
    final currentUid = ref.watch(providerUserProfile.select((profile) => profile.uid));
    final wholeName = ref.watch(
      providerUserProfile.select((profile) => profile.wholeName),
    );
    final currentName = wholeName.trim().isEmpty ? 'Someone' : wholeName.trim();
    final scheduleNotifications = _buildScheduleNotifications(reservations);
    final colorScheme = Theme.of(context).colorScheme;
    final heroGradient = Theme.of(context).brightness == Brightness.dark
        ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
        : const [Color(0xFFF97316), Color(0xFFFB7185)];

    if (currentUid.isEmpty) {
      return const SafeArea(
        child: Center(child: Text('Log in to view notifications.')),
      );
    }

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(currentUid)
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final firestoreNotifications = snapshot.data?.docs
                  .map(_NotificationItem.fromFirestoreDoc)
                  .toList() ??
              const <_NotificationItem>[];
          final notifications = [
            ...firestoreNotifications,
            ...scheduleNotifications,
          ]..sort((a, b) => b.sortDate.compareTo(a.sortDate));

          return Container(
            color: colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: heroGradient,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            color: AppColors.headerOnBrand,
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
                            color: AppColors.headerOnBrandMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: snapshot.hasError
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('Unable to load notifications right now.'),
                          ),
                        )
                      : notifications.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: _NotificationEmptyState(),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                return _NotificationCard(
                                  notification: notification,
                                  isBusy: _busyNotificationIds.contains(
                                    notification.id,
                                  ),
                                  onAccept: notification.canAccept
                                      ? () => _handleInviteResponse(
                                            notification,
                                            accept: true,
                                            currentUid: currentUid,
                                            currentName: currentName,
                                          )
                                      : null,
                                  onDecline: notification.canDecline
                                      ? () => _handleInviteResponse(
                                            notification,
                                            accept: false,
                                            currentUid: currentUid,
                                            currentName: currentName,
                                          )
                                      : null,
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleInviteResponse(
    _NotificationItem notification, {
    required bool accept,
    required String currentUid,
    required String currentName,
  }) async {
    final notificationId = notification.id;
    if (notificationId == null || _busyNotificationIds.contains(notificationId)) {
      return;
    }

    setState(() => _busyNotificationIds.add(notificationId));
    try {
      if (accept) {
        final matNumber = await DBReservations.acceptGroupInvite(
          userId: currentUid,
          notificationId: notificationId,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              matNumber == null
                  ? 'Invite accepted.'
                  : 'Invite accepted. You are booked on $matNumber.',
            ),
          ),
        );
      } else {
        await DBReservations.declineGroupInvite(
          userId: currentUid,
          notificationId: notificationId,
        );
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite declined.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      var message = error.toString();
      if (message.startsWith('Exception: ')) {
        message = message.replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _busyNotificationIds.remove(notificationId));
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final _NotificationItem notification;
  final bool isBusy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _NotificationCard({
    required this.notification,
    this.isBusy = false,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          notification.timeLabel,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (notification.subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        notification.subtitle!,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (notification.inviteStatusBadge != null) ...[
            const SizedBox(height: 14),
            _StatusChip(
              label: notification.inviteStatusBadge!,
              color: notification.color,
            ),
          ],
          if (notification.canAccept || notification.canDecline) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy ? null : onAccept,
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Class reminders and friend invites will show up here.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final String? id;
  final String type;
  final String title;
  final String message;
  final String timeLabel;
  final IconData icon;
  final Color color;
  final DateTime sortDate;
  final String? subtitle;
  final bool canAccept;
  final bool canDecline;
  final String? inviteStatusBadge;

  const _NotificationItem({
    this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.icon,
    required this.color,
    required this.sortDate,
    this.subtitle,
    this.canAccept = false,
    this.canDecline = false,
    this.inviteStatusBadge,
  });

  factory _NotificationItem.fromFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final createdAt = _timestampToDateTime(data['created_at']) ?? DateTime.now();
    final classTime = _timestampToDateTime(data['class_time']);
    final inviteStatus = (data['invite_status'] ?? '').toString();
    final hostMatNumber = (data['host_mat_number'] ?? '').toString().trim();
    final reservedMatNumber =
        (data['reserved_mat_number'] ?? '').toString().trim();
    final baseTitle = (data['title'] ?? 'Notification').toString();
    final baseMessage = (data['message'] ?? '').toString();
    final fromName = (data['from_name'] ?? 'Someone').toString();
    if (type == 'group_invite') {
      final isPending = inviteStatus == 'pending';
      final details = [
        if (classTime != null) DateFormat.MMMd().add_jm().format(classTime),
        if (reservedMatNumber.isNotEmpty) 'Your mat: $reservedMatNumber',
        if (hostMatNumber.isNotEmpty) 'Host mat: $hostMatNumber',
      ];
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.group_add,
        color: const Color(0xFF2563EB),
        sortDate: createdAt,
        subtitle: details.isEmpty ? null : details.join('  •  '),
        canAccept: isPending,
        canDecline: isPending,
        inviteStatusBadge: isPending
            ? null
            : inviteStatus == 'accepted'
                ? 'Accepted'
                : 'Declined',
      );
    }

    if (type == 'group_invite_response') {
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.reply_all_rounded,
        color: const Color(0xFF16A34A),
        sortDate: createdAt,
      );
    }

    if (type == 'friend') {
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage.isEmpty ? '$fromName followed you.' : baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.person_add_alt_1,
        color: const Color(0xFF7C3AED),
        sortDate: createdAt,
      );
    }

    if (type == 'standby_promoted') {
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.event_available,
        color: const Color(0xFF16A34A),
        sortDate: createdAt,
      );
    }

    return _NotificationItem(
      id: doc.id,
      type: type,
      title: baseTitle,
      message: baseMessage,
      timeLabel: _relativeLabel(createdAt),
      icon: Icons.notifications,
      color: const Color(0xFF2563EB),
      sortDate: createdAt,
    );
  }
}

List<_NotificationItem> _buildScheduleNotifications(List<Reservation> reservations) {
  final now = DateTime.now();
  final items = <_NotificationItem>[];
  final sorted = [...reservations]..sort((a, b) => a.date.compareTo(b.date));

  for (final reservation in sorted) {
    final difference = reservation.date.difference(now);
    if (difference.inMinutes >= 0 && difference.inHours < 3) {
      items.add(
        _NotificationItem(
          type: 'schedule',
          title: 'Class starts soon',
          message:
              '${reservation.className} with ${reservation.instructor} starts at ${DateFormat.jm().format(reservation.date)}. Your spot is ${reservation.matNumber}.',
          timeLabel: 'Soon',
          icon: Icons.alarm,
          color: const Color(0xFFDC2626),
          sortDate: reservation.date,
        ),
      );
      continue;
    }

    if (_isTomorrow(reservation.date, now)) {
      items.add(
        _NotificationItem(
          type: 'schedule',
          title: 'Tomorrow\'s reservation',
          message:
              'You are booked for ${reservation.className} tomorrow at ${DateFormat.jm().format(reservation.date)}.',
          timeLabel: 'Tomorrow',
          icon: Icons.event_available,
          color: const Color(0xFF2563EB),
          sortDate: reservation.date,
        ),
      );
      continue;
    }

    if (difference.inDays >= 0) {
      items.add(
        _NotificationItem(
          type: 'schedule',
          title: 'Reservation confirmed',
          message:
              '${reservation.className} is confirmed for ${DateFormat.MMMd().add_jm().format(reservation.date)}.',
          timeLabel: DateFormat.MMMd().format(reservation.date),
          icon: Icons.check_circle,
          color: const Color(0xFF16A34A),
          sortDate: reservation.date,
        ),
      );
      continue;
    }

    if (difference.inDays > -2) {
      items.add(
        _NotificationItem(
          type: 'schedule',
          title: 'Class completed',
          message:
              'You attended ${reservation.className}. Rebook a new session when you are ready.',
          timeLabel: 'Recent',
          icon: Icons.history,
          color: const Color(0xFF7C3AED),
          sortDate: reservation.date,
        ),
      );
    }
  }

  return items;
}

bool _isTomorrow(DateTime date, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return DateTime(date.year, date.month, date.day) == tomorrow;
}

DateTime? _timestampToDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  return null;
}

String _relativeLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Now';
  }
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inMinutes < 1) {
    return 'Now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  return DateFormat.MMMd().format(dateTime);
}
