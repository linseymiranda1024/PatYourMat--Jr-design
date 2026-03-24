import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pat_your_mat/main.dart';
import 'package:pat_your_mat/theme/app_colors.dart';

import '../models/reservation.dart';
import '../providers/provider_auth.dart';
import '../providers/provider_reservations.dart';
import '../providers/provider_user_profile.dart';
import '../widgets/general/widget_profile_avatar.dart';
import 'settings/screen_profile_edit.dart';
import 'settings/screen_settings.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerUserProfile);
    final auth = ref.watch(providerAuth);
    final reservations = [...ref.watch(reservationsProvider).reservations]
      ..sort((a, b) => a.date.compareTo(b.date));

    final thisMonthCount = reservations.where((reservation) {
      final now = DateTime.now();
      return reservation.date.month == now.month &&
          reservation.date.year == now.year;
    }).length;
    final nextReservation = reservations.isEmpty ? null : reservations.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 20),
              _buildStatsSection(
                reservations: reservations,
                thisMonthCount: thisMonthCount,
                nextReservation: nextReservation,
              ),
              const SizedBox(height: 20),
              _buildUpcomingReservationsSection(context, ref, reservations),
              const SizedBox(height: 20),
              _buildAccountSection(context, profile, auth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    final memberSince = _formatMemberSince(profile.accountCreationTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              'Member Profile',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.50),
                    width: 3,
                  ),
                ),
                child: ProfileAvatar(
                  radius: 34,
                  userImage: profile.userImage,
                  userWholeName: profile.wholeName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.wholeName.trim().isEmpty
                          ? 'Your Profile'
                          : profile.wholeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      memberSince ?? profile.email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              return Flex(
                direction: isCompact ? Axis.vertical : Axis.horizontal,
                children: [
                  Expanded(
                    flex: isCompact ? 0 : 1,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push(ScreenProfileEdit.routeName),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                  SizedBox(
                    width: isCompact ? 0 : 12,
                    height: isCompact ? 12 : 0,
                  ),
                  Expanded(
                    flex: isCompact ? 0 : 1,
                    child: TextButton.icon(
                      onPressed: () => context.push(ScreenSettings.routeName),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.tune),
                      label: const Text('Settings'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection({
    required List<Reservation> reservations,
    required int thisMonthCount,
    required Reservation? nextReservation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Snapshot',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;
            final cardWidth = isCompact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(
                  width: cardWidth,
                  label: 'Upcoming Classes',
                  value: '${reservations.length}',
                  icon: Icons.event_available,
                  accent: AppColors.deepPurple,
                ),
                _buildStatCard(
                  width: cardWidth,
                  label: 'Classes This Month',
                  value: '$thisMonthCount',
                  icon: Icons.calendar_month_outlined,
                  accent: const Color(0xFF1F8F71),
                ),
                _buildStatCard(
                  width: cardWidth,
                  label: 'Next Mat Spot',
                  value: nextReservation?.matNumber ?? 'None',
                  icon: Icons.place_outlined,
                  accent: const Color(0xFFC77718),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080E1726),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingReservationsSection(
    BuildContext context,
    WidgetRef ref,
    List<Reservation> reservations,
  ) {
    return _buildSectionCard(
      title: 'Upcoming Reservations',
      subtitle: 'Your next classes and assigned mat spots.',
      child: reservations.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE4EAF4)),
              ),
              child: const Text(
                'No upcoming reservations yet. Reserve a class to build out your history here.',
                style: TextStyle(height: 1.45, color: Color(0xFF5D6470)),
              ),
            )
          : Column(
              children: reservations
                  .map(
                    (reservation) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildReservationCard(context, ref, reservation),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    WidgetRef ref,
    Reservation reservation,
  ) {
    final isConfirmed = reservation.status.toUpperCase() == 'CONFIRMED';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.className,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.instructor,
                      style: const TextStyle(
                        color: Color(0xFF5D6470),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? const Color(0xFFE4F6EE)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reservation.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isConfirmed
                        ? const Color(0xFF0B8F6A)
                        : const Color(0xFFC77718),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _buildInfoPill(Icons.schedule, reservation.dateTime),
              _buildInfoPill(Icons.place_outlined, reservation.matNumber),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(reservationsProvider)
                      .cancelReservation(reservation);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reservation cancelled')),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  var message = error.toString();
                  if (message.startsWith('Exception: ')) {
                    message = message.replaceFirst('Exception: ', '');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cancel failed: $message')),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
              ),
              child: const Text(
                'Cancel Reservation',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    ProviderUserProfile profile,
    ProviderAuth auth,
  ) {
    final hasPhone = profile.phoneNumber.trim().isNotEmpty;

    return _buildSectionCard(
      title: 'Account & Info',
      subtitle: 'Contact details and quick account actions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE6ECF5)),
            ),
            child: Column(
              children: [
                _buildAccountRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: profile.email.isEmpty ? 'Not provided' : profile.email,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFE1E7F0)),
                ),
                _buildAccountRow(
                  icon: Icons.call_outlined,
                  label: 'Phone',
                  value: hasPhone ? profile.phoneNumber : 'Add phone number',
                  supportingText: hasPhone
                      ? 'Saved on your profile.'
                      : 'Open Edit Profile to add one.',
                  valueColor: hasPhone
                      ? const Color(0xFF111827)
                      : AppColors.deepPurple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5D6470),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _buildActionTile(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            subtitle: 'Update your photo, name, and phone number.',
            onTap: () => context.push(ScreenProfileEdit.routeName),
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            subtitle: 'Manage app and account preferences.',
            onTap: () => context.push(ScreenSettings.routeName),
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            icon: Icons.logout,
            label: 'Log Out',
            subtitle: 'Sign out of your Pat Your Mat account.',
            isDestructive: true,
            onTap: () => auth.promptAndClearAuthedUserDetailsAndSignout(
              context: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1726),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5D6470), height: 1.4),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5D6470)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF39414D),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRow({
    required IconData icon,
    required String label,
    required String value,
    String? supportingText,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2957C8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5D6470),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? const Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportingText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5D6470),
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFFF3F1)
              : const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF2957C8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? const Color(0xFFB3261E)
                          : const Color(0xFF111827),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: isDestructive
                            ? const Color(0xFFB3261E).withValues(alpha: 0.76)
                            : const Color(0xFF5D6470),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF8A94A6),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatMemberSince(int epochValue) {
    if (epochValue <= 0) {
      return null;
    }

    final isSeconds = epochValue < 100000000000;
    final date = DateTime.fromMillisecondsSinceEpoch(
      isSeconds ? epochValue * 1000 : epochValue,
    );
    return 'Member since ${DateFormat.yMMMM().format(date)}';
  }
}
