import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/provider_user_profile.dart';
import '../../models/user_profile.dart';
import '../../screens/home_screen.dart';
import '../../screens/calendar_screen.dart';
import '../../screens/friends_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../screens/profile_screen.dart';
import '../../screens/staff/screen_staff_portal.dart';
import '../../screens/staff/screen_staff_profile.dart';
import '../../main.dart';

class WidgetAppOutline extends ConsumerStatefulWidget {
  static const routeName = '/home_outline';
  final int? initialIndex;

  const WidgetAppOutline({super.key, this.initialIndex});

  @override
  ConsumerState<WidgetAppOutline> createState() => _WidgetAppOutlineState();
}

class _WidgetAppOutlineState extends ConsumerState<WidgetAppOutline> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(providerUserProfile);
    final isStaff = userProfile.role == UserRole.STAFF;

    // Dynamically build the list of pages and destinations based on user role.
    final List<Widget> pages = [
      isStaff ? const ScreenStaffPortal() : const HomeScreen(),
      const CalendarScreen(),
      if (!isStaff) const FriendsScreen(), // Only show Friends for non-staff
      const NotificationsScreen(),
      isStaff ? const ScreenStaffProfile() : const ProfileScreen(),
    ];

    final List<NavigationDestination> destinations = [
      NavigationDestination(
        icon: Icon(isStaff ? Icons.admin_panel_settings_outlined : Icons.home_outlined),
        selectedIcon: Icon(isStaff ? Icons.admin_panel_settings : Icons.home),
        label: isStaff ? 'Staff Portal' : 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Calendar',
      ),
      if (!isStaff) // Only show Friends for non-staff
        const NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: 'Friends',
        ),
      const NavigationDestination(
        icon: Icon(Icons.notifications_none),
        selectedIcon: Icon(Icons.notifications),
        label: 'Alerts',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    // Prevent index out of bounds when switching roles.
    if (_index >= pages.length) {
      _index = 0;
    }

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 70,
        destinations: destinations,
      ),
    );
  }
}
