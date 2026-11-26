# Hướng dẫn chạy thủ công Local Passport

[CHƯA XÁC MINH] Các bước bên dưới là hướng dẫn để nhóm thực hiện. Thiết bị, phiên bản phần mềm, thời điểm, người chạy và bằng chứng điền theo lượt kiểm thực tế.

## Chuẩn bị một lượt kiểm

1. [Tên thành viên] ghi phiên bản app/commit từ chính bản đang dùng, thiết bị thật hoặc tên AVD thực tế, hệ điều hành, phiên bản trình duyệt, viewport, tỉ lệ chữ, hướng màn hình và kiểu mạng. Ghi mã TC trong [bảng test case](02-bang-test-case.md) và mã cụ thể trong [ma trận môi trường](01-ke-hoach-kiem-thu.md#ma-trận-môi-trường-dự-kiến) trước khi bắt đầu.
2. Chuẩn bị môi trường Firebase thử của nhóm và tài khoản dùng riêng. Dùng tài khoản được phép xóa cho luồng xóa tài khoản. TC có hai phiên cần hai hồ sơ trình duyệt hoặc hai thiết bị đăng nhập độc lập. Xác minh trước khả năng gửi email và nhà cung cấp thử khi TC cần những dịch vụ này.
3. Chuẩn bị mã QR lấy từ dữ liệu thử của dự án hoặc bản in do nhóm quản lý, điểm chưa check-in cho từng tổ hợp, ảnh hợp lệ/ảnh hỏng, bài đã có ảnh cũ và bộ dữ liệu dựng sẵn theo TC. Dùng bản dữ liệu mới cho ca cần trạng thái ban đầu.
4. Mở đúng bản thử. [TỪ CODE] `README.md` mục **Cài đặt & chạy thử cục bộ** hướng dẫn `flutter pub get` và `flutter run -d chrome`. Flutter chọn thiết bị bằng ID thật xem từ `flutter devices`. Khi kiểm màn hình thật, ghi rõ sử dụng APK, Web/PWA hay bản cài iOS.
5. [TỪ CODE] Bản mặc định lấy cấu hình Firebase từ `lib/firebase_options.dart`. `npm test` tại `rules_tests/` chạy Rules trên emulator theo `package.json` của thư mục đó. Xác nhận riêng ứng dụng đang trỏ đúng môi trường thử trước khi ghi dữ liệu. Nếu môi trường chưa sẵn sàng, giữ TC phụ thuộc ở trạng thái Chưa chạy.
6. Với ca cần kiểm trước/sau sửa, dùng đúng trạng thái ban đầu và cùng biến thể trên mỗi bản. Ghi commit thực và log riêng cho mỗi lượt.

## Web và thay đổi kích thước

1. Mở Chrome/Edge DevTools, bật chế độ mô phỏng thiết bị và thử tuần tự 360×640, 390×844, 768×1024 và 1440×900. Ghi kích thước viewport thực tế. Trên thiết bị thật, kiểm tra bàn phím, dọc/ngang và mức chữ 130% nếu hệ điều hành hỗ trợ đúng mức này. Ghi riêng tỉ lệ chữ và mức zoom của trình duyệt.
2. Mở đăng nhập, đăng ký, Khám phá, địa điểm, QR, đóng dấu/cảm nhận, Hộ chiếu, Cộng đồng, bảng xếp hạng, thông báo và TimeLens theo quyền của phiên thử. Kiểm tra cuộn và các nút hành động ở từng màn liên quan.
3. Nếu có tràn khung, lưu ảnh có màn hình và kích thước. Nếu có lỗi console, lưu nguyên văn và vị trí xảy ra. Với Web, dùng localhost hoặc HTTPS khi kiểm quyền camera. Quay lại trạng thái mặc định sau thử.
4. Dùng `flutter run -d chrome -t lib/main_timelens.dart` khi TC yêu cầu demo TimeLens tách riêng. Entrypoint được nêu tại `lib/main_timelens.dart` (`main`).

## Máy ảo, camera và GPS

1. Chạy Android Emulator để kiểm điều hướng và đặt vị trí giả lập. Lấy tọa độ tâm đúng điểm từ `lib/data/routes.dart` (*Location.coordinates*). Đối chiếu từng mốc bằng `distanceMeters` tại `lib/services/geo.dart:11–19`. Ghi giá trị thực máy nhận trước khi chấm biên 300 m, tránh diễn giải số làm tròn thành giá trị chính xác.
2. Trên Android thật, cấp camera và vị trí khi TC yêu cầu, rồi quét mã QR thử đúng, sai và thiếu trường. Lặp ca tắt GPS, từ chối quyền, thoát khi đang dừng camera và mở lại. Với tình huống tại thực địa, ghi tọa độ/sai số có liên quan mà nhóm được phép lưu.
3. Dùng iOS Simulator trên macOS cho kiểm khởi động/chế độ lưu cục bộ. Dùng iPhone thật để kiểm Safari, cảm ứng, quyền và xoay màn hình nếu TC yêu cầu. Ghi nguồn bản cài và cấu hình Firebase thực tế trước khi kết luận.

## Offline, rớt mạng và đồng bộ

1. Ghi trạng thái ban đầu khi có mạng và tạo dữ liệu thử có thể phân biệt giữa hai phiên. Cùng một chuỗi thử nên có mã riêng để nhận ra bản trùng.
2. Dùng DevTools Offline/Slow 3G hoặc ngắt Wi‑Fi và dữ liệu di động. Thử offline lúc đã lưu, khởi động lại hoàn toàn khi không mạng, rớt ngay trong lúc bấm lưu và quay lại mạng. Với mỗi lượt, ghi thời điểm ngắt/bật tương đối so với thao tác và dữ liệu còn thấy.
3. Khi mạng trở lại, thử nút **Thử lại** nếu xuất hiện. Đối chiếu dữ liệu cục bộ và phiên thứ hai. Với bài, dấu và XP, kiểm cả dấu hiệu cập nhật thiếu hoặc trùng trước khi đánh Pass.
4. Trả cài đặt mạng và quyền thiết bị về trạng thái ban đầu. Ghi rõ mọi điều kiện làm lượt kiểm chưa thể kết luận.

## Ghi kết quả và minh chứng

1. Làm các bước ở từng TC, ghi biến thể thực tế đã thử và nội dung quan sát được. Điền **Pass** khi đúng kết quả mong đợi, **Fail** khi có sai khác có bằng chứng, **Chưa chạy** khi chưa thực hiện được. Nếu chưa hoàn tất các biến thể, ghi rõ phần đã quan sát và phần còn thiếu.
2. Lưu đường dẫn ảnh/video/log thử của nhóm theo mã TC, ghi thời gian và môi trường. Che email, token hoặc vị trí cá nhân khi đưa minh chứng vào báo cáo. Chỉ dùng ảnh từ lần thử thật.
3. Mỗi vấn đề có bằng chứng ghi thêm vào [bảng lỗi](03-bang-loi.md) với bước tái hiện, file/hàm nếu xác định được, mức độ, người phụ trách và trạng thái. Dùng mẫu `[Chèn ảnh: mã TC – thao tác]` ở vị trí chưa có ảnh.

## Phiếu điền theo mã TC

Lặp một dòng cho mỗi môi trường hoặc biến thể cần ghi riêng. Mã giữ nguyên. Cột môi trường thực tế ghi cả viewport, cỡ chữ, hướng màn hình và cấu hình mạng nếu có liên quan.

### Xác thực và tài khoản

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-AUTH-01 | ☐ Đăng ký, xem hộ chiếu, đăng xuất rồi đăng nhập lại khi chưa có cảm nhận. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-01] |
| TC-AUTH-02 | ☐ Thử từng dữ liệu với các ô còn lại hợp lệ. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-02] |
| TC-AUTH-03 | ☐ Thử gửi Đăng ký rồi thử Đăng nhập với email hoặc mật khẩu trống. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-03] |
| TC-AUTH-04 | ☐ Thử từng biên riêng. Dùng tài khoản mới cho mỗi lần đăng ký hợp lệ rồi đăng nhập với email có khoảng trắng. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-04] |
| TC-AUTH-05 | ☐ Gửi quên mật khẩu, mở thư, đặt mật khẩu mới. Trong Hộ chiếu thử đổi mật khẩu khi đã đăng nhập và gửi xác minh email. | WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-05] |
| TC-AUTH-06 | ☐ Thử gửi quên mật khẩu rồi thực hiện đổi mật khẩu với từng dữ liệu sai. Kiểm tra trạng thái xác minh sau khi mở liên kết lỗi. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-06] |
| TC-AUTH-07 | ☐ Bấm Quên mật khẩu hoặc Lưu thay đổi trong từng lượt. Tải lại trạng thái xác minh trước khi mở thư. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-07] |
| TC-AUTH-08 | ☐ Bấm Quên mật khẩu nhiều lần. Trong lượt khác, dùng phím Enter liên tiếp và bấm nút Đăng nhập khi yêu cầu đang bận. Tải lại trạng thái xác minh sau khi mở liên kết đúng. | WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-08] |
| TC-AUTH-09 | ☐ Hộ chiếu → Đổi tên, lưu, tải lại bảng xếp hạng và kiểm tra hai bài trên phiên thứ hai sau đồng bộ. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-09] |
| TC-AUTH-10 | ☐ Dán chuỗi quá dài hoặc thử nhập tiếp sau khi đạt giới hạn rồi lưu. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-10] |
| TC-AUTH-11 | ☐ Xóa tên mặc định trong hộp thoại rồi bấm Lưu. Thử thêm trường hợp bấm Hủy. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-11] |
| TC-AUTH-12 | ☐ Đổi tên riêng từng mốc. Khởi động lại và kiểm tra hộ chiếu. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-12] |
| TC-AUTH-13 | ☐ Nâng cấp Khách bằng email. Với tài khoản thử khác, thử Google/Apple trên cấu hình hỗ trợ. Dùng tài khoản thử có thể xóa để xác thực lại và xóa. | WEB, AND, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-13] |
| TC-AUTH-14 | ☐ Thử nâng cấp/xác thực/xóa riêng từng lượt trong dự án thử. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-14] |
| TC-AUTH-15 | ☐ Mở app sạch để vào Khách. Với tài khoản thử khác, bấm xóa và để trống mật khẩu hiện tại. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-15] |
| TC-AUTH-16 | ☐ Xác thực lại, ngắt mạng khi thao tác đang xử lý, ghi trạng thái. Kết nối lại và thử lại. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-AUTH-16] |

