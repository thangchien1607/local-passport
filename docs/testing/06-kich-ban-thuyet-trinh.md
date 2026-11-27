# Kịch bản thuyết trình Local Passport

Mỗi slide dự kiến 30–60 giây. Đọc các đoạn lời thoại, dùng dòng đối chiếu bên dưới mỗi slide để mở đúng minh chứng thật trong `docs/testing/evidence/` khi hội đồng đặt câu hỏi.

| Slide | Nội dung | Người trình bày |
| --- | --- | --- |
| 1–6 | Giới thiệu, lập kế hoạch, thiết kế và tổng quan 79 test case | Chiến Thắng |
| 7–10 | Test case tiêu biểu và kết quả thực hiện trên Web Chrome 158 & Android 15 | Ngọc Anh |
| 11–15 | 12 lỗi đã xác minh, demo ảnh thật BUG-06, retest và hồi quy 69 bài | Minh Khoa |
| 16–18 | Kết quả cuối, kiểm tra tính trung thực, hạn chế và hỏi đáp | Chiến Thắng / Cả nhóm |

## Slide 1 · Kiểm thử và sửa lỗi Local Passport

Em chào thầy/cô và các bạn. Nhóm em gồm Chiến Thắng, Ngọc Anh và Minh Khoa trình bày đề tài kiểm thử và sửa lỗi cho ứng dụng Local Passport — Hộ chiếu du lịch số Đà Nẵng. Bài trình bày đi qua năm bước chuẩn: lập kế hoạch, thiết kế test case, thực hiện kiểm thử thật trên Web Chrome và máy ảo Android 15, ghi nhận và sửa 11/12 lỗi đã xác minh, sau đó đối chiếu lại bằng retest trực tiếp và hồi quy tự động.

## Slide 2 · Giới thiệu và phạm vi

Local Passport cho phép du khách khám phá di tích Đà Nẵng trên bản đồ OpenStreetMap mặc định, quét QR kèm xác thực GPS trong bán kính 300 mét, thực hiện nhiệm vụ đóng dấu và viết cảm nhận có ảnh. Phạm vi kiểm thử bao phủ đủ 7 phân hệ nghiệp vụ, Firestore Rules và 5 mốc kiểm tra tự động, với cấu hình Firebase cho Web/Android và chế độ cục bộ riêng của iOS.

[TỪ CODE] `lib/services/maps_config.dart`, `lib/screens/map_screen.dart`, `lib/firebase_options.dart`, `lib/main.dart`.

## Slide 3 · Quy trình kiểm thử và sửa lỗi

Quy trình gồm năm bước khép kín, lấy mã test case làm trục đối chiếu xuyên suốt. Mọi ca đánh Pass hoặc Fail đều phải có ảnh chụp màn hình hoặc log thật trong thư mục `docs/testing/evidence/`. Khi phát hiện lỗi mới trong lúc chạy thủ công, nhóm viết test tự động tái hiện lỗi trước, sửa trên nhánh riêng, chạy lại hồi quy gộp và retest trực tiếp trên giao diện.

## Slide 4 · Bước 1 - Lập kế hoạch kiểm thử

Nhóm ưu tiên luồng cốt lõi từ đăng nhập, bản đồ, QR/GPS, đóng dấu đến cảm nhận có ảnh và đồng bộ mạng. Tiêu chí nghiêm ngặt là chống bịa số liệu: ghi đúng môi trường thật đã dùng (Web Chrome 158 hoặc Android Emulator `LP_390x844_API35`), tuyệt đối không ghi "thiết bị thật" nếu chưa chạy trên điện thoại thật, và giữ trạng thái Chưa chạy với lý do cụ thể cho các ca thiếu phần cứng.

## Slide 5 · Bước 2 - Viết test case

