// Dữ liệu mẫu cho Bảng tin cộng đồng và Bảng xếp hạng.

const anonymousAuthor = 'Một Lữ khách Ẩn danh';

class Reflection {
  const Reflection({
    required this.id,
    required this.locationId,
    required this.displayAuthor,
    required this.isAnonymous,
    required this.content,
    required this.aiScore,
    required this.createdAt,
    this.photoUrl,
    this.photoBase64,
  });

  final String id;
  final String locationId;
  final String displayAuthor;
  final bool isAnonymous;
  final String content;
  final int aiScore;
  final DateTime createdAt;

  /// URL ảnh trên Firebase Storage (chuẩn mới).
  final String? photoUrl;

  /// Ảnh base64 cũ — chỉ giữ để đọc tương thích ngược, không ghi mới lên Firestore.
  final String? photoBase64;

  bool get hasPhoto =>
      (photoUrl != null && photoUrl!.isNotEmpty) ||
      (photoBase64 != null && photoBase64!.isNotEmpty);

  Reflection copyWith({
    String? displayAuthor,
    bool? isAnonymous,
    String? content,
    int? aiScore,
    String? photoUrl,
    bool clearPhoto = false,
  }) => Reflection(
    id: id,
    locationId: locationId,
    displayAuthor: displayAuthor ?? this.displayAuthor,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    content: content ?? this.content,
    aiScore: aiScore ?? this.aiScore,
    createdAt: createdAt,
    photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
    photoBase64: clearPhoto ? null : photoBase64,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'locationId': locationId,
    'displayAuthor': displayAuthor,
    'isAnonymous': isAnonymous,
    'content': content,
    'aiScore': aiScore,
    'createdAt': createdAt.toIso8601String(),
    'photoUrl': photoUrl,
    if (photoBase64 != null) 'photoBase64': photoBase64,
  };

  factory Reflection.fromJson(Map<String, dynamic> j) => Reflection(
    id: j['id'] as String,
    locationId: j['locationId'] as String,
    displayAuthor: j['displayAuthor'] as String,
    isAnonymous: j['isAnonymous'] as bool,
    content: j['content'] as String,
    aiScore: (j['aiScore'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(j['createdAt'] as String),
    photoUrl: j['photoUrl'] as String?,
    photoBase64: j['photoBase64'] as String?,
  );
}

final seedReflections = <Reflection>[
  Reflection(
    id: 's1',
    locationId: 'dien-hai',
    displayAuthor: 'Minh Anh',
    isAnonymous: false,
    content:
        'Đứng trên tường thành mới thấy vị trí này nhìn thẳng ra cửa sông Hàn. Kéo TimeLens xong thấy thành phố đổi khác quá nhiều.',
    aiScore: 86,
    createdAt: DateTime.utc(2026, 10, 21, 9, 12),
  ),
  Reflection(
    id: 's2',
    locationId: 'cham-museum',
    displayAuthor: anonymousAuthor,
    isAnonymous: true,
    content:
        'Lần đầu mình đứng trước bệ thờ Trà Kiệu. Các vũ nữ Apsara chạm nổi sống động như đang múa thật.',
    aiScore: 91,
    createdAt: DateTime.utc(2026, 10, 22, 14, 40),
  ),
  Reflection(
    id: 's3',
    locationId: 'non-nuoc',
    displayAuthor: 'Hoàng Long',
    isAnonymous: false,
    content:
        'Chú nghệ nhân kể một pho tượng Phật lớn làm mất gần nửa năm. Tiếng đục đá cả làng nghe vui tai lắm.',
    aiScore: 78,
    createdAt: DateTime.utc(2026, 10, 24, 8, 5),
  ),
  Reflection(
    id: 's4',
    locationId: 'cau-rong',
    displayAuthor: anonymousAuthor,
    isAnonymous: true,
    content:
        'Tối thứ Bảy đứng xem rồng phun lửa, nóng rát cả mặt dù đứng khá xa!',
    aiScore: 64,
    createdAt: DateTime.utc(2026, 10, 26, 21, 10),
  ),
  Reflection(
    id: 's5',
    locationId: 'tuy-loan',
    displayAuthor: 'Thu Trang',
    isAnonymous: false,
    content:
        'Bánh tráng nướng ăn với mì Quảng ngay tại làng ngon hơn hẳn ngoài phố. Đình làng còn giữ nguyên nét xưa.',
    aiScore: 82,
    createdAt: DateTime.utc(2026, 10, 27, 11, 30),
  ),
];

class LeaderEntry {
  const LeaderEntry(
    this.id,
    this.name,
    this.xp,
    this.stamps, {
    this.isMe = false,
  });
  final String id;
  final String name;
  final int xp;
  final int stamps;
  final bool isMe;
}

const leaderboard = <LeaderEntry>[
  LeaderEntry('u1', 'Bảo Ngọc', 1180, 10),
  LeaderEntry('u2', 'Minh Anh', 940, 9),
  LeaderEntry('u3', 'Hoàng Long', 720, 7),
  LeaderEntry('u4', 'Thu Trang', 560, 5),
  LeaderEntry('u5', 'Quốc Huy', 410, 4),
  LeaderEntry('u6', 'Lan Chi', 240, 2),
  LeaderEntry('u7', 'Đức Tài', 120, 1),
];
