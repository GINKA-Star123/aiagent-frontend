class UserIdentity {
  const UserIdentity({
    required this.userId,
    required this.username,
    required this.deviceId,
    required this.createdAt,
    this.email = '',
    this.accessToken = '',
    this.refreshToken = '',
  });

  final String userId;
  final String username;
  final String deviceId;
  final DateTime createdAt;
  final String email;
  final String accessToken;
  final String refreshToken;

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? 'guest',
      deviceId: json['deviceId']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      email: json['email']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
      'email': email,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }

  UserIdentity copyWith({
    String? userId,
    String? username,
    String? deviceId,
    DateTime? createdAt,
    String? email,
    String? accessToken,
    String? refreshToken,
  }) {
    return UserIdentity(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}
