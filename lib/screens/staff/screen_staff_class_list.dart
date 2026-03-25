import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/gym_class.dart';

class ScreenStaffClassList extends ConsumerWidget {
  static const routeName = '/staff/classes';

  final bool showPast;

  const ScreenStaffClassList({super.key, required this.showPast});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymClassProvider = ref.watch(providerGymClass);
    final now = DateTime.now();
    final classes = [...gymClassProvider.classes];
    final filteredClasses =
        classes.where((gymClass) {
          return showPast
              ? gymClass.dateTime.isBefore(now)
              : !gymClass.dateTime.isBefore(now);
        }).toList()..sort(
          (a, b) => showPast
              ? b.dateTime.compareTo(a.dateTime)
              : a.dateTime.compareTo(b.dateTime),
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(showPast ? 'Recent Classes' : 'Active Classes'),
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showPast
                    ? 'Completed classes kept here for quick reference.'
                    : 'Current and upcoming classes on the live schedule.',
                style: const TextStyle(color: Color(0xFF5D6470), height: 1.4),
              ),
              const SizedBox(height: 20),
              if (gymClassProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (filteredClasses.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE4EAF4)),
                  ),
                  child: Text(
                    showPast
                        ? 'No recent classes yet.'
                        : 'No active classes are scheduled yet.',
                    style: const TextStyle(
                      color: Color(0xFF5D6470),
                      height: 1.4,
                    ),
                  ),
                )
              else
                Column(
                  children: filteredClasses
                      .map(
                        (gymClass) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildClassCard(gymClass),
                        ),
                      )
                      .toList(),
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
          Text(
            '${gymClass.filled}/${gymClass.capacity} seats filled',
            style: const TextStyle(
              color: Color(0xFF5D6470),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
