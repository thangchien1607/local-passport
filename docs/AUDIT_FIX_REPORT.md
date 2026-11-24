# Báo cáo khắc phục kỹ thuật — Local Passport (Giai đoạn 1–3)

- **Nhánh làm việc**: `fix/audit-all-phases` (tạo từ `origin/develop` commit `34ceb7f`, đồng bộ cây mã nguồn với `origin/main` `9cb757f` theo `git.md` và `AGENTS.md`).
- **Lưu ý về thay đổi cục bộ trước khi bắt đầu**: Các thay đổi chưa commit trên nhánh cục bộ trước đó (`feature/sync-latest-develop`) đã được cất an toàn bằng `git stash -u` dưới tên **`stash@{0}: On feature/sync-latest-develop: pre-audit-stash`** (có thể khôi phục bằng `git stash show -p stash@{0}` hoặc `git stash pop` trên nhánh cũ nếu cần).
- **Trạng thái dự án thật**: Không có lệnh `firebase deploy` nào được chạy và không có dữ liệu nào bị ghi/xóa trên dự án Firebase thật. Mọi kiểm thử đều chạy cục bộ và trên **Firebase Emulator Suite**.

---

## 1. Tổng hợp kết quả theo từng hạng mục

| Giai đoạn | Hạng mục | Trạng thái | Commit | Ghi chú |
| --- | --- | --- | --- | --- |
| **P0 — 1.1** | Chuyển ảnh từ Base64 sang Firebase Storage + nén ảnh phía client + `storage.rules` + đọc tương thích ngược | **Đã sửa** | `e421b50` | Ảnh nén cạnh dài <= 1280px, JPEG 80%; Firestore chỉ lưu `photoUrl` / `taskPhotoUrls` (< 50 KB); chặn base64 mới; vẫn đọc hiển thị ảnh `photoBase64` / `taskPhotos` cũ. |
| **P0 — 1.2** | Cloud Function `verifyReflection` chấm điểm AI + xác thực ID Token + Secret Manager + rate limit + khóa `aiScore` | **Đã sửa** | `4a54697` | TypeScript Node 22 LTS; lớp `AiVerifierAdapter` thay thế được (`gemini`, `openai-compatible`, `heuristic-server`); trả 401 khi thiếu/sai token, 429 khi vượt rate limit; Admin SDK tự ghi `aiScore`; `firestore.rules` chặn client ghi `aiScore`. |
| **P0 — 1.3** | Sửa `sync()` trong `passport_remote.dart` (chia lô <= 450, bỏ `_written`, idempotent) | **Đã sửa** | `e228b5c` | Chia lô nguyên tử `WriteBatch <= 450` (giữ cặp `reflection_owners` + `reflections` chung batch); đối chiếu trực tiếp server thay vì `_written`; kiểm tra tồn tại `reflection_owners` để không gặp `permission-denied`; test thành công > 500 bản ghi & sync lặp lại. |
| **P0 — 1.4** | Siết schema rules cho `user_passports/{uid}` + bộ test Firebase Emulator (`@firebase/rules-unit-testing`) | **Đã sửa** | `99d5a93` | Thêm helper `validPassport`, `validVisit`, `validNotification` trong `firestore.rules`; viết bộ test `rules_tests/` chạy trên Firestore + Storage Emulator cho 1.1–1.4. |
| **P1 — 2.1** | Loại bỏ vòng lặp N+1 trong `fetch()` bằng `whereIn` (<= 30 ID/lô, `Future.wait`) | **Đã sửa** | `e6dd177` | Đọc song song `user_passports`, `visits`, `notifications`, `reflection_owners` và truy vấn lô `reflections` bằng `FieldPath.documentId whereIn` tối đa 30 ID/lô. |
| **P1 — 2.2** | Leaderboard công khai (`leaderboard_public`) qua Cloud Function trigger + cập nhật UI & rules | **Đã sửa** | `3d2d33b` | `syncLeaderboardOnPassportWrite` chỉ trích xuất `displayName`, `xp`, `stampCount`, `avatarUrl`; không lộ `user_passports`; thêm composite index `(xp DESC, stampCount DESC)`; `LeaderboardScreen` đọc `leaderboard_public` & có `RefreshIndicator`. |
| **P1 — 2.3** | Phân trang `fetchCommunity()` bằng `startAfterDocument` + infinite scroll + `snapshots()` realtime | **Đã sửa** | `48ca970` | Thêm `fetchCommunityPage` (`startAfterDocument`), `watchLatestCommunity` (`snapshots()`) và cuộn vô hạn + kéo làm mới trong `CommunityScreen`. |
| **P1 — 2.4** | Cho tác giả sửa nội dung/ảnh bài cảm nhận & tự kích hoạt chấm lại AI qua Cloud Function | **Đã sửa** | `bb57db0` | Cập nhật `firestore.rules` cho tác giả sửa `content`/`photoUrl` (vẫn khóa `aiScore`/`photoBase64`); thêm `EditReflectionDialog`, nút **Sửa** trên `ReflectionCard`, và trigger `rescoreReflectionOnUpdate` (chống vòng lặp vô hạn). |
| **P2 — 3.1** | Google Sign-In, Apple Sign-In, xác minh email, đổi mật khẩu, xóa tài khoản + Cloud Function dọn Firestore & Storage | **Đã sửa** | `c85eef9` | Hỗ trợ nâng khách lên Google/Apple/Email; tự gửi `sendEmailVerification`; đổi mật khẩu có re-auth; Cloud Function `deleteUserAccountData` xóa toàn bộ Firestore + Storage prefix `users/{uid}/` + Auth user. |
| **P2 — 3.2** | Cấu hình `MAPS_API_KEY` cho iOS từ `.xcconfig` (không commit key thật, có `.example`) | **Đã sửa** | `a2dcb59` | Tạo `ios/Flutter/Secrets.xcconfig.example`, chặn `ios/Flutter/Secrets.xcconfig` trong `.gitignore`, nối `Debug/Release.xcconfig` → `Info.plist` → `AppDelegate.swift` (`GMSServices.provideAPIKey`). |
| **P2 — 3.3** | Rà soát `Permissions-Policy` trong `firebase.timelens.json` | **Đã sửa** | `622a39f` | Đổi `camera=(), geolocation=()` thành `camera=(self), geolocation=(self), microphone=()` + thêm unit test hồi quy. |
| **P2 — 3.4** | Viết lại `README.md` đúng kiến trúc hiện tại | **Đã sửa** | `1416791` | Cập nhật đầy đủ Auth, Firestore, Storage, Functions, Maps đa nền tảng, Emulator và hướng dẫn deploy. |

