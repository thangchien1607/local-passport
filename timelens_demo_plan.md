# Kế hoạch demo TimeLens — bản nộp vòng đơn (~30% dự án)

*Mini Hackathon GDG DevFest MienTrung 2026 · Learn Beyond Limits · Hạn đăng ký: 05/11/2026*

Tài liệu này mô tả **phạm vi, công cụ và cách làm** bản demo công khai chỉ gồm một trang: **Lăng kính thời gian (TimeLens)**.
Trang này nằm trong app Local Passport của nhóm (mở từ tab Khám phá), nhưng **bản public được build riêng** và chỉ có đúng trang này.

---

## 1. Yêu cầu của BTC liên quan đến demo

Trích từ form đăng ký:

| Nội dung trong thể lệ | Ảnh hưởng tới bản demo |
| :--- | :--- |
| Ô mô tả: *"Có thể đính kèm link Demo nếu sản phẩm đã hoàn thiện được ~30%"* | Link demo chỉ thể hiện khoảng 30% dự án. |
| *"Phát triển ý tưởng trước đó đã có (nhưng chưa được hoàn thiện quá 30%)"* | Demo chỉ có 1 tính năng lõi, không kèm luồng đầy đủ. |
| *"Nộp sản phẩm bạn đang làm đến thời điểm hiện tại, hướng build tiếp theo. BTC sẽ kiểm tra và quyết định"* | Phần mô tả trong form ghi rõ hiện trạng và hướng build tiếp (mục 7). |
| Yêu cầu kỹ thuật tối thiểu: *gọi API Google Gemini* và *triển khai trên Google Cloud Run* | Demo vòng đơn chưa cần. Hai việc này làm trong ngày hackathon 14/11 (mục 7). |

---

## 2. Phạm vi demo (≈30%)

Tỉ trọng dưới đây là ước lượng theo khối lượng công việc của toàn bộ MVP trong `local_passport.md`:

| Hạng mục của Local Passport | Tỉ trọng | Trong demo |
| :--- | :---: | :--- |
| A. Bản đồ khám phá: Radar Hotspots + Bộ lọc cảm hứng | 15% | Không |
| B1. Check-in QR thực địa (GPS + nút giả lập) | 15% | Không |
| B2. Câu chuyện văn hóa cô đọng | 10% | Một phần: 1 thẻ/di tích, không khóa/mở (≈5%) |
| **B3. TimeLens Slider — ảnh xưa & nay** | **20%** | **Có, đầy đủ, ảnh thật (20%)** |
| C. Checklist nhánh nhỏ + Thanh tiến độ | 10% | Không |
| D1. Hộ chiếu số + hiệu ứng đóng dấu mộc | 10% | Không |
| D2. Feedback tùy chọn, ẩn danh + Gemini AI Verifier | 10% | Không |
| Hạ tầng: Firebase Auth/Firestore/Storage, Gemini API, Cloud Run | 10% | Chỉ hosting tĩnh (≈5%) |
| **Tổng** | **100%** | **≈30%** |

**Có trong demo**
- Thanh trượt TimeLens: kéo bằng chuột hoặc cảm ứng, trình đọc màn hình tăng/giảm được. Ảnh "xưa" có hiệu ứng sepia + hạt phim.
- 4 di tích tiêu biểu trong đề cương, mỗi điểm một **cặp ảnh thật** xưa/nay chụp cùng chủ thể (mục 4.3):

  | Di tích | Ảnh xưa | Ảnh nay |
  | :--- | :--- | :--- |
  | Thành Điện Hải | Bưu ảnh tường thành, nhà thờ, bệnh viện Pháp — đầu TK XX | Hào và tường thành, cao ốc phía sau — 2024 |
  | Bảo tàng Điêu khắc Chăm | Bưu ảnh hiên cột nhà trưng bày — đầu TK XX | Hiên cột và sân tượng — 2009 |
  | Cầu Rồng | Giàn giáo dựng cầu giữa sông Hàn — 2011 | Cầu Rồng lên đèn dịp 30/4 — 2026 |
  | Ngũ Hành Sơn | Chùa trong động Huyền Không — 1920s | Cùng ngôi chùa — 2024 |
- Mỗi cặp ảnh có chú thích nội dung và dòng ghi nguồn/giấy phép ngay dưới thanh trượt.
- 1 thẻ câu chuyện ngắn cho mỗi di tích.
- Một khung nhỏ liệt kê các phần khác của Local Passport, ghi rõ là *không có trong bản demo*.

**Không có trong bản public**, và cũng không có trong file build: đăng nhập, bản đồ, quét QR/GPS, checklist, tiến độ, đóng dấu, hộ chiếu, bảng tin, xếp hạng, chấm cảm nhận.

---

## 3. Công cụ sử dụng

