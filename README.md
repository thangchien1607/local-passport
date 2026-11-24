# Local Passport (Flutter) — Hộ chiếu trải nghiệm văn hóa Đà Nẵng

Ứng dụng **Local Passport** viết bằng Flutter (Dart `^3.11.3`), chạy trên **Web, Android và iOS** từ cùng một mã nguồn, sử dụng **Firebase Auth, Cloud Firestore, Firebase Storage và Cloud Functions (TypeScript / Node 22 LTS)**.

---

## Kiến trúc hiện tại

### 1. Xác thực (`firebase_auth`)
- **Email & Mật khẩu**: đăng ký (tự gửi `sendEmailVerification`), đăng nhập, quên mật khẩu, xác minh email, đổi mật khẩu (có re-authenticate).
- **Google Sign-In & Apple Sign-In**: tích hợp qua `GoogleAuthProvider` / `AppleAuthProvider` (popup trên Web, provider flow trên Android/iOS).
- **Tài khoản khách (Anonymous)**: vào nhanh, có thể nâng cấp lên tài khoản Email / Google / Apple mà vẫn giữ nguyên `uid`, dấu mộc và tiến độ.
- **Xóa tài khoản vĩnh viễn**: gọi Cloud Function `deleteUserAccountData` để xóa sạch toàn bộ dữ liệu Firestore, ảnh trên Firebase Storage (`users/{uid}/`) và tài khoản Firebase Auth.
- **Chế độ cục bộ (offline / chưa cấu hình Firebase)**: lưu trên thiết bị bằng `shared_preferences`.

### 2. Dữ liệu & đồng bộ (`cloud_firestore`)
- `user_passports/{uid}`: hồ sơ, XP, số dấu mộc (`validPassport` kiểm tra schema chặt chẽ, chỉ chủ tài khoản đọc/ghi).
  - `user_passports/{uid}/visits/{locationId}`: trạng thái mở khóa, danh sách nhiệm vụ, `taskPhotoUrls`, thời điểm đóng dấu (từ chối `taskPhotos` base64 mới).
  - `user_passports/{uid}/notifications/{id}`: thông báo trong ứng dụng.
- `reflections/{id}`: bài cảm nhận công khai (chỉ lưu `photoUrl`, từ chối `photoBase64` mới; trường `aiScore` chỉ do Cloud Function ghi bằng Admin SDK; tác giả được sửa `content`/`photoUrl`/`isAnonymous`/`displayAuthor` và xóa bài).
- `reflection_owners/{id}`: lưu `uid` chủ bài viết (`allow update: if false`, bất biến sau khi tạo).
- `leaderboard_public/{uid}`: bảng xếp hạng công khai (`displayName`, `xp`, `stampCount`, `avatarUrl`) do Cloud Function trigger tổng hợp từ `user_passports/{uid}`; client chỉ được đọc (`allow write: if false`), không lộ `user_passports`.
- `_rate_limits/{doc}`: dữ liệu giới hạn tần suất nội bộ của Cloud Functions (chặn hoàn toàn client).
- **Đồng bộ & truy vấn**:
  - `sync()` chia lô nguyên tử `WriteBatch <= 450` thao tác, không phụ thuộc cache `_written`, kiểm tra tồn tại `reflection_owners/{id}` để đảm bảo idempotent.
  - `fetch()` tải song song bằng `Future.wait` và gom lô `whereIn` (tối đa 30 ID/nhóm), loại bỏ vòng lặp N+1.
  - Bảng tin cộng đồng dùng phân trang `startAfterDocument` + infinite scroll + luồng `snapshots()` realtime cho bài mới.

### 3. Lưu trữ ảnh (`firebase_storage`)
- Ảnh chụp nhiệm vụ và ảnh bài cảm nhận được nén phía client trước khi tải lên (cạnh dài tối đa ~1280px, JPEG chất lượng ~80% qua `flutter_image_compress` trên mobile và `image` trên Web/desktop).
- Đường dẫn theo `uid`:
  - `users/{uid}/tasks/{locationId}/{file}` (chỉ chủ sở hữu đọc/ghi)
  - `users/{uid}/reflections/{file}` (công khai đọc, chỉ chủ sở hữu ghi/xóa)
  - `users/{uid}/avatars/{file}` (công khai đọc, chỉ chủ sở hữu ghi/xóa)
