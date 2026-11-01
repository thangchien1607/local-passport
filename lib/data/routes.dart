import 'package:flutter/material.dart';

// Dữ liệu mẫu cho bản MVP. Khi nối Firebase, các danh sách này tương ứng với
// collection `routes_branches` và `hotspots_locations` trong đề cương.
// Nội dung lịch sử cần được đối chiếu với nguồn chính thống trước khi công bố.

class RouteInfo {
  const RouteInfo({
    required this.id,
    required this.title,
    required this.short,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String id;
  final String title;
  final String short;
  final IconData icon;
  final Color color;
  final String description;
}

class StoryCard {
  const StoryCard(this.title, this.body);
  final String title;
  final String body;
}

enum TaskType { timelens, story, manual, photo }

class TaskItem {
  const TaskItem(this.id, this.type, this.title);
  final String id;
  final TaskType type;
  final String title;
}

class TimeLensInfo {
  const TimeLensInfo({
    required this.pastYear,
    required this.presentYear,
    this.pastImageUrl,
    this.presentImageUrl,
    this.caption,
    this.credit,
  });

  final String pastYear;
  final String presentYear;
  // Ảnh tư liệu thật: URL hoặc asset `assets/photos/...`; nếu null sẽ dùng tranh minh họa.
  final String? pastImageUrl;
  final String? presentImageUrl;

  /// Chú thích nội dung ảnh, hiện dưới thanh trượt.
  final String? caption;

  /// Tác giả & giấy phép ảnh — bắt buộc với ảnh CC BY / CC BY-SA.
  final String? credit;
}

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}

class Location {
  const Location({
    required this.id,
    required this.routeId,
    required this.name,
    required this.address,
    required this.coordinates,
    required this.qrCodeSecret,
    required this.scene,
    required this.timeLens,
    required this.stories,
    required this.tasks,
    this.mapNudge = Offset.zero,
  });

