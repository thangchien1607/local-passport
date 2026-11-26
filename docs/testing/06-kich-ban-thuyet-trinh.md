# Kịch bản thuyết trình Local Passport

Mỗi slide dự kiến 30–60 giây. Điền tên nhóm, thành viên và giảng viên trước buổi trình bày. Đọc các đoạn lời thoại. Dòng đối chiếu giúp người trình bày mở đúng minh chứng khi được hỏi.

| Slide | Nội dung | Người trình bày |
| --- | --- | --- |
| 1–6 | Giới thiệu, lập kế hoạch và thiết kế test case | [Tên thành viên] |
| 7–10 | Test case tiêu biểu và thực hiện kiểm thử | [Tên thành viên] |
| 11–15 | Ghi nhận lỗi, demo, retest và hồi quy | [Tên thành viên] |
| 16–18 | Kết quả, hạn chế và hỏi đáp | [Tên thành viên] |

## Slide 1 · Kiểm thử và sửa lỗi Local Passport

Em chào thầy/cô và các bạn. Nhóm em trình bày đề tài kiểm thử và sửa lỗi cho Local Passport, ứng dụng hộ chiếu trải nghiệm văn hóa Đà Nẵng. Bài trình bày bắt đầu từ cách nhóm lập kế hoạch và chọn dữ liệu kiểm thử. Sau đó, nhóm sẽ chia sẻ kết quả đã chạy, chỉ ra lỗi bằng một ví dụ trước và sau sửa, rồi nêu các tình huống cần thực hiện tiếp trên thiết bị. Thông tin nhóm và người thực hiện được điền trên trang đầu trước khi báo cáo.

## Slide 2 · Giới thiệu và phạm vi

Local Passport cho phép người dùng khám phá địa điểm, quét QR và kiểm tra vị trí để nhận dấu, sau đó viết cảm nhận hoặc lưu ảnh. Nhóm đưa cả tài khoản, cộng đồng, bảng xếp hạng, thông báo, đồng bộ, TimeLens và giao diện vào phạm vi kiểm thử. OpenStreetMap là cấu hình bản đồ mặc định. Google Maps cần khóa và SDK sẵn sàng. Web và Android có cấu hình Firebase. Phần iOS được rà riêng vì bản hiện tại có thể dùng lưu trữ cục bộ.

[TỪ CODE] `lib/services/maps_config.dart`, `initGoogleMaps()` dòng 18–21. `lib/screens/map_screen.dart`, nhánh `OsmDiscoveryMap` dòng 166. `lib/firebase_options.dart`, `currentFirebaseOptions` dòng 9. `lib/main.dart`, `_initFirebase()` dòng 38–47.

## Slide 3 · Quy trình kiểm thử và sửa lỗi

Bài trình bày đi theo năm bước. Nhóm lập kế hoạch để chốt phạm vi và tiêu chí. Khi viết test case, nhóm xác định dữ liệu vào và kết quả mong đợi. Khi thực thi, nhóm lưu kết quả quan sát, môi trường và minh chứng. Nếu kết quả lệch khỏi kỳ vọng, nhóm ghi lỗi kèm cách tái hiện. Sau khi sửa, nhóm chạy lại ca làm lộ lỗi rồi kiểm tra hồi quy các phần liên quan. Ba tài liệu chính để tra cứu là bảng test case, bảng lỗi và báo cáo tổng hợp.

## Slide 4 · Bước 1 - Lập kế hoạch kiểm thử

Nhóm ưu tiên hành trình đăng nhập, mở bản đồ, quét QR, nhận dấu và lưu cảm nhận vì các bước này nối tiếp nhau. Trước khi chạy, người kiểm tra cần ghi phiên bản, dữ liệu thử, thiết bị và kết nối. Tiêu chí Pass là quan sát đúng kết quả mong đợi và có minh chứng. Với lỗi cần sửa, nhóm cần commit, retest và hồi quy. Nghiệm thu đầy đủ còn phụ thuộc vào những bài thực hành trên thiết bị và trong các tình huống mạng đã liệt kê trong kế hoạch.

