# Kịch bản thuyết trình Local Passport

Bám theo 29 slide của [slide.pptx](slide.pptx). Mỗi slide khoảng 20–45 giây, riêng 6 slide bảng test case có thể lướt nhanh và chỉ dừng ở các dòng Fail. Khi hội đồng hỏi, mở minh chứng thật trong `docs/testing/evidence/`.

| Slide | Nội dung | Người trình bày |
| --- | --- | --- |
| 1–8 | Giới thiệu, bước 1 lập kế hoạch, bước 2 cách viết và tổng quan test case | Chiến Thắng |
| 9–14 | Bảng test case đầy đủ 18 chức năng | Ngọc Anh |
| 15–18 | Bước 3 thực hiện: tự động, máy ảo, máy thật, nhiều màn hình, mất mạng | Ngọc Anh |
| 19–23 | Bước 4 ghi nhận lỗi: mẫu, danh sách 12 lỗi, thống kê, ví dụ BUG-06 | Minh Khoa |
| 24–29 | Bước 5 sửa và kiểm thử lại, tình trạng trên code mới nhất, đối chiếu yêu cầu, hỏi đáp | Minh Khoa / Cả nhóm |

## Slide 1 · Mở đầu

Nhóm em gồm Chiến Thắng, Ngọc Anh và Minh Khoa trình bày phần kiểm thử và sửa lỗi ứng dụng Local Passport: bảng test case, danh sách lỗi đã phát hiện và tình trạng xử lý.

## Slide 2 · Giới thiệu và phạm vi

Local Passport là hộ chiếu du lịch số Đà Nẵng viết bằng Flutter. Phạm vi kiểm thử gồm ứng dụng Web/Android/iOS, bản đồ, Firebase, phần cứng camera/GPS và các trải nghiệm đồng bộ, offline. Bản kiểm thử gốc là `develop 065103c`; nhóm đối chiếu lại tình trạng lỗi trên code mới nhất `develop 478505e`.

## Slide 3 · Quy trình 5 bước

Nhóm đi đúng 5 bước: lập kế hoạch, viết test case, thực hiện, ghi nhận lỗi, sửa và kiểm thử lại. Mọi ca Pass/Fail đều có ảnh hoặc log thật.

## Slide 4–6 · Bước 1: chức năng, tiêu chí, môi trường

Chúng em chia ứng dụng thành 8 phân hệ, mỗi phân hệ có người phụ trách. Tiêu chí: Pass khi kết quả thực tế khớp mong đợi và có minh chứng; Fail thì phải lập lỗi gắn mã TC; Chưa chạy phải ghi lý do. Môi trường gồm Web Chrome nhiều kích thước, máy ảo Android 15, điện thoại thật, giả lập mất mạng và Firestore Emulator. iOS chưa có máy nên ghi rõ là chưa chạy.

## Slide 7–8 · Bước 2: cách viết và tổng quan test case

Mỗi chức năng có đủ 4 loại ca: nhập đúng, nhập sai, để trống và dữ liệu biên. Tổng 79 dòng: 18 chức năng × 4 = 72 ca, thêm 2 ca biên và 5 dòng kiểm tra tự động. Kết quả: **59 Pass, 10 Fail, 10 Chưa chạy**. 10 ca Fail đều dẫn tới lỗi thật.

## Slide 9–14 · Bảng test case đầy đủ

Sáu slide này liệt kê toàn bộ test case theo chức năng. Mỗi dòng có dữ liệu vào, kết quả mong đợi, môi trường và trạng thái. Nên dừng ở các ca Fail: TC-AUTH-08 (gửi đăng nhập 2 lần), TC-MAP-05 (tìm “Cầu Rồng” sai), TC-QR-02 (báo nhầm khi sai khóa QR), TC-REF-05/COM-01 (không đồng bộ được bài), TC-REF-10/12/13 (lỗi ảnh), TC-SYNC-02 (màn hình đỏ Android).

## Slide 15 · Kiểm tra tự động

Năm lệnh format, analyze, flutter test, Firestore Rules và build web đều Pass. Số bài flutter test tăng từ 57 lên 69 khi thêm test tái hiện lỗi, và 85 trên code mới nhất.

## Slide 16–18 · Máy ảo, máy thật, nhiều màn hình, mất mạng

Trên máy ảo Android 15, nhóm chạy đăng ký, bản đồ, tìm kiếm, Demo QR, camera ảo, xoay màn hình và chữ 130%. Trên điện thoại thật, nhóm chạy 8 ca cần camera và GPS: quét QR, đứng trong/ngoài 300 m, tắt GPS, chụp ảnh nhiệm vụ; cả 8 ca đều Pass. Nhiều kích thước màn hình: 360×640 đến 1440×900, xoay ngang. Mất mạng: DevTools Offline/Slow 3G và tắt Wi-Fi trên máy ảo.

