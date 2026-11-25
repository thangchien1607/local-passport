# Báo cáo khắc phục kỹ thuật & chuyển sang thuần Firebase Spark — Local Passport

- **Nhánh hiện tại**: `refactor/spark-only` (tạo từ nhánh `fix/audit-all-phases` commit `7445da1`, vốn đã chứa toàn bộ 12 hạng mục sửa lỗi Firestore/FE/Auth của Giai đoạn 1–3).
- **Mục tiêu kiến trúc**: Vận hành **100% trên gói Firebase Spark (miễn phí)** — chỉ dùng **Firebase Auth + Cloud Firestore**, gỡ bỏ hoàn toàn `functions/` và `firebase_storage`, đồng thời giữ trọn toàn bộ các bản sửa lỗi quan trọng về đồng bộ lô `<= 450`, loại bỏ N+1 `whereIn <= 30`, phân trang + realtime `snapshots()`, sửa bài cảm nhận, Google/Apple Sign-In, xác minh email, đổi mật khẩu, Google Maps iOS xcconfig và `Permissions-Policy`.
- **Trạng thái dự án thật**: Không có lệnh `firebase deploy` nào được chạy và không có dữ liệu nào bị ghi/xóa trên dự án Firebase thật. Toàn bộ kiểm thử chạy cục bộ và trên **Firebase Emulator Suite (Firestore Emulator)**.
- **Ghi chú stash trước đó**: Thay đổi cục bộ chưa commit trước đợt kiểm toán trên nhánh cũ vẫn được giữ an toàn tại `stash@{0}: On feature/sync-latest-develop: pre-audit-stash`.

---

## 1. Tổng hợp kết quả chuyển đổi thuần Firebase Spark (S1–S6)

| Hạng mục | Nội dung thực hiện | Trạng thái | Commit |
| --- | --- | --- | --- |
| **S1** | Gỡ Cloud Functions (`functions/`), Firebase Storage (`firebase_storage`, `storage.rules`, `rules_tests/storage.rules.test.mjs`) và dọn `firebase.json` / `.gitignore` / script Emulator chỉ còn `auth` + `firestore` | **Hoàn thành** | `e979d1f` |
| **S2** | Nén ảnh vòng lặp ở client (`720px`, JPEG `70` → mục tiêu `<= 80 KB`, từ chối nếu vẫn `> 120 KB` / `> 120000` ký tự Base64); lưu `photoBase64` và `taskPhotos` (tối đa 3 ảnh/visit), chặn document `> 800 KB`, đọc tương thích ngược `photoUrl` / `taskPhotoUrls`, cập nhật `firestore.rules` | **Hoàn thành** | `e80fcec` |
| **S3** | Chấm điểm AI mặc định dùng heuristic offline; chỉ gọi endpoint ngoài khi có `--dart-define=REFLECTION_VERIFIER_URL` kèm `Authorization: Bearer <Firebase ID Token>` và tự fallback về heuristic khi lỗi/timeout; chấm lại ở client khi sửa bài; rules kiểm tra `aiScore` nguyên `0..100` | **Hoàn thành** | `17d7ea6` |
| **S4** | Leaderboard công khai do client tự ghi `{displayName, xp, stampCount, avatarUrl, updatedAt}` vào `leaderboard_public/{uid}` có debounce `5 giây`; rules siết quyền chỉ chủ sở hữu ghi/xóa trong ngưỡng hợp lý (`displayName <= 40`, `xp 0..50000`, `stampCount 0..200`); giữ composite index `(xp DESC, stampCount DESC)` | **Hoàn thành** | `2cff3bb` |
| **S5** | Xóa tài khoản hoàn toàn từ client theo đúng thứ tự: (1) Re-auth theo nhà cung cấp (mật khẩu / Google / Apple), xử lý rõ `requires-recent-login`; (2) Xóa toàn bộ dữ liệu Firestore của `uid` theo lô `<= 450` (giữ nguyên tử cặp `reflections` + `reflection_owners`, idempotent khi retry); (3) Chỉ gọi `user.delete()` sau khi xóa dữ liệu thành công | **Hoàn thành** | `f211582` |
| **S6** | Hoàn thiện bộ test Flutter & Firestore Emulator rules tests, cập nhật `README.md`, `docs/MANUAL_STEPS.md`, `docs/DECISIONS.md` và báo cáo này, xác minh `flutter build web --release` | **Hoàn thành** | *(commit hiện tại)* |