### Khám phá địa điểm và bản đồ

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-MAP-01 | ☐ Mở Khám phá, chọn tuyến, chọn marker, mở thẻ chi tiết. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-01] |
| TC-MAP-02 | ☐ Trong DevTools, chặn yêu cầu tải Maps JavaScript API. Tải lại bản thử và mở Khám phá để kiểm tra loại bản đồ. | WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-02] |
| TC-MAP-03 | ☐ Mở tab lần đầu. Quan sát bộ lọc và phần chi tiết trước khi chọn marker. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-03] |
| TC-MAP-04 | ☐ Chạm điểm, đổi tuyến rồi zoom/kéo đến biên trên/dưới. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-04] |
| TC-MAP-05 | ☐ Nhập từng từ khóa, chọn một kết quả, ghi tên điểm đã mở. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-05] |
| TC-MAP-06 | ☐ Nhập vào tìm kiếm, chọn Tất cả để đối chiếu lần thứ hai. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-06] |
| TC-MAP-07 | ☐ Tìm một điểm rồi xóa bằng nút xóa. Gõ toàn dấu cách. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-07] |
| TC-MAP-08 | ☐ So sánh với `Cầu Rồng`. Thử cụm từ ghép có một từ không khớp. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-MAP-08] |

### QR và GPS check-in

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-QR-01 | ☐ Dùng dữ liệu sạch cho từng định dạng, mở đúng điểm và quét. Thử mở link QR bằng camera ngoài app trên Web. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-01] |
| TC-QR-02 | ☐ Mở Thành Điện Hải. Quét từng mã độc lập, mở lại màn hình quét mỗi lượt. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-02] |
| TC-QR-03 | ☐ Quét hai mã thiếu trường và quan sát riêng trạng thái đứng chờ khi không có mã. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-03] |
| TC-QR-04 | ☐ Quét rồi bấm Back hoặc Đóng ngay. Ghi log vòng đời nếu có, mở lại để kiểm tra camera. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-04] |
| TC-QR-05 | ☐ Cho phép định vị, quét đúng mã và xác nhận điểm trong Hộ chiếu. | THỰC, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-05] |
| TC-QR-06 | ☐ Cài vị trí ngoài biên rồi quét. Lượt sau từ chối quyền vị trí trước khi quét. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-06] |
| TC-QR-07 | ☐ Tắt vị trí, mở quét mã đúng. Sau khi kiểm tra lỗi, bật lại dịch vụ và thử lại. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-07] |
| TC-QR-08 | ☐ Cấu hình từng tọa độ. Ghi khoảng cách thực tính và sai số, quét trên trạng thái khóa mới ở mỗi mốc. | AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-08] |
| TC-QR-09 | ☐ Mở màn hình quét và bấm giả lập liên tiếp. Lặp lại sau khi quay lại màn hình. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-QR-09] |

