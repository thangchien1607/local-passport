# Các bước cần thực hiện thủ công trên dự án Firebase thật

> **Lưu ý**: Trong quá trình sửa lỗi, không có lệnh `firebase deploy` nào được chạy và không có dữ liệu thật nào bị thay đổi. Toàn bộ kiểm thử được chạy bằng Firebase Emulator Suite và unit/widget test.

---

## 1. Bật gói Blaze & Firebase Storage
1. Mở [Firebase Console](https://console.firebase.google.com/) → chọn project **`local-passport-danang`**.
2. Nâng cấp lên gói **Blaze (Pay as you go)** (bắt buộc để triển khai Cloud Functions v2 và dùng Secret Manager). Thiết lập Budget Alert trên Google Cloud Billing (ví dụ 5–10 USD/tháng).
3. Vào **Build → Storage** → bấm **Get started** để kích hoạt bucket mặc định `local-passport-danang.firebasestorage.app`.
4. Triển khai Storage rules sau khi merge:
   ```bash
   firebase deploy --only storage
   ```

## 2. Triển khai Firestore Rules & Indexes
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## 3. Di chuyển (migrate) dữ liệu ảnh Base64 cũ (nếu đã có trên production)
- Các document `reflections` cũ có `photoBase64` và `user_passports/{uid}/visits/*` cũ có `taskPhotos` **vẫn đọc và hiển thị bình thường** nhờ tương thích ngược ở client.
- Nếu muốn dọn gọn dữ liệu cũ trên production, viết/chạy một script Admin SDK một lần để:
  1. Đọc các document còn `photoBase64` / `taskPhotos`.
  2. Decode base64 → upload lên Firebase Storage theo đường dẫn `users/{uid}/reflections/{id}.jpg` hoặc `users/{uid}/tasks/{locationId}/{taskId}.jpg`.
  3. Cập nhật document với `photoUrl` / `taskPhotoUrls` và xóa trường `photoBase64` / `taskPhotos`.
