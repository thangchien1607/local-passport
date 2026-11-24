# Quyết định kỹ thuật (Audit Fixes)

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
