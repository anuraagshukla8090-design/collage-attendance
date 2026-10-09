enum UserRole { teacher, student }

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.id,
    required this.name,
    this.studentCode,
    this.hasAttendancePin = false,
  });

  final String token;
  final UserRole role;
  final int id;
  final String name;
  final String? studentCode;
  final bool hasAttendancePin;
}