- **Vấn đề bỏ qua (đã sửa từ trước)**: Không có (toàn bộ 12 hạng mục đều được xác nhận còn tồn tại trên commit gốc `34ceb7f` trước khi thực hiện).
- **Vấn đề không hoàn thành**: Không có (12/12 hạng mục hoàn thành và pass đầy đủ kiểm thử).

---

## 2. Thay đổi Rules & Schema

### Cloud Firestore (`firestore.rules` & `firestore.indexes.json`)
- **`user_passports/{uid}`**: Chỉ chủ sở hữu (`request.auth.uid == uid`) đọc/ghi/xóa. Ghi phải qua `validPassport`: bắt buộc `name` (1–60 ký tự), `passportNo` (3–32 ký tự), `joinedAt` (timestamp), `xp` (int 0..1,000,000), `stampCount` (int 0..500), tùy chọn `avatarUrl` (URL HTTP/HTTPS <= 2048 ký tự); cấm mọi trường thừa.
- **`user_passports/{uid}/visits/{locationId}`**: Phải qua `validVisit`: bắt buộc `unlocked` (bool) và `tasks` (list <= 30); cho phép `taskPhotoUrls` (map <= 20), `unlockedAt`, `stampedAt`; **từ chối trường `taskPhotos` (base64)**.
- **`user_passports/{uid}/notifications/{notificationId}`**: Phải qua `validNotification`: bắt buộc `type` (<= 32), `title` (<= 120), `body` (<= 400), `read` (bool), `createdAt` (timestamp), tùy chọn `locationId` (<= 80).
- **`reflections/{id}`**:
  - Đọc công khai.
  - Tạo mới (`validReflectionCreate`): phải đi kèm `reflection_owners/{id}` cho đúng `uid`, **từ chối `aiScore` và `photoBase64`**, chỉ chấp nhận `photoUrl` hợp lệ (`https?://`).
  - Cập nhật (`validReflectionUpdate`): chỉ chủ sở hữu (`ownerOf(id) == request.auth.uid`) được sửa `displayAuthor`, `isAnonymous`, `content`, `photoUrl`, `updatedAt`; **chặn tuyệt đối sửa `aiScore`, `photoBase64`, `locationId`, `createdAt`**.