### Các bản sửa từ `fix/audit-all-phases` được giữ nguyên vẹn
- `sync()` chia lô nguyên tử `WriteBatch <= 450`, bỏ cache `_written`, idempotent (`e228b5c`).
- `firestore.rules` siết schema nghiêm ngặt cho `user_passports/{uid}`, `visits`, `notifications` (`99d5a93`).
- `fetch()` tải song song `Future.wait` + gom lô `whereIn <= 30`, xóa vòng lặp N+1 (`e6dd177`).
- Phân trang cộng đồng `startAfterDocument` + infinite scroll + realtime `snapshots()` (`48ca970`).
- Cho tác giả sửa nội dung/ảnh bài cảm nhận & tự chấm lại điểm (`bb57db0`, đã chuyển chấm lại sang client ở S3).
- Google Sign-In, Apple Sign-In, xác minh email, đổi mật khẩu có re-auth (`c85eef9`).
- Cấu hình Google Maps key cho iOS qua `ios/Flutter/Secrets.xcconfig` (`a2dcb59`).
- `Permissions-Policy: camera=(self), geolocation=(self), microphone=()` trong `firebase.timelens.json` (`622a39f`).

---

## 2. Thay đổi Rules & Schema Firestore (`firestore.rules` & `firestore.indexes.json`)

- **`user_passports/{uid}`**: `allow read, delete: if isOwnerUid(uid)`; tạo/sửa qua `validPassport` (kiểm tra đủ trường bắt buộc, kiểu, giới hạn độ dài/giá trị, chặn trường thừa).
- **`user_passports/{uid}/visits/{locationId}`**: `allow read, delete: if isOwnerUid(uid)`; tạo/sửa qua `validVisit` — **`taskPhotos`** phải là `list` tối đa `3` phần tử, mỗi phần tử là `string` độ dài `1..120000`; giữ tương thích ngược `taskPhotoUrls` (map `<= 3`).
- **`user_passports/{uid}/notifications/{notificationId}`**: `allow read, delete: if isOwnerUid(uid)`; tạo/sửa qua `validNotification`.
- **`reflections/{id}`**:
  - `allow read: if true`.
  - Tạo mới (`validReflectionCreate`): phải đi kèm `reflection_owners/{id}` đúng `uid`; **`photoBase64`** là `null` hoặc `string <= 120000`; **`aiScore`** là `int` trong `0..100`; tương thích ngược `photoUrl` (`https?://`, `<= 2048`).
  - Sửa (`validReflectionUpdate`): chỉ chủ sở hữu (`ownerOf(id) == request.auth.uid`), khóa `locationId` và `createdAt`, kiểm tra lại `aiScore` (`0..100`) và `photoBase64` (`<= 120000`).
  - Xóa: chỉ chủ sở hữu (`ownerOf(id) == request.auth.uid`).
- **`reflection_owners/{id}`**: chủ sở hữu đọc/tạo/xóa; **`allow update: if false`**.
- **`leaderboard_public/{uid}`**:
  - `allow read: if true`.
  - `allow create, update: if isOwnerUid(uid) && validLeaderboardEntry(request.resource.data)` — đúng 5 trường `displayName` (`1..40`), `xp` (`int 0..50000`), `stampCount` (`int 0..200`), `avatarUrl` (URL HTTP/HTTPS `<= 2048` hoặc `null`), `updatedAt` (`timestamp`).
  - `allow delete: if isOwnerUid(uid)`.
  - Giữ composite index `(xp DESC, stampCount DESC)` trong `firestore.indexes.json`.
- **Đã gỡ**: `storage.rules` và quy tắc `_rate_limits`.

---

## 3. Danh sách tệp thay đổi / xóa trong đợt chuyển đổi Spark (`fix/audit-all-phases..HEAD`)

### Đã xóa hoàn toàn
- Toàn bộ thư mục `functions/` (source TypeScript, config, tests)
- `storage.rules`
- `rules_tests/storage.rules.test.mjs`

