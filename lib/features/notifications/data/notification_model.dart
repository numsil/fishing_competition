class AppNotification {
  final String id;
  final String type; // dm | comment | follow
  final String actorId;
  final String? targetId;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String actorUsername;
  final String? actorAvatarUrl;

  AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.targetId,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.actorUsername,
    required this.actorAvatarUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      actorId: json['actor_id'] as String,
      targetId: json['target_id'] as String?,
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      actorUsername: actor?['username'] as String? ?? '알 수 없음',
      actorAvatarUrl: actor?['avatar_url'] as String?,
    );
  }
}
