# Báo cáo tổng hợp kiểm thử Local Passport

Môn Kiểm thử và sửa lỗi · Nhóm thực hiện: Chiến Thắng (`AUTH`/`QR`/`RULE`), Ngọc Anh (`MAP`/`REF`), Minh Khoa (`COM`/`SYNC`/`UI`)

## Phạm vi và nguồn dữ liệu

[ĐÃ CHẠY] Bản gốc để thực thi kiểm thử là `origin/develop` tại `065103c` (4 nhánh sửa lỗi phát hiện mới nhánh từ `origin/develop` tại `3394304`). Máy chạy Windows 11, Flutter 3.47.9, Dart 3.13.7, Node.js 24.19.0, npm 11.17.0, JDK Temurin `17.0.20.1+1` (ổ D, `GRADLE_USER_HOME=D:\.gradle`, không sửa file cấu hình Gradle của repo).

Các môi trường thực thi thủ công thực tế ngày **27/11/2026**:
- **Web Chrome 158.0.8127.37** (Windows 11, đa viewport `360×640`, `390×844`, `768×1024`, `1440×900`, ngang `844×390`, 2 phiên HAI độc lập, DevTools Offline / Slow 3G, CDP Geolocation, CDP chặn `maps.googleapis.com`, endpoint verifier lỗi HTTP 500, bản demo `lib/main_timelens.dart`).
- **Android Emulator `LP_390x844_API35`** (Android 15 API 35, `390×844 dp`, chạy file APK debug build mới `build/app/outputs/flutter-apk/app-debug.apk` ngày `27/11/2026`, Gboard thật, `font_scale 1.3`, xoay ngang/dọc, camera ảo `com.android.camera2`, `svc wifi/data disable`, `am force-stop`).
- Toàn bộ **169 tệp bằng chứng thật** (ảnh chụp PNG và log TXT) được lưu tại `docs/testing/evidence/`.

