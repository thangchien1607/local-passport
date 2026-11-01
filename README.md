# Local Passport (Flutter) — Hộ chiếu trải nghiệm văn hóa Đà Nẵng

Bản Flutter của giao diện Local Passport, chạy trên **Web, Android và iOS** từ cùng một mã nguồn.
Chuyển từ bản React trong `../../local-passport`, giữ nguyên design system và luồng sử dụng.

## Chạy thử

```bash
flutter pub get
flutter run -d chrome        # Web (hoặc -d edge)
flutter run                  # Android/iOS: cắm điện thoại hoặc mở emulator
```

### Chạy bản Android demo bằng Android Studio

1. Cài Flutter SDK, Android Studio, Android SDK và plugin Flutter/Dart.
2. Mở thư mục gốc project trong Android Studio; chờ IDE đồng bộ Flutter packages.
3. Chọn emulator hoặc bật USB debugging trên điện thoại Android rồi chọn thiết bị.
4. Bấm **Run** để cài và chạy bản demo. Android sẽ hỏi quyền camera và vị trí khi cần.

Mặc định app chỉ hiện ba tuyến chính. Để hiện thêm dữ liệu thử Hòa Khánh khi chạy local:

```bash
flutter run -d <android-device-id> --dart-define=LOCAL_PASSPORT_TEST_DATA=true
```

Hồ sơ, tiến độ, ảnh nhiệm vụ và cảm nhận được lưu cục bộ trên thiết bị. Đăng nhập, bảng tin và bảng xếp hạng chưa đồng bộ cloud.

### Chạy bản iOS

iOS dùng chung mã Flutter nhưng cần **macOS có Xcode** để chạy hoặc tạo bản cài; Windows không thể build iOS. Trên Mac, cài Flutter và Xcode, chạy `flutter doctor`, `flutter pub get`, rồi chọn iPhone simulator/thiết bị và chạy `flutter run`. Cài lên iPhone thật cần cấu hình signing/team trong Xcode.

Build bản web để deploy (ví dụ Firebase Hosting):

```bash
flutter build web --release  # kết quả ở build/web
```

> Camera quét QR trên web chỉ hoạt động qua **HTTPS hoặc localhost**. Khi demo cho giám khảo, dùng nút **Giả lập quét QR (Demo)**.

## Google Maps (tùy chọn)

Bản đồ Khám phá dùng **Google Maps** khi build có API key; không có key thì dùng bản đồ minh họa như cũ.

```bash
flutter run -d chrome --dart-define=MAPS_API_KEY=<key>
flutter build web --release --dart-define=MAPS_API_KEY=<key>
flutter build apk --dart-define=MAPS_API_KEY=<key>
```

- Trong Google Cloud bật **Maps JavaScript API** (web) và **Maps SDK for Android**, rồi giới hạn key theo domain web và package `vn.localpassport.local_passport`.
- Android lấy key từ `--dart-define` qua `android/app/build.gradle.kts` → `AndroidManifest.xml`.
- iOS chưa cấu hình nên vẫn dùng bản đồ minh họa.
- **Không commit key vào repo.**

## Deploy lên Firebase Hosting

Bản web đang chạy tại **https://local-passport-danang.web.app** (project `local-passport-danang`).
Mỗi lần sửa code, cập nhật bằng:

```bash
flutter build web --release
firebase.cmd deploy --only hosting
```

Cấu hình nằm trong `firebase.json` (thư mục `build/web`, chế độ SPA, `index.html` và file `.js` không cache
để điện thoại luôn nhận bản mới) và `.firebaserc` (project mặc định).

## Bản demo TimeLens (public riêng, ~30% dự án)

Bản nộp vòng đơn DevFest chỉ gồm **một trang Lăng kính thời gian** cho 4 di tích, build từ entrypoint riêng
`lib/main_timelens.dart` nên không chứa các màn hình khác. Trong app đầy đủ, cùng trang này mở từ banner
"Lăng kính thời gian" ở tab Khám phá. Kế hoạch chi tiết: `timelens_demo_plan.md`.

```bash
node tools/timelens/build.mjs                                      # → build/timelens
firebase.cmd deploy --only hosting --config firebase.timelens.json # → https://local-passport-timelens.web.app
```

Lần đầu cần tạo site: `firebase.cmd hosting:sites:create local-passport-timelens`.

## Luồng demo 30 giây