### Đóng dấu, cảm nhận và ảnh

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-REF-01 | ☐ Mở khóa, thực hiện tất cả nhiệm vụ thật, xem hiệu ứng rồi vào Hộ chiếu. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-01] |
| TC-REF-02 | ☐ Mở điểm chưa check-in, thử chạm vào mục nhiệm vụ và quan sát tiến độ. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-02] |
| TC-REF-03 | ☐ Để lại một nhiệm vụ bắt buộc, quay về Hộ chiếu rồi trở lại điểm. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-03] |
| TC-REF-04 | ☐ Hoàn tất nhiệm vụ cuối, ghi số dấu/XP, lặp thao tác và đối chiếu lại. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-04] |
| TC-REF-05 | ☐ Đăng bài, bật ẩn danh ở một lượt. Mở Sửa trên bài của mình, cập nhật nội dung. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-05] |
| TC-REF-06 | ☐ Thử gửi/sửa hai chuỗi ngoài ngưỡng. Gửi bài hợp lệ từ bản có endpoint thử lỗi. | WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-06] |
| TC-REF-07 | ☐ Thử gửi bài mới và lưu chỉnh sửa nhiều lượt. Kiểm tra bảng tin sau mỗi lượt. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-07] |
| TC-REF-08 | ☐ Thử lần lượt khi đăng và sửa. Ghi nội dung thực lưu, điểm và cách chạy cho mỗi biến thể. | AND, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-08] |
| TC-REF-09 | ☐ Lưu ảnh nhiệm vụ theo checklist địa điểm. Đăng bài có ảnh. Mở lại hộ chiếu và bài. | THỰC, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-09] |
| TC-REF-10 | ☐ Chọn tệp JPEG thử bị hỏng vào cảm nhận. Dùng bộ dữ liệu thử để xác nhận ngưỡng sau nén, không suy từ kích thước trước nén. | WEB, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-10] |
| TC-REF-11 | ☐ Mở rồi hủy ảnh ở nhiệm vụ và ở cảm nhận. Thử đăng cảm nhận hợp lệ không có ảnh. | THỰC, WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-11] |
| TC-REF-12 | ☐ Chọn ảnh mới → Bỏ ảnh mới → Lưu và tải lại. Lượt riêng chọn Xóa ảnh cũ. Kiểm tra giới hạn số ảnh bằng dữ liệu thử. Nếu giao diện không có nhiệm vụ ảnh thứ tư, ghi kết quả đối chiếu Rules riêng. | WEB, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-12] |
| TC-REF-13 | ☐ Dùng bài thử chỉ có `photoUrl` cũ. Chọn Xóa ảnh, lưu, chờ đồng bộ rồi tải qua phiên thứ hai và khởi động lại. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-REF-13] |

