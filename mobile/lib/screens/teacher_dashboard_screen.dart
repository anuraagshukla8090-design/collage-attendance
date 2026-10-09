import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/attendance_session.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../services/ble_service.dart';
import '../widgets/portal_widgets.dart';
import 'timetable_view.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key, required this.auth, this.initialTab = 0});
  final AuthSession auth;
  final int initialTab;

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final _api = ApiService();
  final _ble = BleService();
  AttendanceSession? _session;
  List<Map<String, dynamic>> _attendance = [];
  Timer? _timer;
  bool _loading = false;
  bool _polling = false;
  String? _error;
  int _tick = 0;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  Duration get _remaining {
    if (_session == null) return Duration.zero;
    final duration = _session!.expiresAt.difference(DateTime.now().toUtc());
    return duration.isNegative ? Duration.zero : duration;
  }

  bool get _active => _session?.status == 'ACTIVE' && _remaining > Duration.zero;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    AttendanceSession? created;
    try {
      created = await _api.startSession(widget.auth.token);
      await _ble.startAdvertising(created);
      if (!mounted) return;
      setState(() => _session = created);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _tick++);
        if (_remaining == Duration.zero) {
          _finishLocally('EXPIRED');
        } else if (_tick % 3 == 0) {
          _refreshAttendance();
        }
      });
    } catch (error) {
      if (created != null) await _api.stopSession(widget.auth.token, created.id).catchError((_) {});
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAttendance() async {
    if (_session == null || _polling) return;
    _polling = true;
    try {
      final rows = await _api.sessionAttendance(widget.auth.token, _session!.id);
      if (mounted) setState(() => _attendance = rows);
    } catch (_) {
      // A transient refresh failure should not interrupt the live session.
    } finally {
      _polling = false;
    }
  }

  Future<void> _stop() async {
    if (_session == null) return;
    setState(() => _loading = true);
    try {
      await _api.stopSession(widget.auth.token, _session!.id);
      await _finishLocally('STOPPED');
      await _refreshAttendance();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    if (error is BleException) return error.message;
    return 'Could not start attendance. Check Bluetooth and your connection.';
  }

  Future<void> _finishLocally(String status) async {
    _timer?.cancel();
    await _ble.stopAdvertising().catchError((_) {});
    if (mounted && _session != null) setState(() => _session = _session!.copyWith(status: status));
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_active) _ble.stopAdvertising();
    super.dispose();
  }

  String _clock(Duration duration) {
    final seconds = duration.inSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Teacher Dashboard', 'Attendance', 'Timetable'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _dashboardView(context),
          _attendanceView(context),
          const TimetableView(teacherMode: true),
        ],
      ),
      bottomNavigationBar: PortalBottomBar(index: _tab, onChanged: (value) => setState(() => _tab = value)),
    );
  }

  Widget _dashboardView(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 110),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionEyebrow('Monday · 24 June'),
                    const SizedBox(height: 10),
                    Text('Good morning,\nDr. Meera.', style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppPalette.plum,
                foregroundColor: Colors.white,
                child: Text('MK', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppPalette.coral, borderRadius: BorderRadius.circular(26)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionEyebrow('This week'),
                      const SizedBox(height: 8),
                      Text('87%', style: Theme.of(context).textTheme.displaySmall),
                      const Text('Average attendance'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: _WeeklyBars()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              MetricTile(value: '4', label: 'Classes today', icon: Icons.class_outlined, highlight: true),
              SizedBox(width: 10),
              MetricTile(value: '126', label: 'Total students', icon: Icons.person_outline),
              SizedBox(width: 10),
              MetricTile(value: '18', label: 'Sessions this month', icon: Icons.sensors_outlined),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text('Next class', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('In 12 minutes', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _tab = 1),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: AppPalette.coralSoft, borderRadius: BorderRadius.circular(17)),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('09:00', style: TextStyle(fontWeight: FontWeight.w900)),
                          Text('AM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Machine Learning', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 5),
                          Text('Lab 3  ·  CSE AI/ML', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Dashboard figures and timetable are demo data for the MVP.', style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _attendanceView(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          Row(
            children: [
              Expanded(child: Text('Class attendance', style: Theme.of(context).textTheme.headlineMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(12)),
                child: const Text('MON · 24 JUN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: _ClassInfoCard(label: 'Course', value: 'CSE AI/ML', icon: Icons.class_outlined)),
              SizedBox(width: 11),
              Expanded(child: _ClassInfoCard(label: 'Subject', value: 'Machine Learning', icon: Icons.menu_book_outlined)),
            ],
          ),
          const SizedBox(height: 18),
          if (_session == null) _readyCard(context) else _sessionCard(context),
          if (_error != null) ...[
            const SizedBox(height: 13),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8DFD7), borderRadius: BorderRadius.circular(14)),
              child: Text(_error!, style: const TextStyle(color: AppPalette.error)),
            ),
          ],
          if (_attendance.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Live attendance', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('${_attendance.length} students', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: List.generate(_attendance.length, (index) {
                  final row = _attendance[index];
                  final name = row['student_name'] as String;
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppPalette.coralSoft,
                          foregroundColor: AppPalette.plum,
                          child: Text(name.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${row['student_code']}  ·  RSSI ${row['ble_rssi'] ?? '—'} dBm'),
                        trailing: const CircleAvatar(
                          radius: 17,
                          backgroundColor: AppPalette.plum,
                          child: Icon(Icons.check, color: Colors.white, size: 19),
                        ),
                      ),
                      if (index != _attendance.length - 1) const Divider(height: 1, indent: 72),
                    ],
                  );
                }),
              ),
            ),
          ],
        ],
      );

  Widget _readyCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppPalette.coral, borderRadius: BorderRadius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: SoftIconBox(Icons.sensors)),
            const SizedBox(height: 32),
            Text('Ready for class', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            const Text('A 90-second BLE broadcast begins only after the server creates the session.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _start,
              icon: const Icon(Icons.sensors),
              label: Text(_loading ? 'STARTING…' : 'START ATTENDANCE'),
            ),
          ],
        ),
      );

  Widget _sessionCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: AppPalette.coral, borderRadius: BorderRadius.circular(26)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(_session!.subject, style: Theme.of(context).textTheme.titleLarge)),
                const SoftIconBox(Icons.sensors, size: 48),
              ],
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: AppPalette.peach, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _active ? 'ATTENDANCE ACTIVE' : 'ATTENDANCE CLOSED',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(_clock(_remaining), textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 56)),
            const Text('remaining', textAlign: TextAlign.center),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 10),
                  const Text('Students Present', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${_attendance.length}', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const SizedBox(height: 13),
            if (_active)
              OutlinedButton(
                onPressed: _loading ? null : _stop,
                style: OutlinedButton.styleFrom(backgroundColor: AppPalette.surface, side: BorderSide.none),
                child: const Text('STOP ATTENDANCE', style: TextStyle(color: AppPalette.error)),
              )
            else
              FilledButton(
                onPressed: () => setState(() {
                  _session = null;
                  _attendance = [];
                }),
                child: const Text('START ANOTHER SESSION'),
              ),
          ],
        ),
      );
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars();

  @override
  Widget build(BuildContext context) {
    const heights = [48.0, 72.0, 58.0, 78.0, 82.0];
    const days = ['M', 'T', 'W', 'T', 'F'];
    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(5, (index) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                height: heights[index],
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == 4 ? AppPalette.plum : AppPalette.plum.withValues(alpha: .35 + index * .1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                ),
              ),
              const SizedBox(height: 5),
              Text(days[index], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
            ],
          ),
        )),
      ),
    );
  }
}

class _ClassInfoCard extends StatelessWidget {
  const _ClassInfoCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: SectionEyebrow(label)),
                  SoftIconBox(icon, size: 36),
                ],
              ),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
}
