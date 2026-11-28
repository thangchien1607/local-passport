# Tóm tắt kiểm thử Local Passport

Ngày cập nhật: 28/11/2026 · Nhóm: Chiến Thắng, Ngọc Anh, Minh Khoa · Nhánh: `docs/test-report` · Phạm vi: Web và Android (không gồm iOS)

## 1. Kết quả tổng quan

| Hạng mục | Kết quả |
| --- | --- |
| Test case | 79 dòng: **69 Pass**, **10 Fail**, **0 Chưa chạy** |
| Lỗi đã xác minh | **11** (1 Critical, 2 High, 7 Medium, 1 Low) |
| Tình trạng lỗi | 2 đã có trên `develop`, 9 đã sửa trên nhánh chờ gộp PR, 0 Open |
| Flutter test | 57 bài (bản gốc) → 69 bài (gộp 11 bản vá) → 85 bài (`develop` mới nhất 478505e) |
| Firestore Rules | 12/12 Pass |
| Minh chứng | 169 tệp ảnh và log trong `docs/testing/evidence/` |
| Slide | 28 trang (`slide.pptx`, `slide.pdf`) |

## 2. Test case theo phân hệ

| Phân hệ | Phụ trách | Tổng | Pass | Fail | Chưa chạy |
| --- | --- | ---: | ---: | ---: | ---: |
| Xác thực và tài khoản | Chiến Thắng | 16 | 14 | 2 | 0 |
| Khám phá và bản đồ | Ngọc Anh | 8 | 7 | 1 | 0 |
| QR và GPS check-in | Chiến Thắng | 9 | 8 | 1 | 0 |
| Đóng dấu, cảm nhận, ảnh | Ngọc Anh | 13 | 9 | 4 | 0 |
| Cộng đồng, xếp hạng, thông báo | Minh Khoa | 12 | 11 | 1 | 0 |
| Đồng bộ, offline, TimeLens | Minh Khoa | 8 | 7 | 1 | 0 |
| Đa kích thước màn hình | Minh Khoa | 4 | 4 | 0 | 0 |
| Firestore Rules | Chiến Thắng | 4 | 4 | 0 | 0 |
| Kiểm tra tự động | Cả nhóm | 5 | 5 | 0 | 0 |
| **Tổng** | | **79** | **69** | **10** | **0** |

Đã thực hiện trên:
- **Web Chrome 158**: 360×640, 390×844, 768×1024, 1440×900, xoay ngang, chữ 130%; DevTools Offline và Slow 3G; hai phiên đăng nhập.
- **Máy ảo Android 15** (`LP_390x844_API35`, APK debug build 27/11).
- **Điện thoại Android thật**: 8 ca camera/GPS (TC-QR-01, 03 đến 08, TC-REF-09), tất cả Pass. Người chạy: Ngọc Anh.
- **Firestore Emulator** cho Rules.

Ghi chú: 10 ca được chuyển từ "Chưa chạy" sang Pass theo xác nhận của người kiểm thử. Các ca này chưa có ảnh minh chứng đính kèm trong repo.

## 3. Danh sách lỗi

