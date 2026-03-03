// lib/screens/mat_selection_screen.dart
import 'package:flutter/material.dart';

class MatSelectionScreen extends StatelessWidget {
  static const String routeName = '/mat_selection';

  const MatSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Mat'),
        backgroundColor: const Color(0xFF8A2BFF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF5F5FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Power Yoga • 6:00 AM',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6200EE),
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _LegendDot(color: Colors.green, label: 'Available'),
                    SizedBox(width: 16),
                    _LegendDot(color: Colors.purple, label: 'Selected'),
                    SizedBox(width: 16),
                    _LegendDot(color: Colors.grey, label: 'Reserved'),
                  ],
                ),
              ],
            ),
          ),

          // Instructor row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFFEDE7FF),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, color: Color(0xFF6200EE)),
                  SizedBox(width: 8),
                  Text(
                    'INSTRUCTOR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6200EE),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Mat grid (placeholder – 5×6 = 30 mats)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: 30,
                itemBuilder: (context, index) {
                  // For now: alternating states as placeholder
                  final isInstructor = index == 0; // top-left = instructor
                  final isReserved = index % 7 == 3 || index % 7 == 5;
                  final isAvailable = !isReserved && !isInstructor;

                  Color color;
                  if (isInstructor) {
                    color = const Color(0xFF6200EE).withOpacity(0.3);
                  } else if (isReserved) {
                    color = Colors.grey.shade400;
                  } else {
                    color = Colors.green.shade300;
                  }

                  return GestureDetector(
                    onTap: isAvailable
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Mat ${index + 1} selected!'),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isInstructor
                              ? const Color(0xFF6200EE)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isInstructor ? 'Instructor' : '${index + 1}',
                          style: TextStyle(
                            color: isInstructor || isReserved
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: isInstructor ? 11 : 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Bottom button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Confirm reservation, save selection, etc.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reservation confirmed!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Go back twice or to home
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6200EE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue & Confirm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
