import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db_helpers/db_friends.dart';
import '../db_helpers/db_reservations.dart';
import '../models/gym_class.dart';
import '../main.dart';
import '../models/reservation.dart';
import '../models/user_profile.dart';
import '../providers/provider_reservations.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  final FirebaseFirestore? firestore;
  final List<Reservation>? reservations;
  final List<GymClass>? managedClasses;

  const NotificationsScreen({
    super.key,
    this.firestore,
    this.reservations,
    this.managedClasses,
  });

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _busyNotificationIds = <String>{};
  bool _isClearing = false;

  Future<void> _clearAllNotifications(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text(
          'This will permanently remove your notification history. Pending invites or requests will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Notifications'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      final firestore = widget.firestore ?? FirebaseFirestore.instance;
      final collection = firestore
          .collection('user_profiles')
          .doc(uid)
          .collection('notifications');

      final snapshot = await collection.get();
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear notifications: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = widget.firestore ?? FirebaseFirestore.instance;
    final userProfile = ref.watch(providerUserProfile);
    final reservations =
        widget.reservations ?? ref.watch(reservationsProvider).reservations;
    final currentUid = userProfile.uid;
    final currentName = userProfile.wholeName.trim().isEmpty
        ? 'Someone'
        : userProfile.wholeName.trim();
    final isStaff = userProfile.role == UserRole.STAFF;
    final managedClasses =
        widget.managedClasses ?? ref.watch(providerGymClass).classes;
    final scheduleNotifications = isStaff
        ? _buildStaffScheduleNotifications(
            managedClasses,
            staffName: userProfile.wholeName,
          )
        : _buildScheduleNotifications(reservations);
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
        stream: firestore
            .collection('user_profiles')
            .doc(currentUid)
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          final firestoreNotifications =
              snapshot.data?.docs
                  .map(_NotificationItem.fromFirestoreDoc)
                  .toList() ??
              const <_NotificationItem>[];
          final notifications = [
            ...firestoreNotifications,
            ...scheduleNotifications,
          ]..sort((a, b) => b.sortDate.compareTo(a.sortDate));

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore
                .collectionGroup('pending_group_invites')
                .where('inviter_uid', isEqualTo: currentUid)
                .snapshots(),
            builder: (context, pendingSnapshot) {
              final sentPendingInvites = [
                ...(pendingSnapshot.data?.docs
                        .map(_SentGroupInviteItem.fromFirestoreDoc)
                        .whereType<_SentGroupInviteItem>() ??
                    const <_SentGroupInviteItem>[]),
              ];
              sentPendingInvites.sort(
                (a, b) => a.expiresAt.compareTo(b.expiresAt),
              );

              final totalActiveCount =
                  notifications.length + sentPendingInvites.length;
              final hasContent = totalActiveCount > 0;

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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: AppColors.headerOnBrand,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (notifications.isNotEmpty)
                                  _isClearing
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.headerOnBrand,
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: () =>
                                              _clearAllNotifications(
                                                currentUid,
                                              ),
                                          icon: const Icon(
                                            Icons.clear_all_rounded,
                                            color: AppColors.headerOnBrand,
                                          ),
                                          tooltip: 'Clear All',
                                          visualDensity: VisualDensity.compact,
                                        ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              totalActiveCount == 0
                                  ? 'You are all caught up.'
                                  : isStaff
                                  ? '$totalActiveCount active update${totalActiveCount == 1 ? '' : 's'} for your classes.'
                                  : '$totalActiveCount active update${totalActiveCount == 1 ? '' : 's'} for your schedule.',
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
                                child: Text(
                                  'Unable to load notifications right now.',
                                ),
                              ),
                            )
                          : !hasContent
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _NotificationEmptyState(
                                  isStaff: isStaff,
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: [
                                if (sentPendingInvites.isNotEmpty)
                                  _PendingGroupInviteSection(
                                    invites: sentPendingInvites,
                                  ),
                                if (sentPendingInvites.isNotEmpty &&
                                    notifications.isNotEmpty)
                                  const SizedBox(height: 20),
                                if (notifications.isNotEmpty) ...[
                                  _SectionLabel(
                                    label: isStaff
                                        ? 'Class Updates'
                                        : 'Incoming Updates',
                                  ),
                                  const SizedBox(height: 12),
                                  for (
                                    var index = 0;
                                    index < notifications.length;
                                    index++
                                  ) ...[
                                    () {
                                      final notification = notifications[index];
                                      final card = _NotificationCard(
                                        notification: notification,
                                        isBusy: _busyNotificationIds.contains(
                                          notification.id,
                                        ),
                                        onAccept: notification.canAccept
                                            ? () => _handleNotificationAction(
                                                  notification,
                                                  accept: true,
                                                  currentUid: currentUid,
                                                  currentName: currentName,
                                                )
                                            : null,
                                        onDecline: notification.canDecline
                                            ? () => _handleNotificationAction(
                                                  notification,
                                                  accept: false,
                                                  currentUid: currentUid,
                                                  currentName: currentName,
                                                )
                                            : null,
                                      );

                                      if (notification.id == null) {
                                        return card;
                                      }

                                      return Dismissible(
                                        key: Key(notification.id!),
                                        direction: DismissDirection.endToStart,
                                        onDismissed: (_) {
                                          firestore
                                              .collection('user_profiles')
                                              .doc(currentUid)
                                              .collection('notifications')
                                              .doc(notification.id)
                                              .delete();
                                        },
                                        background: Container(
                                          decoration: BoxDecoration(
                                            color: colorScheme.errorContainer,
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(
                                            right: 24,
                                          ),
                                          child: Icon(
                                            Icons.delete_outline,
                                            color:
                                                colorScheme.onErrorContainer,
                                          ),
                                        ),
                                        child: card,
                                      );
                                    }(),
                                    if (index != notifications.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationAction(
    _NotificationItem notification, {
    required bool accept,
    required String currentUid,
    required String currentName,
  }) async {
    final notificationId = notification.id;
    if (notificationId == null ||
        _busyNotificationIds.contains(notificationId)) {
      return;
    }

    setState(() => _busyNotificationIds.add(notificationId));
    try {
      if (notification.type == 'group_invite') {
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invite declined.')));
        }
      } else if (notification.type == 'friend_request') {
        final fromUid = notification.fromUid;
        if (fromUid == null || fromUid.isEmpty) {
          throw Exception('This friend request is missing sender details.');
        }
        if (accept) {
          await DBFriends.acceptFriendRequest(
            currentUid: currentUid,
            targetUid: fromUid,
            currentName: currentName,
            notificationId: notificationId,
          );
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${notification.fromName ?? 'Someone'} is now your friend!',
              ),
            ),
          );
        } else {
          await DBFriends.declineFriendRequest(
            currentUid: currentUid,
            targetUid: fromUid,
            currentName: currentName,
            notificationId: notificationId,
          );
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Friend request from ${notification.fromName ?? 'Someone'} declined.',
              ),
            ),
          );
        }
      } else {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No action available for this update.')),
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
  final bool isStaff;

  const _NotificationEmptyState({this.isStaff = false});

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
            isStaff
                ? 'Class readiness updates and schedule reminders will show up here.'
                : 'Class reminders and friend invites will show up here.',
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
    );
  }
}

