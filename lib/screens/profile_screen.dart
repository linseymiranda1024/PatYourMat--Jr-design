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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              if (profile.bio.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildBioSection(context, profile.bio.trim()),
              ],
              const SizedBox(height: 20),
              _buildStatsSection(
                context: context,
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
    final headerGradient = Theme.of(context).brightness == Brightness.dark
        ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
        : const [AppColors.gradientStart, AppColors.gradientEnd];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 380;
        final avatarRadius = isCompact ? 30.0 : 34.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: headerGradient,
            ),
          ),
          child: Column(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Align(
                alignment: isCompact ? Alignment.center : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 6 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.headerOnBrand.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.headerOnBrand.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    'Member Profile',
                    style: TextStyle(
                      fontSize: isCompact ? 11 : 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerOnBrand.withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Column(
                crossAxisAlignment: isCompact
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.headerOnBrand.withValues(alpha: 0.50),
                        width: 3,
                      ),
                    ),
                    child: ProfileAvatar(
                      radius: avatarRadius,
                      userImage: profile.userImage,
                      userWholeName: profile.wholeName,
                    ),
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: _buildHeaderText(
                      context,
                      profile,
                      memberSince,
                      isCompact: isCompact,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 16 : 20),
              if (isCompact)
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push(ScreenProfileEdit.routeName),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.headerOnBrand,
                            side: BorderSide(
                              color: AppColors.headerOnBrand.withValues(
                                alpha: 0.54,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text(
                            'Edit Profile',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () =>
                              context.push(ScreenSettings.routeName),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.headerOnBrand,
                            backgroundColor: AppColors.headerOnBrand.withValues(
                              alpha: 0.16,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text(
                            'Settings',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push(ScreenProfileEdit.routeName),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.headerOnBrand,
                          side: BorderSide(
                            color: AppColors.headerOnBrand.withValues(
                              alpha: 0.54,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Profile'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => context.push(ScreenSettings.routeName),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.headerOnBrand,
                          backgroundColor: AppColors.headerOnBrand.withValues(
                            alpha: 0.16,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('Settings'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBioSection(BuildContext context, String bio) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _buildSectionCard(
      context: context,
      title: 'About You',
      subtitle: '',
      child: Text(
        bio,
        style: textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.5,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildStatsSection({
    required BuildContext context,
    required List<Reservation> reservations,
    required int thisMonthCount,
    required Reservation? nextReservation,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Snapshot',
          style: textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 520 ? 2 : 3;
            final childAspectRatio = constraints.maxWidth < 380 ? 1.05 : 1.18;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  context: context,
                  label: 'Upcoming Classes',
                  value: '${reservations.length}',
                  icon: Icons.event_available,
                  accent: AppColors.deepPurple,
                ),
                _buildStatCard(
                  context: context,
                  label: 'Classes This Month',
                  value: '$thisMonthCount',
                  icon: Icons.calendar_month_outlined,
                  accent: AppColors.success,
                ),
                _buildStatCard(
                  context: context,
                  label: 'Next Mat Spot',
                  value: nextReservation?.matNumber ?? 'None',
                  icon: Icons.place_outlined,
                  accent: AppColors.warning,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.3 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.25,
              color: colorScheme.onSurfaceVariant,
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
      context: context,
      title: 'Upcoming Reservations',
      subtitle: 'Your next classes and assigned mat spots.',
      child: reservations.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(
                'No upcoming reservations yet. Reserve a class to build out your history here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusAccent = isConfirmed ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
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
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.instructor,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                  color: statusAccent.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.24
                        : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reservation.status,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusAccent,
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
              _buildInfoPill(context, Icons.schedule, reservation.dateTime),
              _buildInfoPill(
                context,
                Icons.place_outlined,
                reservation.matNumber,
              ),
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
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
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
    return _buildSectionCard(
      context: context,
      title: 'Account & Info',
      subtitle: 'Account details and quick actions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                _buildAccountRow(
                  context: context,
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: profile.email.isEmpty ? 'Not provided' : profile.email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _buildActionTile(
            context: context,
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
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.14
                  : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    String? supportingText,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _buildScaledSingleLineText(
                value,
                alignment: Alignment.centerLeft,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  color: valueColor ?? colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 4),
                Text(
                  supportingText,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
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

  Widget _buildHeaderText(
    BuildContext context,
    ProviderUserProfile profile,
    String? memberSince, {
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: isCompact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          profile.wholeName.trim().isEmpty ? 'Your Profile' : profile.wholeName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isCompact ? 24 : 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
            color: AppColors.headerOnBrand,
          ),
        ),
        const SizedBox(height: 8),
        _buildScaledSingleLineText(
          profile.email.isEmpty ? 'No email on file' : profile.email,
          alignment: isCompact ? Alignment.center : Alignment.centerLeft,
          style: TextStyle(
            fontSize: isCompact ? 14 : 15,
            height: 1.2,
            color: AppColors.headerOnBrand.withValues(alpha: 0.88),
          ),
        ),
        if (memberSince != null) ...[
          const SizedBox(height: 4),
          Text(
            memberSince,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isCompact ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: AppColors.headerOnBrand.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScaledSingleLineText(
    String text, {
    required TextStyle style,
    required Alignment alignment,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(text, maxLines: 1, softWrap: false, style: style),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.3 : 1)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? colorScheme.error : colorScheme.primary,
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
                          ? colorScheme.error
                          : colorScheme.onSurface,
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
                            ? colorScheme.error.withValues(alpha: 0.76)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDestructive
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
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
