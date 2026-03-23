import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings_v2';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends State<SettingsScreen> {
  bool pushNotifications = true;
  bool standbyAlerts = true;
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    // Defining colors based on Dark Mode state
    final backgroundColor = darkMode
        ? const Color(0xFF121212)
        : const Color(0xFFF8F9FE);
    final cardColor = darkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = darkMode ? Colors.white : Colors.black87;
    final subTextColor = darkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Extended Header with Purple Gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 60, // Increased top padding
              left: 16,
              right: 16,
              bottom:
                  60, // Increased bottom padding to "extend" the border downward
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8A2BFF), Color(0xFF2F7BFF)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40), // More pronounced curve
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 8),
                  child: Text(
                    "Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  _buildSectionTitle("App Preferences", textColor),
                  const SizedBox(height: 12),
                  _buildCard(cardColor, [
                    _buildSettingTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: Colors.blue,
                      title: "Push Notifications",
                      subtitle: "Receive alerts for class updates",
                      value: pushNotifications,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      onChanged: (val) =>
                          setState(() => pushNotifications = val),
                    ),
                    const Divider(height: 1),
                    _buildSettingTile(
                      icon: Icons.timer_outlined,
                      iconColor: Colors.orange,
                      title: "Standby Alerts",
                      subtitle: "Notify me when a spot opens up",
                      value: standbyAlerts,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      onChanged: (val) => setState(() => standbyAlerts = val),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Display", textColor),
                  const SizedBox(height: 12),
                  _buildCard(cardColor, [
                    _buildSettingTile(
                      icon: Icons.dark_mode_outlined,
                      iconColor: Colors.purple,
                      title: "Dark Mode",
                      subtitle: "Reduce glare and save battery",
                      value: darkMode,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      onChanged: (val) => setState(() => darkMode = val),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCard(Color color, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Color textColor,
    required Color subTextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: subTextColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
    );
  }
}
