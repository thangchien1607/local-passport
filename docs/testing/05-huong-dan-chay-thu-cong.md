# Hướng dẫn chạy thủ công Local Passport (18 ca còn lại)

[ĐÃ CHẠY] Ngày **27/11/2026**, **52/70 ca thủ công** (42 Pass, 10 Fail trên bản gốc `065103c`) đã được thực thi thực tế trên **Web Chrome 158.0.8127.37** và **Android Emulator `LP_390x844_API35`** (chạy bản APK mới `build/app/outputs/flutter-apk/app-debug.apk` build ngày 27/11/2026), kèm **169 tệp bằng chứng thật** trong `docs/testing/evidence/`.

Tài liệu này rút gọn để tập trung vào **đúng 18 ca thủ công vẫn đang `Chưa chạy`** cần điện thoại thật (camera/GPS), hộp thư/OAuth thật, macOS/iOS hoặc dữ liệu Firestore thử kiểm soát.

## Chuẩn bị chạy trên điện thoại thật

1. Cài bản APK mới build ngày 27/11/2026 tại `build/app/outputs/flutter-apk/app-debug.apk` lên điện thoại Android thật (hoặc build lại sau khi gộp các nhánh sửa lỗi vào `develop`).
2. Chuẩn bị mã QR in/hiển thị từ `qrPayloadFor()` (đúng khóa, sai khóa `k=SAI`, thiếu `k`, `checkin` rỗng, điểm khác).
3. Chuẩn bị hộp thư email thật nhận được thư xác minh/đặt lại mật khẩu của Firebase và tài khoản Google/Apple thử trên miền được phép.
4. Với mỗi ca hoàn thành, lưu ảnh chụp màn hình hoặc log vào `docs/testing/evidence/<MãTC>-real.<png|txt>` và cập nhật lại [bảng test case](02-bang-test-case.md).

## Smoke chuỗi luồng cốt lõi trên thiết bị thật

Chuỗi đăng nhập → bản đồ → check-in Demo → viết/sửa cảm nhận có ảnh → ngắt/bật mạng đồng bộ đã chạy đạt trên **bản Web gộp 11 bản vá** ([RETEST-COMBINED.txt](evidence/RETEST-COMBINED.txt), [RETEST-SMOKE-SYNC.png](evidence/RETEST-SMOKE-SYNC.png)). Chặng còn cần kiểm trên điện thoại thật:

- ☐ Cài bản APK đã gộp các nhánh sửa lên điện thoại Android thật.
- ☐ Cấp quyền Camera + GPS, quét mã QR thật tại vị trí trong bán kính 300 m (`TC-QR-01`, `TC-QR-05`).
- ☐ Chụp ảnh nhiệm vụ bằng camera vật lý, lưu cảm nhận có ảnh và kiểm tra sau khi tắt/bật Wi-Fi + 4G (`TC-REF-09`, `TC-SYNC-02`).

## Danh sách 18 ca thủ công vẫn đang Chưa chạy

### Xác thực và tài khoản (3 ca · Chiến Thắng)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-AUTH-05 | Đã kiểm gửi quên mật khẩu, đổi mật khẩu trong Hộ chiếu và gửi email xác minh ([TC-AUTH-05.png](evidence/TC-AUTH-05.png)). | ☐ Mở thư thật, bấm liên kết đặt lại mật khẩu và liên kết xác minh email rồi bấm `Kiểm tra xác minh`. | Hộp thư thật |
| TC-AUTH-06 | Đã kiểm email sai định dạng, mật khẩu hiện tại sai và xác nhận mới lệch ([TC-AUTH-06.png](evidence/TC-AUTH-06.png)). | ☐ Mở liên kết xác minh đã hết hạn hoặc bị sửa hỏng và xác nhận email vẫn chưa được xác minh. | Hộp thư thật |
| TC-AUTH-13 | Đã kiểm nâng cấp Khách bằng email giữ nguyên UID/dấu và xóa tài khoản vĩnh viễn ([TC-AUTH-13.png](evidence/TC-AUTH-13.png)). | ☐ Đăng nhập bằng tài khoản Google và Apple thử trên cấu hình/miền được cấp phép OAuth. | Tài khoản & miền OAuth Google/Apple |

