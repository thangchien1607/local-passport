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
3. Quy trình kiểm thử 5 bước
4. Bước 1 - Chức năng cần kiểm tra
5. Bước 1 - Tiêu chí đạt yêu cầu
6. Bước 1 - Môi trường kiểm thử
7. Bước 2 - Cách viết test case
8. Bước 2 - Tổng quan bộ test case
9–14. Bước 2 - Bảng test case đầy đủ (6 slide, 18 chức năng × 4 loại ca)
15. Bước 3 - Kiểm tra tự động
16. Bước 3 - Máy ảo, máy thật, nhiều màn hình, mất mạng
17. Bước 3 - Kết quả trên điện thoại thật
18. Bước 3 - Minh chứng nhiều màn hình và mất mạng
19. Bước 4 - Mẫu ghi nhận lỗi
20–21. Bước 4 - Danh sách lỗi đã phát hiện (mô tả, cách tái hiện, mức độ, phụ trách, tình trạng)
22. Bước 4 - Thống kê lỗi theo mức độ và tình trạng
23. Ví dụ một lỗi: BUG-06 giữ ảnh cũ (ảnh trước/sau)
24. Bước 5 - Quy trình sửa lỗi và kiểm thử lại
25. Bước 5 - Kết quả kiểm thử lại từng lỗi
26. Bước 5 - Tình trạng xử lý trên code mới nhất
27. Đối chiếu với 5 yêu cầu của đồ án
28. Hạn chế và hướng phát triển

Slide 6 và 17 có chỗ `[Điền model · phiên bản Android]`, `[Điền ngày]` và `[Bổ sung ảnh]` cho phần điện thoại thật.