Chi tiết tiêu chí đầu vào và kết thúc nằm trong [kế hoạch kiểm thử](01-ke-hoach-kiem-thu.md).

## Slide 5 · Bước 2 - Viết test case

Nhóm chia dữ liệu thành bốn loại. TC-AUTH-01 dùng email và mật khẩu hợp lệ để kiểm tra luồng tài khoản. TC-QR-02 dùng mã đúng địa điểm nhưng sai khóa để kiểm tra phản hồi lỗi. TC-RULE-03 bỏ trường bắt buộc passportNo và kỳ vọng Firestore từ chối ghi. TC-REF-08 dùng cảm nhận 20 và 600 ký tự để kiểm tra hai giá trị ngay tại giới hạn. Việc chọn ví dụ theo hành vi giúp người đọc hiểu vì sao một ca thuộc mỗi nhóm.

[TỪ CODE] `lib/services/validators.dart`, `validateEmail()` dòng 19–24 và `validateReflection()` dòng 43–52. [ĐÃ CHẠY] TC-RULE-03 đối chiếu với bài kiểm tra hộ chiếu thiếu trường tại `rules_tests/firestore.rules.test.mjs` dòng 250–257. Các kỳ vọng và trạng thái nằm ở [bảng test case](02-bang-test-case.md).

## Slide 6 · Tổng quan bộ test case

Bảng có 79 dòng. Trong đó, 70 ca thủ công đang Chưa chạy, bốn ca Firestore Rules có kết quả từ Emulator và năm dòng ghi kết quả lệnh tự động. Theo loại đầu vào, Nhập đúng, Nhập sai và Để trống có 18 ca mỗi loại. Dữ liệu biên có 20 ca. Chín dòng Pass gồm bốn ca Rules và năm dòng lệnh. Bốn ca Rules là các khẳng định đã có trong lượt chạy Rules. Số 12 ở log là tổng số bài mà bộ chạy Rules thực thi.

[ĐÃ CHẠY] Đối chiếu [bảng test case](02-bang-test-case.md) và phần [thống kê của báo cáo](04-bao-cao-tong-hop.md).

## Slide 7 · Test case tài khoản, bản đồ và QR

Mỗi nhóm trong bảng có ví dụ cho cả bốn loại. Ở tài khoản, nhóm so đầu vào hợp lệ, email sai định dạng, trường bị bỏ trống và độ dài mật khẩu tại biên. Ở bản đồ, TC-MAP-04 đổi tuyến khi đang chọn một điểm rồi kiểm tra lựa chọn và khung bản đồ. Ở QR, TC-QR-02 dùng mã đúng điểm nhưng sai khóa. Khi đọc một ví dụ, nhóm chỉ rõ điều kiện đầu vào và kết quả mong đợi. Tất cả các ca trên slide còn Chưa chạy.

[CHƯA XÁC MINH] Kết quả thiết bị của TC-AUTH-01 đến TC-AUTH-04, TC-MAP-01 đến TC-MAP-04 và TC-QR-01 đến TC-QR-04 tra trong [bảng test case](02-bang-test-case.md).

## Slide 8 · Test case đóng dấu, cộng đồng và đồng bộ

Ở nhóm dấu và cảm nhận, TC-REF-01 kiểm tra cấp dấu sau khi hoàn tất nhiệm vụ. Ba ca tiếp theo thử nội dung ngoài giới hạn, nội dung rỗng và hai độ dài hợp lệ ngay tại biên. Ở cộng đồng, TC-COM-03 quan sát trạng thái danh sách rỗng khi lọc. Ở đồng bộ, TC-SYNC-04 dùng Slow 3G, ngắt mạng giữa thao tác rồi nối lại để quan sát việc khôi phục. Cả ba nhóm có đủ bốn loại ca và đang Chưa chạy. Người thử sẽ lưu kết quả, ảnh hoặc log theo từng mã.

