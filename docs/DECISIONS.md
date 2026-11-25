# Quyết định kỹ thuật (Audit Fixes)

> **Kiến trúc đang dùng là Firebase Spark**: chỉ Firebase Auth + Cloud Firestore; xem phần [Chuyển sang thuần Firebase Spark](#quyết-định-kiến-trúc--chuyển-sang-thuần-firebase-spark-refactorspark-only) bên dưới. Các mục 0–3.3 ngay sau đây ghi lại lịch sử bản `fix/audit-all-phases` dùng Blaze; các mô tả Functions/Storage trong phần lịch sử không phải hướng dẫn triển khai bản hiện tại.

Tài liệu này ghi lại các lựa chọn kiến trúc khi thực hiện sửa lỗi kỹ thuật Giai đoạn 1–3 cho Local Passport trên nhánh `fix/audit-all-phases`.

## 0. Quy trình Git & nhánh làm việc
- Repo dùng mô hình `main` / `develop` theo `git.md` và `AGENTS.md`. `origin/develop` (`34ceb7f`) và `origin/main` (`9cb757f`) có cây mã nguồn giống hệt nhau.
- Nhánh `fix/audit-all-phases` được tạo từ `origin/develop` để vừa có mã nguồn mới nhất vừa tuân thủ tuyệt đối quy ước `git.md` / `AGENTS.md`.
- Các thay đổi cục bộ chưa commit trước khi bắt đầu được lưu an toàn trong `git stash` với tên `pre-audit-stash`.

## 1.1 Lưu ảnh bằng Firebase Storage + nén phía client
- **Thư viện nén ảnh**: Dùng `flutter_image_compress` trên Android/iOS (nén native nhanh) kết hợp fallback thuần Dart bằng package `image` cho Web, desktop và môi trường unit test. Mục tiêu cạnh dài tối đa `1280px`, chất lượng JPEG `80%`.
- **Cấu trúc đường dẫn Storage**:
  - Ảnh nhiệm vụ (riêng tư của chủ hộ chiếu): `users/{uid}/tasks/{locationId}/{taskId}_{timestamp}.jpg`
  - Ảnh cảm nhận (công khai trên bảng tin): `users/{uid}/reflections/{reflectionId}_{timestamp}.jpg`
  - Ảnh đại diện (công khai cho bảng xếp hạng): `users/{uid}/avatars/{fileName}`
- **Tương thích ngược**:
  - Giữ lại đọc trường cũ `photoBase64` (trên `reflections`) và `taskPhotos` (trên `visits`) để dữ liệu cũ vẫn hiển thị bình thường.
  - Mọi lượt ghi mới lên Firestore chỉ ghi `photoUrl` và `taskPhotoUrls`; `firestore.rules` từ chối mọi thao tác ghi chứa `photoBase64` hoặc `taskPhotos`.
  - Khi chạy chế độ cục bộ không có Firebase (không cấu hình `PhotoStorageGateway`), app vẫn cho phép lưu ảnh đã nén dạng base64 vào `shared_preferences` để không phá vỡ chế độ demo offline/test.

## 1.2 Cloud Function chấm điểm AI (`verifyReflection`)
- **Kiến trúc**: Dùng Cloud Functions v2 `onRequest` (TypeScript, Node 22 LTS, region `asia-southeast1`) xác thực tường minh `Authorization: Bearer <Firebase ID Token>` qua `admin.auth().verifyIdToken(token)` — trả HTTP `401` khi thiếu hoặc sai token.
- **Lớp adapter AI thay thế được**: Tách `AiVerifierAdapter` với `GeminiAiAdapter` (mặc định `gemini-2.0-flash`), `OpenAiCompatibleAdapter` (đổi endpoint/model qua biến `AI_PROVIDER`, `AI_MODEL`, `AI_ENDPOINT`), và `HeuristicFallbackAdapter` (chạy trên server khi ở môi trường Emulator chưa đặt `AI_API_KEY`).
- **Quyền ghi `aiScore`**: Chỉ Cloud Function ghi `aiScore` vào `reflections/{id}` bằng Firebase Admin SDK. `firestore.rules` chặn hoàn toàn client tạo trường `aiScore` hoặc sửa trường `aiScore`.
- **Rate limit**: Dùng `FirestoreRateLimiter` (transaction theo `uid` lưu trong collection nội bộ `_rate_limits`, mặc định 10 lượt/phút, trả HTTP `429` + `Retry-After`). Collection `_rate_limits` bị khóa hoàn toàn với client trong `firestore.rules`.

## 1.3 Sửa `sync()` trong `passport_remote.dart`
- **Bỏ cache `_written`**: Thay vì tin vào map cache trong RAM (dễ lệch trạng thái khi khởi động lại hoặc khi Cloud Function đã tạo `reflection_owners/{id}`), mỗi lần đồng bộ đối chiếu trực tiếp với trạng thái hiện có trên Firestore (`listVisitIds`, `listNotificationIds`, `listOwnedReflectionIds`, `reflectionOwnerExists`, `reflectionDocExists`).
- **Chia lô `<= 450` thao tác nguyên tử**: Hàm `chunkAtomicOps` gom thao tác theo từng nhóm nguyên tử (cặp `reflection_owners/{id}` + `reflections/{id}` không bao giờ bị cắt sang 2 batch khác nhau để thỏa điều kiện `getAfter(...)` trong Firestore Rules), mỗi lô tối đa `450` thao tác.
- **Idempotent**: Khi `reflection_owners/{id}` đã tồn tại, chỉ cập nhật merge các trường cho phép trên `reflections/{id}`, tuyệt đối không ghi đè `reflection_owners/{id}` (`allow update: if false`) và không đụng vào `aiScore`.

## 1.4 Siết schema cho `user_passports/{uid}` và kiểm thử Rules bằng Emulator
- Tách các hàm kiểm tra schema trong `firestore.rules`: `validPassport`, `validVisit`, `validNotification`, `validReflectionCreate`, `validReflectionUpdate`, `validPhotoUrl`.
- Mọi thao tác ghi thiếu trường bắt buộc, thừa trường lạ, sai kiểu dữ liệu hoặc vượt giới hạn độ dài chuỗi/kích thước danh sách đều bị từ chối ở tầng Security Rules.
- Bộ test `rules_tests/` dùng `@firebase/rules-unit-testing` chạy trên Firebase Emulator Suite (`firestore` + `storage`) để xác minh toàn bộ các ràng buộc từ 1.1 đến 1.4.

## 2.1 Loại bỏ vòng lặp N+1 trong `fetch()`
- Tải song song `user_passports/{uid}`, `visits`, `notifications` và `reflection_owners` trong cùng `Future.wait`.
- Thay vòng lặp `get()` từng bài cảm nhận bằng `fetchInChunks` sử dụng `where(FieldPath.documentId, whereIn: chunk)` với tối đa `30` ID/lô, chạy song song bằng `Future.wait`.

## 2.2 Leaderboard công khai (`leaderboard_public`)
- Thêm Cloud Function Firestore trigger `syncLeaderboardOnPassportWrite` lắng nghe `user_passports/{uid}` và chỉ đồng bộ `displayName`, `xp`, `stampCount`, `avatarUrl`, `updatedAt` sang `leaderboard_public/{uid}`.
- `firestore.rules` cho phép `allow read: if true` và `allow write: if false` trên `leaderboard_public/{uid}`; `user_passports/{uid}` vẫn khóa hoàn toàn cho riêng chủ sở hữu.
- Thêm composite index `(xp DESC, stampCount DESC)` trong `firestore.indexes.json`.
- `LeaderboardScreen` tự tải `leaderboard_public`, hỗ trợ kéo làm mới (`RefreshIndicator`), tự xử lý an toàn khi danh sách có < 3 người dùng, và fallback sang dữ liệu mẫu khi chạy offline/chưa có dữ liệu cloud.

## 2.3 Phân trang cộng đồng & Realtime `snapshots()`
- Thêm `CommunityPage`, `fetchCommunityPage(limit, startAfter)` (dùng `startAfterDocument` trên Firestore) và `watchLatestCommunity(limit)` (dùng `snapshots()`) trên `PassportRemote`.
- `PassportStore` hợp nhất trang đã tải (`_pagedCommunity`) với luồng realtime (`_realtimeCommunity`), tự cập nhật `aiScore` khi server ghi điểm mới, và hỗ trợ `loadMoreCommunity()` cho infinite scroll.
- `CommunityScreen` gắn `ScrollController` tự tải trang tiếp theo khi cuộn gần cuối (`<= 240px`), có `RefreshIndicator` kéo làm mới và nút dự phòng "Tải thêm cảm nhận".

## 2.4 Sửa bài cảm nhận & tự chấm lại AI
- Cập nhật `firestore.rules` cho phép chủ sở hữu (`ownerOf(id) == request.auth.uid`) sửa thêm `content`, `photoUrl`, `updatedAt` nhưng vẫn khóa chặt `aiScore`, `photoBase64`, `locationId`, `createdAt`.
- Thêm Cloud Function trigger `rescoreReflectionOnUpdate` (bên cạnh `verifyReflection`) để tự động chấm lại và ghi `aiScore` mới bằng Admin SDK khi `content` hoặc `photoUrl` thay đổi, có điều kiện chống vòng lặp vô hạn.
- Thêm hộp thoại `EditReflectionDialog` và nút **Sửa** trên `ReflectionCard` cho tác giả sửa nội dung/ảnh và nhận điểm AI mới mà không cộng trùng XP.

## 3.1 Mở rộng xác thực (Google, Apple, xác minh email, đổi mật khẩu, xóa tài khoản)
- Dùng `GoogleAuthProvider` và `AppleAuthProvider` tích hợp sẵn của `firebase_auth` (`signInWithPopup`/`linkWithPopup` trên Web, `signInWithProvider`/`linkWithProvider` trên Android/iOS) giúp hỗ trợ đầy đủ 3 nền tảng và giữ nguyên tiến độ khi nâng tài khoản khách mà không phát sinh xung đột plugin native.
- Tự động gọi `sendEmailVerification()` sau khi đăng ký bằng email và cho phép gửi lại/kiểm tra trạng thái trong tab Hộ chiếu.
- `changePassword()` bắt buộc `reauthenticateWithCredential` bằng mật khẩu hiện tại trước khi gọi `updatePassword`.
- Thêm Cloud Function `deleteUserAccountData` xác thực ID Token, dọn sạch `user_passports/{uid}` (gồm `visits`, `notifications`), `reflections` + `reflection_owners`, `leaderboard_public/{uid}`, `_rate_limits`, toàn bộ file Storage dưới `users/{uid}/` và xóa user trên Firebase Auth.

## 3.2 Cấu hình `MAPS_API_KEY` cho iOS bằng xcconfig
- Dùng `ios/Flutter/Secrets.xcconfig` (được đưa vào `.gitignore`) và file mẫu `ios/Flutter/Secrets.xcconfig.example`.
- `Debug.xcconfig` và `Release.xcconfig` nạp tùy chọn `#include? "Secrets.xcconfig"` với giá trị mặc định rỗng để không làm hỏng build khi chưa tạo file bí mật.
- `Info.plist` ánh xạ `GMSApiKey = $(MAPS_API_KEY)` và `AppDelegate.swift` gọi `GMSServices.provideAPIKey(...)` (bọc `#if canImport(GoogleMaps)`) khi có key thật.

## 3.3 Rà soát `Permissions-Policy` trong `firebase.timelens.json`
- Đổi `camera=(), geolocation=(), microphone=()` thành `camera=(self), geolocation=(self), microphone=()` để nhất quán với `firebase.json` và không chặn quyền camera/GPS trên chính origin khi chia sẻ hoặc nhúng tính năng check-in.

---

# Quyết định kiến trúc — Chuyển sang thuần Firebase Spark (`refactor/spark-only`)

## S1–S2. Gỡ Functions & Storage, nén ảnh Base64 lưu Firestore
- Gỡ hoàn toàn `functions/`, `storage.rules` và `firebase_storage` để dự án vận hành 100% trên gói **Firebase Spark miễn phí** (chỉ dùng Firebase Auth + Cloud Firestore).
- `photo_service.dart` nén ảnh theo vòng lặp giảm kích thước/chất lượng từ `720px`, JPEG `70` xuống mục tiêu **<= 80 KB**; nếu nén tối đa vẫn `> 120 KB` hoặc Base64 `> 120000` ký tự thì từ chối với `PhotoTooLargeException`.
- Mỗi `visit` lưu tối đa 3 ảnh trong danh sách `taskPhotos` (`List<String>` dạng `"<taskId>:<base64>"`, mỗi phần tử `<= 120000` ký tự) và kiểm tra ước lượng document `<= 800 KB` trước khi ghi. Vẫn đọc tương thích ngược `photoUrl` và `taskPhotoUrls` cũ.

## S3. Chấm điểm AI heuristic offline + tùy chọn endpoint ngoài
- Mặc định dùng `scoreReflectionHeuristic` hoàn toàn ở client. Nếu cấu hình `--dart-define=REFLECTION_VERIFIER_URL=https://...`, client gửi request kèm `Authorization: Bearer <Firebase ID Token>` và tự fallback về heuristic khi lỗi mạng/HTTP/timeout.
- **Đánh đổi của kiến trúc Spark**: Trường `aiScore` được client gửi trực tiếp lên Firestore (rules chỉ kiểm tra `aiScore is int && 0..100`) nên **KHÔNG chống gian lận hoàn toàn** nếu người dùng gọi API Firestore trực tiếp. Không còn rate limit phía máy chủ. Chấp nhận được cho đồ án/MVP trên gói Spark.

## S4. Leaderboard công khai do client tự ghi (có debounce 5 giây)
- Không dùng Cloud Function trigger `syncLeaderboard`; `PassportStore` tự ghi tóm tắt `{displayName, xp, stampCount, avatarUrl, updatedAt}` vào `leaderboard_public/{uid}` với debounce `5 giây` mỗi khi thông tin hộ chiếu thay đổi.
- `firestore.rules` cho phép `allow read: if true`, chỉ cho phép chủ tài khoản (`request.auth.uid == uid`) tạo/cập nhật/xóa bản ghi của chính mình với kiểm tra nghiêm ngặt: `displayName` 1–40 ký tự, `xp` int `0..50000`, `stampCount` int `0..200`, `avatarUrl` URL HTTP/HTTPS <= 2048 ký tự hoặc null, `updatedAt` timestamp.
- **Đánh đổi của kiến trúc Spark**: Người dùng am hiểu kỹ thuật có thể tự sửa `xp` hoặc `stampCount` của chính mình trong ngưỡng `0..50000` (không thể sửa của người khác). Điều này được chấp nhận cho phạm vi đồ án/MVP miễn phí trên gói Spark.

## S5. Xóa tài khoản hoàn toàn từ client (có re-authenticate & chia lô <= 450)
- Gỡ bỏ hoàn toàn Cloud Function `deleteAccount`; toàn bộ luồng xóa chạy từ `auth_service.dart`, `passport_store.dart` và `passport_remote.dart` theo đúng thứ tự 3 bước:
  1. **Re-authenticate** theo đúng phương thức đăng nhập (`EmailAuthProvider` nhập mật khẩu hiện tại trong hộp thoại xác nhận, `GoogleAuthProvider` / `AppleAuthProvider` qua popup/provider, bỏ qua cho tài khoản khách). Xử lý tường minh lỗi `requires-recent-login`.
  2. **Xóa toàn bộ dữ liệu Firestore của `uid`** qua `runChunkedUserDataDeletion` (chia lô `<= 450` thao tác): xóa hết `user_passports/{uid}/visits/*`, `user_passports/{uid}/notifications/*`, mọi cặp nguyên tử `reflections/{id}` + `reflection_owners/{id}`, `leaderboard_public/{uid}` và `user_passports/{uid}`.
  3. **Chỉ gọi `user.delete()` khi bước (1) và (2) thành công**. Nếu bước (2) gặp lỗi mạng giữa chừng, giữ nguyên phiên Auth để người dùng có thể bấm thử lại một cách idempotent.
- **Đánh đổi của kiến trúc Spark**: Vì việc xóa diễn ra qua nhiều batch từ phía client, nếu người dùng tắt ứng dụng hoặc mất kết nối vĩnh viễn giữa các lô mà không mở lại để thử lại, có thể còn sót một phần document trên Firestore. Rủi ro này đã được giảm thiểu tối đa bằng cách xóa Firestore trước khi xóa Auth user và đảm bảo mọi bước xóa đều idempotent.

## Đánh đổi của kiến trúc Spark (Tổng hợp Trade-offs)
Khi chuyển từ kiến trúc Blaze (`fix/audit-all-phases`) sang thuần Firebase Spark (`refactor/spark-only`, chỉ dùng Firebase Auth + Cloud Firestore), dự án đánh đổi 4 điểm sau để vận hành hoàn toàn miễn phí và không cần backend:

1. **Chống gian lận điểm AI (`aiScore`) và điểm bảng xếp hạng (`xp`, `stampCount`) không tuyệt đối**:
   - Không có Cloud Function dùng Admin SDK để ghi `aiScore` hay đồng bộ `leaderboard_public`; client tự tính và gửi trực tiếp lên Firestore.
   - `firestore.rules` vẫn ràng buộc chặt kiểu dữ liệu, phạm vi (`aiScore` int `0..100`, `xp` int `0..50000`, `stampCount` int `0..200`), và chỉ chủ tài khoản (`request.auth.uid == uid`) mới ghi được bản ghi của chính mình (không thể sửa của người khác).
   - Người dùng có kiến thức kỹ thuật vẫn có thể gửi request trực tiếp để nâng điểm của chính mình trong ngưỡng cho phép — đánh đổi có chủ đích, chấp nhận được cho phạm vi đồ án/MVP.
2. **Ảnh Base64 làm document Firestore nặng hơn và tốn băng thông đọc**:
   - Mỗi ảnh được nén vòng lặp xuống mục tiêu `40–80 KB` (tối đa `120 KB` / `120000` ký tự Base64), mỗi visit giới hạn tối đa `3` ảnh và client chặn ghi khi ước lượng document vượt `800 KB` (an toàn dưới trần `1 MiB` của Firestore).
   - Dù tránh được lỗi vượt trần 1 MiB, chi phí đọc/băng thông Firestore cho bảng tin cộng đồng và chi tiết chuyến thăm vẫn cao hơn so với lưu URL trên Firebase Storage + CDN.
3. **Xóa tài khoản từ client có thể còn sót dữ liệu nếu mất kết nối giữa các lô**:
   - Không có Cloud Function xóa ngầm, nên client phải truy vấn và xóa tuần tự từng lô `<= 450` thao tác.
   - Rủi ro được giảm thiểu tối đa bằng thứ tự bắt buộc: **(1) Re-auth → (2) Xóa toàn bộ dữ liệu Firestore → (3) Chỉ gọi `user.delete()` sau khi xóa xong**. Nếu mạng đứt ở bước (2), tài khoản Auth chưa bị xóa nên người dùng có thể bấm thử lại (idempotent). Chỉ còn sót dữ liệu nếu người dùng tắt ứng dụng giữa bước (2) và không quay lại hoàn tất.
4. **Không có rate limit phía máy chủ**:
   - Không còn Cloud Function và collection `_rate_limits`. Ở chế độ mặc định (heuristic offline), việc chấm điểm không tốn tài nguyên máy chủ. Nếu sau này cấu hình thêm endpoint ngoài qua `REFLECTION_VERIFIER_URL`, trách nhiệm rate limit và bảo vệ API key thuộc về dịch vụ ngoài đó.
