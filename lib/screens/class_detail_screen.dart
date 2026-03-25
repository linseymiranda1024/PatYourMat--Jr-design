import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db_helpers/db_gym_class.dart';
import '../main.dart';
import '../models/gym_class.dart';
import '../providers/provider_reservations.dart';
import 'mat_selection_screen.dart';
import 'reservation_confirmation_screen.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  static const String routeName = '/class_detail';
  final GymClass gymClass;

  const ClassDetailScreen({super.key, required this.gymClass});

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _isLoading = false;

  Future<void> _registerForClass(GymClass gClass) async {
    setState(() => _isLoading = true);

    try {
      final matNumber = await ref
          .read(reservationsProvider)
          .registerForClass(gClass);

      if (matNumber != null) {
        ref.read(providerGymClass).applyLocalRegistrationDelta(gClass.id, 1);
        if (mounted) {
          context.pushNamed(
            ReservationConfirmationScreen.routeName,
            extra: {
              'className': gClass.title,
              'instructor': gClass.instructor,
              'dateTime': '${gClass.dateText} at ${gClass.timeText}',
              'matNumber': matNumber,
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        var message = e.toString();
        if (message.startsWith('Exception: ')) {
          message = message.replaceFirst('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $message')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GymClass?>(
      stream: DBGymClass.getClassStream(widget.gymClass.id),
      initialData: widget.gymClass,
      builder: (context, snapshot) {
        final gClass = snapshot.data ?? widget.gymClass;

        final reservations = ref.watch(reservationsProvider).reservations;
        final isRegistered = reservations.any((r) => r.id == gClass.id);

        final spotsLeft = gClass.capacity - gClass.filled;
        final progress = gClass.capacity == 0
            ? 0.0
            : (gClass.filled / gClass.capacity).clamp(0.0, 1.0);

        return Scaffold(
          body: Stack(
            children: [
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
                          Expanded(
                            child: Text(
                              gClass.title,
                              style: const TextStyle(
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
                              const Text(
                                'Class Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isRegistered
                                        ? 'You are registered'
                                        : '$spotsLeft Spots Left',
                                    style: const TextStyle(
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
                                      color: isRegistered
                                          ? Colors.blue.shade50
                                          : (gClass.status == ClassStatus.open
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFBE2E2)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isRegistered
                                          ? 'REGISTERED'
                                          : gClass.status.name.toUpperCase(),
                                      style: TextStyle(
                                        color: isRegistered
                                            ? Colors.blue.shade700
                                            : (gClass.status == ClassStatus.open
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFB00020)),
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
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(
                                    gClass.status == ClassStatus.full
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${gClass.filled} / ${gClass.capacity} registered',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Class Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildInfoRow(
                                Icons.category_outlined,
                                'Type',
                                gClass.type,
                              ),
                              _buildInfoRow(
                                Icons.person_outline,
                                'Instructor',
                                gClass.instructor,
                              ),
                              _buildInfoRow(
                                Icons.calendar_today_outlined,
                                'Date & Time',
                                '${gClass.dateText} at ${gClass.timeText}',
                              ),
                              _buildInfoRow(
                                Icons.timer_outlined,
                                'Duration',
                                gClass.durationText,
                              ),
                              _buildInfoRow(
                                Icons.location_on_outlined,
                                'Location',
                                gClass.location,
                              ),
                              _buildInfoRow(
                                Icons.group_outlined,
                                'Capacity',
                                '${gClass.capacity} mats',
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'About This Class',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                gClass.description.isEmpty
                                    ? 'Class details will be added soon.'
                                    : gClass.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 48),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed:
                                      (_isLoading ||
                                          isRegistered ||
                                          gClass.status != ClassStatus.open)
                                      ? null
                                      : () => _registerForClass(gClass),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6200EE),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Text(
                                          isRegistered
                                              ? 'Registered'
                                              : 'Reserve Your Spot',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.push(
                                      MatSelectionScreen.routeName,
                                      extra: gClass,
                                    );
                                  },
                                  icon: const Icon(Icons.grid_view_rounded),
                                  label: const Text('Choose Your Mat'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF6200EE),
                                    side: const BorderSide(
                                      color: Color(0xFF6200EE),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
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
      },
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
