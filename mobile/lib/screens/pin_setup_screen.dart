import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../widgets/portal_widgets.dart';
import 'student_home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.auth, required this.deviceId});
  final AuthSession auth;
  final String deviceId;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _api = ApiService();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _save() async {
    if ((_pin.text.length != 4 && _pin.text.length != 6) || _pin.text != _confirm.text) {
      setState(() => _error = 'Use 4 or 6 digits and make sure both entries match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.setPin(widget.auth.token, widget.deviceId, _pin.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => StudentHomeScreen(auth: widget.auth, deviceId: widget.deviceId)),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Secure your attendance')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SectionEyebrow('Step 1 of 1')),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(color: AppPalette.peach, shape: BoxShape.circle),
                  child: const Icon(Icons.phonelink_lock_outlined, size: 44, color: AppPalette.plum),
                ),
              ),
              const SizedBox(height: 26),
              Text('Create an attendance PIN', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'This phone is now registered to your student account. Choose a private 4 or 6 digit PIN.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppPalette.muted),
              ),
              const SizedBox(height: 28),
              Text('New PIN', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: _obscure,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Confirm PIN', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _confirm,
                keyboardType: TextInputType.number,
                obscureText: _obscure,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: '', suffixIcon: Icon(Icons.visibility_outlined)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppPalette.error)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save PIN'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 19, color: AppPalette.plum),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Installation binding', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            'For this MVP, your account is bound to this app installation. It is not a hardware-level device identity.',
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
      );
}
