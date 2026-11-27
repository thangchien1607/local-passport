# Hướng dẫn chạy thủ công Local Passport (10 ca còn lại)

[ĐÃ CHẠY] **60/70 ca thủ công** (50 Pass, 10 Fail trên bản gốc `065103c`) đã được thực thi trên **Web Chrome 158.0.8127.37**, **Android Emulator `LP_390x844_API35`** và **điện thoại thật** (8 ca camera/GPS: `TC-QR-01`, `TC-QR-03`…`TC-QR-08`, `TC-REF-09`, đều Pass), kèm **169 tệp bằng chứng thật** trong `docs/testing/evidence/`.

Tài liệu này giữ lại **đúng 10 ca thủ công vẫn đang `Chưa chạy`** cần hộp thư/OAuth thật, macOS/iOS hoặc dữ liệu Firestore thử kiểm soát.

## Chuẩn bị chạy trên điện thoại thật

1. Cài bản APK mới build ngày 27/11/2026 tại `build/app/outputs/flutter-apk/app-debug.apk` lên điện thoại Android thật (hoặc build lại sau khi gộp các nhánh sửa lỗi vào `develop`).
2. Chuẩn bị mã QR in/hiển thị từ `qrPayloadFor()` (đúng khóa, sai khóa `k=SAI`, thiếu `k`, `checkin` rỗng, điểm khác).
3. Chuẩn bị hộp thư email thật nhận được thư xác minh/đặt lại mật khẩu của Firebase và tài khoản Google/Apple thử trên miền được phép.
4. Với mỗi ca hoàn thành, lưu ảnh chụp màn hình hoặc log vào `docs/testing/evidence/<MãTC>-real.<png|txt>` và cập nhật lại [bảng test case](02-bang-test-case.md).

## Smoke chuỗi luồng cốt lõi trên thiết bị thật

Chuỗi đăng nhập → bản đồ → check-in Demo → viết/sửa cảm nhận có ảnh → ngắt/bật mạng đồng bộ đã chạy đạt trên **bản Web gộp 11 bản vá** ([RETEST-COMBINED.txt](evidence/RETEST-COMBINED.txt), [RETEST-SMOKE-SYNC.png](evidence/RETEST-SMOKE-SYNC.png)). Chặng còn cần kiểm trên điện thoại thật:

- ☑ Cấp quyền Camera + GPS, quét mã QR thật tại vị trí trong bán kính 300 m (`TC-QR-01`, `TC-QR-05`): Pass trên điện thoại thật.
- ☑ Chụp ảnh nhiệm vụ bằng camera vật lý và lưu (`TC-REF-09`): Pass trên điện thoại thật.
- ☐ Bổ sung ảnh chụp màn hình máy thật vào `evidence/<MãTC>-real.png`.
- ☐ Sau khi gộp 9 nhánh sửa còn lại vào `develop`, cài APK mới và chạy lại chuỗi này.

## Danh sách 10 ca thủ công vẫn đang Chưa chạy

### Xác thực và tài khoản (3 ca · Chiến Thắng)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-AUTH-05 | Đã kiểm gửi quên mật khẩu, đổi mật khẩu trong Hộ chiếu và gửi email xác minh ([TC-AUTH-05.png](evidence/TC-AUTH-05.png)). | ☐ Mở thư thật, bấm liên kết đặt lại mật khẩu và liên kết xác minh email rồi bấm `Kiểm tra xác minh`. | Hộp thư thật |
| TC-AUTH-06 | Đã kiểm email sai định dạng, mật khẩu hiện tại sai và xác nhận mới lệch ([TC-AUTH-06.png](evidence/TC-AUTH-06.png)). | ☐ Mở liên kết xác minh đã hết hạn hoặc bị sửa hỏng và xác nhận email vẫn chưa được xác minh. | Hộp thư thật |
| TC-AUTH-13 | Đã kiểm nâng cấp Khách bằng email giữ nguyên UID/dấu và xóa tài khoản vĩnh viễn ([TC-AUTH-13.png](evidence/TC-AUTH-13.png)). | ☐ Đăng nhập bằng tài khoản Google và Apple thử trên cấu hình/miền được cấp phép OAuth. | Tài khoản & miền OAuth Google/Apple |

### Cộng đồng, bảng xếp hạng và thông báo (4 ca · Minh Khoa)

| Mã TC | Phần đã kiểm trên Web/Emulator | Phần còn cần chạy để chốt Pass/Fail | Môi trường cần bổ sung |
| --- | --- | --- | --- |
| TC-COM-02 | Đã kiểm tìm từ khóa không khớp hiện trạng thái trống ([TC-COM-02.png](evidence/TC-COM-02.png)); trên bản vá `BUG-14` đã xác nhận phiên B không thấy nút Sửa/Xóa ở thẻ của A ([RETEST-BUG-14-COM01.png](evidence/RETEST-BUG-14-COM01.png)). | ☐ `BUG-14` đã được sửa trên `develop` (PR #43): chạy lại 2 phiên HAI trên bản build từ `develop` mới nhất. | Web / Android (2 phiên HAI) |
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
