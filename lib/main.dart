// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_learn/screens/attendance_screen.dart';
import 'package:flutter_application_learn/screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/attendance': (context) => const AttendanceScreen(),
      },
    );
  }
}