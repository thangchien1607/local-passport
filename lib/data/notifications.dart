// Thông báo trong app: lưu cùng hộ chiếu (cục bộ và
// `user_passports/{uid}/notifications/{id}` trên Firestore).

enum NotificationType { welcome, stamp, reflection, rank, account }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.locationId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Địa điểm liên quan, để bấm vào thì mở trang địa điểm.
  final String? locationId;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    read: read ?? this.read,
    locationId: locationId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'locationId': locationId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    type:
        NotificationType.values.asNameMap()[j['type']] ??
        NotificationType.account,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    createdAt: DateTime.parse(j['createdAt'] as String),
    read: j['read'] as bool? ?? false,
    locationId: j['locationId'] as String?,
  );
}