  final String id;
  final String routeId;
  final String name;
  final String address;
  final LatLng coordinates;
  final String qrCodeSecret;
  final String scene;
  final TimeLensInfo timeLens;
  final List<StoryCard> stories;
  final List<TaskItem> tasks;
  final Offset mapNudge;
}

class Rank {
  const Rank(this.id, this.title, this.minXp);
  final String id;
  final String title;
  final int minXp;
}

const routes = <RouteInfo>[
  RouteInfo(
    id: 'history',
    title: 'Tuyến Lịch sử hào hùng',
    short: 'Lịch sử',
    icon: Icons.shield_outlined,
    color: Color(0xFFB91C1C),
    description:
        'Dấu tích những trận chiến giữ cửa biển và chủ quyền biển đảo.',
  ),
  RouteInfo(
    id: 'architecture',
    title: 'Tuyến Kiến trúc & Tín ngưỡng',
    short: 'Kiến trúc',
    icon: Icons.account_balance_outlined,
    color: Color(0xFFA16207),
    description:
        'Từ điêu khắc Chăm cổ đến cây cầu biểu tượng của thành phố trẻ.',
  ),
  RouteInfo(
    id: 'craft',
    title: 'Tuyến Làng nghề truyền thống',
    short: 'Làng nghề',
    icon: Icons.handyman_outlined,
    color: Color(0xFF0F766E),
    description: 'Nghe tiếng đục đá, mùi chượp mắm và nắng phơi bánh tráng.',
  ),
  // Tuyến tạm để thử GPS/QR quanh khu Hòa Khánh — xóa trước khi công bố.
  RouteInfo(
    id: 'test',
    title: 'Tuyến Thử nghiệm Hòa Khánh',
    short: 'Thử nghiệm',
    icon: Icons.science_outlined,
    color: Color(0xFF7C3AED),
    description: 'Các điểm gần Bách khoa để thử check-in GPS và quét QR.',
  ),
];

const _timelensTask = TaskItem(
  'timelens',
  TaskType.timelens,
  'Kéo TimeLens so sánh xưa & nay',
);
const _storyTask = TaskItem(
  'story',
  TaskType.story,
  'Đọc hết các thẻ câu chuyện',
);

const locations = <Location>[
  Location(
    id: 'dien-hai',
    routeId: 'history',
    name: 'Thành Điện Hải',
    address: 'Trần Phú, Hải Châu',
    coordinates: LatLng(16.0757, 108.2208),
    qrCodeSecret: 'DH-1813',
    scene: 'citadel',
    timeLens: TimeLensInfo(
      pastYear: 'Đầu TK XX',
      presentYear: '2024',
      pastImageUrl: 'assets/photos/dien-hai_past.jpg',
      presentImageUrl: 'assets/photos/dien-hai_present.jpg',
      caption:
          'Tường thành Điện Hải: đầu TK XX phía sau là nhà thờ và bệnh viện Pháp, nay là cao ốc bên hào nước.',
      credit: 'Ảnh: Botminh24 (CC BY 4.0) · Wikimedia Commons',
    ),
    stories: [
      StoryCard(
        'Pháo đài giữ cửa biển',
        'Năm 1813, vua Gia Long cho xây đồn Điện Hải gần cửa sông Hàn. Năm 1823, vua Minh Mạng cho dời đồn vào vị trí hiện nay và xây lại bằng gạch.',
      ),
      StoryCard(
        'Mùa thu năm 1858',
        'Tháng 9/1858, liên quân Pháp – Tây Ban Nha nổ súng tấn công Đà Nẵng. Thành Điện Hải cùng đồn An Hải là tuyến phòng thủ chính chặn bước tiến của đối phương.',
      ),
      StoryCard(
        'Tướng Nguyễn Tri Phương',
        'Ông cho đắp lũy dài, thực hiện kế "vườn không nhà trống", khiến liên quân sa lầy gần hai năm rồi phải rút khỏi Đà Nẵng năm 1860.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem(
        'statue',
        TaskType.manual,
        'Tìm tượng đài Tướng Nguyễn Tri Phương',
      ),
    ],
  ),
  Location(
    id: 'nghia-trung',
    routeId: 'history',
    name: 'Nghĩa trủng Hòa Vang',
    address: 'Khuê Trung, Cẩm Lệ',
    coordinates: LatLng(16.013, 108.205),
    qrCodeSecret: 'NT-1860',
    scene: 'memorial',
    timeLens: TimeLensInfo(pastYear: 'TK XIX', presentYear: '2026'),
    stories: [
      StoryCard(
        'Nơi yên nghỉ của nghĩa sĩ',
        'Nghĩa trủng là nơi an táng các nghĩa sĩ hy sinh trong cuộc kháng chiến chống liên quân Pháp – Tây Ban Nha tại Đà Nẵng (1858–1860).',
      ),
      StoryCard(
        'Lễ tế hằng năm',
        'Người dân địa phương vẫn giữ lệ tổ chức lễ tế, tưởng nhớ những người đã ngã xuống để giữ cửa biển.',
      ),
      StoryCard(
        'Những người không tên',
        'Giữa lòng phố thị, nghĩa trủng nhắc rằng chiến công giữ nước thuộc về rất nhiều người dân bình thường, phần lớn không để lại tên tuổi.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('incense', TaskType.manual, 'Dâng một nén hương tưởng niệm'),
    ],
  ),
  Location(
    id: 'hoang-sa',
    routeId: 'history',
    name: 'Nhà trưng bày Hoàng Sa',
    address: 'Hoàng Sa, Sơn Trà',
    coordinates: LatLng(16.102, 108.25),
    qrCodeSecret: 'HS-2018',
    scene: 'seaMuseum',
    timeLens: TimeLensInfo(pastYear: 'TK XVIII', presentYear: '2026'),
    stories: [
      StoryCard(
        'Ngôi nhà của chủ quyền',
        'Khánh thành năm 2018, nhà trưng bày lưu giữ tư liệu, bản đồ và hiện vật khẳng định chủ quyền của Việt Nam với quần đảo Hoàng Sa.',
      ),
      StoryCard(
        'Đội Hoàng Sa',
        'Từ thời các chúa Nguyễn, Đội Hoàng Sa đã ra đảo khai thác sản vật, đo đạc và cắm mốc — được ghi chép trong nhiều thư tịch cổ.',
      ),
      StoryCard(
        'Châu bản triều Nguyễn',
        'Nhiều châu bản — văn bản có bút phê của vua — ghi lại các chuyến ra Hoàng Sa, là bằng chứng pháp lý quý giá.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('map', TaskType.manual, 'Tìm tấm bản đồ cổ có ghi tên Hoàng Sa'),
    ],
  ),
  Location(
    id: 'cham-museum',
    routeId: 'architecture',
    name: 'Bảo tàng Điêu khắc Chăm',
    address: '02 đường 2 Tháng 9, Hải Châu',
    coordinates: LatLng(16.0605, 108.2234),
    mapNudge: Offset(-10, 6),
    qrCodeSecret: 'CHAM-1915',
    scene: 'chamMuseum',
    timeLens: TimeLensInfo(
      pastYear: 'Đầu TK XX',
      presentYear: '2009',
      pastImageUrl: 'assets/photos/cham-museum_past.jpg',
      presentImageUrl: 'assets/photos/cham-museum_present.jpg',
      caption: 'Hiên cột kiến trúc Chăm của nhà trưng bày, nhìn từ sân.',
      credit:
          'Ảnh: bưu ảnh Tourane (public domain), Dinkum (CC0) · Wikimedia Commons',
    ),
    stories: [
      StoryCard(
        'Hơn một thế kỷ',
        'Bảo tàng được xây dựng từ năm 1915 theo đề xuất của Viện Viễn Đông Bác Cổ Pháp, lưu giữ bộ sưu tập điêu khắc Chăm lớn nhất.',
      ),
      StoryCard(
        'Đá kể chuyện thần linh',
        'Tượng thần Shiva, Vishnu, chim thần Garuda hay vũ nữ Apsara cho thấy ảnh hưởng của Ấn Độ giáo trong văn hóa Champa.',
      ),
      StoryCard(
        'Bệ thờ Trà Kiệu',
        'Với các vũ nữ và nhạc công chạm nổi, bệ thờ Trà Kiệu là một trong những bảo vật quốc gia nổi tiếng nhất của bảo tàng.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('apsara', TaskType.manual, 'Tìm tượng vũ nữ Apsara'),
    ],
  ),
  Location(
    id: 'cau-rong',
    routeId: 'architecture',
    name: 'Cầu Rồng',
    address: 'Sông Hàn, Hải Châu – Sơn Trà',
    coordinates: LatLng(16.0612, 108.227),
    mapNudge: Offset(8, -6),
    qrCodeSecret: 'RONG-2013',
    scene: 'bridge',
    timeLens: TimeLensInfo(
      pastYear: '2011',
      presentYear: '2026',
      pastImageUrl: 'assets/photos/cau-rong_past.jpg',
      presentImageUrl: 'assets/photos/cau-rong_present.jpg',
      caption:
          '2011: giàn giáo dựng cầu giữa sông Hàn. 2026: Cầu Rồng lên đèn dịp 30/4.',
      credit:
          'Ảnh: Dragfyre (CC BY-SA 3.0), Shenzybaby (CC0) · Wikimedia Commons',
    ),
    stories: [
      StoryCard(
        'Rồng vươn ra biển',
        'Khánh thành ngày 29/3/2013, cầu dài 666 m, mô phỏng con rồng thời Lý vươn mình hướng ra biển Đông.',
      ),
      StoryCard(
        'Phun lửa, phun nước',
        'Khoảng 21h tối thứ Bảy và Chủ nhật, đầu rồng phun lửa rồi phun nước — màn trình diễn thu hút hàng nghìn người xem.',
      ),
      StoryCard(
        'Ngày khánh thành',
        'Ngày 29/3 cũng là ngày giải phóng Đà Nẵng năm 1975, gửi gắm khát vọng vươn lên của thành phố.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('photo', TaskType.photo, 'Chụp ảnh cùng đầu rồng'),
    ],
  ),
  Location(
    id: 'ngu-hanh-son',
    routeId: 'architecture',
    name: 'Danh thắng Ngũ Hành Sơn',
    address: 'Huyền Trân Công Chúa, Ngũ Hành Sơn',
    coordinates: LatLng(16.0036, 108.2638),
    mapNudge: Offset(-4, -6),
    qrCodeSecret: 'NHS-KMTHT',
    scene: 'mountain',
    timeLens: TimeLensInfo(
      pastYear: '1920s',
      presentYear: '2024',
      pastImageUrl: 'assets/photos/ngu-hanh-son_past.jpg',
      presentImageUrl: 'assets/photos/ngu-hanh-son_present.jpg',
      caption: 'Ngôi chùa trong động Huyền Không, núi Thủy Sơn.',
      credit:
          'Ảnh: khuyết danh (public domain), Chainwit. (CC BY 4.0) · Wikimedia Commons',
    ),
    stories: [
      StoryCard(
        'Năm ngọn núi, năm hành',
        'Vua Minh Mạng đặt tên năm ngọn núi đá vôi theo ngũ hành: Kim Sơn, Mộc Sơn, Thủy Sơn, Hỏa Sơn và Thổ Sơn.',
      ),
      StoryCard(
        'Động Huyền Không',
        'Trên Thủy Sơn — ngọn lớn nhất — động Huyền Không đón ánh sáng rọi qua khe đá, tạo nên khung cảnh huyền ảo.',
      ),
      StoryCard(
        'Chữ trên vách đá',
        'Các bài văn khắc Hán – Nôm trên vách đá Ngũ Hành Sơn được UNESCO ghi danh là Di sản tư liệu khu vực châu Á – Thái Bình Dương.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('cave', TaskType.manual, 'Đến cửa động Huyền Không'),
    ],
  ),
  Location(
    id: 'linh-ung',
    routeId: 'architecture',
    name: 'Chùa Linh Ứng Bãi Bụt',
    address: 'Bán đảo Sơn Trà',
    coordinates: LatLng(16.1, 108.2777),
    mapNudge: Offset(-4, -12),
    qrCodeSecret: 'LU-67M',
    scene: 'pagoda',
    timeLens: TimeLensInfo(pastYear: 'Trước 2004', presentYear: '2026'),
    stories: [
      StoryCard(
        'Tượng Quan Âm 67 mét',
        'Tượng Quan Thế Âm cao 67 m hướng mặt ra biển, được người dân tin là che chở cho ngư dân mỗi chuyến ra khơi.',
      ),
      StoryCard(
        'Trên lưng chừng bán đảo',
        'Chùa nằm trên bán đảo Sơn Trà; từ sân chùa có thể ngắm trọn vịnh Đà Nẵng và bờ biển Mỹ Khê.',
      ),
      StoryCard(
        'Mười tám vị La Hán',
        'Dọc lối vào là 18 vị La Hán tạc bằng đá cẩm thạch, mỗi vị một dáng vẻ, một cảm xúc riêng.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('arhat', TaskType.manual, 'Đếm đủ 18 vị La Hán'),
    ],
  ),
  Location(
    id: 'non-nuoc',
    routeId: 'craft',
    name: 'Làng đá mỹ nghệ Non Nước',
    address: 'Hòa Hải, Ngũ Hành Sơn',
    coordinates: LatLng(15.995, 108.262),
    mapNudge: Offset(-8, 6),
    qrCodeSecret: 'NN-STONE',
    scene: 'stoneVillage',
    timeLens: TimeLensInfo(pastYear: 'TK XX', presentYear: '2026'),
    stories: [
      StoryCard(
        'Tiếng đục đá trăm năm',
        'Làng nghề hình thành từ thế kỷ XVIII dưới chân Ngũ Hành Sơn; tương truyền ông Huỳnh Bá Quát từ Thanh Hóa vào truyền nghề.',
      ),
      StoryCard(
        'Giữ núi, giữ nghề',
        'Để bảo vệ danh thắng, việc khai thác đá tại Ngũ Hành Sơn đã bị cấm; nghệ nhân ngày nay dùng đá đưa về từ nơi khác.',
      ),
      StoryCard(
        'Bàn tay nghệ nhân',
        'Một pho tượng lớn có thể mất nhiều tháng: phác thảo, đẽo thô, tạo hình chi tiết rồi mới đánh bóng.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('artisan', TaskType.manual, 'Xem nghệ nhân chạm khắc trực tiếp'),
    ],
  ),
  Location(
    id: 'nam-o',
    routeId: 'craft',
    name: 'Làng nước mắm Nam Ô',
    address: 'Hòa Hiệp Nam, Liên Chiểu',
    coordinates: LatLng(16.119, 108.13),
    mapNudge: Offset(2, 16),
    qrCodeSecret: 'NAMO-MAM',
    scene: 'fishVillage',
    timeLens: TimeLensInfo(pastYear: 'TK XX', presentYear: '2026'),
    stories: [
      StoryCard(
        'Hương vị của biển',
        'Nước mắm Nam Ô được ủ từ cá cơm than và muối theo tỉ lệ gia truyền, chượp trong thùng gỗ suốt nhiều tháng.',
      ),
      StoryCard(
        'Nghề truyền đời',
        'Nghề làm mắm ở Nam Ô đã có từ hàng trăm năm; tương truyền nước mắm nơi đây từng là sản vật tiến vua.',
      ),
      StoryCard(
        'Làng chài chân đèo',
        'Nằm gần chân đèo Hải Vân, Nam Ô vẫn giữ nếp sống chài lưới và những lễ hội cầu ngư đầu năm.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('barrel', TaskType.manual, 'Ngửi thử một thùng chượp'),
    ],
  ),
  Location(
    id: 'tuy-loan',
    routeId: 'craft',
    name: 'Làng bánh tráng Túy Loan',
    address: 'Hòa Phong, Hòa Vang',
    coordinates: LatLng(15.99, 108.15),
    qrCodeSecret: 'TL-BANHTRANG',
    scene: 'riceVillage',
    timeLens: TimeLensInfo(pastYear: 'TK XX', presentYear: '2026'),
    stories: [
      StoryCard(
        'Làng cổ bên sông',
        'Túy Loan là một trong những làng cổ lâu đời nhất Đà Nẵng, còn giữ được đình làng, cổng làng và những nếp nhà xưa.',
      ),
      StoryCard(
        'Bánh tráng nướng mè',
        'Bánh được tráng mỏng trên nồi hơi, phơi nắng rồi nướng trên than hồng — giòn rụm và thơm mùi mè.',
      ),
      StoryCard(
        'Mì Quảng Túy Loan',
        'Làng còn nổi tiếng với mì Quảng ăn kèm bánh tráng nướng bẻ vụn, đậm chất xứ Quảng.',
      ),
    ],
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('bake', TaskType.manual, 'Thử nướng một chiếc bánh tráng'),
    ],
  ),

  // ---- Điểm thử nghiệm (routeId 'test'). Tọa độ do người dùng cung cấp (28/10/2026).
  Location(
    id: 'bach-khoa',
    routeId: 'test',
    name: 'Đại học Bách khoa Đà Nẵng',
    address: '54 Nguyễn Lương Bằng, Liên Chiểu',
    coordinates: LatLng(16.074187, 108.150217),
    mapNudge: Offset(2, -12),
    qrCodeSecret: 'BK-TEST',
    scene: 'chamMuseum',
    timeLens: TimeLensInfo(pastYear: 'Xưa', presentYear: '2026'),
    stories: _testStories,
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('gate', TaskType.manual, 'Chụp ảnh tại cổng trường'),
    ],
  ),
  Location(
    id: 'cho-hoa-khanh',
    routeId: 'test',
    name: 'Chợ Hòa Khánh',
    address: '78 Âu Cơ, Hòa Khánh Bắc, Liên Chiểu',
    coordinates: LatLng(16.070218, 108.149148),
    mapNudge: Offset(-12, 6),
    qrCodeSecret: 'CHK-TEST',
    scene: 'fishVillage',
    timeLens: TimeLensInfo(pastYear: 'Xưa', presentYear: '2026'),
    stories: _testStories,
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('snack', TaskType.manual, 'Mua thử một món ăn vặt'),
    ],
  ),
  Location(
    id: 'ktx-phia-tay',
    routeId: 'test',
    name: 'Ký túc xá phía Tây',
    address: '08 Hà Văn Tính, Hòa Khánh Nam, Liên Chiểu',
    coordinates: LatLng(16.067306, 108.155193),
    mapNudge: Offset(10, 8),
    qrCodeSecret: 'KTX-TEST',
    scene: 'riceVillage',
    timeLens: TimeLensInfo(pastYear: 'Xưa', presentYear: '2026'),
    stories: _testStories,
    tasks: [
      _timelensTask,
      _storyTask,
      TaskItem('room', TaskType.manual, 'Check-in ngay tại sảnh ký túc xá'),
    ],
  ),
];

/// Keep the Hòa Khánh fixtures available for local QA without publishing them
/// in the default app build. Enable explicitly with --dart-define for testing.
const _includeTestRoute = bool.fromEnvironment('LOCAL_PASSPORT_TEST_DATA');
final publishedRoutes = routes
    .where((route) => _includeTestRoute || route.id != 'test')
    .toList(growable: false);
final publishedLocations = locations
    .where((location) => _includeTestRoute || location.routeId != 'test')
    .toList(growable: false);

const _testStories = [
  StoryCard(
    'Điểm thử nghiệm',
    'Đây là điểm dùng để kiểm tra luồng check-in: quét QR → xác thực GPS (bán kính 300 m) → mở khóa câu chuyện và dấu mộc.',
  ),
  StoryCard(
    'Nếu báo "đang cách…"',
    'Màn check-in sẽ hiện tọa độ của bạn. Gửi tọa độ đó để hiệu chỉnh lại vị trí điểm này cho chính xác.',
  ),
  StoryCard(
    'Tranh minh họa tạm',
    'Hình xưa/nay ở đây là tranh mượn từ di tích khác, chỉ để thử TimeLens.',
  ),
];

const ranks = <Rank>[
  Rank('rookie', 'Tân binh', 0),
  Rank('explorer', 'Nhà thám hiểm', 300),
  Rank('ambassador', 'Sứ giả văn hóa', 800),
];

const stampXp = 100;

final routeById = {for (final r in routes) r.id: r};
final locationById = {for (final l in locations) l.id: l};

List<Location> locationsOfRoute(String routeId) =>
    publishedLocations.where((l) => l.routeId == routeId).toList();

({Rank current, Rank? next}) rankForXp(int xp) {
  var current = ranks.first;
  for (final r in ranks) {
    if (xp >= r.minXp) current = r;
  }
  final i = ranks.indexOf(current);
  return (current: current, next: i + 1 < ranks.length ? ranks[i + 1] : null);
}