[CHƯA XÁC MINH] Kết quả của TC-REF-01, TC-REF-06 đến TC-REF-08, TC-COM-01 đến TC-COM-04 và TC-SYNC-01 đến TC-SYNC-04 tra trong [bảng test case](02-bang-test-case.md).

## Slide 9 · Test case giao diện và Firestore Rules

Bốn ca giao diện thay đổi kích thước, bàn phím, trạng thái form và cỡ chữ khi xoay để quan sát khả năng hiển thị. Bốn ca Firestore Rules minh họa quyền chủ hộ chiếu, quyền của tài khoản khác, hồ sơ thiếu trường và biên số lượng ảnh tác vụ. Trong bài thử tại biên, Firestore cho phép ba ảnh và từ chối bốn ảnh. Bốn ca Rules lấy bằng chứng từ cùng một suite trên Emulator. Nhóm giao diện còn Chưa chạy, chờ thực hiện đủ bước trên các cấu hình đã nêu.

[ĐÃ CHẠY] TC-RULE-01 đến TC-RULE-04 ánh xạ tới `rules_tests/firestore.rules.test.mjs`, bài S2 dòng 123 và các bài hộ chiếu dòng 237, 250. [CHƯA XÁC MINH] TC-UI-01 đến TC-UI-04 trong [bảng test case](02-bang-test-case.md).

## Slide 10 · Bước 3 - Thực hiện kiểm thử

Lượt chạy bản gốc kiểm tra format, analyze, Flutter test, Firestore Rules và build Web release. Format sạch, analyze báo không có vấn đề, Flutter đạt 57 bài và Rules đạt 12 bài. Build Web release đã tạo bản build. Riêng lượt Edge quan sát thấy màn chào mở được ở cả bốn kích thước theo kế hoạch. Ca thủ công cần thiết bị thật, máy ảo hoặc thử mất mạng vẫn Chưa chạy. Mỗi dòng trong ma trận cho biết nhóm cần môi trường nào và sẽ điền gì sau khi thực hiện.

[ĐÃ CHẠY] Log lệnh và giới hạn lượt Edge nằm trong [báo cáo tổng hợp](04-bao-cao-tong-hop.md). [CHƯA XÁC MINH] Ma trận thực thi thiết bị và mạng nằm trong [hướng dẫn thủ công](05-huong-dan-chay-thu-cong.md).

## Slide 11 · Bước 4 - Ghi nhận lỗi

Nhóm ghi bốn thông tin chính cho mỗi lỗi. Mô tả cho biết hành vi quan sát được. Cách tái hiện giúp người khác thử lại. Mức độ dựa trên ảnh hưởng và phạm vi. Người phụ trách tiếp nhận việc xác minh hoặc xử lý. Critical chặn luồng chính trên diện rộng hoặc gây hậu quả dữ liệu nghiêm trọng. High chặn chức năng chính hay có thể làm văng màn hình. Medium ảnh hưởng một luồng con, còn Low có ảnh hưởng giới hạn. Bảng chi tiết thêm mã TC, file hoặc log, commit và kết quả retest.

Căn cứ phân mức và trường cần ghi nằm ở [bảng lỗi](03-bang-loi.md).

## Slide 12 · Lỗi tiêu biểu

BUG-02 xảy ra khi màn hình QR cập nhật giao diện sau khi đã đóng. BUG-06 làm mất ảnh cũ trong tình huống bỏ ảnh vừa chọn. BUG-12 là lỗi tràn dòng chú thích check-in trên khung hẹp. Cả ba có bản sửa và retest trên nhánh riêng. BUG-07 giữ Open vì còn cần cấu hình Firebase iOS và một lượt xác nhận trên môi trường phù hợp. Khi được hỏi, nhóm mở bảng lỗi để chỉ đoạn code, điều kiện tái hiện và bằng chứng xử lý.

[TỪ CODE] `lib/screens/qr_scanner_screen.dart`, `_handleCode` dòng 89–105 và `_simulate` dòng 121–128. `lib/widgets/edit_reflection_dialog.dart`, `build` dòng 205–212 và `_save` dòng 131–138. [ĐÃ CHẠY] Bằng chứng retest ở [BUG-02 và BUG-06](03-bang-loi.md).

