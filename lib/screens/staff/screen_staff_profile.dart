import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/provider_user_profile.dart';
import '../../providers/provider_auth.dart';
import '../../providers/provider_gym_class.dart';
import '../../models/user_profile.dart';
import '../../models/gym_class.dart' as model;
import '../../widgets/general/widget_profile_avatar.dart';
import '../settings/screen_profile_edit.dart';
import '../../main.dart';

class ScreenStaffProfile extends ConsumerWidget {
  static const routeName = '/staff_profile';

  const ScreenStaffProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerUserProfile);
    final auth = ref.watch(providerAuth);
    final gymClassProvider = ref.watch(providerGymClass);
    final upcomingClasses = gymClassProvider.classes.take(3).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8A2BFF), Color(0xFF2F7BFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    _buildHeader(context, profile),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          _buildAboutCard(profile),
                          const SizedBox(height: 20),
                          _buildUpcomingClassesCard(context, upcomingClasses),
                          const SizedBox(height: 20),
                          _buildPerformanceSnapshot(),
                          const SizedBox(height: 20),
                          _buildQuickActions(context),
                          const SizedBox(height: 20),
                          _buildAccountSection(context, auth),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => context.push(ScreenProfileEdit.routeName),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ProfileAvatar(
              radius: 65,
              userImage: profile.userImage,
              userWholeName: profile.wholeName,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            profile.wholeName,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Group Fitness Instructor",
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF00E676)),
                SizedBox(width: 8),
                Text(
                  "ACTIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(ProviderUserProfile profile) {
    return _buildGlassCard(
      title: "About Me",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.bio.isEmpty ? "No bio provided yet." : profile.bio,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Specialties",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                (profile.specialties.isEmpty
                        ? ["Yoga", "HIIT", "Cardio"]
                        : profile.specialties)
                    .map((s) => _buildPill(s))
                    .toList(),
          ),
          if (profile.yearsTeaching > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: Color(0xFF7A2CFF),
                ),
                const SizedBox(width: 8),
                Text(
                  "${profile.yearsTeaching} Years Teaching",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesCard(
    BuildContext context,
    List<model.GymClass> classes,
  ) {
    return _buildGlassCard(
      title: "My Upcoming Classes",
      child: Column(
        children: [
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "No classes scheduled.",
                style: TextStyle(color: Colors.black45),
              ),
            )
          else
            ...classes.map((c) => _buildClassItem(c)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                "View All Classes",
                style: TextStyle(
                  color: Color(0xFF7A2CFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSnapshot() {
    return _buildGlassCard(
      title: "Performance Snapshot",
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: [
          _buildStatTile("Total Taught", "142", Icons.fitness_center),
          _buildStatTile("Avg Atten.", "18", Icons.people),
          _buildStatTile("Avg Rating", "4.9 ⭐", Icons.star),
          _buildStatTile("Popular", "Power Yoga", Icons.trending_up),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8A2BFF), Color(0xFF2F7BFF)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A2BFF).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "Create New Class",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryAction(
                "My Attendance",
                Icons.fact_check_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSecondaryAction(
                "Message Group",
                Icons.chat_bubble_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, ProviderAuth auth) {
    return _buildGlassCard(
      title: "Account",
      child: Column(
        children: [
          _buildMenuRow("Edit Profile", Icons.person_outline, () {}),
          _buildMenuRow(
            "Notification Settings",
            Icons.notifications_none,
            () {},
          ),
          const Divider(height: 24),
          _buildMenuRow(
            "Log Out",
            Icons.logout,
            () => auth.promptAndClearAuthedUserDetailsAndSignout(
              context: context,
            ),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7A2CFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7A2CFF),
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildClassItem(model.GymClass c) {
    final progress = c.capacity == 0 ? 0.0 : c.filled / c.capacity;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                c.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                c.timeText,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${c.dateText} • ${c.location}",
            style: const TextStyle(color: Colors.black45, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2F7BFF),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${c.filled}/${c.capacity} spots filled",
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2F7BFF)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryAction(String label, IconData icon) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? Colors.red : Colors.black54,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
            const Spacer(),
            if (!isDestructive)
              const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
