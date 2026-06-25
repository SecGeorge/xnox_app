import 'package:flutter/material.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XNOX-SOFT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A2B4C)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
