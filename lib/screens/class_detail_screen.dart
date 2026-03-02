// lib/screens/class_detail_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/provider_reservations.dart'; // ← your reservations provider
import 'reservation_confirmation_screen.dart'; // ← the success screen

class ClassDetailScreen extends ConsumerWidget {
  static const String routeName = '/class_detail';

  const ClassDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // Purple gradient header background
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8A2BFF), Color(0xFF6A1B9A)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button + title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Power Yoga\nYoga Class',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // White content area
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Class Status ────────────────────────────────────────
                          const Text(
                            'Class Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '18 Spots Left',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'OPEN',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: 12 / 30,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.green,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                          const Text(
                            '12 / 30 registered',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),

                          const SizedBox(height: 32),

                          // ── Class Information ───────────────────────────────────
                          const Text(
                            'Class Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildInfoRow(
                            Icons.person_outline,
                            'Instructor',
                            'Sarah Johnson',
                          ),
                          _buildInfoRow(
                            Icons.calendar_today_outlined,
                            'Date & Time',
                            'Mon, Feb 3 at 6:00 AM',
                          ),
                          _buildInfoRow(
                            Icons.timer_outlined,
                            'Duration',
                            '60 min',
                          ),
                          _buildInfoRow(
                            Icons.location_on_outlined,
                            'Location',
                            'Recreation Center - Studio A',
                          ),
                          _buildInfoRow(
                            Icons.group_outlined,
                            'Capacity',
                            '30 mats',
                          ),

                          const SizedBox(height: 32),

                          // ── About This Class ────────────────────────────────────
                          const Text(
                            'About This Class',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            'Join us for an energizing Power Yoga session!\n'
                            'This class is perfect for all levels and focuses on '
                            'building strength, flexibility, and mindfulness.\n\n'
                            'Bring your water bottle and get ready to sweat!',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: Colors.black87,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // ── Reserve Button ──────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // For demo: hardcoded class info
                                // In a real app, you'd receive this via constructor or route extra
                                final className = 'Power Yoga';
                                final instructor = 'Sarah Johnson';
                                final dateTimeStr = 'Mon, Feb 3 6:00 AM';
                                final fakeDate = DateTime(
                                  2025,
                                  2,
                                  3,
                                  6,
                                  0,
                                ); // for sorting

                                // 1. Add to reservations provider (random mat assigned inside)
                                ref
                                    .read(reservationsProvider.notifier)
                                    .reserveClass(
                                      className: className,
                                      instructor: instructor,
                                      dateTime: dateTimeStr,
                                      date: fakeDate,
                                    );

                                // 2. Get the latest added reservation to show in confirmation
                                final reservations = ref.read(
                                  reservationsProvider,
                                );
                                final justAdded = reservations.lastWhere(
                                  (r) =>
                                      r.className == className &&
                                      r.dateTime == dateTimeStr,
                                );

                                // 3. Navigate to confirmation screen
                                context.pushNamed(
                                  ReservationConfirmationScreen.routeName,
                                  extra: {
                                    'className': justAdded.className,
                                    'instructor': justAdded.instructor,
                                    'dateTime': justAdded.dateTime,
                                    'matNumber': justAdded.matNumber,
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6200EE),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Reserve Your Spot',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6200EE), size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
