import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/provider_user_profile.dart';
import '../../main.dart';

class ScreenStaffPortal extends ConsumerWidget {
  static const routeName = '/staff_portal';

  const ScreenStaffPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(providerUserProfile);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Portal',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back, ${userProfile.firstName}!',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            
            // Stats Row
            Row(
              children: [
                _buildStatCard('Active Classes', '12', Icons.class_, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('Total Members', '245', Icons.people, Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard('Pending Registrations', '45', Icons.pending_actions, Colors.orange),
                const SizedBox(width: 16),
                _buildStatCard('Gym Capacity', '75%', Icons.pie_chart, Colors.purple),
              ],
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Class Management (Dummy Data)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Dummy Class Management List
            _buildManagementItem('Morning Vinyasa', 'Sarah J.', '6:00 AM', '28/30'),
            _buildManagementItem('Power HIIT', 'Mike C.', '7:30 AM', '15/20'),
            _buildManagementItem('Beginner Pilates', 'Emma W.', '9:00 AM', '10/25'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementItem(String title, String instructor, String time, String filled) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$instructor • $time', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(filled, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const Text('Filled', style: TextStyle(fontSize: 12, color: Colors.black45)),
            ],
          ),
          const SizedBox(width: 16),
          const Icon(Icons.edit_outlined, color: Colors.grey),
        ],
      ),
    );
  }
}
