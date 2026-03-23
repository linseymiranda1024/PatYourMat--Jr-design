import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../models/gym_class.dart';
import '../../providers/provider_auth.dart';
import '../../providers/provider_user_profile.dart';
import '../../widgets/general/widget_profile_avatar.dart';
import '../settings/screen_profile_edit.dart';
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

    final totalCapacity = managedClasses.fold<int>(
      0,
      (total, gymClass) => total + gymClass.capacity,
    );
    final totalFilled = managedClasses.fold<int>(
      0,
      (total, gymClass) => total + gymClass.filled,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 20),
              _buildStatsSection(
                managedClasses: managedClasses,
                upcomingCount: upcomingClasses.length,
                totalCapacity: totalCapacity,
                totalFilled: totalFilled,
              ),
              const SizedBox(height: 20),
              _buildManagementTools(context, auth, profile),
              const SizedBox(height: 20),
              _buildScheduleSection(upcomingClasses, profile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
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
                  border: Border.all(color: const Color(0xFFFFC857), width: 2),
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
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildHeaderBadge(
                          label: profile.isActiveInstructor
                              ? 'ACTIVE STAFF'
                              : 'STAFF',
                          background: const Color(0x1AFFFFFF),
                          foreground: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        _buildHeaderBadge(
                          label: profile.allowClassCreation
                              ? 'CAN CREATE CLASSES'
                              : 'PROFILE ACCESS',
                          background: const Color(0x26FFC857),
                          foreground: const Color(0xFFFFD87E),
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
            style: TextStyle(
              height: 1.45,
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.80),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildStatsSection({
    required List<GymClass> managedClasses,
    required int upcomingCount,
    required int totalCapacity,
    required int totalFilled,
  }) {
    final occupancy = totalCapacity == 0
        ? '0%'
        : '${((totalFilled / totalCapacity) * 100).round()}%';

    return _buildPanel(
      title: 'Staff Stats',
      subtitle: 'Quick view of the classes currently tied to your profile.',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          _buildStatTile(
            label: 'Managed Classes',
            value: '${managedClasses.length}',
            icon: Icons.class_outlined,
            accent: const Color(0xFF2957C8),
          ),
          _buildStatTile(
            label: 'Upcoming',
            value: '$upcomingCount',
            icon: Icons.schedule_outlined,
            accent: const Color(0xFF0B8F6A),
          ),
          _buildStatTile(
            label: 'Seats Filled',
            value: '$totalFilled',
            icon: Icons.people_outline,
            accent: const Color(0xFFC77718),
          ),
          _buildStatTile(
            label: 'Occupancy',
            value: occupancy,
            icon: Icons.analytics_outlined,
            accent: const Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTools(
    BuildContext context,
    ProviderAuth auth,
    ProviderUserProfile profile,
  ) {
    return _buildPanel(
      title: 'Management Tools',
      subtitle:
          'Primary staff actions, surfaced as a focused operations dashboard.',
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: [
          _buildToolCard(
            icon: Icons.add_box_outlined,
            label: 'Create Class',
            description: 'Add a new class to the schedule.',
            accent: const Color(0xFF2957C8),
            onTap: () => context.push(ScreenCreateClass.routeName),
          ),
          _buildToolCard(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            description: 'Update contact details and profile image.',
            accent: const Color(0xFF0B8F6A),
            onTap: () => context.push(ScreenProfileEdit.routeName),
          ),
          _buildToolCard(
            icon: Icons.edit_note,
            label: 'Edit Bio',
            description: profile.bio.isEmpty
                ? 'Add staff bio details.'
                : 'Refresh the instructor bio shown to members.',
            accent: const Color(0xFFC77718),
            onTap: () => context.push(ScreenProfileEdit.routeName),
          ),
          _buildToolCard(
            icon: Icons.logout,
            label: 'Log Out',
            description: 'Sign out of the staff account.',
            accent: const Color(0xFFB3261E),
            onTap: () => auth.promptAndClearAuthedUserDetailsAndSignout(
              context: context,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(
    List<GymClass> upcomingClasses,
    ProviderUserProfile profile,
  ) {
    return _buildPanel(
      title: 'Upcoming Schedule',
      subtitle: 'Classes matched to your instructor profile.',
      child: upcomingClasses.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                profile.wholeName.trim().isEmpty
                    ? 'No upcoming classes are linked to this staff account yet.'
                    : 'No upcoming classes currently list ${profile.wholeName} as instructor.',
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            )
          : Column(
              children: upcomingClasses
                  .take(4)
                  .map(
                    (gymClass) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildClassCard(gymClass),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPanel({
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
            color: Color(0x120E1726),
            blurRadius: 20,
            offset: Offset(0, 8),
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

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5D6470),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required String description,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF4B5563), height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(GymClass gymClass) {
    final occupancy = gymClass.capacity == 0
        ? 0.0
        : gymClass.filled / gymClass.capacity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                gymClass.timeText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${gymClass.dateText} • ${gymClass.location}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: occupancy,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFC857),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${gymClass.filled}/${gymClass.capacity} seats filled',
            style: const TextStyle(
              color: Colors.white70,
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
