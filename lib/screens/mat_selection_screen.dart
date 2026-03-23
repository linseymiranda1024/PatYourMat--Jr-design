// lib/screens/mat_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/provider_reservations.dart';
import 'reservation_confirmation_screen.dart';

class MatSelectionScreen extends ConsumerStatefulWidget {
  static const String routeName = 'mat_selection';

  // These come from the 'extra' map passed in ClassDetailScreen
  final String className;
  final String time;

  const MatSelectionScreen({
    super.key,
    required this.className,
    required this.time,
  });

  @override
  ConsumerState<MatSelectionScreen> createState() => _MatSelectionScreenState();
}

class _MatSelectionScreenState extends ConsumerState<MatSelectionScreen> {
  int? selectedMat;
  bool _isSubmitting = false;

  // Mocking 20 mats for the grid
  final List<int> availableMats = List.generate(20, (index) => index + 1);
  // Simulating some already taken mats
  final List<int> takenMats = [3, 7, 12, 18];

  Future<void> _confirmSpot() async {
    if (selectedMat == null) return;

    setState(() => _isSubmitting = true);

    try {
      // In a real app, you'd call a method to reserve this SPECIFIC mat
      // For now, we'll simulate the successful booking
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        context.pushNamed(
          ReservationConfirmationScreen.routeName,
          extra: {
            'className': widget.className,
            'instructor': 'TBD', // You could pass this from details too
            'dateTime': widget.time,
            'matNumber': selectedMat,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Your Spot'),
        backgroundColor: const Color(0xFF8A2BFF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Text(
                  widget.className,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(widget.time, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),

          // Front of Class Indicator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "FRONT OF CLASS / INSTRUCTOR",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
              ),
              itemCount: availableMats.length,
              itemBuilder: (context, index) {
                final matNum = availableMats[index];
                final isTaken = takenMats.contains(matNum);
                final isSelected = selectedMat == matNum;

                return GestureDetector(
                  onTap: isTaken
                      ? null
                      : () => setState(() => selectedMat = matNum),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isTaken
                          ? Colors.grey[300]
                          : (isSelected
                                ? const Color(0xFF8A2BFF)
                                : Colors.white),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8A2BFF)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        "$matNum",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isTaken ? Colors.grey : Colors.black),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Legend and Confirm Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(Colors.white, "Available"),
                    const SizedBox(width: 15),
                    _buildLegendItem(const Color(0xFF8A2BFF), "Selected"),
                    const SizedBox(width: 15),
                    _buildLegendItem(Colors.grey[300]!, "Taken"),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (selectedMat == null || _isSubmitting)
                        ? null
                        : _confirmSpot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Confirm Spot",
                            style: TextStyle(fontSize: 18, color: Colors.white),
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
