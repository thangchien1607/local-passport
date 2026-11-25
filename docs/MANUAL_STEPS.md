# Các bước cần thực hiện thủ công trên dự án Firebase thật (Gói Spark)

> **Lưu ý**: Kiến trúc hiện tại chạy hoàn toàn trên gói **Firebase Spark miễn phí** (chỉ dùng **Firebase Auth** và **Cloud Firestore**).
> Trong quá trình phát triển/kiểm thử, không có lệnh `firebase deploy` nào được chạy và không có dữ liệu thật nào bị thay đổi.

---

## 1. Triển khai Firestore Rules & Indexes
Chạy sau khi đã kiểm tra và merge nhánh `refactor/spark-only`:
```bash
firebase deploy --only firestore:rules,firestore:indexes
```
- `firestore.rules` áp dụng ràng buộc schema cho `user_passports/{uid}`, `visits`, `notifications`, `reflections` (`photoBase64 <= 120000` ký tự, `aiScore` nguyên `0..100`), `reflection_owners` (`allow update: if false`), và `leaderboard_public/{uid}` (chỉ chủ tài khoản ghi/xóa).
- `firestore.indexes.json` tạo composite index `(xp DESC, stampCount DESC)` cho bảng xếp hạng công khai `leaderboard_public`.

---

## 2. Bật nhà cung cấp xác thực (Firebase Authentication)
Trong [Firebase Console](https://console.firebase.google.com/) → project **`local-passport-danang`** → **Authentication → Sign-in method**:
1. Đảm bảo đã bật **Email/Password** và **Anonymous** (cho chế độ khách).
2. Bật **Google** (chọn Support email của dự án).
3. Bật **Apple** (điền Services ID, Team ID, Key ID và Private Key từ Apple Developer Portal nếu chạy Web/Android; với iOS bật thêm Capability *Sign in with Apple* trong Xcode).
4. Với **Android**: thêm mã SHA-1 và SHA-256 (debug & release keystore) vào **Project Settings → Your apps → Android app**, rồi tải lại `google-services.json`.
5. Với **Web**: xác nhận các domain (`local-passport-danang.web.app`, `localhost`) nằm trong **Authentication → Settings → Authorized domains**.

---

## 3. Cấu hình Google Maps API key cho Web / Android / iOS
Mặc định ứng dụng dùng **OpenStreetMap** và không cần thực hiện mục này. Cấu hình Google Maps dưới đây chỉ dành cho tích hợp tùy chọn đã có; bản Spark miễn phí không phụ thuộc Google Maps.

1. Trong Google Cloud Console bật **Maps JavaScript API** (Web), **Maps SDK for Android** và **Maps SDK for iOS**, giới hạn key theo từng nền tảng.
2. Trên macOS trước khi build iOS, sao chép file mẫu và điền API key thật (tuyệt đối không commit file thật vào git):
   ```bash
   cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
   ```
   Điền `MAPS_API_KEY=<key>` vào `ios/Flutter/Secrets.xcconfig`.
3. Khi build Web/Android/iOS, truyền `--dart-define=MAPS_API_KEY=<key>`.

---

## 4. Triển khai bản Web lên Firebase Hosting (tùy chọn)
```bash
flutter build web --release --dart-define=MAPS_API_KEY=<key>
firebase deploy --only hosting
```
Nếu sau này muốn gắn một dịch vụ thẩm định bài cảm nhận bên ngoài (tùy chọn), chỉ cần truyền thêm:
```bash
flutter build web --release \
  --dart-define=MAPS_API_KEY=<key> \
  --dart-define=REFLECTION_VERIFIER_URL=https://your-verifier.example.com/verify
```
(Nếu không truyền biến này, ứng dụng mặc định chấm điểm bằng bộ heuristic offline.)

---

## 5. Dữ liệu cũ và hướng nâng cấp
- **Tương thích ngược ảnh cũ**: Nếu trên production đã có document cũ lưu `photoUrl` hoặc `taskPhotoUrls`, ứng dụng vẫn đọc và hiển thị bình thường song song với ảnh mới dạng `photoBase64` / `taskPhotos`.
- **Nâng lên gói Blaze sau này (nếu cần)**: Phiên bản đầy đủ dùng Firebase Storage + Cloud Functions vẫn được giữ nguyên vẹn trên nhánh `fix/audit-all-phases`. Có thể xem lại mã nguồn trong lịch sử tại commit `7445da1`.