1. Đăng nhập → bản đồ Radar Hotspots, chọn Bộ lọc cảm hứng.
2. Chọn địa điểm → **Quét QR Check-in** → **Giả lập quét QR (Demo)**.
3. Lướt 3 thẻ câu chuyện, kéo TimeLens, tích nhiệm vụ còn lại → tiến độ 100%.
4. Hiệu ứng **Cộp!** đóng dấu → tùy chọn viết cảm nhận (bật ẩn danh) → AI chấm điểm, cộng XP.
5. Tab **Hộ chiếu / Bảng tin / Xếp hạng**. Nút "Làm lại từ đầu" trong tab Hộ chiếu để demo lại.

## Cấu trúc

```
lib/
  main.dart                    App, khung mobile 440px trên web, thanh điều hướng
  main_timelens.dart           Entrypoint bản demo public: chỉ trang TimeLens
  theme.dart                   Màu, font, nút dùng chung (design system)
  data/routes.dart             Tuyến & 10 địa điểm (routes_branches, hotspots_locations)
  data/community.dart          Cảm nhận & bảng xếp hạng mẫu
  state/passport_store.dart    Hộ chiếu, tiến độ và ảnh nhiệm vụ lưu cục bộ cho bản demo
  services/geo.dart            Haversine, GPS (geolocator), định dạng mã QR
  services/ai_verifier.dart    Bộ chấm offline; có thể cấu hình HTTPS verifier backend
  widgets/time_lens.dart       ★ Lăng kính thời gian (thanh trượt xưa/nay)
  widgets/scene_art.dart       Tranh minh họa + hiệu ứng sepia/hạt phim cho ảnh "xưa"
  widgets/stamp_seal.dart      Con dấu mộc vẽ bằng CustomPainter
  widgets/discovery_map.dart   Bản đồ minh họa + hotspot phát sáng
  screens/                     Welcome, Map, Location, QR Scanner, Stamp Ceremony, Passport, Community, Leaderboard
  screens/timelens_screen.dart Lăng kính thời gian 4 di tích (demo public + mở từ tab Khám phá)
assets/
  photos/<id>_<past|present>.jpg      Ảnh thật xưa/nay (Wikimedia Commons, xem "Nguồn ảnh")
  scenes/<scene>_<past|present>.svg   Tranh xưa/nay của từng địa điểm (dùng khi chưa có ảnh thật)
  map/danang_map.svg                     Nền bản đồ
```

## Mã QR dán tại di tích

File in sẵn: **`tools/qr/qr_checkin.pdf`** (10 mã, 4 mã/trang A4) và bản HTML `tools/qr/qr_checkin.html`.

Mỗi mã là một link, ví dụ `https://local-passport-danang.web.app/?checkin=dien-hai&k=DH-1813`:
- Quét bằng **camera thường** của điện thoại → mở app, vào thẳng di tích, tự xác thực GPS (bán kính 300 m).
- Quét bằng nút **Quét QR Check-in** trong app cũng được. App vẫn chấp nhận dạng cũ `LOCALPASSPORT|<id>|<secret>`.

Khi thêm/sửa địa điểm trong `lib/data/routes.dart`, tạo lại trang in:

```bash
cd tools/qr
npm.cmd install
npm.cmd run generate      # cập nhật qr_checkin.html → mở bằng trình duyệt, bấm "In / Lưu PDF"
```

## Thêm ảnh thật cho TimeLens

4 di tích tiêu biểu (Điện Hải, Bảo tàng Chăm, Cầu Rồng, Ngũ Hành Sơn) đã có ảnh thật trong `assets/photos/`.
Với điểm khác, trong `lib/data/routes.dart` điền đường dẫn asset hoặc URL:

```dart
timeLens: TimeLensInfo(
  pastYear: '1920s',            // ghi đúng năm chụp của ảnh
  presentYear: '2024',
  pastImageUrl: 'assets/photos/<id>_past.jpg',
  presentImageUrl: 'assets/photos/<id>_present.jpg',
  caption: 'Ảnh chụp gì, ở đâu',
  credit: 'Ảnh: <tác giả> (<giấy phép>) · <nguồn>',
),
```

Ảnh xưa sẽ tự được phủ hiệu ứng sepia + hạt phim. Hai ảnh nên cùng góc chụp, cắt về tỉ lệ 20:13
(đang dùng 1040×676, JPEG ~80%). Chỉ dùng ảnh public domain / CC0 / CC BY / CC BY-SA và luôn điền `credit`.

## Nguồn ảnh

