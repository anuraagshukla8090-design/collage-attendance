import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/attendance_session.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../widgets/portal_widgets.dart';
import 'timetable_view.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({
    super.key,
    required this.auth,
    required this.deviceId,
    this.initialTab = 0,
    this.autoScan = true,
  });

  final AuthSession auth;
  final String deviceId;
  final int initialTab;
  final bool autoScan;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _api = ApiService();
  final _ble = BleService();
  late int _selectedTab;
  NearbySession? _nearby;
  bool _scanning = false;
  bool _submitting = false;
  DateTime? _markedAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2);
    if (_selectedTab == 1 && widget.autoScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  String _friendlyError(Object error) {
    final value = error is ApiException ? error.code : error.toString().replaceFirst('Exception: ', '');
    const messages = {
      'SESSION_EXPIRED': 'Attendance closed — the 90-second session has ended.',
      'SESSION_NOT_ACTIVE': 'Attendance closed by your teacher.',
      'DEVICE_NOT_REGISTERED': 'This account has no registered phone.',
      'DEVICE_MISMATCH': 'Device mismatch — use the phone registered to this account.',
      'INVALID_PIN': 'That attendance PIN is not correct.',
      'BLE_TOKEN_INVALID': 'The nearby signal changed. Scan again and retry.',
      'ALREADY_MARKED': 'Already marked for this class.',
    };
    if (messages[value] case final message?) return message;
    if (error is ApiException) return error.message;
    return value;
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _nearby = null;
      _error = null;
    });
    try {
      final result = await _ble.scan(duration: const Duration(seconds: 4));
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = 'No active class found nearby. Stay close to your teacher and scan again.');
        return;
      }
      final session = await _api.resolveSession(widget.auth.token, result.sessionCode);
      if (!mounted) return;
      setState(() {
        _nearby = NearbySession(session: session, bleToken: result.token, rssi: result.rssi);
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _markAttendance() async {
    final nearby = _nearby;
    if (nearby == null || _submitting) return;
    final pin = await _requestPin();
    if (pin == null || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final fresh = await _ble.scan(duration: const Duration(seconds: 3));
      if (fresh == null || fresh.sessionCode != nearby.session.sessionCode) {
        throw const BleException('The teacher signal was lost. Stay nearby and scan again.');
      }
      await _api.markAttendance(
        token: widget.auth.token,
        deviceId: widget.deviceId,
        sessionId: nearby.session.id,
        bleToken: fresh.token,
        rssi: fresh.rssi,
        pin: pin,
      );
      if (mounted) setState(() => _markedAt = DateTime.now());
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _requestPin() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Enter Attendance PIN',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Confirm it is really you marking attendance.',
              style: TextStyle(color: AppPalette.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                letterSpacing: 12,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(hintText: '••••••', counterText: ''),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('CONFIRM ATTENDANCE'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _selectTab(int value) {
    setState(() {
      _selectedTab = value;
      _error = null;
    });
    if (value == 1 &&
        widget.autoScan &&
        _nearby == null &&
        _markedAt == null &&
        !_scanning) {
      _scan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Student Dashboard', 'Attendance', 'Timetable'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedTab]),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _selectedTab,
          children: [
            _StudentDashboard(
              student: widget.auth,
              onOpenAttendance: () => _selectTab(1),
            ),
            _buildAttendance(),
            const TimetableView(teacherMode: false),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: PortalBottomBar(index: _selectedTab, onChanged: _selectTab),
      ),
    );
  }

  Widget _buildAttendance() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        ProfileStrip(
          initials: _initials(widget.auth.name),
          name: widget.auth.name,
          subtitle: 'Student ID · ${widget.auth.studentCode}',
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _markedAt != null
              ? _successCard()
              : _nearby != null
                  ? _detectedCard(_nearby!)
                  : _scanningCard(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.error.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppPalette.error),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(18)),
          child: const Row(
            children: [
              Icon(Icons.bluetooth_rounded, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listening only', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text(
                      'This phone will not pair or connect.',
                      style: TextStyle(color: AppPalette.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scanningCard() {
    return Container(
      key: const ValueKey('scanning'),
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(99)),
            child: Text(
              _scanning ? '•  SCANNING NEARBY' : 'READY TO SCAN',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 30),
          _BluetoothPulse(active: _scanning),
          const SizedBox(height: 30),
          Text(
            _scanning ? 'Searching for active class…' : 'Find your active class',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Stay near your teacher for a few seconds.',
            style: TextStyle(color: AppPalette.muted),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(_scanning ? 'Scanning…' : 'Scan again'),
          ),
        ],
      ),
    );
  }

  Widget _detectedCard(NearbySession nearby) {
    final signal = nearby.rssi >= -55
        ? 'Excellent'
        : nearby.rssi >= -70
            ? 'Good'
            : 'Weak';
    return Container(
      key: const ValueKey('detected'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppPalette.coral, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionEyebrow('ACTIVE CLASS FOUND'),
              const SoftIconBox(Icons.bluetooth_connected_rounded),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Machine Learning', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppPalette.success, size: 20),
              SizedBox(width: 8),
              Text('Teacher detected nearby', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppPalette.surface.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.signal_cellular_alt_rounded, size: 20),
                const SizedBox(width: 10),
                Text('Signal: $signal'),
                const Spacer(),
                Text('${nearby.rssi} dBm', style: const TextStyle(color: AppPalette.muted)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _submitting ? null : _markAttendance,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.how_to_reg_rounded),
            label: Text(_submitting ? 'VERIFYING…' : 'MARK ATTENDANCE'),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }

  Widget _successCard() {
    return Container(
      key: const ValueKey('success'),
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.success.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: AppPalette.success, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
          ),
          const SizedBox(height: 20),
          const Text('Attendance Marked', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Machine Learning', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_markedAt!)),
            style: const TextStyle(color: AppPalette.muted),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((part) => part.isEmpty ? '' : part[0]).join().toUpperCase();
  }
}

class _StudentDashboard extends StatelessWidget {
  const _StudentDashboard({required this.student, required this.onOpenAttendance});

  final AuthSession student;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final initials = student.name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0])
        .join()
        .toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        ProfileStrip(
          initials: initials,
          name: student.name,
          subtitle: 'Student ID · ${student.studentCode}',
        ),
        const SizedBox(height: 30),
        const SectionEyebrow('YOUR SEMESTER'),
        const SizedBox(height: 8),
        const Text('Attendance overview', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        const Text("You're on track across all enrolled subjects.", style: TextStyle(color: AppPalette.muted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: AppPalette.coral, borderRadius: BorderRadius.circular(26)),
          child: Row(
            children: [
              SizedBox(
                width: 94,
                height: 94,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: .86,
                        strokeWidth: 8,
                        backgroundColor: AppPalette.plum.withValues(alpha: .16),
                        valueColor: const AlwaysStoppedAnimation(AppPalette.plum),
                      ),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('86%', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                        Text('Overall', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionEyebrow('GOOD STANDING'),
                    SizedBox(height: 8),
                    Text('Keep it up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text(
                      'You are 11% above the minimum attendance requirement.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            MetricTile(value: '48', label: 'Classes attended'),
            SizedBox(width: 8),
            MetricTile(value: '8', label: 'Classes missed'),
            SizedBox(width: 8),
            MetricTile(value: '3', label: 'Classes today'),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppPalette.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('By subject', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('Semester 5', style: TextStyle(color: AppPalette.muted, fontSize: 12)),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Machine Learning', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('92%', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: .92,
                minHeight: 6,
                borderRadius: BorderRadius.all(Radius.circular(99)),
                color: AppPalette.plum,
                backgroundColor: AppPalette.peach,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onOpenAttendance,
          icon: const Icon(Icons.sensors_rounded),
          label: const Text('FIND ACTIVE CLASS'),
        ),
      ],
    );
  }
}

class _BluetoothPulse extends StatelessWidget {
  const _BluetoothPulse({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.coral.withValues(alpha: active ? .55 : .28)),
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.coral.withValues(alpha: active ? .8 : .4)),
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: AppPalette.plum, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 34),
          ),
        ],
      ),
    );
  }
}
