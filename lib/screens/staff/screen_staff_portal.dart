import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pat_your_mat/theme/app_colors.dart';
import 'package:pat_your_mat/theme/colors.dart';

import '../../models/gym_class.dart';
import 'screen_create_class.dart';
import '../../main.dart';

class ScreenStaffPortal extends ConsumerWidget {
  static const routeName = '/staff_portal';

  const ScreenStaffPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(providerUserProfile);
    final gymClassProvider = ref.watch(providerGymClass);
    final classes = gymClassProvider.classes;
    final totalSeats = classes.fold<int>(
      0,
      (total, gymClass) => total + gymClass.capacity,
    );
    final seatsFilled = classes.fold<int>(
      0,
      (total, gymClass) => total + gymClass.filled,
    );
    final averageOccupancy = totalSeats == 0
        ? '0%'
        : '${((seatsFilled / totalSeats) * 100).round()}%';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(context, userProfile),
              const SizedBox(height: 20),
              _buildPanel(
                title: 'Portal Snapshot',
                subtitle: 'Useful, real metrics from the current class roster.',
                child: LayoutBuilder(
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
                          label: 'Active Classes',
                          value: '${classes.length}',
                          icon: Icons.class_,
                          color: AppColors.deepPurple,
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          label: 'Total Capacity',
                          value: '$totalSeats',
                          icon: Icons.event_seat_outlined,
                          color: CustomColors.statusInfo,
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          label: 'Total Seats Filled',
                          value: '$seatsFilled',
                          icon: Icons.people_outline,
                          color: const Color(0xFFC77718),
                        ),
                        _buildStatCard(
                          width: cardWidth,
                          label: 'Average Occupancy',
                          value: averageOccupancy,
                          icon: Icons.pie_chart_outline,
                          color: AppColors.primaryPurple,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildPanel(
                title: 'Class Management',
                subtitle:
                    'Current classes with capacity visibility and quick cleanup.',
                child: gymClassProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : classes.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FD),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4EAF4)),
                        ),
                        child: const Text(
                          'No classes created yet.',
                          style: TextStyle(
                            color: Color(0xFF5D6470),
                            height: 1.4,
                          ),
                        ),
                      )
                    : Column(
                        children: classes
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildManagementItem(context, ref, c),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, userProfile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff Portal',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userProfile.firstName.trim().isEmpty
                    ? 'Manage classes and monitor capacity in one place.'
                    : 'Welcome back, ${userProfile.firstName}. Manage classes and monitor capacity in one place.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildHeaderAction(
                    label: 'Create Class',
                    icon: Icons.add,
                    filled: true,
                    onTap: () => context.push(ScreenCreateClass.routeName),
                  ),
                  _buildHeaderAction(
                    label: 'Class Setup',
                    icon: Icons.calendar_month_outlined,
                    filled: false,
                    onTap: () => context.push(ScreenCreateClass.routeName),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderAction({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.deepPurple,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: child,
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1726),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5D6470), height: 1.4),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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

  Widget _buildManagementItem(
    BuildContext context,
    WidgetRef ref,
    GymClass gymClass,
  ) {
    final occupancy = gymClass.capacity == 0
        ? 0.0
        : gymClass.filled / gymClass.capacity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EAF4)),
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
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
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
                  style: const TextStyle(
                    color: Color(0xFF5D6470),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${gymClass.instructor} • ${gymClass.dateText} • ${gymClass.location}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF5D6470), height: 1.35),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: occupancy,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EDF5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFC857),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${gymClass.filled}/${gymClass.capacity} seats filled',
                style: const TextStyle(
                  color: Color(0xFF5D6470),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Class'),
                      content: const Text(
                        'Are you sure you want to delete this class?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(providerGymClass).deleteClass(gymClass.id);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC857),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
