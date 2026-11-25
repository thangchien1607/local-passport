# Quyết định kiến trúc — Chuyển sang thuần Firebase Spark (`refactor/spark-only`)

## S1–S2. Nén ảnh Base64 và lưu trong Firestore
- Ứng dụng dùng Firebase Auth để xác thực và Cloud Firestore để lưu dữ liệu.
- `photo_service.dart` nén ảnh theo vòng lặp giảm kích thước/chất lượng từ `720px`, JPEG `70` xuống mục tiêu **<= 80 KB**; nếu nén tối đa vẫn `> 120 KB` hoặc Base64 `> 120000` ký tự thì từ chối với `PhotoTooLargeException`.
- Mỗi `visit` lưu tối đa 3 ảnh trong danh sách `taskPhotos` (`List<String>` dạng `"<taskId>:<base64>"`, mỗi phần tử `<= 120000` ký tự) và kiểm tra ước lượng document `<= 800 KB` trước khi ghi. Vẫn đọc tương thích ngược `photoUrl` và `taskPhotoUrls` cũ.

## S3. Chấm điểm AI heuristic offline + tùy chọn endpoint ngoài
- Mặc định dùng `scoreReflectionHeuristic` hoàn toàn ở client. Nếu cấu hình `--dart-define=REFLECTION_VERIFIER_URL=https://...`, client gửi request kèm `Authorization: Bearer <Firebase ID Token>` và tự fallback về heuristic khi lỗi mạng/HTTP/timeout.
- **Đánh đổi của kiến trúc Spark**: Trường `aiScore` được client gửi trực tiếp lên Firestore (rules chỉ kiểm tra `aiScore is int && 0..100`) nên **KHÔNG chống gian lận hoàn toàn** nếu người dùng gọi API Firestore trực tiếp. Không còn rate limit phía máy chủ. Chấp nhận được cho đồ án/MVP trên gói Spark.

## S4. Leaderboard công khai do client tự ghi (có debounce 5 giây)
- `PassportStore` tự ghi tóm tắt `{displayName, xp, stampCount, avatarUrl, updatedAt}` vào `leaderboard_public/{uid}` với debounce `5 giây` mỗi khi thông tin hộ chiếu thay đổi.
- `firestore.rules` cho phép `allow read: if true`, chỉ cho phép chủ tài khoản (`request.auth.uid == uid`) tạo/cập nhật/xóa bản ghi của chính mình với kiểm tra nghiêm ngặt: `displayName` 1–40 ký tự, `xp` int `0..50000`, `stampCount` int `0..200`, `avatarUrl` URL HTTP/HTTPS <= 2048 ký tự hoặc null, `updatedAt` timestamp.
- **Đánh đổi của kiến trúc Spark**: Người dùng am hiểu kỹ thuật có thể tự sửa `xp` hoặc `stampCount` của chính mình trong ngưỡng `0..50000` (không thể sửa của người khác). Điều này được chấp nhận cho phạm vi đồ án/MVP miễn phí trên gói Spark.

## S5. Xóa tài khoản hoàn toàn từ client (có re-authenticate & chia lô <= 450)
- Toàn bộ luồng xóa chạy từ `auth_service.dart`, `passport_store.dart` và `passport_remote.dart` theo đúng thứ tự 3 bước:
  1. **Re-authenticate** theo đúng phương thức đăng nhập (`EmailAuthProvider` nhập mật khẩu hiện tại trong hộp thoại xác nhận, `GoogleAuthProvider` / `AppleAuthProvider` qua popup/provider, bỏ qua cho tài khoản khách). Xử lý tường minh lỗi `requires-recent-login`.
  2. **Xóa toàn bộ dữ liệu Firestore của `uid`** qua `runChunkedUserDataDeletion` (chia lô `<= 450` thao tác): xóa hết `user_passports/{uid}/visits/*`, `user_passports/{uid}/notifications/*`, mọi cặp nguyên tử `reflections/{id}` + `reflection_owners/{id}`, `leaderboard_public/{uid}` và `user_passports/{uid}`.
  3. **Chỉ gọi `user.delete()` khi bước (1) và (2) thành công**. Nếu bước (2) gặp lỗi mạng giữa chừng, giữ nguyên phiên Auth để người dùng có thể bấm thử lại một cách idempotent.
