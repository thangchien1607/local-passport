# Nguồn slide Local Passport

[slide.pptx](slide.pptx) là bản trình chiếu có thể chỉnh sửa. [slide.pdf](slide.pdf) được xuất từ bản đó bằng PowerPoint. [Kịch bản](06-kich-ban-thuyet-trinh.md) bám theo thứ tự của hai bản.

## Tái tạo từ tài liệu kiểm thử

`build-slides.cjs` đọc số liệu từ [bảng test case](02-bang-test-case.md), [bảng lỗi](03-bang-loi.md) và [báo cáo tổng hợp](04-bao-cao-tong-hop.md). Lệnh bên dưới dùng Node.js và PowerPoint trên Windows. Thư viện tạo bảng và biểu đồ PowerPoint được cài trong thư mục tạm, ngoài repo.

```powershell
$slideTools = Join-Path $env:TEMP 'local-passport-slide-tools'
npm.cmd install --prefix $slideTools --no-audit --no-fund --ignore-scripts pptxgenjs@4.0.1
$env:NODE_PATH = Join-Path $slideTools 'node_modules'
node docs/testing/build-slides.cjs
```

Để lưu bản render PNG phục vụ đối chiếu, đặt `LOCAL_PASSPORT_SLIDE_QA_DIR` thành đường dẫn thư mục trước khi chạy. Nếu chỉnh tay PowerPoint, xuất lại PDF từ chính tệp PPTX đã chỉnh. Nếu sinh lại từ mã nguồn, sửa số liệu ở các bảng Markdown trước và cập nhật phần diễn giải trong `build-slides.cjs` khi nội dung trình bày thay đổi.

## Thứ tự trình chiếu

1. Kiểm thử và sửa lỗi Local Passport
2. Giới thiệu và phạm vi
3. Quy trình kiểm thử và sửa lỗi
4. Bước 1 - Lập kế hoạch kiểm thử
5. Bước 2 - Viết test case
6. Tổng quan bộ test case
7. Test case tài khoản, bản đồ và QR
8. Test case đóng dấu, cộng đồng và đồng bộ
9. Test case giao diện và Firestore Rules
10. Bước 3 - Thực hiện kiểm thử
11. Bước 4 - Ghi nhận lỗi
12. Lỗi tiêu biểu
13. Danh sách lỗi đã phát hiện
14. Demo BUG-06 - Giữ ảnh cũ
15. Bước 5 - Sửa lỗi và kiểm thử lại
16. Kết quả cuối
17. Hạn chế và hướng phát triển
18. Hỏi đáp

Slide 14 có khung `[Chèn ảnh: BUG-06 trước sửa và sau retest]` dành cho ảnh chụp thật.