## Slide 13 · Danh sách lỗi đã phát hiện

Bảng có tám lỗi với bằng chứng, gồm hai High, năm Medium và một Low. Bảy lỗi đã có commit riêng, retest và kết quả hồi quy trên nhánh sửa. BUG-07 còn Open. Cấu hình trong repo đang đưa iOS native vào chế độ cục bộ. Để xác minh đăng nhập và đồng bộ từ xa, nhóm cần cấu hình Firebase iOS và môi trường chạy phù hợp. Các nhận định từ bản nháp được đối chiếu ở phần riêng trong bảng lỗi để hội đồng có thể kiểm tra vì sao một mục được giữ, sửa hoặc cần xác minh thêm.

[TỪ CODE] `lib/firebase_options.dart`, `currentFirebaseOptions` dòng 9–13 và `lib/main.dart`, `_initFirebase` dòng 38–47. [ĐÃ CHẠY] Trạng thái và retest tại [bảng lỗi](03-bang-loi.md).

## Slide 14 · Demo BUG-06 - Giữ ảnh cũ

Tình huống bắt đầu với một bài cảm nhận đã có ảnh. Người dùng chọn ảnh mới, bấm Bỏ ảnh mới rồi lưu. Trước khi sửa, nhánh này truyền cờ xóa ảnh cũ nên lần lưu làm mất ảnh trước đó. Sau bản vá, thao tác Bỏ ảnh mới chỉ xóa ảnh vừa chọn. Lượt tái hiện trước sửa có năm bài đạt và một bài thất bại. Chạy lại cùng tệp sau sửa, cả sáu bài đạt, gồm kiểm tra ảnh cũ được giữ. Khung trên slide 14 dành cho ảnh chụp thật trước sửa và sau retest.

