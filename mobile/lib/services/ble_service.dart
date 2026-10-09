import 'dart:async';

import 'package:flutter/services.dart';

import '../models/attendance_session.dart';

class BleException implements Exception {
  const BleException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BleScanResult {
  const BleScanResult({required this.sessionCode, required this.token, required this.rssi});
  final String sessionCode;
  final String token;
  final int rssi;
}

class BleService {
  static const _channel = MethodChannel('com.demo.ble_attendance/ble');
  Timer? _rotationTimer;
  String? _advertisedToken;
  bool _changingAdvertisement = false;

  Future<void> requestPermissions(String mode) async {
    try {
      await _channel.invokeMethod<void>('requestPermissions', {'mode': mode});
    } on PlatformException catch (error) {
      throw BleException(error.message ?? 'Bluetooth permission is required.');
    }
  }

  Future<void> startAdvertising(AttendanceSession session) async {
    await requestPermissions('advertise');
    _rotationTimer?.cancel();
    await _advertiseCurrent(session);
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _advertiseCurrent(session).catchError((_) {});
    });
  }

  Future<void> _advertiseCurrent(AttendanceSession session) async {
    final now = DateTime.now().toUtc();
    BleTokenSlot? current;
    for (final slot in session.tokenSchedule) {
      if (!now.isBefore(slot.validFrom) && now.isBefore(slot.validUntil)) {
        current = slot;
        break;
      }
    }
    if (current == null || current.token == _advertisedToken || _changingAdvertisement) return;
    _changingAdvertisement = true;
    try {
      await _channel.invokeMethod<void>('startAdvertising', {
        'sessionCode': session.sessionCode,
        'token': current.token,
      });
      _advertisedToken = current.token;
    } on PlatformException catch (error) {
      throw BleException(error.message ?? 'This phone could not start BLE advertising.');
    } finally {
      _changingAdvertisement = false;
    }
  }

  Future<void> stopAdvertising() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _advertisedToken = null;
    _changingAdvertisement = false;
    await _channel.invokeMethod<void>('stopAdvertising');
  }

  Future<BleScanResult?> scan({Duration duration = const Duration(seconds: 5)}) async {
    await requestPermissions('scan');
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('scan', {
        'timeoutMs': duration.inMilliseconds,
      });
      if (raw == null) return null;
      return BleScanResult(
        sessionCode: raw['sessionCode'] as String,
        token: raw['token'] as String,
        rssi: raw['rssi'] as int,
      );
    } on PlatformException catch (error) {
      throw BleException(error.message ?? 'Bluetooth scan failed.');
    }
  }
}
