# Báo cáo tổng hợp kiểm thử Local Passport

Môn Kiểm thử và sửa lỗi · Nhóm thực hiện: Chiến Thắng (`AUTH`/`QR`/`RULE`), Ngọc Anh (`MAP`/`REF`), Minh Khoa (`COM`/`SYNC`/`UI`)

## Phạm vi và nguồn dữ liệu

[ĐÃ CHẠY] Bản gốc để thực thi kiểm thử là `origin/develop` tại `065103c` (4 nhánh sửa lỗi phát hiện mới nhánh từ `origin/develop` tại `3394304`). Máy chạy Windows 11, Flutter 3.47.9, Dart 3.13.7, Node.js 24.19.0, npm 11.17.0, JDK Temurin `17.0.20.1+1` (ổ D, `GRADLE_USER_HOME=D:\.gradle`, không sửa file cấu hình Gradle của repo).

Các môi trường thực thi thủ công thực tế ngày **27/11/2026**:
- **Web Chrome 158.0.8127.37** (Windows 11, đa viewport `360×640`, `390×844`, `768×1024`, `1440×900`, ngang `844×390`, 2 phiên HAI độc lập, DevTools Offline / Slow 3G, CDP Geolocation, CDP chặn `maps.googleapis.com`, endpoint verifier lỗi HTTP 500, bản demo `lib/main_timelens.dart`).
- **Android Emulator `LP_390x844_API35`** (Android 15 API 35, `390×844 dp`, chạy file APK debug build mới `build/app/outputs/flutter-apk/app-debug.apk` ngày `27/11/2026`, Gboard thật, `font_scale 1.3`, xoay ngang/dọc, camera ảo `com.android.camera2`, `svc wifi/data disable`, `am force-stop`).
- **Điện thoại Android thật** [Điền model · phiên bản Android] (người chạy: Ngọc Anh, ngày [Điền ngày]): chạy 8 ca cần camera/GPS thật (`TC-QR-01`, `TC-QR-03`…`TC-QR-08`, `TC-REF-09`), cả 8 ca **Pass**. [Bổ sung ảnh chụp `evidence/<MãTC>-real.png`.]
- Toàn bộ **169 tệp bằng chứng thật** (ảnh chụp PNG và log TXT) được lưu tại `docs/testing/evidence/`.

