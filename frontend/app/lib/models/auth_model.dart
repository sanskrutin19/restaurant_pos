import 'dart:convert';

class AuthUser {
  final String token;
  final String role;
  final String? username;
  final int? id;

  AuthUser({
    required this.token,
    required this.role,
    this.username,
    this.id,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String;
    // Decode JWT payload to get role, username, and id
    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
    );
    final role = payload['role'] as String? ?? 'cashier';
    final username = payload['sub'] as String?;
    final id = payload['user_id'] as int?;
    
    return AuthUser(
      token: token,
      role: role,
      username: username,
      id: id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': token,
      'role': role,
      'username': username,
      'id': id,
    };
  }
}