| Công cụ | Phiên bản | Vai trò |
| :--- | :--- | :--- |
| Flutter (stable) / Dart | 3.47.6 / 3.13.5 | Framework, build bản web |
| `google_fonts`, `flutter_svg` | có sẵn trong `pubspec.yaml` | Font của design system; tranh SVG cho 6 điểm chưa có ảnh thật |
| Wikimedia Commons (API + trang file) | — | Nguồn ảnh tư liệu có giấy phép mở: public domain, CC0, CC BY, CC BY-SA |
| Python 3 + Pillow | 3.14 / 12.x | Cắt ảnh về 20:13, thu nhỏ 1040×676, nén JPEG, xóa EXIF |
| Firebase Hosting + `firebase-tools` | CLI 15.x | Host demo trên **site riêng** `local-passport-timelens` trong project `local-passport-danang` |
| Node.js | 22.x | Script build `tools/timelens/build.mjs` |
| Git + GitHub + GitHub CLI (`gh`) | gh 2.x | Nhánh, Pull Request theo quy trình ở mục 5 |
| Chrome DevTools | — | Kiểm tra giao diện desktop và mobile (360–440px) |

Không thêm package Flutter mới.

---

## 4. Phương thức thực hiện

### 4.1. Kiến trúc: một màn hình, hai cách mở

```
lib/main.dart (app đầy đủ)                    lib/main_timelens.dart (bản public)
  └─ Khám phá → banner "Lăng kính thời gian"     └─ TimeLensScreen(standalone: true)
        └─ TimeLensScreen(onOpenLocation)  ──┐
                                             ├─ screens/timelens_screen.dart
                                             │    ├─ widgets/time_lens.dart  → widgets/scene_art.dart
                                             │    │                           → assets/photos/<id>_<past|present>.jpg
                                             │    ├─ widgets/passport_cover.dart
                                             │    ├─ data/routes.dart (4 di tích qua locationById)
                                             │    └─ theme.dart
```

- **Trong app đầy đủ**: trang mở từ banner ở tab Khám phá, có nút quay lại và nút *"Xem di tích & check-in"* sang trang di tích. Nút này dùng callback nên `timelens_screen.dart` không phải import màn hình nào khác.
- **Bản public**: entrypoint `lib/main_timelens.dart` không import `PassportStore`, các màn hình khác, `mobile_scanner`, `geolocator`, `image_picker`. Khi build với `-t lib/main_timelens.dart`, trình biên dịch Dart→JS (tree-shaking) chỉ giữ code mà entrypoint dùng tới. Vì vậy file build không chứa code các màn hình còn lại (đã kiểm tra bằng cách dò chuỗi trong `main.dart.js`).
- Dữ liệu ảnh nằm trong `TimeLensInfo` (`pastImageUrl`, `presentImageUrl`, `caption`, `credit`). Trang di tích trong app đầy đủ tự dùng ảnh thật cho ảnh bìa, TimeLens và ảnh mờ khi chưa mở khóa.

### 4.2. Giao diện trang

1. **Header** nền bìa hộ chiếu: *LOCAL PASSPORT · BẢN DEMO* (bản public) hoặc *· XEM TRƯỚC* (trong app), tiêu đề "Lăng kính thời gian".
2. **TimeLens lớn** (20:13). Tay nắm tự lắc nhẹ một lần để gợi ý là kéo được. Kéo hết về một phía thì hiện thông báo "nhìn xuyên thời gian". Ngay dưới là chú thích ảnh và dòng ghi nguồn.
3. **Dải 4 ảnh thu nhỏ** (ảnh "nay") để chọn di tích. Ảnh của cả 4 điểm được nạp sẵn để đổi điểm không bị nháy trắng.
4. **Thẻ di tích**: tuyến, tên, địa chỉ, mốc xưa → nay, 1 câu chuyện ngắn.

Bố cục giữ khung mobile tối đa 440px như app chính, đọc tốt trên điện thoại 360px.

### 4.3. Ảnh thật: chọn, cắt, ghi nguồn

1. **Tìm** trên Wikimedia Commons qua API (tên di tích, "Tourane", category của từng di tích). Chỉ nhận ảnh public domain, CC0, CC BY, CC BY-SA.
2. **Ghép cặp**: ưu tiên hai ảnh cùng chủ thể, cùng hướng nhìn, để khi kéo thanh trượt thấy đúng một chỗ ở hai thời điểm (ví dụ cùng ngôi chùa trong động Huyền Không, cùng lan can nhìn ra sông Hàn).
3. **Mốc năm** ghi đúng theo ngày chụp trong metadata của ảnh, không làm tròn thành "2026".
4. **Cắt** bằng Pillow: chọn vùng theo lưới tọa độ, căn chủ thể/đường chân trời của hai ảnh trùng nhau → 1040×676, JPEG ~80%, xóa EXIF. Tổng 8 ảnh ≈ 1,3 MB.
5. **Ghi nguồn**: dòng `credit` hiện dưới thanh trượt. Bảng đầy đủ (tên file gốc, tác giả, giấy phép, link) ở mục "Nguồn ảnh" trong `README.md`.

