class BleTokenSlot {
  const BleTokenSlot({
    required this.token,
    required this.validFrom,
    required this.validUntil,
  });

  factory BleTokenSlot.fromJson(Map<String, dynamic> json) => BleTokenSlot(
        token: json['token'] as String,
        validFrom: DateTime.parse(json['valid_from'] as String).toUtc(),
        validUntil: DateTime.parse(json['valid_until'] as String).toUtc(),
      );

  final String token;
  final DateTime validFrom;
  final DateTime validUntil;
}

class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.sessionCode,
    required this.subject,
    required this.startedAt,
    required this.expiresAt,
    required this.status,
    required this.presentCount,
    this.tokenSchedule = const [],
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) => AttendanceSession(
        id: json['id'] as String,
        sessionCode: json['session_code'] as String,
        subject: json['subject'] as String,
        startedAt: DateTime.parse(json['started_at'] as String).toUtc(),
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        status: json['status'] as String,
        presentCount: json['present_count'] as int? ?? 0,
        tokenSchedule: (json['token_schedule'] as List<dynamic>? ?? const [])
            .map((item) => BleTokenSlot.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String sessionCode;
  final String subject;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String status;
  final int presentCount;
  final List<BleTokenSlot> tokenSchedule;

  AttendanceSession copyWith({String? status, int? presentCount}) => AttendanceSession(
        id: id,
        sessionCode: sessionCode,
        subject: subject,
        startedAt: startedAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        presentCount: presentCount ?? this.presentCount,
        tokenSchedule: tokenSchedule,
      );
}

class NearbySession {
  const NearbySession({
    required this.session,
    required this.bleToken,
    required this.rssi,
  });

  final AttendanceSession session;
  final String bleToken;
  final int rssi;

  String get signalLabel {
    if (rssi >= -60) return 'Excellent';
    if (rssi >= -75) return 'Good';
    return 'Weak';
  }
}
