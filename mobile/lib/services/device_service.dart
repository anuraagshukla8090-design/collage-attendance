import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceService {
  static const _key = 'attendance_device_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-'
        '${(8 + random.nextInt(4)).toRadixString(16)}${hex.substring(17, 20)}-${hex.substring(20)}';
    await _storage.write(key: _key, value: id);
    // TODO(production): replace this installation UUID with an Android
    // Keystore key pair, signed server challenges, and Play Integrity checks.
    return id;
  }
}