### 4.4. Build

```bash
node tools/timelens/build.mjs
```

Script này:
1. Chạy `flutter build web --release -t lib/main_timelens.dart -o build/timelens`.
2. Sửa `build/timelens/index.html`: tiêu đề tab, thẻ mô tả và chữ ở màn chờ thành của TimeLens. Script báo lỗi nếu `web/index.html` đổi cấu trúc. File `web/index.html` của app chính không bị đổi.

### 4.5. Deploy lên Firebase Hosting (site riêng)

Làm một lần:

```bash
firebase.cmd login
firebase.cmd hosting:sites:create local-passport-timelens --project local-passport-danang
```

Mỗi lần cập nhật demo:

```bash
node tools/timelens/build.mjs
firebase.cmd deploy --only hosting --config firebase.timelens.json
```

- `firebase.timelens.json` trỏ tới `site: local-passport-timelens`, thư mục `build/timelens`, giữ các header no-cache như app chính và tắt quyền camera/vị trí (demo không cần).
- `firebase.json` của app chính không đổi. Lệnh `firebase.cmd deploy --only hosting` vẫn chỉ deploy app đầy đủ.
- Link demo: **https://local-passport-timelens.web.app**

### 4.6. Kiểm thử & nghiệm thu

- `flutter analyze` không có lỗi.
- `flutter test`: kiểm tra 4 di tích của demo tồn tại, có đủ dữ liệu, có ảnh thật kèm `credit` và file ảnh tồn tại.
- Chạy bản build ở máy, kiểm tra trên Chrome desktop và khung 360px:
  - [x] Kéo thanh trượt bằng chuột; kéo hết về một phía thì có thông báo.
  - [x] Đổi đủ 4 di tích; ảnh, mốc năm, chú thích, nguồn ảnh và câu chuyện đổi theo.
  - [x] Không có đường vào màn hình nào khác. Mở link check-in `?checkin=...` cũng chỉ hiện trang TimeLens.
  - [x] Không có lỗi trong console.
  - [x] Trong app đầy đủ: banner ở tab Khám phá → TimeLens → "Xem di tích & check-in" → quay lại.
- Sau khi deploy, mở link public trên 2 điện thoại thật (Android + iOS).

---

## 5. Quy trình Git

```
main  ←  develop  ←  feature/monster9k-timelens-demo
```

1. Tách nhánh `feature/monster9k-timelens-demo` từ `develop`.
2. Commit theo từng bước: kế hoạch → trang TimeLens → ảnh thật → build/deploy.
3. Push nhánh, mở PR vào `develop`, rồi merge.
4. Mở PR từ `develop` vào `main`, rồi merge.
5. Build từ `main` và deploy site demo.

---

## 6. Kế hoạch thời gian

| Ngày | Việc | Phụ trách |
| :--- | :--- | :--- |
| 01/11 | Viết kế hoạch, code trang TimeLens, tìm và xử lý ảnh thật, test, PR, deploy link public | monster9k |
| 02/11 | Cả nhóm mở link trên điện thoại thật, góp ý giao diện, nội dung và ảnh | Cả nhóm |
| 03–04/11 | Điền form: mô tả dự án, hiện trạng, hướng build tiếp, công nghệ Google, link demo | Trưởng nhóm |
| 05/11 | Hạn chót đăng ký | — |

---

## 7. Hiện trạng & hướng build tiếp theo (dùng cho phần mô tả trong form)

| Hạng mục | Hiện trạng (01/11/2026) | Làm tại hackathon 14/11 |
| :--- | :--- | :--- |
| TimeLens | Có slider. 4 di tích có ảnh thật (Wikimedia Commons), 6 điểm còn lại dùng tranh SVG | Tự chụp ảnh "nay" cùng góc với ảnh tư liệu; bổ sung ảnh cho các điểm còn lại |
| Bản đồ Hotspots | Bản đồ SVG minh họa | Google Maps Platform |
| Check-in QR | Đã có prototype camera + GPS, dữ liệu lưu trên máy | Xác thực và lưu qua Firebase |
| Checklist, tiến độ, hộ chiếu, dấu mộc | Prototype giao diện, dữ liệu lưu trên máy | Firebase Auth + Cloud Firestore |
| Chấm cảm nhận | Mô phỏng theo độ dài và từ khóa | **Gemini API** gọi từ server, không để API key trong app |
| Trợ lý văn hóa AI | Chưa có | **Gemini**: thuyết minh và hỏi đáp tại di tích |
| Triển khai | Firebase Hosting | **Google Cloud Run** (yêu cầu tối thiểu của BTC) |
| Nội dung lịch sử | Dữ liệu mẫu | Đối chiếu nguồn chính thống |

Phần mô tả trong form nên ghi đúng hiện trạng ở bảng trên, vì BTC sẽ tự kiểm tra mức độ hoàn thiện.