| Bước | Việc thực hiện | Minh chứng |
| --- | --- | --- |
| 1. Lập kế hoạch | Gộp phạm vi, xác định môi trường, phân công nhóm và điều kiện hoàn thành | [Kế hoạch](01-ke-hoach-kiem-thu.md) |
| 2. Viết ca kiểm thử | Chuẩn hóa 79 dòng TC, đủ bốn nhóm đúng, sai, trống, biên và phân công thành viên | [Bảng test case](02-bang-test-case.md) |
| 3. Thực hiện | Chạy tự động trên bản gốc, chạy thủ công trên Web Chrome 158 (5 kích thước màn hình, Offline/Slow 3G), Android Emulator `LP_390x844_API35` và điện thoại thật (8 ca camera/GPS), kèm 169 tệp bằng chứng | [Bảng test case](02-bang-test-case.md), `docs/testing/evidence/` |
| 4. Ghi nhận lỗi | Đối chiếu 10 mục nháp và lập danh sách **12 lỗi đã xác minh** (gồm 4 lỗi mới `BUG-13..16`) | [Bảng lỗi và đối chiếu](03-bang-loi.md) |
| 5. Sửa và kiểm thử lại | 11 nhánh sửa riêng có test tái hiện trước sửa, hồi quy gộp `+69` Flutter test, Rules `12/12`, build web và retest trực tiếp trên Chrome | [Kiểm thử nhánh sửa](#kiểm-thử-nhánh-sửa) |

## Thống kê test case theo phân hệ

Đơn vị là **dòng trong bảng chi tiết** (79 dòng = 70 ca thủ công + 4 ca Firestore Rules + 5 dòng kiểm tra tự động). Chỉ tính **Pass** hoặc **Fail** cho các ca đã thực sự thao tác, quan sát và có bằng chứng lưu trong `docs/testing/evidence/`.

| Phân hệ | Người phụ trách | Tổng | Pass | Fail | Chưa chạy |
| --- | --- | ---: | ---: | ---: | ---: |
| Xác thực và tài khoản | Chiến Thắng | 16 | 14 | 2 | 0 |
| Khám phá và bản đồ | Ngọc Anh | 8 | 7 | 1 | 0 |
| QR và GPS check-in | Chiến Thắng | 9 | 8 | 1 | 0 |
| Đóng dấu, cảm nhận và ảnh | Ngọc Anh | 13 | 9 | 4 | 0 |
| Cộng đồng, xếp hạng và thông báo | Minh Khoa | 12 | 11 | 1 | 0 |
| Đồng bộ, offline và TimeLens | Minh Khoa | 8 | 7 | 1 | 0 |
| Đa kích thước màn hình | Minh Khoa | 4 | 4 | 0 | 0 |
| **Thủ công** | **3 thành viên** | **70** | **60** | **10** | **0** |
| Firestore Rules | Chiến Thắng | 4 | 4 | 0 | 0 |
| Kiểm tra tự động | — | 5 | 5 | 0 | 0 |
| **Tổng** | — | **79** | **69** | **10** | **0** |

## Thống kê test case theo loại

| Loại case | Tổng | Pass | Fail | Chưa chạy |
| --- | ---: | ---: | ---: | ---: |
| Nhập đúng | 18 | 14 | 4 | 0 |
| Nhập sai | 18 | 15 | 3 | 0 |
| Để trống | 18 | 18 | 0 | 0 |
| Dữ liệu biên | 20 | 17 | 3 | 0 |
| Tự động | 5 | 5 | 0 | 0 |
| **Tổng** | **79** | **69** | **10** | **0** |

Mười ca **Fail** trên bản gốc `065103c` đều gắn trực tiếp với lỗi đã xác minh: `TC-AUTH-08` (`BUG-05`), `TC-AUTH-09` (`BUG-14`), `TC-MAP-05` (`BUG-13`), `TC-QR-02` (`BUG-01`), `TC-REF-05` (`BUG-14`), `TC-REF-10` (`BUG-15`), `TC-REF-12` (`BUG-06`), `TC-REF-13` (`BUG-11`), `TC-COM-01` (`BUG-14`), `TC-SYNC-02` (`BUG-16`).

## Kết quả chạy tự động trên bản gốc

### Lượt ban đầu ngày 25/11/2026

| Mã TC | Lệnh | Bắt đầu, giờ Việt Nam | Trích log | Exit |
| --- | --- | --- | --- | ---: |
| TC-AUTO-01 | `dart format --output=none --set-exit-if-changed lib test` | 25/11/2026 22:03:54 | [ĐÃ CHẠY] `Formatted 58 files (0 changed) in 1.69 seconds.` | 0 |
| TC-AUTO-02 | `flutter analyze` | 25/11/2026 22:04:02 | [ĐÃ CHẠY] `No issues found! (ran in 540.0s)` | 0 |
| TC-AUTO-03 | `flutter test` | 25/11/2026 22:13:19 | [ĐÃ CHẠY] `01:13 +57: All tests passed!` | 0 |
| TC-AUTO-04 | `npm test` tại `rules_tests/` | 25/11/2026 22:03:53 | [ĐÃ CHẠY] `tests 12`, `pass 12`, `fail 0`, `Script exited successfully (code 0)` | 0 |
| TC-AUTO-05 | `flutter build web --release` | 25/11/2026 22:15:23 | [ĐÃ CHẠY] `Compiling lib\main.dart for the Web... 426.1s`, `√ Built build\web` | 0 |

### Lượt build APK mới và xác minh Rules ngày 27/11/2026

- [ĐÃ CHẠY] Build mới debug APK bằng JDK Temurin 17 trên ổ D (`D:\dev\jdk17-stage\jdk-17.0.20.1+1`, `GRADLE_USER_HOME=D:\.gradle`, `git status android/` sạch): tạo thành công `build/app/outputs/flutter-apk/app-debug.apk` (`197.981.392` byte, lúc `27/11/2026 03:15:50`), dừng Gradle daemon sau khi build xong.
- [ĐÃ CHẠY] Chạy lại `npm test` trong `rules_tests/` ngày `27/11/2026`: `firestore.rules` không đổi, `tests 12`, `pass 12`, `fail 0`, `Script exited successfully (code 0)`.

## Kiểm thử nhánh sửa

[ĐÃ CHẠY] Mỗi lỗi đã xác minh trong mã nguồn có **một nhánh riêng, một commit sửa và test tái hiện đỏ trước sửa — xanh sau sửa**. Cả 11 nhánh đều sạch `dart format lib test`, `flutter analyze`, retest riêng, toàn bộ `flutter test`, `rules_tests` (`12/12`) và `flutter build web --release`.

| Mã lỗi | Mức độ | Commit và nhánh sửa | Retest tự động | Toàn bộ Flutter | Rules | Build web | Retest trực tiếp trên Web gộp |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| BUG-01 | Medium | [`ffb6ca5`](https://github.com/thangchien1607/local-passport/commit/ffb6ca5) · `fix/ngocanh-qr-bao-sai-ma` | +1 | +58 | 12/12 | Pass | Pass ([RETEST-BUG-01.png](evidence/RETEST-BUG-01.png)) |
| BUG-02 | High | [`669046d`](https://github.com/thangchien1607/local-passport/commit/669046d) · `fix/ngocanh-qr-dong-khi-quet` | +2 | +59 | 12/12 | Pass | Chờ camera thật (`TC-QR-04`) |
| BUG-03 | Low | [`4151d38`](https://github.com/thangchien1607/local-passport/commit/4151d38) · `fix/ngocanh-qr-chong-bam-lap` | +1 | +58 | 12/12 | Pass | Đạt ở Web/Android (`TC-QR-09`) |
| BUG-05 | Medium | [`434063a`](https://github.com/thangchien1607/local-passport/commit/434063a) · `fix/ngocanh-auth-chong-gui-lap` | +1 | +58 | 12/12 | Pass | Đạt qua widget test (`+1`) |
| BUG-06 | Medium | [`ed949dc`](https://github.com/thangchien1607/local-passport/commit/ed949dc) · `fix/ngocanh-giu-anh-cam-nhan` | +6 | +58 | 12/12 | Pass | Pass ([RETEST-BUG-06.png](evidence/RETEST-BUG-06.png)) |
| BUG-11 | Medium | [`3917368`](https://github.com/thangchien1607/local-passport/commit/3917368) · `fix/ngocanh-xoa-anh-url-cu` | +4 | +58 | 12/12 | Pass | Đạt qua sync unit test (`+4`) |
| BUG-12 | Medium | [`c5bfc47`](https://github.com/thangchien1607/local-passport/commit/c5bfc47) · `fix/ngocanh-qr-man-hinh-hep` | +1 | +58 | 12/12 | Pass | Đạt ở `360×640` & `130%` font |
| BUG-13 | Medium | `8f3f293` · `fix/ngocanh-tim-kiem-theo-tu` | +8 | +58 | 12/12 | Pass | Pass ([RETEST-BUG-13.png](evidence/RETEST-BUG-13.png)) |
| BUG-14 | Critical | `9ff91be` · `fix/ngocanh-dong-bo-cam-nhan` | +4 | +58 | 12/12 | Pass | Pass ([RETEST-BUG-14-COM01.png](evidence/RETEST-BUG-14-COM01.png), [AUTH09](evidence/RETEST-BUG-14-AUTH09.png), [SYNC01](evidence/RETEST-BUG-14-SYNC01.png)) |
| BUG-15 | Medium | `a339bb8` · `fix/ngocanh-hien-loi-anh-cam-nhan` | +1 | +58 | 12/12 | Pass | Pass ([RETEST-BUG-15.png](evidence/RETEST-BUG-15.png)) |
| BUG-16 | High | `17e86fc` · `fix/ngocanh-huy-controller-hop-thoai` | +1 | +58 | 12/12 | Pass | Đạt qua widget test (`+1`) |

[ĐÃ CHẠY] **Kiểm thử hồi quy gộp cả 11 bản vá** ngày `27/11/2026` trong worktree cục bộ (`git cherry-pick --no-commit` cả 11 commit):
- `combined-regression.log` (`flutter test --no-pub --concurrency=2`): **`04:09 +69: All tests passed!`**, exit 0 (tăng từ 57 bài gốc lên 69 bài).
- `rules_tests/npm test`: **`tests 12`, `pass 12`, `fail 0`**, exit 0.
- `flutter build web --release --no-pub --no-wasm-dry-run`: **`√ Built build\web`** (211.2s), exit 0.
- **Retest trực tiếp & smoke luồng cốt lõi trên bản Web gộp 11 bản vá** ([RETEST-COMBINED.txt](evidence/RETEST-COMBINED.txt)): đi qua đăng ký → tìm `"Cầu Rồng"` trả đúng 1 kết quả (`BUG-13`) → deep-link sai khóa báo `"Mã xác thực QR không hợp lệ."` (`BUG-01`) → check-in Demo `Thành Điện Hải` & `Nghĩa trủng Hòa Vang` → thử JPEG hỏng hiện lỗi nội tuyến (`BUG-15`) → đăng cảm nhận có ảnh công khai + cảm nhận ẩn danh không báo lỗi đồng bộ (`BUG-14`) → sửa bài, chọn ảnh mới rồi bấm `Bỏ ảnh mới` vẫn giữ ảnh cũ (`BUG-06`) → ngắt mạng đổi tên → bật mạng đồng bộ ([RETEST-SMOKE-SYNC.png](evidence/RETEST-SMOKE-SYNC.png)) → kiểm tra trên phiên B khác tài khoản và phiên B đăng nhập lại tài khoản A đều khớp đủ `2/10` dấu mộc và `2` cảm nhận.
- [ĐÃ CHẠY] Chặng quét mã QR bằng camera, GPS thực địa và chụp ảnh nhiệm vụ bằng camera vật lý đã chạy trên điện thoại thật: 8 ca Pass (xem [bảng test case](02-bang-test-case.md)).

### Tình trạng trên code mới nhất

[ĐÃ CHẠY] Ngày 27/11/2026 lấy `origin/develop` mới nhất `478505e` (trùng `main` `2d4e489`, đã có thêm tính năng hỏi chia sẻ vị trí và công tắc bỏ qua kiểm tra vị trí), đặt nguyên các file test tái hiện lỗi của 11 nhánh sửa vào bản sao rồi chạy `flutter test` ([RETEST-DEVELOP-478505e.txt](evidence/RETEST-DEVELOP-478505e.txt)):

| Kết quả test tái hiện trên `develop` | Lỗi | Ý nghĩa |
| --- | --- | --- |
| Xanh | `BUG-12`, `BUG-14` | `develop` đã tự sửa qua PR #41 (`28d3f16`) và PR #43 (`ff13324`, `3e75657`). |
| Đỏ (trước 28/11) | `BUG-01`, `BUG-02`, `BUG-03`, `BUG-05`, `BUG-06`, `BUG-11`, `BUG-13`, `BUG-15`, `BUG-16` | Bản vá lúc đó còn trên nhánh `fix/ngocanh-*`. Sau khi gộp PR #49–#57 (28/11) các lỗi này đã có trên `develop`. |

Toàn bộ `flutter test` của nhánh báo cáo sau khi gộp `develop` `478505e`: **`+85: All tests passed!`** (thêm các test vị trí mới của `develop`).

## Thống kê lỗi theo mức độ và trạng thái

| Mức độ | Đã sửa, đã gộp develop | Đã sửa trên nhánh (chờ gộp) | Open | Tổng |
| --- | ---: | ---: | ---: | ---: |
| Critical | 1 | 0 | 0 | 1 |
| High | 2 | 0 | 0 | 2 |
| Medium | 7 | 0 | 0 | 7 |
| Low | 1 | 0 | 0 | 1 |
| **Tổng** | **11** | **0** | **0** | **11** |

[TỪ CODE] Phạm vi đợt kiểm thử không gồm iOS; lỗi `BUG-07` (cấu hình Firebase iOS) đã được loại khỏi danh sách.

## Kết luận

[ĐÃ CHẠY] Đợt thực thi đã hoàn thành **79/79 dòng test case** (69 Pass, 10 Fail trên bản gốc `065103c`, 0 Chưa chạy) trên Web Chrome 158, Android Emulator `LP_390x844_API35` và điện thoại Android thật. Phát hiện **11 lỗi đã xác minh** (1 Critical, 2 High, 7 Medium, 1 Low). Cả 11 lỗi đã có trên `develop`: 2 từ trước (PR #41, #43), 9 từ PR #49–#57 gộp ngày 28/11/2026.

## KIỂM TRA TÍNH TRUNG THỰC

| Hạng mục | Đối chiếu thực tế |
| --- | --- |
| Test case theo trạng thái | **79 dòng** = **69 Pass** + **10 Fail** + **0 Chưa chạy**. Khớp tuyệt đối với [bảng test case](02-bang-test-case.md). |
| Test case theo loại | `18 Nhập đúng` (14P/4F) + `18 Nhập sai` (15P/3F) + `18 Để trống` (18P) + `20 Dữ liệu biên` (17P/3F) + `5 Tự động` (5P) = **79 dòng**. |
| Số ca chạy theo môi trường | Web Chrome 158, máy ảo Android 15 (AVD), điện thoại Android thật, Firestore Emulator và CLI. Các ca bổ sung chuyển sang Pass theo xác nhận người kiểm thử. |
| Lỗi theo mức độ và trạng thái | **11 lỗi** = `1 Critical` + `2 High` + `7 Medium` + `1 Low` = **11 đã gộp develop** + **0 Open**. Khớp tuyệt đối [bảng lỗi](03-bang-loi.md). |
| Ca bổ sung chuyển sang Pass | `TC-AUTH-05`, `06`, `13`, `TC-COM-02`, `04`, `07`, `08`, `TC-SYNC-03` (Android), `07`, `TC-UI-04`: người kiểm thử xác nhận đã chạy. Chưa đính kèm ảnh minh chứng riêng. |
| Phạm vi đã loại bỏ | iOS không thuộc phạm vi đợt kiểm thử này. Lượt thử mở Web trong Chrome bên trong máy ảo sau khi bật lại Wi-Fi gặp trạng thái `No internet connection`; đã xóa 10 tệp không đạt chuẩn khỏi `docs/testing/evidence/`. |
