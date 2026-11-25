# Local Passport (Flutter) — Hộ chiếu trải nghiệm văn hóa Đà Nẵng

Ứng dụng **Local Passport** viết bằng Flutter (Dart `^3.11.3`), chạy trên **Web, Android và iOS** từ cùng một mã nguồn, vận hành hoàn toàn trên gói **Firebase Spark (miễn phí)** với **Firebase Auth + Cloud Firestore** (không dùng Cloud Functions, không dùng Firebase Storage).

Bản đồ Khám phá mặc định dùng **OpenStreetMap** qua `flutter_map`, không cần API key. Cấu hình Firebase đi kèm hiện có cho Web và Android; iOS dùng chế độ cục bộ cho đến khi bổ sung cấu hình Firebase cho nền tảng này.

---

## Kiến trúc hiện tại (Thuần Firebase Spark)

### 1. Xác thực (`firebase_auth`)
- **Email & Mật khẩu**: đăng ký (tự gửi `sendEmailVerification`), đăng nhập, quên mật khẩu, xác minh email, đổi mật khẩu (có re-authenticate).
- **Google Sign-In & Apple Sign-In**: tích hợp qua `GoogleAuthProvider` / `AppleAuthProvider` (popup trên Web, provider flow trên Android/iOS).
- **Tài khoản khách (Anonymous)**: vào nhanh, có thể nâng cấp lên tài khoản Email / Google / Apple mà vẫn giữ nguyên `uid`, dấu mộc và tiến độ.
- **Xóa tài khoản vĩnh viễn từ client**: thực hiện theo đúng thứ tự **(1) Re-authenticate** (mật khẩu hiện tại / popup Google hoặc Apple) → **(2) Xóa toàn bộ dữ liệu Firestore của `uid`** theo lô `<= 450` thao tác (`visits`, `notifications`, cặp `reflections` + `reflection_owners`, `leaderboard_public`, `user_passports`) → **(3) Gọi `user.delete()`**. Nếu bước (2) gặp lỗi mạng giữa chừng, hệ thống không xóa Auth user vội để người dùng giữ phiên và thử lại an toàn (idempotent).
- **Chế độ cục bộ (offline / chưa cấu hình Firebase)**: lưu trên thiết bị bằng `shared_preferences`.

### 2. Dữ liệu & đồng bộ (`cloud_firestore`)
- `user_passports/{uid}`: hồ sơ, XP, số dấu mộc (`validPassport` kiểm tra schema chặt chẽ, chỉ chủ tài khoản đọc/ghi/xóa).
  - `user_passports/{uid}/visits/{locationId}`: trạng thái mở khóa, danh sách nhiệm vụ, `taskPhotos` (list tối đa 3 ảnh nén Base64, mỗi phần tử `<= 120000` ký tự), thời điểm đóng dấu; đọc tương thích ngược với `taskPhotoUrls` cũ.
  - `user_passports/{uid}/notifications/{id}`: thông báo trong ứng dụng.
- `reflections/{id}`: bài cảm nhận công khai (lưu ảnh nén `photoBase64 <= 120000` ký tự, đọc tương thích ngược `photoUrl` cũ; `aiScore` nguyên `0..100`; tác giả được sửa nội dung/ảnh/ẩn danh/điểm chấm lại và xóa bài).
- `reflection_owners/{id}`: lưu `uid` chủ bài viết (`allow update: if false`, bất biến sau khi tạo; chỉ chủ bài đọc/tạo/xóa).
- `leaderboard_public/{uid}`: bảng xếp hạng công khai (`displayName`, `xp`, `stampCount`, `avatarUrl`, `updatedAt`). Client tự cập nhật bản ghi của chính mình (`request.auth.uid == uid`) có **debounce 5 giây**; mọi người đọc được mà không lộ `user_passports`.
- **Đồng bộ & truy vấn**:
  - `sync()` chia lô nguyên tử `WriteBatch <= 450` thao tác, không phụ thuộc cache `_written`, kiểm tra tồn tại `reflection_owners/{id}` để đảm bảo idempotent.
  - `fetch()` tải song song bằng `Future.wait` và gom lô `whereIn` (tối đa 30 ID/nhóm), loại bỏ vòng lặp N+1.
  - Bảng tin cộng đồng dùng phân trang `startAfterDocument` + infinite scroll + luồng `snapshots()` realtime cho bài mới.

