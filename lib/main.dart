import 'package:flutter/material.dart';
import 'app_shell.dart';

void main() {
  runApp(const PatYourMatApp());
}

class PatYourMatApp extends StatelessWidget {
  const PatYourMatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pat Your Mat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A2CFF)),
        fontFamily: null, // add your custom font later if you want
      ),
      home: const AppShell(),
    );
  }
}
