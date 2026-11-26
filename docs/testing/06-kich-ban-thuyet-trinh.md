# Kịch bản thuyết trình Local Passport

Mỗi phần dự kiến 30–60 giây. Người trình bày điền tên trước buổi báo cáo. Đối chiếu các số liệu với [báo cáo tổng hợp](04-bao-cao-tong-hop.md), [bảng test case](02-bang-test-case.md) và [bảng lỗi](03-bang-loi.md).

| Phần | Người trình bày |
| --- | --- |
| Slide 1–5, dự án và kế hoạch | [Điền tên thành viên phụ trách kế hoạch] |
| Slide 6–8, thiết kế và kết quả | [Điền tên thành viên phụ trách kiểm thử] |
| Slide 9–14, lỗi và kết luận | [Điền tên thành viên phụ trách xử lý lỗi] |

## Slide 1 · Local Passport

Em chào thầy/cô và các bạn. Nhóm em trình bày bài kiểm thử và sửa lỗi cho Local Passport, ứng dụng hộ chiếu trải nghiệm văn hóa Đà Nẵng. Nhóm sẽ lần lượt nói về phạm vi, cách chọn dữ liệu đầu vào và kết quả thu được từ các lệnh kiểm thử. Sau đó, nhóm sẽ trình bày bảng lỗi cùng những thao tác còn cần xác nhận trên thiết bị.

## Slide 2 · Phạm vi kiểm thử

[TỪ CODE] Luồng chính bắt đầu từ tài khoản và bản đồ khám phá, tiếp theo là quét mã QR, kiểm tra vị trí, đóng dấu, rồi lưu ảnh hoặc cảm nhận. Nhóm cũng kiểm tra cộng đồng, bảng xếp hạng, thông báo, đồng bộ và TimeLens. OpenStreetMap là bản đồ mặc định. Google Maps chỉ là cấu hình tùy chọn. Ứng dụng có cấu hình Firebase trên Web và Android. Phần iOS được ghi riêng theo chế độ mà mã nguồn hỗ trợ. Mốc đối chiếu là `lib/firebase_options.dart`, `currentFirebaseOptions`, và `lib/services/maps_config.dart`, `initGoogleMaps()`.

## Slide 3 · Quy trình kiểm thử và sửa lỗi

Đầu tiên nhóm xác định mục tiêu và môi trường kiểm thử. Tiếp theo, nhóm thiết kế dữ liệu và kết quả mong đợi cho từng test case. Khi thực thi, nhóm ghi kết quả quan sát được cùng môi trường và minh chứng. Nếu phát hiện chênh lệch, nhóm lập lỗi có bước tái hiện và vị trí trong mã. Với bản sửa, nhóm chạy lại đúng tình huống lỗi rồi chọn các luồng dễ bị ảnh hưởng để kiểm tra hồi quy.

## Slide 4 · Kế hoạch và tiêu chí đạt

Nhóm ưu tiên đăng nhập, check-in, đóng dấu và lưu tiến độ vì đây là hành trình chính của người dùng. Trước khi chạy, người kiểm tra ghi lại phiên bản, môi trường và dữ liệu cần chuẩn bị. Một test case chỉ được đánh Pass khi kết quả quan sát khớp với kỳ vọng. Khi còn tình huống chưa thực thi, bảng giữ nguyên trạng thái Chưa chạy để nhóm có thể tiếp tục mà không cần suy ra từ kết quả tự động.

## Slide 5 · Môi trường dự kiến

[CHƯA XÁC MINH] Nhóm lên kế hoạch dùng trình duyệt, máy ảo và thiết bị thật. Trình duyệt giúp lặp lại các kích thước màn hình và cấu hình mạng. Trên máy thật, nhóm cần thử thao tác quét bằng camera, quyền GPS và định vị ngoài hiện trường. Nhóm cũng thử cỡ chữ lớn, xoay ngang, mất mạng và kết nối khôi phục. Các môi trường này là kế hoạch, kết quả được điền sau từng phiên chạy.

## Slide 6 · Thiết kế test case

[TỪ CODE] Các ví dụ minh họa bốn nhóm dữ liệu. Email đúng định dạng qua bước kiểm tra đầu vào. Email thiếu ký tự `@` phải hiện lỗi định dạng và email trống phải yêu cầu nhập. Với cảm nhận, nhóm lấy ngay ngưỡng trong hàm kiểm tra độ dài. Chuỗi ngay dưới ngưỡng phải bị chặn, còn chuỗi tại đúng ngưỡng qua bước kiểm tra độ dài. Kết quả đăng nhập hay lưu bài vẫn cần được kiểm tra riêng. Căn cứ trong `lib/services/validators.dart` là `validateEmail()` và `validateReflection()`.

## Slide 7 · Kiểm tra tự động

[ĐÃ CHẠY] Ở bản gốc, trình định dạng kiểm tra 58 tệp và không đổi tệp nào. Phân tích tĩnh không báo vấn đề. Flutter ghi nhận 57 bài test đạt, còn Firestore Rules ghi nhận 12 bài đạt trên Emulator. Các số này là số bài bên trong suite. Mỗi suite hoặc lệnh được ghi một dòng riêng trong bảng test case. Build Web release hoàn thành. Tổng cộng 5 dòng kiểm tra tự động đều đạt.

## Slide 8 · Kết quả kiểm thử thủ công