Bộ test case chia bốn nhóm dữ liệu vào: Nhập đúng, Nhập sai, Để trống và Dữ liệu biên. Ví dụ `TC-AUTH-01` kiểm tra đăng ký/đăng nhập hợp lệ, `TC-QR-02` kiểm tra mã đúng điểm nhưng sai khóa `k`, `TC-RULE-03` bỏ trường bắt buộc `passportNo` để xác minh Firestore Rules từ chối ghi, và `TC-REF-08` thử sát biên 20 và 600 ký tự.

## Slide 6 · Tổng quan bộ test case

Tổng cộng có 79 dòng test case: 70 ca thủ công, 4 ca Firestore Rules và 5 dòng kiểm tra tự động. Sau đợt thực thi thật ngày 27/11/2026, toàn bộ bảng có **51 Pass**, **10 Fail** (đều gắn lỗi đã xác minh trên bản gốc `065103c`) và **18 Chưa chạy** (chủ yếu cần camera/GPS điện thoại thật, iOS hoặc hộp thư/OAuth thật). Phân bố loại ca gồm 18 Nhập đúng, 18 Nhập sai, 18 Để trống, 20 Dữ liệu biên và 5 Tự động.

[ĐÃ CHẠY] Đối chiếu [02-bang-test-case.md](02-bang-test-case.md) và [04-bao-cao-tong-hop.md](04-bao-cao-tong-hop.md).

## Slide 7 · Test case tài khoản, bản đồ và QR

Ở nhóm Tài khoản và Bản đồ, cả 4 ca tiêu biểu `TC-AUTH-01..04` và `TC-MAP-01..04` đều đã chạy thật trên Web Chrome 158 (và Android 15 cho `AUTH-01`, `MAP-01`) với kết quả **Pass**, bao gồm cả `TC-MAP-02` chứng minh tự fallback về OpenStreetMap khi chặn SDK Google Maps. Riêng nhóm QR, `TC-QR-02` **Fail** trực tiếp trên Web do `BUG-01`, còn `TC-QR-01`, `03`, `04` giữ **Chưa chạy** vì camera ảo máy ảo không quét được mã QR thật.

## Slide 8 · Test case đóng dấu, cộng đồng và đồng bộ

Ở nhóm Đóng dấu & cảm nhận, cả bốn ca `TC-REF-01`, `06`, `07`, `08` đều **Pass** — trong đó `TC-REF-06` đã dựng endpoint trả HTTP 500 thật để xác nhận fallback về chấm điểm heuristic `70/100`. Ở Cộng đồng, `TC-COM-01` **Fail** do lỗi nghiêm trọng `BUG-14` chặn đồng bộ cảm nhận, `TC-COM-03` **Pass**, còn `TC-COM-02` và `04` giữ **Chưa chạy**. Ở Đồng bộ, `TC-SYNC-01` và `04` **Pass**, `TC-SYNC-02` **Fail** trên Android 15 do lỗi văng màn hình đỏ `BUG-16`, còn `TC-SYNC-03` giữ **Chưa chạy** vì thiếu iOS.

## Slide 9 · Test case giao diện và Firestore Rules

Nhóm giao diện đã chạy thật `TC-UI-01`, `TC-UI-02` (xoay ngang/dọc cùng Gboard thật trên Android 15 không mất chữ) và `TC-UI-03` (`360×640` Web và cỡ chữ hệ thống `130%` Android 15) đạt **Pass**. `TC-UI-04` đã chụp đủ 4 viewport trên Web và cỡ chữ `130%` trên máy ảo nhưng giữ **Chưa chạy** vì còn thiếu điện thoại thật và iOS. Cả 4 ca Firestore Rules đều **Pass** trên Emulator (`12/12` bài).

## Slide 10 · Bước 3 - Thực hiện kiểm thử

