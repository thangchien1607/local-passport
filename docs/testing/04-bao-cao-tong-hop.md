# Báo cáo tổng hợp kiểm thử Local Passport

Môn Kiểm thử và sửa lỗi · Nhóm [Điền tên nhóm] · Thành viên [Tên thành viên] · Giảng viên [Điền tên]

## Phạm vi và nguồn dữ liệu

[ĐÃ CHẠY] Bản gốc để lập và chạy bộ kiểm tra là `origin/develop` ở `065103c`. Máy chạy Windows 11, Flutter 3.47.9, Dart 3.13.7, Node.js 24.19.0 và npm 11.17.0. Ngày giờ của log bên dưới theo giờ Việt Nam.

[TỪ CODE] Dự án dùng Flutter, OpenStreetMap mặc định, Firebase Auth và Firestore cho Web/Android. Khi `currentFirebaseOptions` trả `null`, `main()` nạp luồng lưu cục bộ. Nguồn [README](../../README.md), [cấu hình Firebase](../../lib/firebase_options.dart#L9) và [khởi tạo](../../lib/main.dart#L26).

| Bước | Việc thực hiện | Minh chứng |
| --- | --- | --- |
| 1. Lập kế hoạch | Gộp phạm vi của hai bản nháp, xác định môi trường và điều kiện hoàn thành | [Kế hoạch](01-ke-hoach-kiem-thu.md) |
| 2. Viết ca kiểm thử | Chuẩn hóa mã TC, dùng bốn nhóm đúng, sai, trống và biên | [Bảng test case](02-bang-test-case.md) |
| 3. Thực hiện | Chạy kiểm tra tự động trên commit gốc, chuẩn bị checklist thiết bị | [Log kiểm tra tự động](#kết-quả-chạy-tự-động-trên-bản-gốc), [checklist](05-huong-dan-chay-thu-cong.md) |
| 4. Ghi nhận lỗi | Đối chiếu mười mục nháp và bổ sung lỗi có bằng chứng | [Bảng lỗi và đối chiếu](03-bang-loi.md) |
| 5. Sửa và kiểm thử lại | Tái hiện tự động, sửa từng lỗi trên nhánh riêng, chạy retest và hồi quy | [Kiểm thử nhánh sửa](#kiểm-thử-nhánh-sửa) |

## Dữ liệu biên và cấu hình dự kiến

[TỪ CODE] Tên sau khi cắt khoảng trắng phải có nội dung và tối đa 30 ký tự. Mật khẩu gồm chữ, số và dài 6–64 ký tự. Cảm nhận dài 20–600 ký tự sau trim, nên dùng 19 và 20 để thử sát ngưỡng dưới. Nguồn [validators.dart](../../lib/services/validators.dart#L4), `validateName`, `validatePassword`, `validateReflection`.

[TỪ CODE] QR đi qua `parseQr`. `_handleCode` từ chối khi khoảng cách lớn hơn bán kính 300 m, do đó mốc 300 m được chấp nhận về mặt điều kiện code. Nguồn [geo.dart](../../lib/services/geo.dart#L8) và [qr_scanner_screen.dart](../../lib/screens/qr_scanner_screen.dart#L89).

[TỪ CODE] `compressImageBytes` nhắm ảnh sau nén 80 KiB, có ngưỡng ảnh nhị phân 120 KiB. `compressImageToBase64` còn giới hạn 120000 ký tự. `validTaskPhotos` cho tối đa ba ảnh nhiệm vụ mỗi visit. Ứng dụng kiểm tra kích thước document ước lượng 800 KiB trước ghi. Nguồn [photo_service.dart](../../lib/services/photo_service.dart#L8), [firestore.rules](../../firestore.rules#L28) và [passport_remote.dart](../../lib/services/passport_remote.dart), `runIdempotentChunkedSync`.

[CHƯA XÁC MINH] Các cấu hình thiết bị dự kiến là 360×640, 390×844, 768×1024 và 1440×900, cỡ chữ 130%, dọc/ngang, Slow 3G, offline và rớt mạng khi đang thao tác. Đây là thông số kế hoạch, kết quả lấy từ từng lần thực hiện trong [checklist](05-huong-dan-chay-thu-cong.md).

## Thống kê test case theo phân hệ

Đơn vị là **dòng trong bảng chi tiết**. Trong 74 ca nghiệp vụ và Rules có 70 ca thủ công và 4 ca Rules có assertion được đối chiếu từ log của `TC-AUTO-04`. Năm dòng còn lại thuộc nhóm Tự động, ghi việc chạy các lệnh hoặc bộ kiểm thử. Số bài do trình chạy báo được trình bày riêng ở phần log.

| Phân hệ | Tổng | Pass | Fail | Chưa chạy |
| --- | ---: | ---: | ---: | ---: |
| Xác thực và tài khoản | 16 | 0 | 0 | 16 |
| Khám phá và bản đồ | 8 | 0 | 0 | 8 |
| QR và GPS check-in | 9 | 0 | 0 | 9 |
| Đóng dấu, cảm nhận và ảnh | 13 | 0 | 0 | 13 |
| Cộng đồng, xếp hạng và thông báo | 12 | 0 | 0 | 12 |
| Đồng bộ, offline và TimeLens | 8 | 0 | 0 | 8 |
| Đa kích thước màn hình | 4 | 0 | 0 | 4 |
| **Thủ công** | **70** | **0** | **0** | **70** |
| Firestore Rules | 4 | 4 | 0 | 0 |
| Kiểm tra tự động | 5 | 5 | 0 | 0 |
| **Tổng** | **79** | **9** | **0** | **70** |

## Thống kê test case theo loại

| Loại case | Tổng | Pass | Fail | Chưa chạy |
| --- | ---: | ---: | ---: | ---: |
| Nhập đúng | 18 | 1 | 0 | 17 |
| Nhập sai | 18 | 1 | 0 | 17 |
| Để trống | 18 | 1 | 0 | 17 |
| Dữ liệu biên | 20 | 1 | 0 | 19 |
| Tự động | 5 | 5 | 0 | 0 |
| **Tổng** | **79** | **9** | **0** | **70** |

Mỗi ca Rules bổ sung một dòng Pass cho nhóm đầu vào tương ứng. Các ca kỳ vọng từ chối đạt Pass khi assertion xác nhận Rules từ chối. Xem các assertion và kết quả đối chiếu tại [bảng test case](02-bang-test-case.md#firestore-rules).

## Kết quả chạy tự động trên bản gốc

### Lượt ban đầu ngày 25/11/2026

| Mã TC | Lệnh | Bắt đầu, giờ Việt Nam | Trích log | Exit |
| --- | --- | --- | --- | ---: |
| TC-AUTO-01 | `dart format --output=none --set-exit-if-changed lib test` | 25/11/2026 22:03:54 | [ĐÃ CHẠY] `Formatted 58 files (0 changed) in 1.69 seconds.` | 0 |
| TC-AUTO-02 | `flutter analyze` | 25/11/2026 22:04:02 | [ĐÃ CHẠY] `No issues found! (ran in 540.0s)` | 0 |
| TC-AUTO-03 | `flutter test` | 25/11/2026 22:13:19 | [ĐÃ CHẠY] `01:13 +57: All tests passed!` | 0 |
| TC-AUTO-04 | `npm test` tại `rules_tests/` | 25/11/2026 22:03:53 | [ĐÃ CHẠY] `tests 12`, `pass 12`, `fail 0`, `Script exited successfully (code 0)` | 0 |
| TC-AUTO-05 | `flutter build web --release` | 25/11/2026 22:15:23 | [ĐÃ CHẠY] `Compiling lib\main.dart for the Web... 426.1s`, `√ Built build\web` | 0 |

[ĐÃ CHẠY] Log Firestore có các dòng `PERMISSION_DENIED` từ những bài chủ động kiểm tra rules từ chối thao tác. Kết quả suite là 12 bài đạt và exit 0. Lệnh `npm ci --no-audit --no-fund` cũng đã chạy xong với exit 0.

### Lượt chạy lại ngày 26/11/2026

Lượt này đối chiếu lại cùng các mốc tự động khi cập nhật tài liệu. Tên tệp dưới đây tra trong thư mục tạm `localpassport-qa-pptx-ef2afd7d` trên máy chạy. Các dòng trong bảng TC vẫn giữ ngày của lượt ban đầu.

| Mã TC | Lệnh | Bắt đầu, giờ Việt Nam | Trích log | Exit |
| --- | --- | --- | --- | ---: |
| TC-AUTO-01 | `dart format --output=none --set-exit-if-changed lib test` | 26/11/2026 13:57:53 | [ĐÃ CHẠY] `Formatted 58 files (0 changed) in 1.24 seconds.` · `dart-format.log` | 0 |
| TC-AUTO-02 | `flutter analyze` | 26/11/2026 13:58:07 | [ĐÃ CHẠY] `No issues found! (ran in 196.6s)` · `flutter-analyze.log` | 0 |
| TC-AUTO-03 | `flutter test` | 26/11/2026 14:01:35 | [ĐÃ CHẠY] `00:21 +57: All tests passed!` · `flutter-test.log` | 0 |
| TC-AUTO-04 | `npm test` tại `rules_tests/` | 26/11/2026 13:57:53 | [ĐÃ CHẠY] `tests 12`, `pass 12`, `fail 0`, `Script exited successfully (code 0)` · `rules-test.log` | 0 |
| TC-AUTO-05 | `flutter build web --release` | 26/11/2026 14:02:15 | [ĐÃ CHẠY] `Compiling lib\main.dart for the Web... 212.0s`, `√ Built build\web` · `flutter-build-web.log` | 0 |

## Quan sát màn chào trên Web

[ĐÃ CHẠY] Mở bản build tại localhost với Microsoft Edge Headless 158.0.4370.33 trên Windows. Ở cả 360×640, 390×844, 768×1024 và 1440×900, màn chào hiện tab Đăng nhập/Đăng ký. Ở 360×640, cần cuộn để xem form. CDP ghi `documentWidth` bằng viewport, `exceptions: []`, `consoleErrors: []` và `missingLocalResources: []` ở lượt cho phép tải SDK/phông chữ công khai.

[ĐÃ CHẠY] Minh chứng cục bộ của lượt quan sát gồm `result.json` và bốn ảnh `welcome-<viewport>.png` trong thư mục tạm `local-passport-smoke-BPe5SJ`. Cấu hình lượt này chặn endpoint dữ liệu Firebase. [CHƯA XÁC MINH] Kết quả của toàn bộ các màn hình, thao tác tài khoản, camera/GPS và mạng trong checklist vẫn chờ thực hiện, nên trạng thái của các TC thủ công giữ nguyên.

## Chênh lệch với bản nháp

| Mục trong nháp | Đối chiếu |
| --- | --- |
| [CHƯA XÁC MINH] `52/52` Flutter test | [ĐÃ CHẠY] Log bản gốc báo 57 bài đạt. Chênh 5 bài so với tuyên bố trong nháp. |
| [CHƯA XÁC MINH] `12/12` bài rules và 16 file test Flutter | [ĐÃ CHẠY] Runner báo 12 bài rules đạt. Đếm `rg --files test -g '*_test.dart'` trên bản gốc có 16 file. |
| [CHƯA XÁC MINH] 29 TC | Bộ hợp nhất có 79 dòng, gồm 70 ca thủ công, 4 ca Rules có assertion đối chiếu và 5 dòng lệnh tự động. Các ca được tách theo loại đầu vào và môi trường. |
| [CHƯA XÁC MINH] `PR #27` và `v1.8.2` là căn cứ phiên chạy | [ĐÃ CHẠY] Phiên này bám commit `065103c` của `origin/develop`. [TỪ CODE] Phiên bản khai báo trong [pubspec.yaml](../../pubspec.yaml#L19) là `1.0.0+1`. |
| Google Maps, OpenStreetMap và iOS | [TỪ CODE] OpenStreetMap là mặc định. Google Maps là tùy chọn. iOS có đường chạy cục bộ khi `currentFirebaseOptions` trả `null`. |
| Danh sách lỗi nháp | Nhận định gốc, điều đã xác minh và rủi ro được truy theo từng hàng trong [bảng lỗi](03-bang-loi.md). |

## Kiểm thử nhánh sửa

[ĐÃ CHẠY] Mỗi lỗi có một commit riêng từ `065103c`. Các cột retest và smoke là số bài đạt trong các tệp đã chạy. Mỗi nhánh có log exit 0 cho `dart format lib test`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub`, retest Flutter, hồi quy Flutter, smoke Flutter, `npm test` trong `rules_tests/` và `flutter build web --release --no-pub`. Các lượt `--no-pub` dùng dependencies đã được giải quyết cho worktree. Build ghi `√ Built build\web`. Đây là kết quả trên nhánh sửa, tách khỏi bảng TC bản gốc.

| Mã lỗi | Commit và nhánh sửa | Retest đạt | Toàn bộ Flutter đạt | Smoke đạt | Rules đạt | Build web |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| BUG-01 | [`ffb6ca5`](https://github.com/thangchien1607/local-passport/commit/ffb6ca5) · `fix/ngocanh-qr-bao-sai-ma` | 1 | 58 | 23 | 12/12 | Pass |
| BUG-02 | [`669046d`](https://github.com/thangchien1607/local-passport/commit/669046d) · `fix/ngocanh-qr-dong-khi-quet` | 2 | 59 | 23 | 12/12 | Pass |
| BUG-03 | [`4151d38`](https://github.com/thangchien1607/local-passport/commit/4151d38) · `fix/ngocanh-qr-chong-bam-lap` | 1 | 58 | 23 | 12/12 | Pass |
| BUG-05 | [`434063a`](https://github.com/thangchien1607/local-passport/commit/434063a) · `fix/ngocanh-auth-chong-gui-lap` | 1 | 58 | 23 | 12/12 | Pass |
| BUG-06 | [`ed949dc`](https://github.com/thangchien1607/local-passport/commit/ed949dc) · `fix/ngocanh-giu-anh-cam-nhan` | 6 | 58 | 23 | 12/12 | Pass |
| BUG-11 | [`3917368`](https://github.com/thangchien1607/local-passport/commit/3917368) · `fix/ngocanh-xoa-anh-url-cu` | 4 | 58 | 24 | 12/12 | Pass |
| BUG-12 | [`c5bfc47`](https://github.com/thangchien1607/local-passport/commit/c5bfc47) · `fix/ngocanh-qr-man-hinh-hep` | 1 | 58 | 23 | 12/12 | Pass |

[ĐÃ CHẠY] BUG-06 là ví dụ trước và sau sửa. `flutter test test/reflection_edit_test.dart --reporter expanded` trên bản gốc kèm test tái hiện ghi `+5 -1`, exit 1. Test chờ giữ Base64 cũ và nhận `Actual: <null>`. Cùng lệnh sau sửa ghi `+6: All tests passed!`, exit 0. Các lỗi tái hiện trước sửa nằm trong [bảng lỗi](03-bang-loi.md#minh-chứng-tái-hiện-bằng-kiểm-thử-tự-động).

[ĐÃ CHẠY] Bộ smoke chọn các bài xác thực, đóng dấu, cộng đồng, bảng xếp hạng, đồng bộ và TimeLens. Để kiểm tra tương tác giữa các bản vá, một worktree cục bộ áp dụng cả bảy commit bằng `git cherry-pick --no-commit`. Log `combined-regression.log` ngày 25/11/2026 ghi `01:19 +65: All tests passed!`, exit 0, với `flutter test --no-pub --concurrency=2 --reporter expanded`. Các commit sửa hiện có trên bảy nhánh GitHub độc lập.

[ĐÃ CHẠY] Ngày 26/11/2026 lúc 14:09:07, trên worktree gộp bản vá, đã thử `flutter test --no-pub --reporter expanded "$env:TEMP\localpassport-qa-pptx-ef2afd7d\core_smoke_test.dart"`. Bài thử dùng camera, GPS, ảnh và backend mô phỏng. Lượt này đi qua đăng nhập, mở bản đồ và xác nhận địa điểm được mở khóa. Widget test dừng ở nút **Viết cảm nhận** do thao tác chạm không tới nút, sau đó ghi `Bad state: No element` và exit 1. Log `core-smoke.log` có chẩn đoán về phông chữ và `ListTile`. Kết quả thăm dò được ghi riêng, các TC về cảm nhận, ảnh và đồng bộ vẫn Chưa chạy theo checklist.

[CHƯA XÁC MINH] Smoke xuyên suốt trên thiết bị còn chờ. Chuỗi cần thực hiện gồm đăng nhập, mở bản đồ, quét QR check-in, viết/sửa cảm nhận kèm ảnh, rồi ngắt và bật mạng để kiểm đồng bộ. Ghi kết quả từng chặng theo [checklist smoke](05-huong-dan-chay-thu-cong.md#smoke-chuỗi-luồng-cốt-lõi).

## Thống kê lỗi theo mức độ và trạng thái

| Mức độ | Đã sửa trên nhánh | Open | Tổng |
| --- | ---: | ---: | ---: |
| Critical | 0 | 0 | 0 |
| High | 1 | 1 | 2 |
| Medium | 5 | 0 | 5 |
| Low | 1 | 0 | 1 |
| **Tổng** | **7** | **1** | **8** |

[TỪ CODE] BUG-07 giữ Open. `currentFirebaseOptions` trả `null` trên iOS nên bản iOS chạy cục bộ. Phần Auth/Firestore cần cấu hình Firebase iOS, macOS/Xcode và lượt kiểm trên simulator hoặc thiết bị thật. Nguồn [firebase_options.dart](../../lib/firebase_options.dart#L9), [main.dart](../../lib/main.dart#L38).

## Kết luận

[ĐÃ CHẠY] Năm kiểm tra tự động trên bản gốc hoàn tất thành công. Bảy nhánh sửa có retest, hồi quy và build web đạt. [CHƯA XÁC MINH] Điều kiện nghiệm thu thiết bị và mạng vẫn còn 70 ca thủ công theo [checklist](05-huong-dan-chay-thu-cong.md). Thành viên nhóm chạy ca được giao, ghi kết quả và đính kèm ảnh thật trước khi chốt nghiệm thu.

## KIỂM TRA TÍNH TRUNG THỰC

| Hạng mục | Đối chiếu |
| --- | --- |
| Test case theo trạng thái | 79 dòng = 9 Pass + 0 Fail + 70 Chưa chạy. Khớp [bảng test case](02-bang-test-case.md). Báo đỏ khi tái hiện lỗi và số bài do runner báo được thống kê riêng trong log. |
| Test case theo loại | 18 Nhập đúng + 18 Nhập sai + 18 Để trống + 20 Dữ liệu biên + 5 Tự động = 79 dòng. |
| Lỗi theo mức độ | 8 lỗi = 0 Critical + 2 High + 5 Medium + 1 Low. |
| Lỗi theo trạng thái | 8 lỗi = 7 Đã sửa trên nhánh + 1 Open (BUG-07). Khớp [bảng lỗi](03-bang-loi.md). Các mục đối chiếu nháp và rủi ro có bảng riêng. |
| [CHƯA XÁC MINH] Kết quả thủ công | 70 ca còn chờ, gồm hành vi trên máy ảo và thiết bị thật, camera/GPS, nhà cung cấp đăng nhập, toàn bộ luồng hiển thị khi tăng chữ/xoay, offline/Slow 3G/rớt mạng và phục hồi đồng bộ. Tên thành viên, thiết bị, phiên bản, thời điểm và ảnh của từng lượt còn chờ điền. |
| [CHƯA XÁC MINH] Các điểm cần môi trường riêng | Hành vi Firebase iOS, mức sử dụng quota khi tải nhiều ảnh, retest bằng phần cứng và dữ liệu ngoài emulator. |
| Công việc chưa thực hiện và lý do | [ĐÃ CHẠY] Kiểm tra lại ngày 26/11/2026, `emulator.exe -list-avds` không liệt kê AVD, `adb.exe devices -l` chỉ trả tiêu đề danh sách. Windows không có môi trường iOS Simulator. Smoke Edge chỉ quan sát màn chào. Lượt thử với widget mô phỏng dừng trước khi lưu cảm nhận, chi tiết tại [kiểm thử nhánh sửa](#kiểm-thử-nhánh-sửa). Các luồng thật cần thiết bị, quyền camera/GPS, tài khoản và dữ liệu Firebase thử của nhóm. |