- **Đánh đổi của kiến trúc Spark**: Vì việc xóa diễn ra qua nhiều batch từ phía client, nếu người dùng tắt ứng dụng hoặc mất kết nối vĩnh viễn giữa các lô mà không mở lại để thử lại, có thể còn sót một phần document trên Firestore. Rủi ro này đã được giảm thiểu tối đa bằng cách xóa Firestore trước khi xóa Auth user và đảm bảo mọi bước xóa đều idempotent.

## Đánh đổi của kiến trúc Spark (Tổng hợp Trade-offs)
Bản Spark có bốn đánh đổi khi xử lý ảnh, điểm và dữ liệu tài khoản trên thiết bị:

1. **Chống gian lận điểm AI (`aiScore`) và điểm bảng xếp hạng (`xp`, `stampCount`) không tuyệt đối**:
   - Client tự tính và gửi trực tiếp lên Firestore.
   - `firestore.rules` vẫn ràng buộc chặt kiểu dữ liệu, phạm vi (`aiScore` int `0..100`, `xp` int `0..50000`, `stampCount` int `0..200`), và chỉ chủ tài khoản (`request.auth.uid == uid`) mới ghi được bản ghi của chính mình (không thể sửa của người khác).
   - Người dùng có kiến thức kỹ thuật vẫn có thể gửi request trực tiếp để nâng điểm của chính mình trong ngưỡng cho phép — đánh đổi có chủ đích, chấp nhận được cho phạm vi đồ án/MVP.
2. **Ảnh Base64 làm document Firestore nặng hơn và tốn băng thông đọc**:
   - Mỗi ảnh được nén vòng lặp xuống mục tiêu `40–80 KB` (tối đa `120 KB` / `120000` ký tự Base64), mỗi visit giới hạn tối đa `3` ảnh và client chặn ghi khi ước lượng document vượt `800 KB` (an toàn dưới trần `1 MiB` của Firestore).
   - Dù tránh được lỗi vượt trần 1 MiB, chi phí đọc/băng thông Firestore cho bảng tin cộng đồng và chi tiết chuyến thăm vẫn cao hơn so với chỉ lưu URL ảnh.
3. **Xóa tài khoản từ client có thể còn sót dữ liệu nếu mất kết nối giữa các lô**:
   - Client phải truy vấn và xóa tuần tự từng lô `<= 450` thao tác.
   - Rủi ro được giảm thiểu tối đa bằng thứ tự bắt buộc: **(1) Re-auth → (2) Xóa toàn bộ dữ liệu Firestore → (3) Chỉ gọi `user.delete()` sau khi xóa xong**. Nếu mạng đứt ở bước (2), tài khoản Auth chưa bị xóa nên người dùng có thể bấm thử lại (idempotent). Chỉ còn sót dữ liệu nếu người dùng tắt ứng dụng giữa bước (2) và không quay lại hoàn tất.
4. **Không có rate limit phía máy chủ**:
   - Ở chế độ mặc định (heuristic offline), việc chấm điểm không tốn tài nguyên máy chủ. Nếu sau này cấu hình thêm endpoint ngoài qua `REFLECTION_VERIFIER_URL`, trách nhiệm rate limit và bảo vệ API key thuộc về dịch vụ ngoài đó.

## Hướng nâng cấp
Nếu cần xác minh điểm ở máy chủ hoặc lưu ảnh ngoài Firestore, có thể đánh giá Cloud Functions và Firebase Storage trên gói Blaze. Thiết kế đã thử trước đây được ghi tại commit 7445da1, trong tài liệu docs/DECISIONS.md.
