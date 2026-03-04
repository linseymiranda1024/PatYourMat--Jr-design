// lib/screens/reservation_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/navigation/widget_app_outline.dart';

class ReservationConfirmationScreen extends StatelessWidget {
  static const String routeName = '/reservation_confirmed';

  final String className;
  final String instructor;
  final String dateTime;
  final String matNumber;

  const ReservationConfirmationScreen({
    super.key,
    required this.className,
    required this.instructor,
    required this.dateTime,
    required this.matNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              context.pop(), // Pops back to previous screen (Class Detail)
        ),
        title: const Text("Reservation Confirmed"),
        backgroundColor: const Color(0xFF4CAF50), // Matches the success green
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Green success header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: const [
                Icon(Icons.check_circle, size: 80, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  "You're All Set!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Your mat spot has been reserved",
                  style: TextStyle(fontSize: 16, color: Colors.white70),
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
                  // Reservation Details
                  const Text(
                    "Reservation Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    icon: Icons.event,
                    label: "Class Name",
                    value: className,
                  ),
                  _DetailRow(
                    icon: Icons.access_time,
                    label: "Date & Time",
                    value: dateTime,
                  ),
                  _DetailRow(
                    icon: Icons.place,
                    label: "Your Mat Location",
                    value: matNumber,
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.qr_code_2,
                            size: 140,
                            color: Colors.deepPurple,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "Show this QR code at check-in",
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Important Reminders
                  const Text(
                    "Important Reminders",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• Arrive at least 5 minutes early to check in"),
                          SizedBox(height: 8),
                          Text("• Bring your student ID and water bottle"),
                          SizedBox(height: 8),
                          Text(
                            "• Cancel at least 2 hours in advance to avoid penalty",
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text("Add to Calendar"),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text("Share"),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // View My Reservations button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6200EE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        context.go(
                          '${WidgetAppOutline.routeName}?tab=4',
                        ); // Navigates to the Profile tab in the main shell
                      },
                      child: const Text(
                        "View My Reservations",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Back to Home / Schedule option
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(
                        Icons.home_outlined,
                        color: Color(0xFF6200EE),
                      ),
                      label: const Text(
                        "Back to Home",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6200EE),
                        ),
                      ),
                      onPressed: () {
                        context.go(
                          WidgetAppOutline.routeName,
                        ); // or HomeScreen.routeName if you prefer named route
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _DetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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