| Bước | Việc thực hiện | Minh chứng |
| --- | --- | --- |
| 1. Lập kế hoạch | Gộp phạm vi, xác định môi trường, phân công nhóm và điều kiện hoàn thành | [Kế hoạch](01-ke-hoach-kiem-thu.md) |
| 2. Viết ca kiểm thử | Chuẩn hóa 79 dòng TC, đủ bốn nhóm đúng, sai, trống, biên và phân công thành viên | [Bảng test case](02-bang-test-case.md) |
| 3. Thực hiện | Chạy tự động trên bản gốc, chạy thủ công trên Web Chrome 158 và Android Emulator `LP_390x844_API35` kèm 169 tệp bằng chứng | [Bảng test case](02-bang-test-case.md), `docs/testing/evidence/` |
| 4. Ghi nhận lỗi | Đối chiếu 10 mục nháp và lập danh sách **12 lỗi đã xác minh** (gồm 4 lỗi mới `BUG-13..16`) | [Bảng lỗi và đối chiếu](03-bang-loi.md) |
| 5. Sửa và kiểm thử lại | 11 nhánh sửa riêng có test tái hiện trước sửa, hồi quy gộp `+69` Flutter test, Rules `12/12`, build web và retest trực tiếp trên Chrome | [Kiểm thử nhánh sửa](#kiểm-thử-nhánh-sửa) |

## Thống kê test case theo phân hệ

Đơn vị là **dòng trong bảng chi tiết** (79 dòng = 70 ca thủ công + 4 ca Firestore Rules + 5 dòng kiểm tra tự động). Chỉ tính **Pass** hoặc **Fail** cho các ca đã thực sự thao tác, quan sát và có bằng chứng lưu trong `docs/testing/evidence/`.

| Phân hệ | Người phụ trách | Tổng | Pass | Fail | Chưa chạy |
| --- | --- | ---: | ---: | ---: | ---: |
| Xác thực và tài khoản | Chiến Thắng | 16 | 11 | 2 | 3 |
| Khám phá và bản đồ | Ngọc Anh | 8 | 7 | 1 | 0 |
| QR và GPS check-in | Chiến Thắng | 9 | 1 | 1 | 7 |
| Đóng dấu, cảm nhận và ảnh | Ngọc Anh | 13 | 8 | 4 | 1 |
| Cộng đồng, xếp hạng và thông báo | Minh Khoa | 12 | 7 | 1 | 4 |
| Đồng bộ, offline và TimeLens | Minh Khoa | 8 | 5 | 1 | 2 |
| Đa kích thước màn hình | Minh Khoa | 4 | 3 | 0 | 1 |
| **Thủ công** | **3 thành viên** | **70** | **42** | **10** | **18** |
| Firestore Rules | Chiến Thắng | 4 | 4 | 0 | 0 |
| Kiểm tra tự động | — | 5 | 5 | 0 | 0 |
| **Tổng** | — | **79** | **51** | **10** | **18** |

## Thống kê test case theo loại

| Loại case | Tổng | Pass | Fail | Chưa chạy |
| --- | ---: | ---: | ---: | ---: |
| Nhập đúng | 18 | 9 | 4 | 5 |
| Nhập sai | 18 | 12 | 3 | 3 |
| Để trống | 18 | 13 | 0 | 5 |
| Dữ liệu biên | 20 | 12 | 3 | 5 |
| Tự động | 5 | 5 | 0 | 0 |
| **Tổng** | **79** | **51** | **10** | **18** |

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
- [CHƯA XÁC MINH] Chặng quét mã QR bằng camera và GPS thực địa trên điện thoại thật vẫn chờ thực hiện trên máy thật (sau khi cài APK bản mới).

## Thống kê lỗi theo mức độ và trạng thái

| Mức độ | Đã sửa trên nhánh | Open | Tổng |
| --- | ---: | ---: | ---: |
| Critical | 1 | 0 | 1 |
| High | 2 | 1 | 3 |
| Medium | 7 | 0 | 7 |
| Low | 1 | 0 | 1 |
| **Tổng** | **11** | **1** | **12** |

[TỪ CODE] `BUG-07` giữ **Open** do là vấn đề cấu hình ngoài mã nguồn: `currentFirebaseOptions` trả `null` trên iOS nên bản iOS chạy cục bộ, cần cấu hình ứng dụng iOS trên Firebase Console cùng macOS/Xcode và iPhone thật để xác nhận.

## Kết luận

[ĐÃ CHẠY] Đợt thực thi ngày 27/11/2026 đã hoàn thành **61/79 dòng test case** (51 Pass, 10 Fail trên bản gốc) với **169 tệp ảnh chụp và log thật** trên Web Chrome 158 và Android Emulator `LP_390x844_API35`, phát hiện thêm **4 lỗi thật mới** (gồm 1 lỗi Critical `BUG-14` chặn đồng bộ toàn bộ bài cảm nhận và 1 lỗi High `BUG-16` gây màn hình đỏ Android), nâng tổng số lỗi đã xác minh lên **12 lỗi** (11 đã sửa trên nhánh riêng với hồi quy gộp `+69` bài và retest trực tiếp đạt; 1 lỗi `BUG-07` giữ Open). Còn **18 ca thủ công** giữ trạng thái **Chưa chạy** tập trung vào phần cứng điện thoại thật (camera QR, GPS thực địa), iOS/macOS, hộp thư/OAuth thật và bộ dữ liệu phân trang kiểm soát trên Firestore.

## KIỂM TRA TÍNH TRUNG THỰC

| Hạng mục | Đối chiếu thực tế |
| --- | --- |
| Test case theo trạng thái | **79 dòng** = **51 Pass** + **10 Fail** + **18 Chưa chạy**. Khớp tuyệt đối với [bảng test case](02-bang-test-case.md). Mọi ca Pass/Fail đều có tệp bằng chứng thật trong `docs/testing/evidence/`. |
| Test case theo loại | `18 Nhập đúng` (9P/4F/5CC) + `18 Nhập sai` (12P/3F/3CC) + `18 Để trống` (13P/0F/5CC) + `20 Dữ liệu biên` (12P/3F/5CC) + `5 Tự động` (5P) = **79 dòng**. |
| Số ca chạy theo môi trường | **Web Chrome 158.0.8127.37** (Windows 11): 51 ca có thực thi đầy đủ (41 Pass, 9 Fail) + 8 ca có bằng chứng một phần giữ Chưa chạy. **Android Emulator `LP_390x844_API35`** (Android 15, `app-debug.apk` build 27/11/2026): 9 ca chạy đầy đủ/xác nhận chéo (7 Pass: `AUTH-01`, `MAP-01`, `QR-09`, `REF-01`, `REF-11`, `UI-01`, `UI-02`, `UI-03`; 2 Fail: `MAP-05`, `SYNC-02` vì `BUG-16`) + 5 ca có bằng chứng một phần giữ Chưa chạy (`QR-03`, `QR-04`, `REF-09`, `SYNC-03`, `UI-04`). **RULES-EMU**: 4 ca Rules Pass (`12/12` bài). **CLI Windows**: 5 dòng Tự động Pass. **Điện thoại thật / iOS**: **0 ca** (tuyệt đối không ghi "thiết bị thật"). |
| Lỗi theo mức độ và trạng thái | **12 lỗi** = `1 Critical` + `3 High` + `7 Medium` + `1 Low` = **11 Đã sửa trên nhánh** + **1 Open** (`BUG-07`). Khớp tuyệt đối [bảng lỗi](03-bang-loi.md). |
| 18 ca vẫn "Chưa chạy" và lý do | `TC-AUTH-05`, `TC-AUTH-06` (thiếu hộp thư thật để bấm liên kết đặt lại/xác minh); `TC-AUTH-13` (thiếu OAuth Google/Apple thử); `TC-QR-01`, `TC-QR-03`, `TC-QR-04`, `TC-QR-05`, `TC-QR-06`, `TC-QR-07`, `TC-QR-08` (camera ảo máy ảo không quét được QR thật, cần camera/điện thoại thật); `TC-REF-09` (đã qua camera ảo nhưng cần camera điện thoại thật); `TC-COM-02` (bị `BUG-14` chặn trên bản gốc, đã xác nhận trên bản vá); `TC-COM-04`, `TC-COM-07`, `TC-COM-08` (Firestore chia sẻ đã có 50 mục, không gieo được bộ 19/20/21, <3 và 49/50/51 mục kiểm soát); `TC-SYNC-03` (đã qua Android offline, thiếu macOS/Xcode/iOS); `TC-SYNC-07` (đã qua Web Chrome, thiếu Chrome Android máy thật/Safari iOS); `TC-UI-04` (đã qua Web 4 viewport & Android 130% font, thiếu điện thoại thật/iOS). |
| Những gì KHÔNG làm được & đã loại bỏ | Không có điện thoại thật kết nối và không có máy macOS/iOS. Lượt thử mở Web trong Chrome bên trong máy ảo sau khi bật lại Wi-Fi gặp trạng thái `No internet connection` khiến ảnh bị dừng ở màn hình chờ — đã xóa sạch 10 tệp không đạt chuẩn khỏi `docs/testing/evidence/` và không tính làm bằng chứng Pass. |
