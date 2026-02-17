import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart'; // Make sure this path matches your folder structure

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pat Your Mat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),

        // Student Home - temporary placeholder
        '/home': (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Student Home'),
            backgroundColor: Colors.green[700],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Student Home Screen',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Class list and reservations coming soon\n(after merge)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),

        // Staff/Admin Dashboard - temporary placeholder
        '/admin': (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Staff Dashboard'),
            backgroundColor: Colors.blue[700],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.dashboard, size: 100, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Staff/Admin Dashboard',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Attendance tracking and class management\ncoming soon (after team merge)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