| Mã | TC | Mô tả ngắn | Mức độ | Phụ trách | Tình trạng |
| --- | --- | --- | --- | --- | --- |
| BUG-01 | TC-QR-02 | Sai khóa QR báo nhầm sang điểm khác | Medium | Chiến Thắng | Đã sửa trên nhánh, chờ gộp |
| BUG-02 | TC-QR-04 | setState sau khi màn quét đã đóng | High | Chiến Thắng | Đã sửa trên nhánh, chờ gộp |
| BUG-03 | TC-QR-09 | Bấm Demo liên tiếp đóng màn hình nhiều lần | Low | Chiến Thắng | Đã sửa trên nhánh, chờ gộp |
| BUG-05 | TC-AUTH-08 | Enter 2 lần gửi 2 yêu cầu đăng nhập | Medium | Chiến Thắng | Đã sửa trên nhánh, chờ gộp |
| BUG-06 | TC-REF-12 | Bỏ ảnh mới làm mất ảnh cũ | Medium | Ngọc Anh | Đã sửa trên nhánh, chờ gộp |
| BUG-11 | TC-REF-13 | Đồng bộ vẫn giữ URL ảnh cũ đã xóa | Medium | Ngọc Anh | Đã sửa trên nhánh, chờ gộp |
| BUG-12 | TC-UI-03, 04 | Chú thích QR tràn ngang màn hình hẹp | Medium | Minh Khoa | Đã sửa, đã có trên develop |
| BUG-13 | TC-MAP-05 | Tìm "Cầu Rồng" khớp nhầm 7 điểm | Medium | Ngọc Anh | Đã sửa trên nhánh, chờ gộp |
| BUG-14 | TC-COM-01, 02, AUTH-09, REF-05, SYNC-01 | Đồng bộ bài cảm nhận mới bị HTTP 403 | Critical | Minh Khoa | Đã sửa, đã có trên develop (PR #43) |
| BUG-15 | TC-REF-10 | Ảnh JPEG hỏng bị che lỗi sau hộp thoại | Medium | Ngọc Anh | Đã sửa trên nhánh, chờ gộp |
| BUG-16 | TC-SYNC-02, AUTH-09 | Đóng hộp thoại Đổi tên làm văng màn đỏ Android | High | Chiến Thắng | Đã sửa trên nhánh, chờ gộp |

Lỗi iOS (BUG-07) đã được loại khỏi danh sách vì không thuộc phạm vi.

## 4. Kiểm tra lại trên code mới nhất

Lấy `origin/develop` `478505e` (trùng `main` `2d4e489`), đặt các file test tái hiện của 11 nhánh sửa vào bản sao rồi chạy `flutter test`. Kết quả lưu tại `evidence/RETEST-DEVELOP-478505e.txt`:
- **Xanh (đã có trên develop):** BUG-12, BUG-14.
- **Đỏ (chưa gộp):** BUG-01, 02, 03, 05, 06, 11, 13, 15, 16.
- `flutter test` toàn bộ: **+85 All tests passed**.

## 5. Nhánh và PR

- Nhánh làm việc: `docs/test-report`, đã push lên `origin`, commit mới nhất `2fa4453`.
- Base PR phải là **`develop`**, không chọn `main` (CI chỉ cho `develop`, `release/*`, `hotfix/*` vào `main`).
- Trạng thái PR: chưa xác nhận đã tạo.

## 6. Việc còn lại

1. Tạo PR `docs/test-report` → `develop`, kiểm tra 2 check CI xanh.
2. Điền model điện thoại Android và ngày chạy (còn `[Điền …]` trong bảng test case, slide 6 và slide 17).
3. Bổ sung ảnh minh chứng cho 8 ca máy thật (`evidence/<MãTC>-real.png`) và các ca chuyển sang Pass theo xác nhận.
4. Điền tên nhóm và tên giảng viên trong `01-ke-hoach-kiem-thu.md`.
5. Mở PR cho 9 nhánh `fix/ngocanh-*` để đưa lỗi đã sửa vào `develop`, sau đó chạy lại bộ kiểm tra và cài APK mới lên máy thật.

## 7. Tài liệu trong `docs/testing`

| File | Nội dung |
| --- | --- |
| `01-ke-hoach-kiem-thu.md` | Phạm vi, quy trình, điều kiện bắt đầu và hoàn thành, ma trận môi trường |
| `02-bang-test-case.md` | 79 dòng test case với kết quả và minh chứng |
| `03-bang-loi.md` | 11 lỗi, cách tái hiện, vị trí code, commit sửa, kết quả retest |
| `04-bao-cao-tong-hop.md` | Báo cáo tổng hợp và kiểm tra tính trung thực |
| `05-huong-dan-chay-thu-cong.md` | Việc còn lại để hoàn tất minh chứng |
| `06-kich-ban-thuyet-trinh.md` | Kịch bản thuyết trình theo 28 slide và câu hỏi thường gặp |
| `slide.pptx`, `slide.pdf`, `slide.md`, `build-slides.cjs` | Slide và script sinh slide |
| `evidence/` | 169 ảnh chụp và log, cộng `RETEST-DEVELOP-478505e.txt` |
