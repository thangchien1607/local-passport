# Hướng dẫn chạy thủ công Local Passport

Ngày 27/11/2026, nhóm đã chạy đủ các ca thủ công trong [bảng test case](02-bang-test-case.md). Tài liệu này không còn danh sách ca chưa chạy.

Phạm vi đợt kiểm thử: Web Chrome 158, máy ảo Android 15 (`LP_390x844_API35`, APK debug build 27/11) và điện thoại Android thật. iOS không thuộc phạm vi.

## Việc còn lại để hoàn tất minh chứng

- ☐ Điền model điện thoại Android và ngày chạy vào bảng test case, môi trường `AND-REAL`.
- ☐ Chụp ảnh màn hình 8 ca máy thật, lưu vào `evidence/<MãTC>-real.png` (`TC-QR-01`, `TC-QR-03`…`TC-QR-08`, `TC-REF-09`).
- ☐ Bổ sung ảnh hoặc log cho các ca chuyển sang Pass theo xác nhận người kiểm thử: `TC-AUTH-05`, `TC-AUTH-06`, `TC-AUTH-13`, `TC-COM-02`, `TC-COM-04`, `TC-COM-07`, `TC-COM-08`, `TC-SYNC-07`, `TC-UI-04`.
- ☐ Sau khi gộp 9 nhánh sửa lỗi vào `develop`, cài APK mới và chạy lại chuỗi smoke: đăng nhập → bản đồ → check-in Demo → cảm nhận có ảnh → offline/online.