- **`reflection_owners/{id}`**: Chủ bài đọc/tạo/xóa; **`allow update: if false`**.
- **`leaderboard_public/{uid}`** (mới): `allow read: if true; allow write: if false;` (chỉ Cloud Function Admin SDK ghi). Thêm composite index `(xp DESC, stampCount DESC)`.
- **`_rate_limits/{docId}`** (mới): `allow read, write: if false;` (nội bộ Cloud Functions).

### Firebase Storage (`storage.rules`)
- `users/{uid}/tasks/{locationId}/{fileName}`: chỉ chủ sở hữu đọc/ghi/xóa.
- `users/{uid}/reflections/{fileName}` và `users/{uid}/avatars/{fileName}`: đọc công khai, chỉ chủ sở hữu ghi/xóa.
- Ràng buộc upload: `size <= 5 MB`, `contentType` khớp `image/(jpeg|png|webp)`. Mọi đường dẫn khác bị chặn mặc định.

---

## 3. Danh sách tệp đã thay đổi / thêm mới

### Cấu hình & Rules
- `.gitignore`
- `firebase.json`
- `firebase.timelens.json`
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules` *(mới)*
- `pubspec.yaml`, `pubspec.lock`
- `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Flutter/Secrets.xcconfig.example` *(mới)*
- `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`

### Ứng dụng Flutter (`lib/`)
- `lib/main.dart`
- `lib/data/community.dart`
- `lib/services/photo_service.dart` *(mới)*
- `lib/services/ai_verifier.dart`
- `lib/services/passport_remote.dart`
- `lib/services/auth_service.dart`
- `lib/services/maps_config.dart`
- `lib/state/passport_store.dart`
- `lib/screens/location_screen.dart`
- `lib/screens/stamp_ceremony.dart`
- `lib/screens/community_screen.dart`
- `lib/screens/leaderboard_screen.dart`
- `lib/screens/passport_screen.dart`
- `lib/widgets/passport_photo.dart` *(mới)*
- `lib/widgets/edit_reflection_dialog.dart` *(mới)*
- `lib/widgets/reflection_card.dart`
- `lib/widgets/auth_form.dart`

### Cloud Functions (`functions/`) *(mới)*
- `functions/package.json`, `functions/package-lock.json`, `functions/tsconfig.json`, `functions/tsconfig.test.json`
- `functions/src/index.ts`
- `functions/src/ai/adapter.ts`, `functions/src/ai/rateLimit.ts`, `functions/src/ai/verifyReflection.ts`, `functions/src/ai/rescoreOnReflectionEdit.ts`
- `functions/src/leaderboard/syncLeaderboard.ts`
- `functions/src/auth/deleteAccount.ts`
- `functions/test/verifyReflection.test.ts`, `functions/test/rescoreOnEdit.test.ts`, `functions/test/syncLeaderboard.test.ts`, `functions/test/deleteAccount.test.ts`

### Kiểm thử & Tài liệu
- `rules_tests/package.json`, `rules_tests/package-lock.json`, `rules_tests/firestore.rules.test.mjs`, `rules_tests/storage.rules.test.mjs` *(mới)*
- `test/photo_storage_test.dart` *(mới)*
- `test/ai_verifier_test.dart` *(mới)*
- `test/passport_remote_sync_test.dart` *(mới)*
- `test/passport_remote_fetch_test.dart` *(mới)*
- `test/community_pagination_test.dart` *(mới)*
- `test/auth_flow_test.dart`, `test/leaderboard_test.dart`, `test/maps_config_test.dart`, `test/passport_remote_test.dart`, `test/reflection_edit_test.dart`, `test/timelens_demo_test.dart`
- `README.md`, `docs/DECISIONS.md`, `docs/MANUAL_STEPS.md`, `docs/AUDIT_FIX_REPORT.md`

---

## 4. Kết quả kiểm tra cuối cùng

| Kiểm tra | Lệnh chạy | Kết quả |
| --- | --- | --- |
| Format Dart | `dart format --output=none --set-exit-if-changed lib test` | **PASS** (57 files, 0 thay đổi) |
| Phân tích tĩnh | `flutter analyze` | **PASS** (`No issues found!`) |
| Unit & Widget test Flutter | `flutter test` | **PASS** (**47/47** test đạt) |
| Build release Web | `flutter build web --release` | **PASS** (`Built build\web`, Wasm dry run thành công) |
| Build & Test Cloud Functions | `cd functions && npm run build && npm test` | **PASS** (**12/12** test đạt) |
| Test Firestore & Storage Rules (Emulator) | `cd rules_tests && npm test` | **PASS** (**16/16** test đạt trên Firestore + Storage Emulator) |

---

## 5. Rủi ro còn lại & cách rollback

### Rủi ro còn lại cần lưu ý trước khi đưa lên production
1. **Triển khai theo đúng thứ tự**: Cần deploy `storage.rules`, `firestore.indexes.json` và `functions` **trước** khi deploy phiên bản Web/mobile mới nhất để các endpoint `verifyReflection`, `deleteUserAccountData` và trigger `syncLeaderboardOnPassportWrite` sẵn sàng.
2. **Bản build iOS**: Không thể biên dịch Xcode trên môi trường Windows. Cần chạy `flutter build ios` trên macOS sau khi tạo `ios/Flutter/Secrets.xcconfig` và cài CocoaPods (`pod install`).
3. **Dữ liệu `leaderboard_public` ban đầu**: Trigger `syncLeaderboardOnPassportWrite` chỉ chạy khi `user_passports/{uid}` có thao tác ghi mới. Với các tài khoản cũ đã tồn tại trước khi deploy trigger, cần chạy backfill một lần hoặc chờ người dùng đồng bộ lại (chi tiết tại `docs/MANUAL_STEPS.md`).
4. **Hạn mức gói Blaze & Secret AI**: Cần thiết lập `AI_API_KEY` trong Secret Manager và đặt Budget Alert trên Google Cloud Billing trước khi bật public.

### Cách rollback
- **Rollback theo từng hạng mục**: Mỗi hạng mục là một commit độc lập trên nhánh `fix/audit-all-phases`. Có thể hoàn tác riêng lẻ bằng `git revert <commit-hash>` (ví dụ `git revert c85eef9`).
- **Rollback toàn bộ nhánh**: Quay về `develop` (`git switch develop`) hoặc không merge nhánh `fix/audit-all-phases`.
- **Rollback trên Firebase (sau khi đã deploy)**: Dùng Firebase Console → Firestore Rules / Storage Rules → tab **Releases** để khôi phục bản rules trước đó, hoặc triển khai lại từ commit ổn định trên `main`.

---

## 6. Tài liệu liên quan

- Hướng dẫn các bước cần làm thủ công trên Firebase thật: **[docs/MANUAL_STEPS.md](MANUAL_STEPS.md)**
- Các quyết định kiến trúc trong đợt khắc phục: **[docs/DECISIONS.md](DECISIONS.md)**