Biểu đồ thể hiện số ca thủ công theo từng phân hệ. Cả 70 ca hiện ở trạng thái Chưa chạy. [ĐÃ CHẠY] Riêng lượt smoke Web đã mở màn chào trên Edge ở bốn kích thước. [CHƯA XÁC MINH] Những ca thủ công còn cần chạy đủ các bước liên quan đến camera, GPS, tài khoản và điều kiện mạng. Khi thực thi một ca, người chạy ghi môi trường, kết quả quan sát và minh chứng để cập nhật biểu đồ.

## Slide 9 · Lỗi tiêu biểu

[TỪ CODE] Nhóm chọn ba tình huống để trình bày. Màn hình quét có đường gọi cập nhật giao diện sau một thao tác chờ. Nếu màn hình đã đóng, lần cập nhật này có thể xảy ra sai vòng đời. Luồng sửa cảm nhận dùng cờ xóa ảnh cũ khi bỏ ảnh vừa chọn. Trên iOS, mã nguồn chuyển sang lưu cục bộ khi chưa có cấu hình Firebase. [ĐÃ CHẠY] BUG-02 và BUG-06 có commit và kết quả retest trên từng nhánh. BUG-07 vẫn Open, cần cấu hình Firebase iOS và thiết bị để xác nhận. Bảng lỗi dẫn đến vị trí code, bước tái hiện và minh chứng của mỗi mục.

## Slide 10 · Demo BUG-06

[TỪ CODE] Với BUG-06, người dùng vào sửa bài đã có ảnh, chọn ảnh mới rồi bấm Bỏ ảnh mới. Trước bản sửa, thao tác này truyền cờ xóa cả ảnh cũ khi lưu. Bản vá tách việc bỏ ảnh vừa chọn khỏi hành động xóa ảnh đã lưu. [ĐÃ CHẠY] Lượt thử trước sửa báo 5 đạt và 1 lỗi. Sau bản sửa, cả 6 bài trong lượt retest đạt. Widget test xác nhận ảnh cũ vẫn còn sau khi bỏ ảnh mới và lưu. [CHƯA XÁC MINH] Nhóm vẫn cần thử thư viện ảnh trên máy thật.

## Slide 11 · Retest và regression

Nhóm dùng retest để kiểm tra đúng tình huống lỗi, rồi chạy hồi quy các luồng liên quan như xác thực, đồng bộ, cảm nhận và QR. [ĐÃ CHẠY] Các nhánh sửa đều hoàn thành kiểm tra định dạng, phân tích tĩnh, Flutter, Firestore Rules và build Web. Lượt chạy gộp các bản sửa trên bản kiểm tra cục bộ đạt 65 bài Flutter. Bảng báo cáo dẫn đến từng commit và log để người xem lần lại kết quả.

## Slide 12 · Tổng hợp lỗi theo trạng thái

[TỪ CODE] Mức độ lỗi phản ánh ảnh hưởng đã đối chiếu trong bảng lỗi. Có 8 mục với bằng chứng, gồm 2 High, 5 Medium và 1 Low. [ĐÃ CHẠY] Các commit và kết quả retest, hồi quy xác nhận đã sửa 7 mục trên nhánh riêng. BUG-07 là mục High còn Open. Các nhận định nháp về quota và đánh đổi kiến trúc có phần đối chiếu riêng để người xem biết căn cứ.

## Slide 13 · Hạn chế và bước tiếp theo

[CHƯA XÁC MINH] Phần còn lại là vận hành trên máy thật, đặc biệt là camera, GPS, xoay màn hình và các luồng đang thao tác thì mất mạng. Firebase trên iOS cần cấu hình và xác nhận trên thiết bị. Bài học của nhóm là ghi riêng kết quả từng lần quan sát và chỉ cập nhật trạng thái khi có đủ bằng chứng cho ca đó. Nhóm sẽ dùng checklist, ghi môi trường và đính kèm minh chứng theo đúng mã test case.

## Slide 14 · Hỏi đáp

Em xin kết thúc phần trình bày. Nhóm có thể mở bảng test case để chỉ rõ dữ liệu, kỳ vọng và bằng chứng của từng tình huống, hoặc mở bảng lỗi để giải thích cách nhóm xác minh. Các mục chưa chạy đang được giữ đúng trạng thái để các thành viên có thể tiếp tục trên thiết bị. Nhóm xin mời thầy/cô và các bạn đặt câu hỏi.

## Câu hỏi giảng viên có thể hỏi

| Câu hỏi | Gợi ý trả lời |
| --- | --- |
| Tại sao nhiều test case thủ công ở trạng thái Chưa chạy? | Bảng ghi trạng thái theo từng lần thực thi. Camera, GPS, kích cỡ màn hình và mất mạng phải được quan sát trên môi trường ghi trong hướng dẫn thủ công. |
| Vì sao dùng OpenStreetMap trong kế hoạch? | [TỪ CODE] `lib/services/maps_config.dart`, `initGoogleMaps()` chỉ khởi tạo SDK Google khi có API key. `lib/screens/map_screen.dart` chọn `OsmDiscoveryMap` khi Google Maps chưa sẵn sàng. |
| Khi nào được đánh một lỗi là đã sửa? | Khi có commit sửa thực tế, test case tái hiện đã được chạy lại và các luồng hồi quy liên quan đã có kết quả. Bảng lỗi liên kết tới bằng chứng tương ứng. |
| Kết quả build Web xác nhận những gì? | [ĐÃ CHẠY] Lệnh đã tạo bản build Web release. Các luồng thao tác được xác nhận theo từng test case và môi trường ghi trong bảng. |
| Vì sao test các giá trị sát ngưỡng? | Nhiều lỗi xuất hiện ở dấu so sánh tại ngưỡng. Kiểm tra dưới, đúng và trên ngưỡng giúp phân biệt giá trị bị chặn với giá trị hợp lệ. |
