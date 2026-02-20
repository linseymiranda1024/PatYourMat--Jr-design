import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/provider_user_profile.dart';
import '../providers/provider_auth.dart';
import '../main.dart';
import '../widgets/general/widget_profile_avatar.dart';
import 'settings/screen_profile_edit.dart';
import 'settings/screen_settings.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(providerUserProfile);
    final auth = ref.watch(providerAuth);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8A2BFF),
              Color(0xFF2F7BFF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context, userProfile),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      _buildStatsSection(context),
                      const SizedBox(height: 24),
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      _buildRecentActivity(context),
                      const SizedBox(height: 24),
                      _buildAchievements(context),
                      const SizedBox(height: 24),
                      _buildAccountManagement(context, auth),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProviderUserProfile profile) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ProfileAvatar(
                  radius: 60,
                  userImage: profile.userImage,
                  userWholeName: profile.wholeName,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.star, color: Colors.orange.shade700, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            profile.wholeName,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            profile.email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Premium Member",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push(ScreenProfileEdit.routeName),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2F7BFF),
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
            child: const Text(
              "Edit Profile",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Activity Stats",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard("Total Classes", "42", Icons.fitness_center, Colors.blue, progress: 0.42, progressText: "42/100 to Silver"),
            const SizedBox(width: 16),
            _buildStatCard("This Month", "12", Icons.calendar_month, Colors.orange),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard("Active Res.", "3", Icons.bookmark, Colors.green),
            const SizedBox(width: 16),
            _buildStatCard("Attend Rate", "98%", Icons.trending_up, Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {double? progress, String? progressText}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
            if (progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(progressText!, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        _buildActionButton(context, "My Reservations", Icons.event_available, () {}),
        _buildActionButton(context, "Friends", Icons.people_outline, () {}),
        _buildActionButton(context, "Account Status", Icons.info_outline, () {}),
        _buildActionButton(context, "Settings", Icons.settings_outlined, () => context.push(ScreenSettings.routeName)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF2F7BFF)),
                const SizedBox(width: 16),
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildActivityItem("Power Yoga", "Today, 6:00 AM", "Upcoming", Colors.blue),
          _buildActivityItem("HIIT Blast", "Yesterday, 7:30 AM", "Attended", Colors.green),
          _buildActivityItem("Pilates Core", "Feb 3, 8:30 AM", "Attended", Colors.green),
          _buildActivityItem("Spin Power", "Jan 30, 5:00 PM", "Missed", Colors.red),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: Colors.black45, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Achievements",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 20,
            crossAxisSpacing: 10,
            children: [
              _buildBadge(Icons.wb_sunny, "Early Bird", true),
              _buildBadge(Icons.self_improvement, "Yogi", true),
              _buildBadge(Icons.bolt, "HIIT King", false),
              _buildBadge(Icons.workspace_premium, "Perfect", false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, bool earned) {
    return Column(
      children: [
        Opacity(
          opacity: earned ? 1.0 : 0.3,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: earned ? const Color(0xFFF0F4FF) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: earned ? const Color(0xFF2F7BFF) : Colors.grey, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, color: earned ? Colors.black87 : Colors.grey), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildAccountManagement(BuildContext context, ProviderAuth auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildActionRow("Change Password", Icons.lock_outline, () {}),
          _buildActionRow("Notifications", Icons.notifications_none, () {}),
          _buildActionRow("Connected Devices", Icons.important_devices, () {}),
          const Divider(height: 32),
          _buildActionRow("Logout", Icons.logout, () => auth.clearAuthedUserDetailsAndSignout(), isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.red : Colors.black54, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
            const Spacer(),
            if (!isDestructive) const Icon(Icons.chevron_right, color: Colors.black12),
          ],
        ),
      ),
    );
  }
}