Ảnh lấy từ Wikimedia Commons, đã cắt về 20:13 và thu nhỏ; ảnh "xưa" được phủ sepia khi hiển thị.
Bản phái sinh giữ nguyên giấy phép của ảnh gốc.

| File | Ảnh gốc | Tác giả | Giấy phép |
| --- | --- | --- | --- |
| `dien-hai_past.jpg` | [Dien Hai in early 20th century](https://commons.wikimedia.org/wiki/File:Dien_Hai_in_early_20th_century.jpg) | Botminh24 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `dien-hai_present.jpg` | [Dien Hai Citadel Moat 2](https://commons.wikimedia.org/wiki/File:Dien_Hai_Citadel_Moat_2.jpg) | Botminh24 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `cham-museum_past.jpg` | [Tourane - Façade principale du Musée Cham](https://commons.wikimedia.org/wiki/File:Tourane_-_Fa%C3%A7ade_principale_du_Mus%C3%A9e_Cham.jpg) | Khuyết danh (đầu TK XX) | Public domain |
| `cham-museum_present.jpg` | [Musée d'art Cham](https://commons.wikimedia.org/wiki/File:Mus%C3%A9e_d%27art_Cham.JPG) | Dinkum | CC0 |
| `cau-rong_past.jpg` | [Construction in Han River DN](https://commons.wikimedia.org/wiki/File:Construction_in_Han_River_DN.jpg) | Dragfyre | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `cau-rong_present.jpg` | [Dragon Bridge, Da Nang, 2026 04 30 Reunification Day anniversary](https://commons.wikimedia.org/wiki/File:Dragon_Bridge,_Da_Nang,_2026_04_30_Reunification_Day_anniversary.jpg) | Shenzybaby | CC0 |
| `ngu-hanh-son_past.jpg` | [Ngôi chùa trong động Huyền Không, Ngũ Hành Sơn](https://commons.wikimedia.org/wiki/File:Ng%C3%B4i_ch%C3%B9a_trong_%C4%91%E1%BB%99ng_Huy%E1%BB%81n_Kh%C3%B4ng,_Ng%C5%A9_H%C3%A0nh_S%C6%A1n.jpg) | Khuyết danh (1920s) | Public domain |
| `ngu-hanh-son_present.jpg` | [Da Nang - Động Huyền Không (2024) - img 05](https://commons.wikimedia.org/wiki/File:Da_Nang_-_%C3%90%E1%BB%99ng_Huy%E1%BB%81n_Kh%C3%B4ng_(2024)_-_img_05.jpg) | Chainwit. | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |

## Phần đang mô phỏng (cần làm tiếp)

| Hiện tại | Thay bằng |
| --- | --- |
| Đăng nhập lưu tên vào shared_preferences | `firebase_auth` + Google Sign-In |
| Tiến độ/dấu mộc/cảm nhận lưu cục bộ | `cloud_firestore` + `firebase_storage` |
| Bản đồ SVG minh họa | `google_maps_flutter` với cùng tọa độ |
| Tranh SVG xưa/nay (6 điểm chưa có ảnh thật) | Ảnh tư liệu thật (`pastImageUrl` / `presentImageUrl`) |
| `ai_verifier.dart` chấm theo độ dài + từ khóa | Đầu nối HTTPS đã có; cần triển khai Cloud Function Gemini và cấu hình `REFLECTION_VERIFIER_URL` (không để API key trong app) |

Nội dung lịch sử là dữ liệu mẫu, cần đối chiếu nguồn chính thống trước khi công bố.

### Kết nối bộ thẩm định cảm nhận

Mặc định ứng dụng dùng bộ chấm offline. Khi đã triển khai HTTPS Cloud Function gọi Gemini phía máy chủ, chạy với endpoint:

```bash
flutter run -d chrome --dart-define=REFLECTION_VERIFIER_URL=https://<region>-<project>.cloudfunctions.net/verifyReflection
```

Endpoint nhận `content`, `hasPhoto`, `locationId`, `locationName`, `stories`; trả `score`, `approved`, `soulmate`, `bonusXp` và `comment`. Ảnh không được gửi lên dịch vụ thẩm định. Khi endpoint lỗi, nội dung không bị đăng và người dùng có thể thử gửi lại.

## Quyền đã khai báo

- **Android** (`AndroidManifest.xml`): INTERNET, CAMERA, ACCESS_FINE/COARSE_LOCATION.
- **iOS** (`Info.plist`): NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription.
- **Web**: trình duyệt tự hỏi quyền camera/vị trí; cần HTTPS.