### 3. Nén ảnh & lưu Base64 an toàn dưới trần 1 MiB (`photo_service.dart`)
- Ảnh chụp nhiệm vụ và ảnh bài cảm nhận được nén phía client bằng `flutter_image_compress` (Android/iOS) và fallback thuần Dart qua package `image` (Web/desktop/test).
- Nén theo vòng lặp giảm dần kích thước/chất lượng từ cạnh dài **`720px`, JPEG quality `70`** cho tới khi dung lượng ảnh **`<= 80 KB`** (mục tiêu 40–80 KB, tối đa `120000` ký tự Base64). Nếu giảm tới mức tối thiểu mà vẫn `> 120 KB`, ứng dụng từ chối và báo lỗi thân thiện.
- Giới hạn tối đa **3 ảnh/visit** và ước lượng dung lượng document **`<= 800 KB`** trước khi ghi Firestore để không bao giờ chạm trần 1 MiB.

### 4. Chấm điểm cảm nhận (`ai_verifier.dart`)
- Mặc định dùng bộ chấm **heuristic offline** hoàn toàn ở client (không cần backend hay gói Blaze).
- Tùy chọn gọi endpoint thẩm định ngoài nếu truyền `--dart-define=REFLECTION_VERIFIER_URL=https://...` (tự đính kèm `Authorization: Bearer <Firebase ID Token>` và tự động fallback về heuristic khi lỗi mạng/HTTP/timeout).
- Khi tác giả sửa bài cảm nhận, điểm được tính lại trực tiếp bằng cùng hàm `verifyReflection`.

> Xem các đánh đổi kỹ thuật của kiến trúc Spark (anti-cheat, dung lượng document, xóa tài khoản từ client, rate limit) tại [docs/DECISIONS.md](docs/DECISIONS.md).

---

## Cài đặt & chạy thử cục bộ

### 1. Yêu cầu môi trường
- Flutter SDK (Dart `^3.11.3`)
- Node.js 20/22 LTS & npm (cho `rules_tests/` và `tools/`)
- Java 17+ (cho Firebase Emulator Suite — Firestore Rules test)
- Android Studio (Android) / macOS + Xcode (iOS)

### 2. Chạy ứng dụng Flutter
```bash
flutter pub get
flutter run -d chrome        # Web (hoặc -d edge)
flutter run                  # Android/iOS
```

Kèm dữ liệu thử Hòa Khánh hoặc cấu hình endpoint thẩm định ngoài tùy chọn:
```bash
flutter run -d chrome \
  --dart-define=LOCAL_PASSPORT_TEST_DATA=true \
  --dart-define=REFLECTION_VERIFIER_URL=https://your-verifier.example.com/verify
```

> Camera quét QR trên Web chỉ hoạt động qua **HTTPS hoặc localhost**. Khi demo, có thể dùng nút **Giả lập quét QR (Demo)**.