Bên trái là 5 mốc kiểm tra tự động đạt 100% (`format`, `analyze`, `57` bài Flutter gốc, `12/12` Rules, `build web`). Bên phải là kết quả thực thi thủ công ngày 27/11/2026: **Web Chrome 158** chạy 51 ca (41 Pass, 9 Fail) đủ 4 viewport, offline/Slow 3G, 2 phiên HAI; **Android Emulator `LP_390x844_API35`** cài bản `app-debug.apk` build mới chạy bàn phím thật, cỡ chữ 130%, camera ảo và tắt Wi-Fi/Data. Tổng cộng lưu **169 tệp ảnh và log thật**; phần điện thoại thật và iOS còn chờ.

## Slide 11 · Bước 4 - Ghi nhận lỗi

Mỗi lỗi được chuẩn hóa đầy đủ mô tả, cách tái hiện kèm ảnh/log thật, vị trí file/dòng code, mức độ nghiêm trọng từ Critical đến Low và người phụ trách theo phân hệ (Chiến Thắng, Ngọc Anh, Minh Khoa).

## Slide 12 · Lỗi tiêu biểu

Slide nhấn mạnh 4 lỗi đại diện có ảnh hưởng lớn nhất:
- **`BUG-14` (Critical)**: hàm đồng bộ gọi `.get()` vào `reflection_owners/{id}` chưa tồn tại khiến Firestore trả 403 `PERMISSION_DENIED`, chặn đồng bộ toàn bộ bài cảm nhận mới.
- **`BUG-16` (High)**: hủy `TextEditingController` ngay khi đóng hộp thoại Đổi tên gây văng màn hình đỏ `_dependents.isEmpty` trên Android 15 debug APK.
- **`BUG-06` (Medium)**: bấm `Bỏ ảnh mới` khi sửa cảm nhận làm mất luôn ảnh cũ.
- **`BUG-07` (High · Open)**: thiếu cấu hình Firebase iOS ngoài mã nguồn nên iOS native chạy cục bộ.

## Slide 13 · Danh sách lỗi đã phát hiện

Tổng cộng có **12 lỗi đã xác minh** (8 lỗi từ rà soát mã nguồn & widget test + 4 lỗi mới `BUG-13..16` phát hiện khi chạy thật trên Chrome và Android 15): gồm **1 Critical, 3 High, 7 Medium và 1 Low**. Trong đó **11 lỗi đã có commit sửa trên nhánh riêng** kèm test tái hiện và hồi quy, chỉ còn **1 lỗi `BUG-07` giữ Open** do cần cấu hình Firebase iOS ngoài code.

## Slide 14 · Demo BUG-06 - Giữ ảnh cũ

Đây là bằng chứng trực quan trước và sau khi sửa cho `BUG-06` trên trình duyệt thật. Ảnh bên trái (`TC-REF-12.png`) chụp trên bản gốc: bài cảm nhận vốn có ảnh Cầu Rồng phía sau, nhưng khi chọn ảnh mới rồi bấm `Bỏ ảnh mới`, khung xem trước biến mất thành `Thêm ảnh` và lưu xong mất luôn ảnh cũ. Ảnh bên phải (`RETEST-BUG-06.png`) chụp sau bản vá `ed949dc`: sau khi bấm `Bỏ ảnh mới`, ảnh Thành Điện Hải cũ vẫn được giữ nguyên cùng nút `Đổi ảnh`, cả trước và sau khi bấm `Lưu & chấm lại`.

[ĐÃ CHẠY] [TC-REF-12.png](evidence/TC-REF-12.png), [RETEST-BUG-06.png](evidence/RETEST-BUG-06.png), `test/reflection_edit_test.dart` (`+5 -1` → `+6`).

## Slide 15 · Bước 5 - Sửa lỗi và kiểm thử lại

Khi gộp cả **11 bản vá** vào cùng một worktree cục bộ, bộ Flutter test tăng từ **57** lên **69 bài đạt 100%**, Firestore Rules giữ **12/12 đạt**, và build Web release thành công. Nhóm đã chạy retest trực tiếp trên bản Web gộp xác nhận hết lỗi `BUG-01`, `BUG-06`, `BUG-13`, `BUG-14`, `BUG-15` và đi trọn chuỗi smoke đăng nhập → bản đồ → đóng dấu → cảm nhận có ảnh → ngắt/bật mạng đồng bộ hai phiên.