## Slide 19 · Mẫu ghi nhận lỗi

Mỗi lỗi ghi mã, TC liên quan, mô tả, cách tái hiện, vị trí code, mức độ, người phụ trách, tình trạng, commit sửa và kết quả retest.

## Slide 20–21 · Danh sách 12 lỗi

Đọc nhanh từng lỗi theo cột mô tả và cách tái hiện. Nhấn mạnh BUG-14 (Critical): mọi bài cảm nhận mới không đồng bộ được; BUG-16 (High): đóng hộp thoại Đổi tên làm văng màn hình đỏ trên Android.

## Slide 22 · Thống kê lỗi

12 lỗi gồm 1 Critical, 3 High, 7 Medium, 1 Low. Hiện có 2 lỗi đã sửa và đã gộp develop, 9 lỗi đã sửa trên nhánh chờ gộp, 1 lỗi Open.

## Slide 23 · Ví dụ BUG-06

Trước khi sửa, bấm “Bỏ ảnh mới” làm mất luôn ảnh cũ. Nguyên nhân là nút này bật cả cờ xóa ảnh cũ. Sau khi sửa, ảnh cũ còn nguyên, có ảnh chụp trước và sau.

## Slide 24–25 · Bước 5: sửa và kiểm thử lại

Mỗi lỗi: viết test tái hiện (đỏ), sửa trên nhánh riêng, chạy lại test (xanh), chạy lại toàn bộ để chắc không phát sinh lỗi mới. Gộp đủ 11 bản vá: 69 bài Pass, Rules 12/12, build web đạt, không bài hồi quy nào đỏ.

## Slide 26 · Tình trạng trên code mới nhất

Nhóm lấy code develop mới nhất và chạy lại đúng các test tái hiện. BUG-12 và BUG-14 đã hết vì develop đã sửa qua PR #41 và #43. 9 lỗi còn lại đã có bản sửa nhưng chưa mở PR gộp vào develop, nên trên code chung vẫn còn. Việc tiếp theo là mở PR cho 9 nhánh này.

## Slide 27 · Đối chiếu 5 yêu cầu

Bốn yêu cầu đầu đạt. Yêu cầu sửa và kiểm thử lại đạt một phần vì 9 bản sửa chưa gộp vào code chung.

## Slide 28–29 · Hạn chế và hỏi đáp

Hạn chế: chưa có macOS/iPhone, chưa có hộp thư và OAuth thật, chưa dựng Firestore riêng cho ca phân trang, ảnh máy thật chưa đính kèm. Nhóm em xin cảm ơn thầy/cô và các bạn đã lắng nghe.

## Câu hỏi giảng viên có thể hỏi

| Câu hỏi | Gợi ý trả lời |
| --- | --- |
| Vì sao vẫn còn 10 ca Fail dù đã sửa lỗi? | Bảng test case ghi kết quả trên **bản gốc `065103c`** làm mốc so sánh. Kết quả sau sửa ghi riêng ở [03-bang-loi.md](03-bang-loi.md) và `evidence/RETEST-*.png`. |
| Lỗi nào nghiêm trọng nhất? | `BUG-14` (Critical): đồng bộ bài cảm nhận mới gọi `.get()` vào `reflection_owners/{id}` chưa tồn tại nên Firestore trả 403. Nhóm sửa ở `9ff91be`; develop đã sửa tương đương qua PR #43. |
| Vì sao nói “đạt một phần” ở bước 5? | 9 bản sửa đã có test và retest đạt nhưng nằm trên nhánh `fix/ngocanh-*`, chưa gộp vào develop. Chạy test tái hiện trên develop `478505e` vẫn đỏ ([RETEST-DEVELOP-478505e.txt](evidence/RETEST-DEVELOP-478505e.txt)). |
| `BUG-16` do đâu? | Ba hộp thoại trong `passport_screen.dart` gọi `TextEditingController.dispose()` ngay sau `await showDialog(...)` khi hoạt ảnh đóng vẫn chạy. Sửa ở `17e86fc` bằng cách tách thành `StatefulWidget` tự hủy controller. |
| 57 → 69 → 85 nghĩa là gì? | 57 bài test trên bản gốc; 69 bài khi thêm test tái hiện và gộp 11 bản vá; 85 bài trên code mới nhất (develop thêm test cho tính năng vị trí). |
