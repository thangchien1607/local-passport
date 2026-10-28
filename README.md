# Local Passport (Flutter) — Hộ chiếu trải nghiệm văn hóa Đà Nẵng

Bản Flutter của giao diện Local Passport, chạy trên **Web, Android và iOS** từ cùng một mã nguồn.
Chuyển từ bản React trong `../../local-passport`, giữ nguyên design system và luồng sử dụng.

## Chạy thử

```bash
flutter pub get
flutter run -d chrome        # Web (hoặc -d edge)
flutter run                  # Android/iOS: cắm điện thoại hoặc mở emulator
```

Build bản web để deploy (ví dụ Firebase Hosting):

```bash
flutter build web --release  # kết quả ở build/web
```

> Camera quét QR trên web chỉ hoạt động qua **HTTPS hoặc localhost**. Khi demo cho giám khảo, dùng nút **Giả lập quét QR (Demo)**.

## Deploy lên Firebase Hosting

Bản web đang chạy tại **https://local-passport-danang.web.app** (project `local-passport-danang`).
Mỗi lần sửa code, cập nhật bằng:

```bash
flutter build web --release
firebase.cmd deploy --only hosting
```

Cấu hình nằm trong `firebase.json` (thư mục `build/web`, chế độ SPA, `index.html` và file `.js` không cache
để điện thoại luôn nhận bản mới) và `.firebaserc` (project mặc định).

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
  theme.dart                   Màu, font, nút dùng chung (design system)
  data/routes.dart             Tuyến & 10 địa điểm (routes_branches, hotspots_locations)
  data/community.dart          Cảm nhận & bảng xếp hạng mẫu
  state/passport_store.dart    Trạng thái hộ chiếu + công thức tiến độ (user_passports)
  services/geo.dart            Haversine, GPS (geolocator), định dạng mã QR
  services/ai_verifier.dart    Thẩm định cảm nhận (MÔ PHỎNG)
  widgets/time_lens.dart       ★ Lăng kính thời gian (thanh trượt xưa/nay)
  widgets/scene_art.dart       Tranh minh họa + hiệu ứng sepia/hạt phim cho ảnh "xưa"
  widgets/stamp_seal.dart      Con dấu mộc vẽ bằng CustomPainter
  widgets/discovery_map.dart   Bản đồ minh họa + hotspot phát sáng
  screens/                     Welcome, Map, Location, QR Scanner, Stamp Ceremony, Passport, Community, Leaderboard
assets/
  scenes/<scene>_<past|present>.svg   Tranh xưa/nay của từng địa điểm
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

Trong `lib/data/routes.dart`, điền URL cho địa điểm:

```dart
timeLens: TimeLensInfo(
  pastYear: '1885',
  presentYear: '2026',
  pastImageUrl: 'https://.../dien-hai-1885.jpg',
  presentImageUrl: 'https://.../dien-hai-2026.jpg',
),
```

Ảnh xưa sẽ tự được phủ hiệu ứng sepia + hạt phim. Hai ảnh nên cùng góc chụp và cùng tỉ lệ 20:13.

## Phần đang mô phỏng (cần làm tiếp)

| Hiện tại | Thay bằng |
| --- | --- |
| Đăng nhập lưu tên vào shared_preferences | `firebase_auth` + Google Sign-In |
| Tiến độ/dấu mộc/cảm nhận lưu cục bộ | `cloud_firestore` + `firebase_storage` |
| Bản đồ SVG minh họa | `google_maps_flutter` với cùng tọa độ |
| Tranh SVG xưa/nay | Ảnh tư liệu thật (`pastImageUrl` / `presentImageUrl`) |
| `ai_verifier.dart` chấm theo độ dài + từ khóa | Gemini API qua Cloud Function (không để API key trong app) |

Nội dung lịch sử là dữ liệu mẫu, cần đối chiếu nguồn chính thống trước khi công bố.

## Quyền đã khai báo

- **Android** (`AndroidManifest.xml`): INTERNET, CAMERA, ACCESS_FINE/COARSE_LOCATION.
- **iOS** (`Info.plist`): NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, NSPhotoLibraryUsageDescription.
- **Web**: trình duyệt tự hỏi quyền camera/vị trí; cần HTTPS.
