import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/landing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BleAttendanceApp());
}

class BleAttendanceApp extends StatelessWidget {
  const BleAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Attendance',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LandingScreen(),
    );
  }
}