- `storage.rules` giới hạn kích thước <= 5 MB và chỉ chấp nhận `image/(jpeg|png|webp)`.
- Firestore chỉ lưu URL (`photoUrl`, `taskPhotoUrls`); client vẫn đọc tương thích ngược với ảnh `photoBase64` / `taskPhotos` cũ.

### 4. Cloud Functions (`functions/`, TypeScript)
- `verifyReflection` (HTTPS v2, `asia-southeast1`): xác thực `Authorization: Bearer <Firebase ID Token>` (trả 401 nếu thiếu/sai), rate limit theo `uid` (429), gọi mô hình AI qua lớp adapter có thể đổi (`GeminiAiAdapter`, `OpenAiCompatibleAdapter`, `HeuristicFallbackAdapter` dùng `AI_API_KEY` trong Secret Manager) và tự ghi `aiScore` vào Firestore bằng Admin SDK.
- `rescoreReflectionOnUpdate` (Firestore trigger): tự động chấm lại và cập nhật `aiScore` khi tác giả sửa nội dung hoặc ảnh bài cảm nhận.
- `syncLeaderboardOnPassportWrite` (Firestore trigger): đồng bộ dữ liệu tối thiểu từ `user_passports/{uid}` sang `leaderboard_public/{uid}`.
- `deleteUserAccountData` (HTTPS v2): xác thực ID Token và dọn sạch Firestore, Storage (`users/{uid}/`) và tài khoản Auth.

---

## Cài đặt & chạy thử cục bộ

### 1. Yêu cầu môi trường
- Flutter SDK (Dart `^3.11.3`)
- Node.js 22 LTS & npm (cho `functions/` và `rules_tests/`)
- Java 17+ (cho Firebase Emulator Suite)
- Android Studio (Android) / macOS + Xcode (iOS)

### 2. Chạy ứng dụng Flutter
```bash
flutter pub get
flutter run -d chrome        # Web (hoặc -d edge)
flutter run                  # Android/iOS
```

Kèm dữ liệu thử Hòa Khánh và trỏ tới Cloud Functions Emulator cục bộ:
```bash
flutter run -d chrome \
  --dart-define=LOCAL_PASSPORT_TEST_DATA=true \
  --dart-define=CLOUD_FUNCTIONS_BASE_URL=http://127.0.0.1:5001/local-passport-danang/asia-southeast1
```

> Camera quét QR trên Web chỉ hoạt động qua **HTTPS hoặc localhost**. Khi demo, có thể dùng nút **Giả lập quét QR (Demo)**.

### 3. Chạy Firebase Emulator Suite & kiểm thử
```bash
# 1. Cài đặt và chạy test Cloud Functions
cd functions
npm install
npm run build
npm test
cd ..

# 2. Cài đặt và chạy test Firestore Rules & Storage Rules trên Emulator
cd rules_tests
npm install
npm test
cd ..

# 3. Khởi động đầy đủ Emulator (Auth, Firestore, Storage, Functions, UI)
npx firebase emulators:start --project demo-local-passport

# 4. Kiểm tra mã nguồn & test Flutter
dart format lib test
flutter analyze
flutter test
```

---

## Google Maps (Web / Android / iOS)

Bản đồ Khám phá tự dùng **Google Maps** khi có API key; nếu để trống thì dùng bản đồ minh họa (`DiscoveryMap`).

```bash
flutter run -d chrome --dart-define=MAPS_API_KEY=<key>
flutter build web --release --dart-define=MAPS_API_KEY=<key>
flutter build apk --dart-define=MAPS_API_KEY=<key>
```

