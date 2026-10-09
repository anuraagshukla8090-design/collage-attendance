import 'package:ble_attendance/main.dart';
import 'package:ble_attendance/models/auth_session.dart';
import 'package:ble_attendance/screens/landing_screen.dart';
import 'package:ble_attendance/screens/login_screen.dart';
import 'package:ble_attendance/screens/pin_setup_screen.dart';
import 'package:ble_attendance/screens/student_home_screen.dart';
import 'package:ble_attendance/screens/teacher_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([roboto.load(), materialIcons.load()]);
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> renderScreen(
    WidgetTester tester,
    Widget screen,
    String filename,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BleAttendanceAppPreview(home: screen),
    );
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('previews/$filename'));
  }

  testWidgets('landing preview', (tester) async {
    await renderScreen(tester, const LandingScreen(), '01-landing.png');
  });

  testWidgets('teacher login preview', (tester) async {
    await renderScreen(
      tester,
      const LoginScreen(role: UserRole.teacher),
      '02-teacher-login.png',
    );
  });

  testWidgets('teacher dashboard preview', (tester) async {
    await renderScreen(
      tester,
      const TeacherDashboardScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.teacher,
          id: 1,
          name: 'Dr. Meera Kapoor',
        ),
      ),
      '03-teacher-dashboard.png',
    );
  });

  testWidgets('student pin setup preview', (tester) async {
    await renderScreen(
      tester,
      const PinSetupScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.student,
          id: 1,
          name: 'Rahul Sharma',
          studentCode: 'student001',
        ),
        deviceId: 'preview-device',
      ),
      '04-student-pin-setup.png',
    );
  });

  testWidgets('student dashboard preview', (tester) async {
    await renderScreen(
      tester,
      const StudentHomeScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.student,
          id: 1,
          name: 'Rahul Sharma',
          studentCode: 'student001',
          hasAttendancePin: true,
        ),
        deviceId: 'preview-device',
        autoScan: false,
      ),
      '05-student-dashboard.png',
    );
  });

  testWidgets('student attendance preview', (tester) async {
    await renderScreen(
      tester,
      const StudentHomeScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.student,
          id: 1,
          name: 'Rahul Sharma',
          studentCode: 'student001',
          hasAttendancePin: true,
        ),
        deviceId: 'preview-device',
        initialTab: 1,
        autoScan: false,
      ),
      '06-student-attendance.png',
    );
  });

  testWidgets('student timetable preview', (tester) async {
    await renderScreen(
      tester,
      const StudentHomeScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.student,
          id: 1,
          name: 'Rahul Sharma',
          studentCode: 'student001',
          hasAttendancePin: true,
        ),
        deviceId: 'preview-device',
        initialTab: 2,
        autoScan: false,
      ),
      '07-student-timetable.png',
    );
  });

  testWidgets('teacher attendance preview', (tester) async {
    await renderScreen(
      tester,
      const TeacherDashboardScreen(
        auth: AuthSession(
          token: 'preview',
          role: UserRole.teacher,
          id: 1,
          name: 'Dr. Meera Kapoor',
        ),
        initialTab: 1,
      ),
      '08-teacher-attendance.png',
    );
  });
}

class BleAttendanceAppPreview extends StatelessWidget {
  const BleAttendanceAppPreview({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final productionApp = const BleAttendanceApp().build(context) as MaterialApp;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: productionApp.theme,
      home: home,
    );
  }
}
