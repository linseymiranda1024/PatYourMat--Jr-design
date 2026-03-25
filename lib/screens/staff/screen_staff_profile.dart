import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pat_your_mat/theme/app_colors.dart';

import '../../main.dart';
import '../../models/gym_class.dart';
import '../../providers/provider_auth.dart';
import '../../providers/provider_user_profile.dart';
import '../../widgets/general/widget_profile_avatar.dart';
import '../settings/screen_profile_edit.dart';
import '../settings/screen_settings.dart';
import 'screen_create_class.dart';

class ScreenStaffProfile extends ConsumerWidget {
  static const routeName = '/staff_profile';

  const ScreenStaffProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerUserProfile);
    final auth = ref.watch(providerAuth);
    final allClasses = ref.watch(providerGymClass).classes;
    final managedClasses = _managedClassesForProfile(allClasses, profile);
    final upcomingClasses = managedClasses.where((gymClass) {
      return gymClass.dateTime.isAfter(DateTime.now());
    }).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 20),
              _buildAccountSection(context, profile),
              const SizedBox(height: 20),
              _buildManagementTools(context, auth, profile),
              const SizedBox(height: 20),
              _buildScheduleSection(context, upcomingClasses, profile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [AppColors.gradientStartDark, AppColors.gradientEndDark]
              : const [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.warning.withValues(alpha: 0.45)
                        : const Color(0xFFFFC857),
                    width: 2,
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
                          ? 'Staff Profile'
                          : profile.wholeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headerOnBrand,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildHeaderBadge(
                          label: profile.isActiveInstructor
                              ? 'ACTIVE STAFF'
                              : 'STAFF',
                          background: isDark
                              ? AppColors.headerOnBrand.withValues(alpha: 0.08)
                              : const Color(0xFFF8FAFF),
                          foreground: isDark
                              ? AppColors.headerOnBrand
                              : const Color(0xFF2F3D5C),
                        ),
                        _buildHeaderBadge(
                          label: profile.allowClassCreation
                              ? 'CAN CREATE CLASSES'
                              : 'PROFILE ACCESS',
                          background: isDark
                              ? AppColors.warning.withValues(alpha: 0.18)
                              : const Color(0xFFFFD27A),
                          foreground: isDark
                              ? colorScheme.onSurface
                              : const Color(0xFF5E3A00),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            profile.bio.isEmpty
                ? 'Manage classes, keep your schedule in view, and maintain your staff profile.'
                : profile.bio,
            maxLines: profile.bio.isEmpty ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.45,
              fontSize: 14,
              color: AppColors.headerOnBrand.withValues(alpha: 0.80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildManagementTools(
    BuildContext context,
    ProviderAuth auth,
    ProviderUserProfile profile,
  ) {
    return _buildPanel(
      context: context,
      title: 'Management Tools',
      subtitle: 'Compact shortcuts for the staff tasks that matter here.',
      child: Column(
        children: [
          _buildToolRow(
            context: context,
            icon: Icons.add_box_outlined,
            label: 'Create Class',
            description: 'Add a new class to the schedule.',
            accent: AppColors.deepPurple,
            onTap: () => context.push(ScreenCreateClass.routeName),
          ),
          const SizedBox(height: 10),
          _buildToolRow(
            context: context,
            icon: Icons.person_outline,
            label: 'Edit Profile',
            description: 'Update contact details, bio, and staff info.',
            accent: const Color(0xFF1F8F71),
            onTap: () => context.push(ScreenProfileEdit.routeName),
          ),
          const SizedBox(height: 10),
          _buildToolRow(
            context: context,
            icon: Icons.logout,
            label: 'Log Out',
            description: 'Sign out of the staff account.',
            accent: const Color(0xFFB3261E),
            isDestructive: true,
            onTap: () => auth.promptAndClearAuthedUserDetailsAndSignout(
              context: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    ProviderUserProfile profile,
  ) {
    return _buildPanel(
      context: context,
      title: 'Account & Preferences',
      subtitle: 'Basic profile access for staff accounts.',
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
          _buildToolRow(
            context: context,
            icon: Icons.settings_outlined,
            label: 'Settings',
            description: 'Manage app and account preferences.',
            accent: AppColors.primaryPurple,
            onTap: () => context.push(ScreenSettings.routeName),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(
    BuildContext context,
    List<GymClass> upcomingClasses,
    ProviderUserProfile profile,
  ) {
    return _buildPanel(
      context: context,
      title: 'Upcoming Schedule',
      subtitle: 'Classes matched to your instructor profile.',
      child: upcomingClasses.isEmpty
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
                profile.wholeName.trim().isEmpty
                    ? 'No upcoming classes are linked to this staff account yet.'
                    : 'No upcoming classes currently list ${profile.wholeName} as instructor.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            )
          : Column(
              children: upcomingClasses
                  .take(4)
                  .map(
                    (gymClass) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildClassCard(context, gymClass),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPanel({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.deepPurple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.deepPurple, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: valueColor ?? colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (supportingText != null) ...[
                const SizedBox(height: 2),
                Text(
                  supportingText,
                  style: textTheme.bodySmall?.copyWith(
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

  Widget _buildToolRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String description,
    required Color accent,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.3 : 1)
              : accent.withValues(alpha: isDark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? colorScheme.error.withValues(alpha: 0.25)
                : accent.withValues(alpha: isDark ? 0.28 : 0.14),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? colorScheme.error.withValues(alpha: 0.12)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? colorScheme.error : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDestructive
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
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
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, GymClass gymClass) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final occupancy = gymClass.capacity == 0
        ? 0.0
        : gymClass.filled / gymClass.capacity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  gymClass.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  gymClass.timeText,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${gymClass.dateText} • ${gymClass.location}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: occupancy,
              minHeight: 8,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.warning,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${gymClass.filled}/${gymClass.capacity} seats filled',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<GymClass> _managedClassesForProfile(
    List<GymClass> allClasses,
    ProviderUserProfile profile,
  ) {
    final fullName = profile.wholeName.trim().toLowerCase();
    if (fullName.isEmpty) {
      return const [];
    }

    return allClasses.where((gymClass) {
      return gymClass.instructor.trim().toLowerCase() == fullName;
    }).toList();
  }
}
