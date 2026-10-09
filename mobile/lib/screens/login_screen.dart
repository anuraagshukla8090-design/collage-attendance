import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../widgets/brand_header.dart';
import '../widgets/portal_widgets.dart';
import 'pin_setup_screen.dart';
import 'student_home_screen.dart';
import 'teacher_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});
  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  final _deviceService = DeviceService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  bool get _teacher => widget.role == UserRole.teacher;

  @override
  void initState() {
    super.initState();
    _identityController.text = _teacher ? 'teacher@demo.com' : 'student001';
    _passwordController.text = _teacher ? 'teacher123' : 'student123';
  }

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_teacher) {
        final auth = await _api.teacherLogin(_identityController.text.trim(), _passwordController.text);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => TeacherDashboardScreen(auth: auth)));
      } else {
        final auth = await _api.studentLogin(_identityController.text.trim(), _passwordController.text);
        final deviceId = await _deviceService.getOrCreateDeviceId();
        await _api.registerDevice(auth.token, deviceId);
        if (!mounted) return;
        final next = auth.hasAttendancePin
            ? StudentHomeScreen(auth: auth, deviceId: deviceId)
            : PinSetupScreen(auth: auth, deviceId: deviceId);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const SizedBox.shrink()),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(compact: true),
                  const SizedBox(height: 42),
                  SectionEyebrow(_teacher ? 'Teacher portal' : 'Student portal'),
                  const SizedBox(height: 9),
                  Text(_teacher ? 'Teacher Login' : 'Student Login', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    _teacher ? 'Start and monitor your classroom sessions.' : 'Listen for your class and mark attendance.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
                  ),
                  const SizedBox(height: 26),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_teacher ? 'Email' : 'Student ID', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _identityController,
                            decoration: InputDecoration(hintText: _teacher ? 'teacher@demo.com' : 'student001'),
                            validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          Text('Password', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 13),
                            Text(_error!, style: const TextStyle(color: AppPalette.error)),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 20, color: AppPalette.plum),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Demo credentials', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(
                                _teacher ? 'teacher@demo.com  ·  teacher123' : 'student001  ·  student123',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