### Cộng đồng, bảng xếp hạng và thông báo

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-COM-01 | ☐ Đăng bài hợp lệ trên tài khoản A. Mở Cộng đồng ở B, dùng bộ lọc và tìm kiếm có kết quả. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-01] |
| TC-COM-02 | ☐ Mở thẻ của A, tìm nút sửa/xóa. Tìm từ khóa không khớp. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-02] |
| TC-COM-03 | ☐ Thử trên môi trường không có bài ở tuyến chọn, xóa từ khóa hoặc chọn lại Tất cả. | WEB | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-03] |
| TC-COM-04 | ☐ Cuộn đến cuối sau mỗi bộ dữ liệu. Thêm một bài mới ở phiên khác, làm mới và đối chiếu ID. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-04] |
| TC-COM-05 | ☐ Mở bảng xếp hạng, thay đổi XP bằng luồng hợp lệ, chờ đồng bộ và làm mới phiên thứ hai. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-05] |
| TC-COM-06 | ☐ Đối chiếu TC-AUTO-04 trên Emulator. Trên giao diện ngắt mạng khi làm mới bảng xếp hạng rồi kết nối lại. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-06] |
| TC-COM-07 | ☐ Mở bảng xếp hạng, kiểm tra dòng bản thân và bục chưa đủ người. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-07] |
| TC-COM-08 | ☐ Làm mới với từng bộ dữ liệu thử, kiểm tra phần người khác và dòng bản thân. Đối chiếu rule trong Emulator. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-08] |
| TC-COM-09 | ☐ Mở chuông, chạm vào mục có địa điểm, đánh dấu đã đọc và thử xóa một mục thử. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-09] |
| TC-COM-10 | ☐ Mở chuông trên A rồi đổi sang B. Làm mới và xem danh sách. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-10] |
| TC-COM-11 | ☐ Mở chuông và quan sát badge, trạng thái danh sách. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-11] |
| TC-COM-12 | ☐ Kiểm tra badge ở hai mốc, chọn đánh dấu tất cả đã đọc rồi khởi động lại. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-COM-12] |

