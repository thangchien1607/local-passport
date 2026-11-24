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