## Slide 16 · Kết quả cuối

Ba tài liệu báo cáo (`02`, `03`, `04`) và slide đều đồng bộ số liệu: **79 dòng TC** (**51 Pass, 10 Fail bản gốc, 18 Chưa chạy**), **169 tệp minh chứng thật**, **12 lỗi có bằng chứng** (**11 đã sửa trên nhánh, 1 Open**), và file APK debug mới sẵn sàng cài lên điện thoại thật để khép kín các ca phần cứng.

## Slide 17 · Hạn chế và hướng phát triển

Hạn chế chính được ghi nhận trung thực là chưa có điện thoại thật kết nối (nên 7 ca quét QR/GPS camera thật giữ Chưa chạy), chưa có máy macOS/Xcode cho iOS (`BUG-07`, `TC-SYNC-03`), và chưa gieo bộ dữ liệu phân trang riêng trên Firestore dùng chung. Hướng tiếp theo là cài bản APK mới lên điện thoại thật để chạy nốt 18 ca theo checklist rút gọn ở `05-huong-dan-chay-thu-cong.md`, gộp 11 nhánh sửa lỗi vào `develop` và bổ sung cấu hình Firebase iOS.

## Slide 18 · Hỏi đáp

Nhóm em xin cảm ơn thầy/cô và các bạn đã lắng nghe, rất mong nhận được câu hỏi và góp ý.

## Năm câu hỏi giảng viên có thể hỏi

| Câu hỏi | Gợi ý trả lời |
| --- | --- |
| Vì sao vẫn còn 10 ca Fail trong bảng test case dù đã sửa 11 lỗi? | Bảng `02-bang-test-case.md` ghi kết quả thực thi trên **bản gốc `065103c`** để làm mốc so sánh trung thực. Kết quả retest sau khi sửa được ghi riêng trong [03-bang-loi.md](03-bang-loi.md) và `docs/testing/evidence/RETEST-*.png`. |
| Lỗi nào nghiêm trọng nhất phát hiện trong đợt chạy thủ công? | `BUG-14` (Critical): trên bản gốc `065103c`, mọi bài cảm nhận mới đều bị Firestore trả 403 `PERMISSION_DENIED` khi gọi `.get()` vào `reflection_owners/{id}` chưa tồn tại, khiến cộng đồng và đồng bộ 2 phiên không nhận được bài mới. Đã vá ở `9ff91be` và retest đạt trên 2 phiên HAI. |
| Vì sao 7 ca QR vẫn giữ Chưa chạy dù đã chạy trên máy ảo Android 15? | Camera ảo của máy ảo Android chỉ hiển thị cảnh mô phỏng, không quét được mã QR thật in ra hay trên màn hình. Theo quy tắc chống bịa, nhóm chỉ ghi nhận phần camera đứng chờ/mở lại và deep-link Web, giữ Chưa chạy cho các ca cần camera thật. |
| Lỗi `BUG-16` trên Android debug APK nguyên nhân do đâu? | Trong `lib/screens/passport_screen.dart`, ba hộp thoại Đổi tên, Đổi mật khẩu và Xóa tài khoản gọi `TextEditingController.dispose()` ngay sau `await showDialog(...)` khi hoạt ảnh đóng dialog vẫn đang dựng frame, gây assertion `_dependents.isEmpty`. Đã tách thành `StatefulWidget` tự hủy trong `State.dispose()` ở `17e86fc`. |
| Con số 57 → 69 trên slide 15 có ý nghĩa gì? | 57 là số bài unit/widget test Flutter trên bản gốc `065103c`. Sau khi bổ sung test tái hiện cho 11 lỗi và gộp cả 11 nhánh sửa vào cùng bản làm việc cục bộ, toàn bộ **69 bài Flutter test** đều Pass (`combined-regression.log`), kèm `12/12` bài Firestore Rules. |
