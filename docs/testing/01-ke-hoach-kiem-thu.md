# Kế hoạch kiểm thử Local Passport

Đồ án Kiểm thử và sửa lỗi · Nhóm [Điền tên nhóm] · Thành viên Chiến Thắng, Ngọc Anh, Minh Khoa · Giảng viên [Điền tên]

## Mục tiêu và phạm vi

[TỪ CODE] Local Passport là ứng dụng Flutter cho Web, Android và iOS. Bản đồ mặc định là OpenStreetMap. Google Maps là tùy chọn khi có khóa và khởi tạo được. Firebase Auth và Firestore được cấu hình cho Web và Android. Luồng lưu cục bộ được dùng khi không có cấu hình Firebase. Nguồn [README](../../README.md), [cấu hình bản đồ](../../lib/services/maps_config.dart), [MapScreen](../../lib/screens/map_screen.dart), [khởi tạo ứng dụng](../../lib/main.dart) và [currentFirebaseOptions](../../lib/firebase_options.dart#L9).

| Phân hệ | Hành vi cần kiểm tra |
| --- | --- |
| Xác thực và tài khoản | Đăng ký, đăng nhập, đặt lại và đổi mật khẩu, đổi tên, đăng nhập khách và nâng cấp, xóa tài khoản |
| Khám phá và bản đồ | Tìm kiếm, lọc tuyến, mở chi tiết, định vị, tải OpenStreetMap |
| QR và GPS check-in | Kiểm mã, địa điểm, quyền vị trí và khoảng cách, xử lý vòng đời camera, chế độ demo |
| Đóng dấu, cảm nhận và ảnh | Nhiệm vụ, đóng dấu, ảnh hợp lệ/ảnh lỗi, chấm và sửa bài, giữ hoặc bỏ ảnh |
| Cộng đồng, xếp hạng và thông báo | Phân trang, ẩn danh, thao tác đúng chủ sở hữu, thứ hạng và trạng thái đọc |
| Đồng bộ, offline và TimeLens | Tải/lưu lại, gián đoạn rồi kết nối lại, hành vi iOS cục bộ, ảnh xưa và nay |
| Đa kích thước màn hình | Các tuyến thao tác chính, vùng cuộn, xoay máy, tăng cỡ chữ và bàn phím |
| Firestore Rules | Quyền truy cập của chủ hộ chiếu, dữ liệu sai hoặc thiếu trường bắt buộc, giới hạn số ảnh tác vụ |

[CHƯA XÁC MINH] Các mục trong bảng là phạm vi cần kiểm tra. Kết quả thực tế nằm ở [bảng test case](02-bang-test-case.md). Thông tin phiên bản và thiết bị chỉ điền sau khi đo được trong lần chạy.

## Quy trình

1. **Lập kế hoạch.** Chốt commit tham chiếu, nhóm chức năng, dữ liệu thử, môi trường và người phụ trách.
2. **Thiết kế test case.** Với mỗi nhóm chức năng, bao phủ dữ liệu đúng, sai, để trống và biên. Với thao tác không có trường nhập, “để trống” là không có dữ liệu, thiếu quyền hoặc chưa có thiết lập theo từng TC.
3. **Thực hiện kiểm thử.** Chạy kiểm tra tự động trên bản đã chốt. Thành viên chạy các ca thiết bị/mạng theo [hướng dẫn kiểm thử thủ công](05-huong-dan-chay-thu-cong.md), ghi từng môi trường và minh chứng thật.
4. **Ghi nhận lỗi.** Gắn mã TC, mô tả, bước tái hiện, kết quả mong đợi/thực tế, file hoặc log, mức độ và người xử lý. Đối chiếu lỗi nháp với code trước khi đưa vào danh sách lỗi.
5. **Sửa, retest và regression.** Tái hiện trước sửa, sửa trên nhánh riêng từ develop, chạy lại cùng test và bộ kiểm tra liên quan. Với lỗi thiết bị, chạy lại trên thiết bị và cấu hình gốc. Cập nhật bảng lỗi theo bằng chứng thực tế.

## Điều kiện bắt đầu

- Có commit gốc, cây source và dependencies khóa theo repo. Mỗi lần kiểm thử ghi commit, hệ điều hành, SDK/trình duyệt và lệnh đã chạy.
- Chuẩn bị tài khoản và dữ liệu thử biệt lập. Với emulator, dùng dự án demo; với thiết bị thật, dùng tài khoản thử của nhóm và điểm thử được phép dùng.
- Với Firestore Rules, dùng dữ liệu dựng sẵn và Firestore Emulator của bộ `rules_tests/`. [TỪ CODE] Script `test` dùng project `demo-local-passport` trong [package.json](../../rules_tests/package.json#L8).
- Trước khi thử tài khoản, xác định Web/Android đang trỏ đám mây hay emulator. Kiểm tra camera, GPS và kết nối trước khi ghi kết quả luồng check-in. Người kiểm thử iOS ghi rõ đã cấu hình Firebase hay đang chạy cục bộ.
- Có mã QR chuẩn, mã sai/thiếu, ảnh hợp lệ/ảnh lỗi và dữ liệu sát ngưỡng code. Xác nhận vị trí thử và sai số GPS khi kiểm tra biên.

## Điều kiện hoàn thành

- Từng TC có một kết quả thực tế với minh chứng hoặc trạng thái “Chưa chạy” kèm lý do. Tự động và thủ công được cộng theo phạm vi tương ứng.
- Các lệnh kiểm tra repo chạy thành công hoặc báo cáo ghi rõ lệnh, lỗi và phần chưa thực hiện được. Kiểm tra thiết bị và mạng còn thiếu là điều kiện chưa đạt để nghiệm thu đầy đủ.
- Với ca Firestore Rules, dữ liệu hợp lệ phải được chấp nhận và trường hợp vi phạm phải bị từ chối đúng như kết quả mong đợi. Với kiểm tra sau sửa, thực hiện cả retest lỗi và [smoke chuỗi luồng cốt lõi](05-huong-dan-chay-thu-cong.md#smoke-chuỗi-luồng-cốt-lõi) trên cấu hình phù hợp.
- Lỗi Critical/High mở được nêu rõ trong báo cáo. Với lỗi đã sửa, commit, retest và regression phải truy được. Lỗi cần cấu hình hoặc tái hiện thêm giữ trạng thái phù hợp.
- Báo cáo, bảng TC, bảng lỗi và slide dùng cùng số liệu. Trước khi trình bày, kiểm tra lần cuối với [báo cáo tổng hợp](04-bao-cao-tong-hop.md).

## Ma trận môi trường dự kiến

Các dòng dưới đây là cấu hình yêu cầu thử. [CHƯA XÁC MINH] Kết quả trên thiết bị, trình duyệt, hệ điều hành và mạng sẽ được điền khi thực hiện từng ca.

| Mã môi trường | Nền tảng và phương tiện | Cỡ khung hoặc thiết lập | Ca ưu tiên | Người chạy |
| --- | --- | --- | --- | --- |
| WEB-P | Web, DevTools hoặc trình duyệt thật | 360×640 và 390×844, dọc rồi ngang | Chào, xác thực, QR HTTPS/localhost, chi tiết, đánh giá | Chiến Thắng, Ngọc Anh |
| WEB-T | Web, DevTools hoặc tablet thật | 768×1024, dọc rồi ngang | Bản đồ, TimeLens, cộng đồng, hộ chiếu | Minh Khoa |
| WEB-D | Web, màn hình lớn | 1440×900, cỡ chữ 100% và 130% | Điều hướng, cuộn, dialog, bảng xếp hạng | Minh Khoa |
| AND-EM | Android Emulator | AVD `LP_390x844_API35` (Android 15 API 35, 390×844 dp), GPS giả lập | Biên khoảng cách, luồng demo, cấp/từ chối quyền | Chiến Thắng, Ngọc Anh, Minh Khoa |
| AND-REAL | Android thật | Thiết bị/OS [Điền sau], dọc/ngang, cỡ chữ 130% | Camera thật, định vị thực địa, ảnh, ứng dụng quay về foreground | Ngọc Anh |
| IOS-SIM | iOS Simulator trên macOS/Xcode | Cấu hình Simulator [Điền sau] | Khởi động cục bộ, điều hướng, bố cục, GPS giả lập | Minh Khoa (chưa có máy) |
| IOS-REAL | iPhone thật | Thiết bị/OS [Điền sau], dọc/ngang, cỡ chữ 130% | Camera/GPS, ảnh, lưu cục bộ, Firebase nếu đã cấu hình | Minh Khoa (chưa có máy) |
| NET | Web DevTools và thiết bị thật | Online, Slow 3G, offline trước khi mở và rớt mạng giữa chừng | Tải bản đồ/TimeLens, gửi bài, đồng bộ và phục hồi sau kết nối | Minh Khoa |
| RULES-EMU | CLI và Firestore Emulator | Project `demo-local-passport`, dữ liệu dựng sẵn trong test | Quyền truy cập, schema hộ chiếu, biên số ảnh | Chiến Thắng |

Giữ riêng lần chạy trên từng thiết bị/cấu hình. Khi dùng emulator để đặt vị trí biên, ghi tọa độ và khoảng cách tính. Khi có lỗi, ghi mức zoom/cỡ chữ, hướng màn hình, điều kiện mạng và đúng bước bị gián đoạn.

## Lệnh kiểm tra

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
cd rules_tests
npm ci
npm test
cd ..
flutter build web --release
```

[TỪ CODE] `npm test` tại `rules_tests/` gọi Firestore Emulator trong project demo qua [package.json](../../rules_tests/package.json). Workflow PR kiểm tra quy ước Git và chạy format, analyze, Flutter test tại [pr-check.yml](../../.github/workflows/pr-check.yml). Nhánh, commit và phê duyệt PR tuân theo [git.md](../../git.md).