### Đã cập nhật
- **Cấu hình & Rules**: `.gitignore`, `firebase.json`, `firestore.rules`, `pubspec.yaml`, `pubspec.lock`, `rules_tests/package.json`
- **Ứng dụng Flutter (`lib/`)**: `lib/main.dart`, `lib/data/community.dart`, `lib/services/photo_service.dart`, `lib/services/ai_verifier.dart`, `lib/services/passport_remote.dart`, `lib/services/auth_service.dart`, `lib/state/passport_store.dart`, `lib/screens/location_screen.dart`, `lib/screens/stamp_ceremony.dart`, `lib/screens/passport_screen.dart`, `lib/widgets/edit_reflection_dialog.dart`, `lib/widgets/passport_photo.dart`
- **Kiểm thử**: `rules_tests/firestore.rules.test.mjs`, `test/photo_storage_test.dart`, `test/ai_verifier_test.dart`, `test/leaderboard_test.dart`, `test/auth_flow_test.dart`, `test/passport_remote_sync_test.dart`, `test/passport_remote_test.dart`, `test/community_pagination_test.dart`
- **Tài liệu**: `README.md`, `docs/MANUAL_STEPS.md`, `docs/DECISIONS.md`, `docs/AUDIT_FIX_REPORT.md`

---

## 4. Đánh đổi của kiến trúc Spark

1. **`aiScore` và `xp` / `stampCount` không chống gian lận tuyệt đối**: Do không có Cloud Function dùng Admin SDK, client tự tính điểm cảm nhận và tự đẩy bản ghi của chính mình lên `leaderboard_public/{uid}`. Security Rules chặn ghi sang `uid` khác và giới hạn kiểu/ngưỡng (`aiScore: 0..100`, `xp: 0..50000`, `stampCount: 0..200`), nhưng người dùng có kỹ thuật vẫn có thể tự sửa điểm của chính mình trong ngưỡng cho phép. Điều này chấp nhận được cho phạm vi đồ án/MVP miễn phí.
2. **Ảnh Base64 làm document Firestore nặng hơn**: Dù đã nén xuống mục tiêu `40–80 KB` (trần cứng `120 KB` / `120000` ký tự Base64), giới hạn tối đa `3` ảnh/visit và chặn ghi khi document ước lượng `> 800 KB` (dưới trần `1 MiB`), dung lượng lưu trữ và băng thông đọc mỗi document vẫn lớn hơn so với lưu URL trên Firebase Storage.
3. **Xóa tài khoản chạy ở client có thể còn sót một phần dữ liệu nếu mất kết nối giữa các lô**: Nếu người dùng tắt hẳn ứng dụng hoặc mất mạng vĩnh viễn giữa chừng khi xóa nhiều lô `<= 450` thao tác và không quay lại, có thể còn sót một số document. Hệ thống đã giảm thiểu tối đa rủi ro bằng cách bắt buộc xóa xong toàn bộ Firestore trước khi gọi `user.delete()` và làm mọi thao tác xóa đều idempotent để người dùng bấm thử lại được khi mạng phục hồi.
4. **Không có rate limit phía máy chủ**: Không dùng Cloud Function hay `_rate_limits`. Chế độ mặc định (heuristic offline) không tốn tài nguyên máy chủ; nếu cấu hình thêm endpoint ngoài qua `REFLECTION_VERIFIER_URL`, dịch vụ ngoài đó tự chịu trách nhiệm giới hạn tần suất và bảo mật API key.

---

## 5. Kết quả kiểm tra cuối cùng

| Kiểm tra | Lệnh chạy | Kết quả |
| --- | --- | --- |
| Format Dart | `dart format --output=none --set-exit-if-changed lib test` | **PASS** (57 files, 0 thay đổi) |
| Phân tích tĩnh | `flutter analyze` | **PASS** (`No issues found!`) |
| Unit & Widget test Flutter | `flutter test` | **PASS** (**52/52** test đạt) |
| Firestore Rules test (Emulator) | `cd rules_tests && npm test` | **PASS** (**12/12** test đạt trên Firestore Emulator) |
| Build release Web | `flutter build web --release` | **PASS** (`Built build\web`) |

---

## 6. Cách rollback / chuyển lại kiến trúc Blaze

- **Quay lại kiến trúc đầy đủ Blaze (có Firebase Storage + Cloud Functions)**:
  ```bash
  git checkout fix/audit-all-phases
  ```
- **Hoàn tác riêng từng hạng mục Spark**: mỗi hạng mục S1–S6 là một commit độc lập trên nhánh `refactor/spark-only`, có thể dùng `git revert <commit-hash>`.
- **Rollback Rules trên Firebase Console (sau khi đã deploy)**: vào **Firestore Database → Rules → Releases** để khôi phục phiên bản trước đó.

---

## 7. Tài liệu liên quan

- Hướng dẫn cấu hình & triển khai thủ công cho gói Spark: **[docs/MANUAL_STEPS.md](MANUAL_STEPS.md)**
- Chi tiết quyết định kỹ thuật & đánh đổi kiến trúc: **[docs/DECISIONS.md](DECISIONS.md)**