### Đồng bộ, offline và TimeLens

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-SYNC-01 | ☐ Tạo dấu hoặc sửa hồ sơ trên A. Sau khi lưu, đăng nhập cùng tài khoản trên B. | WEB, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-01] |
| TC-SYNC-02 | ☐ Lưu thay đổi rồi tắt mạng có kiểm soát. Ghi trạng thái. Bật lại mạng, dùng Thử lại nếu hiện, kiểm tra trên B. | WEB, AND, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-02] |
| TC-SYNC-03 | ☐ Đóng app sau khi tạo dữ liệu mẫu. Khởi động lại khi offline. Trên iOS, mở bản build hiện tại và thử tạo hồ sơ cục bộ. | AND, IOS | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-03] |
| TC-SYNC-04 | ☐ Tạo/sửa dữ liệu khi bóp mạng. Đối chiếu smoke và test batch hiện có, dùng bộ thử riêng nếu đo quy mô qua Emulator. | WEB, AND, HAI | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-04] |
| TC-SYNC-05 | ☐ Từ Khám phá mở TimeLens, đổi điểm, kéo vạch so sánh. Mở nút xem điểm nếu có. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-05] |
| TC-SYNC-06 | ☐ Kéo con trỏ ra khỏi ảnh, rồi đổi sang ảnh khác ngay sau đó. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-06] |
| TC-SYNC-07 | ☐ Mở demo TimeLens trên Chrome Android/Safari iOS. Không cấp camera/GPS và chưa kéo. | WEB, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-07] |
| TC-SYNC-08 | ☐ Trong lần chạy riêng, kéo hết về trái và phải rồi quay lại giữa. Đổi ảnh tại các biên. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-SYNC-08] |

### Đa kích thước màn hình

| Mã TC | Checklist thao tác | Môi trường dự kiến | Môi trường thực tế | Người chạy | Ngày chạy | Kết quả thực tế | Trạng thái | Ảnh chụp minh chứng |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TC-UI-01 | ☐ Mở lần lượt màn hình chính, điều hướng và cuộn tới các nút chính. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-UI-01] |
| TC-UI-02 | ☐ Mở form đăng ký, bật bàn phím, đổi ngang rồi quay dọc. Lặp ở form cảm nhận. | AND, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-UI-02] |
| TC-UI-03 | ☐ Mở màn hình trống, bật lỗi kiểm tra form. Mở quét QR ở màn hình hẹp và đọc chú thích bán kính. | WEB, AND | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-UI-03] |
| TC-UI-04 | ☐ Chạy ma trận kích thước, mở các màn hình lõi, phóng chữ và xoay thiết bị thật. Lưu ảnh mỗi tổ hợp cần nghiệm thu. | WEB, AND, IOS, THỰC | [Điền sau] | [Tên thành viên] | — | — | Chưa chạy | [Chèn ảnh: TC-UI-04] |