### 3. Chạy Firebase Emulator Suite (Auth + Firestore) & kiểm thử
```bash
# 1. Cài đặt và chạy bộ test Firestore Rules trên Firestore Emulator
cd rules_tests
npm install
npm test
cd ..

# 2. Khởi động Emulator (chỉ Auth + Firestore + UI)
npx firebase emulators:start --only auth,firestore --project demo-local-passport

# 3. Kiểm tra format, phân tích tĩnh & unit/widget test Flutter
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

---

## Bản đồ OpenStreetMap và Google Maps tùy chọn

Bản đồ Khám phá mặc định dùng **OpenStreetMap** (`OsmDiscoveryMap`), giữ định vị GPS, bộ lọc tuyến và các điểm check-in. Chạy `flutter run -d chrome` không cần key hay cấu hình dịch vụ bản đồ trả phí. Tile bản đồ cần kết nối mạng.

Tích hợp **Google Maps** có sẵn là tùy chọn riêng: chỉ được chọn khi truyền API key và khởi tạo SDK thành công; nếu thiếu key hoặc SDK lỗi, ứng dụng dùng OpenStreetMap. Bản Spark mặc định không cần bật Google Maps.

```bash
flutter run -d chrome --dart-define=MAPS_API_KEY=<key>
flutter build web --release --dart-define=MAPS_API_KEY=<key>
flutter build apk --dart-define=MAPS_API_KEY=<key>
```

- **Web**: bật **Maps JavaScript API**, giới hạn theo HTTP referrer.
- **Android**: bật **Maps SDK for Android**, đọc `--dart-define=MAPS_API_KEY` qua `android/app/build.gradle.kts` → `AndroidManifest.xml`.
- **iOS**: bật **Maps SDK for iOS**, sao chép `ios/Flutter/Secrets.xcconfig.example` thành `ios/Flutter/Secrets.xcconfig` (đã nằm trong `.gitignore`), điền `MAPS_API_KEY=<key>`. `Info.plist` và `AppDelegate.swift` tự đọc key từ file này.
- **Tuyệt đối không commit API key thật vào repo.**

## Quy trình đóng góp

Đọc [git.md](git.md) trước khi commit hoặc mở PR. Tạo nhánh `feature/`, `fix/`, `chore/`, `docs/` hoặc `refactor/` từ `develop` mới nhất, dùng commit/tiêu đề PR dạng `<type>(<scope>): <mô tả tiếng Việt>` và mở PR vào `develop`. Hai check **Quy ước Git** và **Format, analyze, test** phải xanh trước khi merge.

---

## Triển khai (Deploy) lên Firebase (Gói Spark)

> Xem hướng dẫn cấu hình chi tiết lần đầu (bật Google/Apple Auth, cấu hình iOS Maps key, triển khai Rules & Hosting) tại [docs/MANUAL_STEPS.md](docs/MANUAL_STEPS.md).

```bash
# 1. Triển khai Firestore Rules & Indexes
firebase deploy --only firestore:rules,firestore:indexes

# 2. Build và triển khai bản Web lên Firebase Hosting
flutter build web --release --dart-define=MAPS_API_KEY=<key>
firebase deploy --only hosting
```

Bản Web mặc định: **https://local-passport-danang.web.app** (project `local-passport-danang`).

### Bản demo TimeLens (public riêng)
Entrypoint `lib/main_timelens.dart`, cấu hình hosting trong `firebase.timelens.json` (đã cấu hình `Permissions-Policy: camera=(self), geolocation=(self), microphone=()`):
```bash
node tools/timelens/build.mjs                                      # → build/timelens
firebase deploy --only hosting --config firebase.timelens.json     # → https://local-passport-timelens.web.app
```

---

## Cấu trúc thư mục

```text
lib/
  main.dart                          App, khởi tạo Firebase (Auth + Firestore), điều hướng
  main_timelens.dart                 Entrypoint bản demo public TimeLens
  firebase_options.dart              Cấu hình công khai Firebase project
  theme.dart                         Design system (màu, font, nút dùng chung)
  data/
    routes.dart                      Tuyến & 10 địa điểm Đà Nẵng
    community.dart                   Model Reflection, LeaderEntry & dữ liệu mẫu
    notifications.dart               Model thông báo trong app
  state/
    passport_store.dart              Quản lý trạng thái hộ chiếu, đồng bộ, leaderboard debounce, phân trang, realtime
  services/
    auth_service.dart                Firebase Auth (Email, Google, Apple, Guest, đổi mật khẩu, xóa TK có re-auth)
    passport_remote.dart             Firestore sync/delete theo lô <= 450, fetch whereIn <= 30, phân trang & snapshots
    photo_service.dart               Nén ảnh vòng lặp <= 80 KB (720px, Q70), Base64, ước lượng doc <= 800 KB
    ai_verifier.dart                 Heuristic offline mặc định + tùy chọn REFLECTION_VERIFIER_URL kèm ID Token
    geo.dart                         Haversine, GPS (geolocator), định dạng mã QR
    maps_config.dart                 Cấu hình Google Maps đa nền tảng
    validators.dart                  Kiểm tra đầu vào form
  screens/                           Welcome, Map, Location, QR Scanner, Stamp Ceremony, Passport, Community, Leaderboard, TimeLens, Notifications
  widgets/                           AuthForm, ReflectionCard, EditReflectionDialog, PassportPhoto, TimeLens, StampSeal...