[TỪ CODE] `lib/widgets/edit_reflection_dialog.dart`, `build` dòng 205–212 và `_save` dòng 131–138. `lib/state/passport_store.dart`, `updateReflection` dòng 1019–1022. [ĐÃ CHẠY] Trích log trước và sau tại [báo cáo tổng hợp](04-bao-cao-tong-hop.md#kiểm-thử-nhánh-sửa). [CHƯA XÁC MINH] Kết quả thư viện ảnh thật ở TC-REF-12.

## Slide 15 · Bước 5 - Sửa lỗi và kiểm thử lại

Retest tập trung vào tình huống đã gây lỗi. Regression kiểm tra những phần khác có thể chịu ảnh hưởng. Mỗi nhánh có commit riêng và log chạy lại format, analyze, Flutter, Rules, build Web và các bài smoke tự động. Bản gốc có 57 bài Flutter đạt. Sau khi áp dụng cả bảy bản vá vào cùng một bản làm việc cục bộ và chạy gộp, 65 bài đạt. Luồng từ đăng nhập qua bản đồ, quét QR, sửa ảnh đến ngắt và nối mạng vẫn cần thực hiện đủ bước trên thiết bị thật.

[ĐÃ CHẠY] Bảng nhánh sửa và `combined-regression.log` được dẫn trong [báo cáo tổng hợp](04-bao-cao-tong-hop.md). [CHƯA XÁC MINH] Smoke xuyên luồng có thiết bị thật.

## Slide 16 · Kết quả cuối

Khi nộp bài, nhóm có ba nơi để tra cứu. Bảng test case cho biết dữ liệu, kỳ vọng và trạng thái từng ca. Bảng lỗi ghi các vấn đề xác minh được, cách xử lý và commit liên quan. Báo cáo tổng hợp lưu số liệu và log. Tại mốc báo cáo, 9 trong 79 dòng có bằng chứng Pass, 70 dòng Chưa chạy và 0 dòng Fail trong bảng hiện hành. Bảy trong tám lỗi đã sửa trên nhánh riêng. Nhóm dùng bảng chi tiết để xác định ca nào còn cần người thực hiện.

[ĐÃ CHẠY] Số dòng và trạng thái được đối chiếu từ [bảng test case](02-bang-test-case.md), [bảng lỗi](03-bang-loi.md) và [báo cáo tổng hợp](04-bao-cao-tong-hop.md).

## Slide 17 · Hạn chế và hướng phát triển

Các công việc còn lại tập trung vào quét camera, GPS, xoay màn hình, cỡ chữ lớn, Slow 3G và rớt mạng khi thao tác. Nhóm cần chạy theo checklist trên máy ảo và máy thật, lưu ảnh hoặc log cùng mã TC. Firebase iOS cần bổ sung cấu hình rồi kiểm tra trên nền tảng đó. Bài học của nhóm là một bước quan sát thành công chỉ xác nhận phạm vi đã thực thi. Khi mở rộng bộ kiểm thử, nhóm ưu tiên tự động hóa các ca lặp lại và giữ các tình huống phụ thuộc phần cứng cho lượt thử thiết bị.

[CHƯA XÁC MINH] Ca thủ công, hành vi Firebase iOS và việc tái thử bằng phần cứng theo [hướng dẫn chạy thủ công](05-huong-dan-chay-thu-cong.md).

## Slide 18 · Hỏi đáp

Nhóm xin kết thúc phần trình bày và mời thầy/cô đặt câu hỏi. Nếu cần xem một ca cụ thể, nhóm có thể mở bảng test case để đọc dữ liệu vào, kỳ vọng, môi trường và trạng thái. Với lỗi đã sửa, nhóm sẽ mở bảng lỗi và log trước, sau bản vá để phân biệt retest với hồi quy. Với những tình huống còn chờ thiết bị hoặc cấu hình, nhóm sẽ chỉ rõ điều kiện cần chuẩn bị và ai sẽ điền minh chứng sau khi thử.

## Năm câu hỏi giảng viên có thể hỏi

| Câu hỏi | Gợi ý trả lời |
| --- | --- |
| Vì sao bảng có 79 dòng nhưng Flutter báo 57 và Firestore Rules báo 12? | 79 là số dòng theo dõi trong tài liệu, gồm ca nghiệp vụ, ca Rules ánh xạ tới các khẳng định của suite, và dòng tổng hợp lệnh. 57 và 12 là số bài do từng bộ chạy báo. [ĐÃ CHẠY] Căn cứ bảng thống kê và log trong [báo cáo tổng hợp](04-bao-cao-tong-hop.md). |
| Vì sao chọn OpenStreetMap làm mặc định trong kế hoạch? | [TỪ CODE] `lib/services/maps_config.dart`, `initGoogleMaps()` dòng 18–21, chỉ khởi tạo SDK Google khi có khóa. `lib/screens/map_screen.dart` chọn `OsmDiscoveryMap` khi Google Maps chưa sẵn sàng. |
| Retest BUG-06 và regression khác nhau thế nào? | [ĐÃ CHẠY] Retest chạy lại ca bỏ ảnh mới trong `test/reflection_edit_test.dart`, kết quả cả sáu bài trong tệp đạt. Regression chạy thêm các bài liên quan và toàn bộ bộ Flutter, gồm lượt chạy gộp bảy bản vá đạt 65 bài. |
| Vì sao có dòng `PERMISSION_DENIED` nhưng bộ Rules vẫn Pass? | [ĐÃ CHẠY] Với đầu vào sai quyền hoặc sai dữ liệu, việc Firestore từ chối chính là kết quả mong đợi của khẳng định. Runner xác nhận cả 12 bài đạt trên Emulator. |
| Vì sao thử được màn chào trên Edge mà 70 ca thủ công vẫn Chưa chạy? | [ĐÃ CHẠY] Smoke Edge chỉ quan sát màn chào ở bốn viewport. [CHƯA XÁC MINH] Mỗi ca thủ công còn cần chạy đủ thao tác và quan sát kết quả trong môi trường đã ghi, nhất là camera, GPS, đồng bộ và gián đoạn mạng. |