### QR và GPS check-in (7 ca · Chiến Thắng)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-QR-01 | Chưa quét được QR bằng camera ảo. | ☐ Quét mã QR định dạng mới (`qrPayloadFor`) và định dạng cũ (legacy) trong bán kính 300 m; mở link QR từ camera ngoài app. | Điện thoại thật (Camera + GPS) |
| TC-QR-03 | Đã kiểm camera ảo `MobileScanner` đứng chờ không tự mở khóa ([TC-QR-03-android-camera.png](evidence/TC-QR-03-android-camera.png)). | ☐ Quét 2 mã QR thật bị thiếu khóa `k` hoặc có `checkin` rỗng trên màn hình quét. | Điện thoại thật (Camera) |
| TC-QR-04 | Đã kiểm đóng và mở lại `MobileScanner` trên camera ảo không ghi lỗi `dispose` ([TC-QR-04-android-reopen.png](evidence/TC-QR-04-android-reopen.png)). | ☐ Quét mã QR hợp lệ và bấm Back/Đóng đúng lúc camera đang dừng, kiểm tra logcat và mở lại camera. | Điện thoại thật (Camera) |
| TC-QR-05 | Chưa quét được QR thực địa. | ☐ Cấp quyền vị trí, đứng trong bán kính 300 m (hoặc mock GPS điện thoại thật) và quét mã hợp lệ, xác nhận mở khóa và thông báo thực địa. | Điện thoại thật (Camera + GPS) |
| TC-QR-06 | Đã kiểm deep-link Web Chrome với CDP Geolocation ngoài 300 m bị từ chối ([TC-QR-06-web.png](evidence/TC-QR-06-web.png)). | ☐ Quét mã QR hợp lệ trên APK khi ở ngoài 300 m và lượt riêng khi từ chối quyền vị trí. | Điện thoại thật (Camera + GPS) |
| TC-QR-07 | Chưa quét được QR thật khi tắt GPS. | ☐ Tắt dịch vụ Vị trí trên điện thoại, quét mã đúng, xác nhận thông báo lỗi, bật lại Vị trí và thử lại. | Điện thoại thật (Camera + GPS) |
| TC-QR-08 | Đã kiểm deep-link Web Chrome với CDP Geolocation tại 301 m (chặn) và 299 m (nhận) ([TC-QR-08-web.png](evidence/TC-QR-08-web.png)). | ☐ Quét mã QR hợp lệ trên APK ở đúng 3 mốc `299 m`, `300 m` và `301 m` theo `distanceMeters` (ghi sai số GPS thực). | Điện thoại thật / mock location + Camera |

### Đóng dấu, cảm nhận và ảnh (1 ca · Ngọc Anh)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-REF-09 | Đã kiểm ảnh JPEG cảm nhận trên Web ([TC-REF-09.png](evidence/TC-REF-09.png)) và chụp ảnh nhiệm vụ bằng camera ảo trên `LP_390x844_API35` ([TC-REF-09-android.png](evidence/TC-REF-09-android.png)). | ☐ Chụp ảnh nhiệm vụ bằng camera vật lý trên điện thoại thật và kiểm tra ảnh mở được sau khi lưu. | Điện thoại thật (Camera) |

### Cộng đồng, bảng xếp hạng và thông báo (4 ca · Minh Khoa)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-COM-02 | Đã kiểm tìm từ khóa không khớp hiện trạng thái trống ([TC-COM-02.png](evidence/TC-COM-02.png)); trên bản vá `BUG-14` đã xác nhận phiên B không thấy nút Sửa/Xóa ở thẻ của A ([RETEST-BUG-14-COM01.png](evidence/RETEST-BUG-14-COM01.png)). | ☐ Chạy xác nhận lại sau khi gộp nhánh sửa `BUG-14` vào `develop`. | Web / Android (2 phiên HAI sau khi gộp `BUG-14`) |
| TC-COM-04 | Chưa gieo dữ liệu kiểm soát trên Firestore chia sẻ. | ☐ Tạo môi trường Firestore thử riêng với lần lượt 19, 20 và 21 bài, kiểm tra nạp trang tiếp và bài mới không trùng ID. | Firestore thử tách biệt |
| TC-COM-07 | Đã kiểm dòng tài khoản mới `0 XP` ([TC-COM-07.png](evidence/TC-COM-07.png)). | ☐ Kiểm tra hiển thị bục vinh danh khi dự án Firestore thử có ít hơn 3 người dùng. | Firestore thử `< 3` mục |
| TC-COM-08 | Đã đối chiếu biên Rules trong `TC-AUTO-04`. | ☐ Kiểm tra giao diện bảng xếp hạng với bộ 49, 50 và 51 mục từ xa trên dự án Firestore thử riêng. | Firestore thử 49/50/51 mục |

### Đồng bộ, offline và TimeLens (2 ca · Minh Khoa)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-SYNC-03 | Đã kiểm `am force-stop` và mở lại offline trên Android Emulator `LP_390x844_API35` đọc được hộ chiếu cục bộ ([TC-SYNC-03-android.png](evidence/TC-SYNC-03-android.png)). | ☐ Build và chạy bản iOS native trên macOS/Xcode Simulator hoặc iPhone thật để xác nhận chế độ lưu cục bộ (`BUG-07`). | macOS + Xcode / iPhone thật |
| TC-SYNC-07 | Đã kiểm bản demo `main_timelens.dart` trên Web Chrome 158 ([TC-SYNC-07.png](evidence/TC-SYNC-07.png)). | ☐ Mở URL bản demo TimeLens trên Chrome của điện thoại Android thật và Safari trên iPhone (chưa đăng nhập, không cấp camera/GPS). | Android thật + iPhone thật (Safari) |

### Đa kích thước màn hình (1 ca · Minh Khoa)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-UI-04 | Đã chụp đủ 4 viewport (`360×640`, `390×844`, `768×1024`, `1440×900`) + xoay ngang trên Web Chrome 158 và cỡ chữ hệ thống 130% dọc/ngang trên Android 15 Emulator ([TC-UI-04-android-130-landscape.png](evidence/TC-UI-04-android-130-landscape.png)). | ☐ Kiểm tra phóng chữ 130% và xoay ngang/dọc trên điện thoại Android thật và iPhone/iOS. | Android thật + iOS thật |