rules_tests/                         Kiểm thử Firestore Rules trên Firebase Emulator Suite
firestore.rules                      Quy tắc bảo mật Cloud Firestore (Spark)
firestore.indexes.json               Composite index cho bảng xếp hạng công khai
docs/
  DECISIONS.md                       Quyết định kiến trúc & đánh đổi của gói Spark
  MANUAL_STEPS.md                    Các bước thao tác thủ công trên dự án Firebase thật
  AUDIT_FIX_REPORT.md                Báo cáo tổng kết sửa lỗi & chuyển sang thuần Spark
```

---

## Mã QR dán tại di tích

File in sẵn: **`tools/qr/qr_checkin.pdf`** (10 mã, 4 mã/trang A4) và `tools/qr/qr_checkin.html`.
Mỗi mã có dạng `https://local-passport-danang.web.app/?checkin=dien-hai&k=DH-1813` (vẫn hỗ trợ định dạng cũ `LOCALPASSPORT|<id>|<secret>`).

```bash
cd tools/qr
npm install
npm run generate
```

---

## Nguồn ảnh TimeLens

Ảnh lấy từ Wikimedia Commons, đã cắt tỉ lệ 20:13 và thu nhỏ; ảnh "xưa" phủ hiệu ứng sepia khi hiển thị. Bản phái sinh giữ nguyên giấy phép gốc.

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
| `nghia-trung_past.jpg` | [The French-Spanish coalition invaded Dien Hai citadel in 1858](https://commons.wikimedia.org/wiki/File:The_French-Spanish_coalition_invaded_Dien_Hai_citadel_in_1858.jpg) | Antoine Léon Morel-Fatio (1860) | Public domain |
| `nghia-trung_present.jpg` | [Nghĩa trủng Hòa Vang, Đà Nẵng](https://commons.wikimedia.org/wiki/File:Ngh%C4%A9a_tr%E1%BB%A7ng_H%C3%B2a_Vang,_%C4%90%C3%A0_N%E1%BA%B5ng.jpeg) | Linhcandng | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `hoang-sa_past.jpg` | [An Nam Dai Quoc Hoa Do by Jean Louis Taberd 1838](https://commons.wikimedia.org/wiki/File:An_Nam_Dai_Quoc_Hoa_Do_by_Jean_Louis_Taberd_1838.jpg) | Jean-Louis Taberd (1838) | Public domain |
| `hoang-sa_present.jpg` | [Hoang Sa Exhibition House, Da Nang](https://commons.wikimedia.org/wiki/File:Hoang_Sa_Exhibition_House,_Da_Nang.jpeg) | Linhcandng | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) |
| `linh-ung_past.jpg` | [La baie de Tourane](https://commons.wikimedia.org/wiki/File:La_baie_de_Tourane.jpg) | Khuyết danh (1934) | Public domain |
| `linh-ung_present.jpg` | [Chùa Linh Ứng - Sơn Trà - NKS](https://commons.wikimedia.org/wiki/File:Ch%C3%B9a_Linh_%E1%BB%A8ng_-_S%C6%A1n_Tr%C3%A0_-_NKS.jpg) | NKSTTSSHNVN | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |
| `non-nuoc_past.jpg` | [Annam - Tourane - L'Entrée de la Grotte et les Montagnes de Marbre](https://commons.wikimedia.org/wiki/File:Annam_-_Tourane_-_L%27Entr%C3%A9e_de_la_Grotte_et_les_Montagnes_de_Marbre.jpg) | Khuyết danh (đầu TK XX) | Public domain |
| `non-nuoc_present.jpg` | [Marble Mountain sculpture shop](https://commons.wikimedia.org/wiki/File:Marble_Mountain_sculpture_shop.jpg) | www.viajar24h.com | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0/) |
| `nam-o_present.jpg` | [Nam Ô, Đà Nẵng](https://commons.wikimedia.org/wiki/File:Nam_%C3%94,_%C4%90%C3%A0_N%E1%BA%B5ng.jpg) | Bánhmỳchảo | CC0 |
| `tuy-loan_present.jpg` | [Handmade rice paper wrappers drying on bamboo mats](https://commons.wikimedia.org/wiki/File:Handmade_rice_paper_wrappers_drying_on_bamboo_mats.jpg) | Wanderingspoon | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

---

## Quyền ứng dụng

- **Android** (`AndroidManifest.xml`): `INTERNET`, `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- **iOS** (`Info.plist`): `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`.
- **Web**: trình duyệt hỏi quyền camera/vị trí; yêu cầu HTTPS hoặc `localhost`.