class _PendingGroupInviteSection extends StatelessWidget {
  final List<_SentGroupInviteItem> invites;

  const _PendingGroupInviteSection({required this.invites});

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
          const _SectionLabel(label: 'Pending Group Invites'),
          const SizedBox(height: 6),
          Text(
            'These are the invites you sent that are still waiting on a response.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < invites.length; index++) ...[
            _PendingGroupInviteCard(invite: invites[index]),
            if (index != invites.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PendingGroupInviteCard extends StatelessWidget {
  final _SentGroupInviteItem invite;

  const _PendingGroupInviteCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.friendName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invite sent for ${invite.className}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            invite.detailsLabel,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _StatusChip(
            label: 'Waiting • ${invite.expiresLabel}',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _SentGroupInviteItem {
  final String friendName;
  final String className;
  final String detailsLabel;
  final String expiresLabel;
  final DateTime expiresAt;

  const _SentGroupInviteItem({
    required this.friendName,
    required this.className,
    required this.detailsLabel,
    required this.expiresLabel,
    required this.expiresAt,
  });

  static _SentGroupInviteItem? fromFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final expiresAt = _timestampToDateTime(data['expires_at']);
    if (status != 'pending' ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now())) {
      return null;
    }

    final className = (data['class_name'] ?? 'this class').toString();
    final classTime = _timestampToDateTime(data['class_time']);
    final reservedMatNumber = (data['reserved_mat_number'] ?? '')
        .toString()
        .trim();
    final friendName = (data['invitee_name'] ?? 'A friend').toString().trim();

    final details = [
      if (classTime != null) DateFormat.MMMd().add_jm().format(classTime),
      if (reservedMatNumber.isNotEmpty) 'Held mat: $reservedMatNumber',
    ];

    return _SentGroupInviteItem(
      friendName: friendName.isEmpty ? 'A friend' : friendName,
      className: className,
      detailsLabel: details.join('  •  '),
      expiresLabel: _expiresInLabel(expiresAt),
      expiresAt: expiresAt,
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
  final String? fromUid;
  final String? fromName;

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
    this.fromUid,
    this.fromName,
  });

  factory _NotificationItem.fromFirestoreDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final type = (data['type'] ?? '').toString();
    final createdAt =
        _timestampToDateTime(data['created_at']) ?? DateTime.now();
    final classTime = _timestampToDateTime(data['class_time']);
    final inviteStatus = (data['invite_status'] ?? '').toString();
    final inviteExpiresAt = _timestampToDateTime(data['invite_expires_at']);
    final hostMatNumber = (data['host_mat_number'] ?? '').toString().trim();
    final inviteMessage = (data['invite_message'] ?? '').toString().trim();
    final reservedMatNumber = (data['reserved_mat_number'] ?? '')
        .toString()
        .trim();
    final baseTitle = (data['title'] ?? 'Update').toString();
    final baseMessage = (data['message'] ?? '').toString();
    final fromName = (data['from_name'] ?? 'Someone').toString();
    if (type == 'group_invite') {
      final isExpired =
          inviteStatus == 'expired' ||
          (inviteStatus == 'pending' &&
              inviteExpiresAt != null &&
              !inviteExpiresAt.isAfter(DateTime.now()));
      final isPending = inviteStatus == 'pending' && !isExpired;
      final details = [
        if (classTime != null) DateFormat.MMMd().add_jm().format(classTime),
        if (reservedMatNumber.isNotEmpty) 'Your mat: $reservedMatNumber',
        if (hostMatNumber.isNotEmpty) 'Host mat: $hostMatNumber',
        if (isPending && inviteExpiresAt != null)
          'Expires ${DateFormat.jm().format(inviteExpiresAt)}',
      ];
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: inviteMessage.isNotEmpty
            ? '$baseMessage\n\n"$inviteMessage"'
            : baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.group_add,
        color: const Color(0xFF2563EB),
        sortDate: createdAt,
        subtitle: details.isEmpty ? null : details.join('  •  '),
        canAccept: isPending,
        canDecline: isPending,
        inviteStatusBadge: isPending
            ? null
            : isExpired
            ? 'Expired'
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

    if (type == 'friend_request') {
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage.isEmpty
            ? '$fromName wants to be friends with you.'
            : baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.person_add_alt_1,
        color: const Color(0xFF2563EB),
        sortDate: createdAt,
        canAccept: true,
        canDecline: true,
        fromUid: (data['from_uid'] ?? '').toString(),
        fromName: fromName,
      );
    }

    if (type == 'friend_request_response' ||
        type == 'friend_request_accepted' ||
        type == 'friend_request_declined') {
      return _NotificationItem(
        id: doc.id,
        type: type,
        title: baseTitle,
        message: baseMessage.isEmpty
            ? '$fromName responded to your friend request.'
            : baseMessage,
        timeLabel: _relativeLabel(createdAt),
        icon: Icons.person_add_alt_1,
        color: const Color(0xFF16A34A),
        sortDate: createdAt,
        fromUid: (data['from_uid'] ?? '').toString(),
        fromName: fromName,
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

List<_NotificationItem> _buildScheduleNotifications(
  List<Reservation> reservations,
) {
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

List<_NotificationItem> _buildStaffScheduleNotifications(
  List<GymClass> classes, {
  required String staffName,
  DateTime? now,
}) {
  final normalizedStaffName = staffName.trim().toLowerCase();
  if (normalizedStaffName.isEmpty) {
    return const <_NotificationItem>[];
  }

  final currentTime = now ?? DateTime.now();
  final managedClasses =
      classes
          .where(
            (gymClass) =>
                gymClass.instructor.trim().toLowerCase() == normalizedStaffName,
          )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final items = <_NotificationItem>[];
  for (final gymClass in managedClasses) {
    final classDuration = gymClass.durationMinutes > 0
        ? gymClass.durationMinutes
        : 60;
    final classEnd = gymClass.dateTime.add(Duration(minutes: classDuration));
    if (classEnd.isBefore(currentTime)) {
      continue;
    }

    final difference = gymClass.dateTime.difference(currentTime);
    final occupancySummary =
        '${gymClass.filled}/${gymClass.capacity} booked • ${gymClass.location}';

    if (difference.inMinutes >= 0 && difference.inHours < 3) {
      items.add(
        _NotificationItem(
          type: 'staff_schedule',
          title: 'Class begins soon',
          message:
              '${gymClass.title} starts at ${DateFormat.jm().format(gymClass.dateTime)}. ${gymClass.filled}/${gymClass.capacity} spots are booked.',
          timeLabel: 'Soon',
          icon: Icons.alarm,
          color: const Color(0xFFDC2626),
          sortDate: gymClass.dateTime,
          subtitle: occupancySummary,
        ),
      );
      continue;
    }

    if (gymClass.filled >= gymClass.capacity) {
      items.add(
        _NotificationItem(
          type: 'staff_schedule',
          title: 'Class is full',
          message:
              '${gymClass.title} reached capacity for ${DateFormat.MMMd().add_jm().format(gymClass.dateTime)}.${gymClass.standbyCount > 0 ? ' ${gymClass.standbyCount} on standby.' : ''}',
          timeLabel: 'Full',
          icon: Icons.groups_2_rounded,
          color: const Color(0xFFF59E0B),
          sortDate: gymClass.dateTime,
          subtitle: occupancySummary,
        ),
      );
      continue;
    }

    if (_isTomorrow(gymClass.dateTime, currentTime)) {
      items.add(
        _NotificationItem(
          type: 'staff_schedule',
          title: 'Tomorrow\'s class',
          message:
              '${gymClass.title} starts tomorrow at ${DateFormat.jm().format(gymClass.dateTime)}.',
          timeLabel: 'Tomorrow',
          icon: Icons.event_available,
          color: const Color(0xFF2563EB),
          sortDate: gymClass.dateTime,
          subtitle: occupancySummary,
        ),
      );
      continue;
    }

    if (difference.inDays >= 0 && difference.inDays < 7) {
      items.add(
        _NotificationItem(
          type: 'staff_schedule',
          title: 'Upcoming class',
          message:
              '${gymClass.title} is scheduled for ${DateFormat.MMMd().add_jm().format(gymClass.dateTime)}.',
          timeLabel: DateFormat.MMMd().format(gymClass.dateTime),
          icon: Icons.calendar_today,
          color: const Color(0xFF16A34A),
          sortDate: gymClass.dateTime,
          subtitle: occupancySummary,
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
  if (value is DateTime) {
    return value;
  }
  return null;
}

String _expiresInLabel(DateTime expiresAt) {
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining.inMinutes <= 1) {
    return 'Expires in under a minute';
  }
  if (remaining.inHours < 1) {
    return 'Expires in ${remaining.inMinutes} min';
  }
  return 'Expires at ${DateFormat.jm().format(expiresAt)}';
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