- **Web**: bật **Maps JavaScript API**, giới hạn theo HTTP referrer.
- **Android**: bật **Maps SDK for Android**, đọc `--dart-define=MAPS_API_KEY` qua `android/app/build.gradle.kts` → `AndroidManifest.xml`.
- **iOS**: bật **Maps SDK for iOS**, sao chép `ios/Flutter/Secrets.xcconfig.example` thành `ios/Flutter/Secrets.xcconfig` (đã nằm trong `.gitignore`), điền `MAPS_API_KEY=<key>`. `Info.plist` và `AppDelegate.swift` tự đọc key từ file này.
- **Tuyệt đối không commit API key thật vào repo.**

---

## Triển khai (Deploy) lên Firebase

> Xem hướng dẫn cấu hình chi tiết lần đầu (bật gói Blaze, đặt `AI_API_KEY` trong Secret Manager, bật Google/Apple provider, migrate ảnh cũ) tại [docs/MANUAL_STEPS.md](docs/MANUAL_STEPS.md).

```bash
# 1. Thiết lập secret AI (làm một lần)
firebase functions:secrets:set AI_API_KEY

# 2. Triển khai Rules, Indexes và Cloud Functions
cd functions && npm ci && npm run build && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions

# 3. Build và triển khai bản Web lên Firebase Hosting
flutter build web --release \
  --dart-define=CLOUD_FUNCTIONS_BASE_URL=https://asia-southeast1-local-passport-danang.cloudfunctions.net \
  --dart-define=MAPS_API_KEY=<key>
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
  main.dart                          App, khởi tạo Firebase (Auth/Firestore/Storage), điều hướng
  main_timelens.dart                 Entrypoint bản demo public TimeLens
  firebase_options.dart              Cấu hình công khai Firebase project
  theme.dart                         Design system (màu, font, nút dùng chung)
  data/
    routes.dart                      Tuyến & 10 địa điểm Đà Nẵng
    community.dart                   Model Reflection, LeaderEntry & dữ liệu mẫu
    notifications.dart               Model thông báo trong app
  state/
    passport_store.dart              Quản lý trạng thái hộ chiếu, đồng bộ, phân trang, realtime
  services/
    auth_service.dart                Firebase Auth (Email, Google, Apple, Guest, đổi mật khẩu, xóa TK)
    passport_remote.dart             Firestore sync theo lô <= 450, fetch whereIn <= 30, phân trang & snapshots
    photo_service.dart               Nén ảnh (~1280px, 80%) và tải lên Firebase Storage
    ai_verifier.dart                 Gọi Cloud Function verifyReflection kèm Firebase ID Token
    geo.dart                         Haversine, GPS (geolocator), định dạng mã QR
    maps_config.dart                 Cấu hình Google Maps đa nền tảng
    validators.dart                  Kiểm tra đầu vào form
  screens/                           Welcome, Map, Location, QR Scanner, Stamp Ceremony, Passport, Community, Leaderboard, TimeLens, Notifications
  widgets/                           AuthForm, ReflectionCard, EditReflectionDialog, PassportPhoto, TimeLens, StampSeal...
functions/
  src/ai/                            verifyReflection, adapter AI, rateLimit, rescoreOnReflectionEdit
  src/leaderboard/                   syncLeaderboardOnPassportWrite
  src/auth/                          deleteUserAccountData
  test/                              Unit test Cloud Functions (Node test runner)
rules_tests/                         Kiểm thử Firestore Rules & Storage Rules trên Firebase Emulator Suite
firestore.rules / storage.rules      Quy tắc bảo mật Firestore & Storage
firestore.indexes.json               Composite index cho bảng xếp hạng công khai
docs/
  DECISIONS.md                       Các quyết định kiến trúc trong đợt sửa lỗi kỹ thuật
  MANUAL_STEPS.md                    Các bước thao tác thủ công trên dự án Firebase thật
  AUDIT_FIX_REPORT.md                Báo cáo tổng kết đợt kiểm toán & khắc phục kỹ thuật
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
