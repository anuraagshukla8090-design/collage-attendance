import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/auth_session.dart';
import '../widgets/brand_header.dart';
import '../widgets/portal_widgets.dart';
import 'login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openLogin(BuildContext context, UserRole role) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginScreen(role: role)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 18),
                      const Divider(),
                      const Spacer(),
                      const Center(child: SectionEyebrow('Smart campus attendance')),
                      const SizedBox(height: 14),
                      Text(
                        'Attendance using\nonly phones.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 38),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Teachers broadcast a short-range signal. Students simply listen and mark their presence.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppPalette.muted),
                      ),
                      const SizedBox(height: 28),
                      const _PhoneBroadcastGraphic(),
                      const SizedBox(height: 18),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TrustPoint('No hardware'),
                          SizedBox(width: 22),
                          _TrustPoint('No pairing'),
                        ],
                      ),
                      const Spacer(),
                      const SectionEyebrow('Continue as'),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () => _openLogin(context, UserRole.teacher),
                        child: const Text('Teacher Login'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _openLogin(context, UserRole.student),
                        child: const Text('Student Login'),
                      ),
                      const SizedBox(height: 17),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined, size: 17, color: AppPalette.muted),
                          SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              'Private, PIN-protected, and proximity based',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppPalette.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _PhoneBroadcastGraphic extends StatelessWidget {
  const _PhoneBroadcastGraphic();

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppPalette.border))),
            Container(width: 98, height: 98, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppPalette.coralSoft, width: 2))),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(color: AppPalette.plum, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.bluetooth, color: Colors.white, size: 34),
            ),
            const Positioned(left: 42, bottom: 7, child: SoftIconBox(Icons.phone_android, size: 38)),
            const Positioned(right: 42, top: 6, child: SoftIconBox(Icons.phone_android, size: 38)),
          ],
        ),
      );
}

class _TrustPoint extends StatelessWidget {
  const _TrustPoint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: AppPalette.plum, size: 17),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      );
}
