---
marp: true
size: 16:9
paginate: true
style: |
  :root {
    --ink: #142e35;
    --muted: #43585a;
    --accent: #0c655a;
    --line: #bdccc6;
    --paper: #f6f6ee;
    --subtle: #e6eee6;
    --passed: #0c655a;
    --failed: #a03e28;
    --pending: #b8cfc1;
  }
  section {
    background: var(--paper);
    color: var(--ink);
    font-family: "Segoe UI", Arial, sans-serif;
    font-size: 30px;
    justify-content: flex-start;
    padding: 64px 84px 62px;
  }
  section::after { color: var(--muted); font-size: 18px; right: 44px; bottom: 25px; }
  h1 { margin: 0 0 36px; color: var(--ink); font-size: 52px; font-weight: 700; letter-spacing: -1.4px; }
  p { margin: 0 0 20px; }
  .auto td:first-child { width: 55%; }
  strong { color: var(--accent); }
  ul { margin: 0; padding-left: 36px; }
  li { padding-left: 7px; margin: 0 0 21px; }
  li::marker { color: var(--accent); }
  .flag { color: var(--accent); font-size: 19px; font-weight: 700; }
  .dim { color: var(--muted); font-size: 23px; }
  .source { color: var(--muted); font-size: 17px; margin-top: 22px; }
  .plain td code { color: var(--ink); font-size: .89em; font-weight: 600; background: transparent; padding: 0; }
  .cover { background: #11363a; color: #f6f6ee; justify-content: center; }
  .cover h1 { color: #f6f6ee; font-size: 96px; margin-bottom: 12px; }
  .cover h2 { color: #d1e5d7; margin: 0 0 54px; font-size: 43px; border: 0; }
  .cover p { color: #d1e5d7; font-size: 26px; margin: 0 0 11px; }
  table.plain, table.stats { width: 100%; display: table; border-collapse: collapse; font-size: 25px; }
  table.plain thead th, table.stats thead th { color: var(--accent); text-align: left; font-size: .90em; border-bottom: 2px solid var(--accent); }
  table.plain th, table.plain td, table.stats th, table.stats td { padding: 12px 14px 12px 0; border: 0; border-bottom: 1px solid var(--line); vertical-align: top; background: none; }
  table.plain tr, table.stats tr { background: none; }
  table.stats th:not(:first-child), table.stats td:not(:first-child) { text-align: center; }
  table.stats tbody tr:last-child td { font-weight: 700; border-bottom: 2px solid var(--accent); }
  .compact { font-size: 23px !important; }
  .workflow { display: grid; grid-template-columns: 1fr .23fr 1fr .23fr 1.08fr .23fr 1fr .23fr 1.55fr; gap: 8px; align-items: center; margin-top: 110px; }
  .workflow b { border-top: 2px solid var(--accent); align-self: stretch; padding-top: 23px; font-size: 29px; }
  .workflow span { color: var(--accent); padding-top: 19px; text-align: center; }
  .legend { margin: 0 0 14px; display: flex; align-items: center; gap: 30px; font-size: 21px; }
  .legend span { display: flex; align-items: center; gap: 9px; }
  .chip { width: 19px; height: 19px; display: inline-block; }
  .pass { background: var(--passed); }
  .fail { background: var(--failed); }
  .pending { background: var(--pending); }
  .bars { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); align-items: end; gap: 14px; margin-top: 21px; }
  .bar-item { min-width: 0; text-align: center; }
  .track { height: 260px; display: flex; flex-direction: column-reverse; align-items: center; border-bottom: 1px solid var(--line); }
  .track .segment { display: block; min-height: 0; width: 64%; }
  .bar-total { font-size: 25px; font-weight: 700; line-height: 1.12; padding: 0 0 7px; }
  .bar-label { margin-top: 10px; font-size: 20px; white-space: nowrap; }
  .demo { display: grid; grid-template-columns: 1.18fr 1fr; align-items: center; gap: 40px; }
  .demo p { font-size: 25px; margin: 0 0 18px; }
  .evidence { display: grid; min-height: 350px; padding: 30px; place-items: center; text-align: center; color: var(--muted); border: 2px dashed var(--line); font-size: 22px; background: var(--subtle); }
  .closing { background: #11363a; justify-content: center; }
  .closing h1 { color: #f6f6ee; font-size: 92px; }
  .closing p { color: #d1e5d7; font-size: 32px; }
---

<!-- Xuất PDF từ thư mục docs/testing bằng npx @marp-team/marp-cli@4.5.1 --html --pdf slide.md -->
<!-- _class: cover -->
<!-- _paginate: false -->

# Local Passport

## Kiểm thử và sửa lỗi

Nhóm [Điền tên nhóm]

Thành viên [Điền tên thành viên]

Giảng viên [Điền tên giảng viên]

---

# Phạm vi kiểm thử

- Khám phá Đà Nẵng, quét QR và nhận dấu trong hộ chiếu.
- Tài khoản, cảm nhận, ảnh, cộng đồng và bảng xếp hạng.
- Đồng bộ, thông báo, TimeLens và giao diện đa kích thước.
- OpenStreetMap mặc định. Firebase cho Web và Android.

<p class="source">[TỪ CODE] lib/main.dart, _initFirebase() · lib/services/maps_config.dart, initGoogleMaps()</p>

---

# Quy trình kiểm thử và sửa lỗi

<div class="workflow">
  <b>Lập kế hoạch</b><span>→</span>
  <b>Viết test case</b><span>→</span>
  <b>Thực hiện</b><span>→</span>
  <b>Ghi nhận lỗi</b><span>→</span>
  <b>Sửa và kiểm thử lại</b>
</div>

---

# Kế hoạch và tiêu chí đạt

- Ưu tiên đăng nhập, check-in, đóng dấu và lưu tiến độ.
- Chuẩn bị bộ dữ liệu, phiên bản và môi trường trước khi chạy.
- Đối chiếu kết quả thực tế với kỳ vọng của từng test case.
- Xác nhận bản sửa bằng retest và regression có bằng chứng.

---

# Môi trường dự kiến

- [CHƯA XÁC MINH] Web, máy ảo Android/iOS, điện thoại thật.
- 360×640 và 390×844 cho màn hình điện thoại.
- 768×1024 và 1440×900 cho tablet, desktop.
- Cỡ chữ 130%, xoay ngang, quyền camera và GPS.
- Offline, Slow 3G và mất mạng giữa thao tác.


---

# Thiết kế test case

<table class="plain">
<thead><tr><th>Nhóm dữ liệu</th><th>Ví dụ</th><th>[TỪ CODE] Kết quả mong đợi</th></tr></thead>
<tbody>
<tr><td>Đúng</td><td>Email đúng định dạng</td><td>Qua bước kiểm tra định dạng</td></tr>
<tr><td>Sai</td><td>Email thiếu <code>@</code></td><td>Hiện lỗi định dạng</td></tr>
<tr><td>Trống</td><td>Email để trống</td><td>Yêu cầu nhập email</td></tr>
<tr><td>Biên</td><td>Cảm nhận 19 / 20 ký tự</td><td>19 bị chặn, 20 qua kiểm tra độ dài</td></tr>
</tbody>
</table>


---

# Kiểm tra tự động

<table class="plain compact auto" aria-label="Kết quả từng lệnh trong báo cáo tổng hợp">
<tbody>
<tr><td><code>dart format</code></td><td>[ĐÃ CHẠY] Pass · 58 tệp, 0 thay đổi</td></tr>
<tr><td><code>flutter analyze</code></td><td>[ĐÃ CHẠY] Pass · No issues found!</td></tr>
<tr><td><code>flutter test</code></td><td>[ĐÃ CHẠY] Pass · 57 bài kiểm thử</td></tr>
<tr><td><code>npm test (rules_tests)</code></td><td>[ĐÃ CHẠY] Pass · 12 bài kiểm thử</td></tr>
<tr><td><code>flutter build web --release</code></td><td>[ĐÃ CHẠY] Pass · Đã tạo build Web</td></tr>
</tbody>
</table>


---

# Kết quả kiểm thử thủ công

<div class="legend">
<span><i class="chip pass"></i> Pass</span><span><i class="chip fail"></i> Fail</span><span><i class="chip pending"></i> Chưa chạy</span>
</div>

<div class="bars" role="img" aria-label="Tài khoản 0 Pass, 0 Fail, 16 Chưa chạy. Bản đồ 0 Pass, 0 Fail, 8 Chưa chạy. QR/GPS 0 Pass, 0 Fail, 9 Chưa chạy. Dấu và ảnh 0 Pass, 0 Fail, 13 Chưa chạy. Cộng đồng 0 Pass, 0 Fail, 12 Chưa chạy. Đồng bộ 0 Pass, 0 Fail, 8 Chưa chạy. Giao diện 0 Pass, 0 Fail, 4 Chưa chạy">
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:86.00%"></i>
      <span class="bar-total">16</span>
    </div>
    <div class="bar-label">Tài khoản</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:43.00%"></i>
      <span class="bar-total">8</span>
    </div>
    <div class="bar-label">Bản đồ</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:48.38%"></i>
      <span class="bar-total">9</span>
    </div>
    <div class="bar-label">QR/GPS</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:69.88%"></i>
      <span class="bar-total">13</span>
    </div>
    <div class="bar-label">Dấu và ảnh</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:64.50%"></i>
      <span class="bar-total">12</span>
    </div>
    <div class="bar-label">Cộng đồng</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:43.00%"></i>
      <span class="bar-total">8</span>
    </div>
    <div class="bar-label">Đồng bộ</div>
  </div>
  <div class="bar-item">
    <div class="track">
      <i class="segment pass" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment fail" aria-hidden="true" style="height:0.00%"></i>
      <i class="segment pending" aria-hidden="true" style="height:21.50%"></i>
      <span class="bar-total">4</span>
    </div>
    <div class="bar-label">Giao diện</div>
  </div>
</div>

<p class="source">[CHƯA XÁC MINH] Thủ công · 0 Pass · 0 Fail · 70 Chưa chạy</p>

---

# Lỗi tiêu biểu

<table class="plain compact">
<thead><tr><th>Mã</th><th>Mô tả</th><th>Mức độ</th><th>Phụ trách</th><th>Trạng thái</th></tr></thead>
<tbody>
<tr><td>BUG-02</td><td>Cập nhật màn hình QR sau khi đóng</td><td>High</td><td>[Tên thành viên]</td><td>Đã sửa trên nhánh</td></tr>
<tr><td>BUG-06</td><td>Bỏ ảnh mới có thể xóa ảnh cũ</td><td>Medium</td><td>[Tên thành viên]</td><td>Đã sửa trên nhánh</td></tr>
<tr><td>BUG-07</td><td>Thiếu cấu hình Firebase cho iOS</td><td>High</td><td>[Tên thành viên]</td><td>Open</td></tr>
</tbody>
</table>

<p class="source">[TỪ CODE] Vị trí trong bảng lỗi · [ĐÃ CHẠY] Retest các nhánh sửa</p>

---

# Demo BUG-06

<div class="demo">
<div>
<p><strong>Trước sửa</strong> Bỏ ảnh mới có thể xóa ảnh cũ. [ĐÃ CHẠY] 5 đạt, 1 lỗi.</p>
<p><strong>Nguyên nhân</strong> Dùng cờ xóa ảnh cũ khi bỏ ảnh vừa chọn.</p>
<p><strong>Cách sửa</strong> Tách việc bỏ ảnh mới và xóa ảnh cũ.</p>
<p><strong>Sau sửa</strong> [ĐÃ CHẠY] 6 bài đạt, ảnh cũ được giữ.</p>
</div>
<div class="evidence">[Chèn ảnh: BUG-06 trước sửa và sau retest]</div>
</div>

---

# Retest và regression

- [ĐÃ CHẠY] Ca tái hiện đạt lại trên từng nhánh sửa.
- [ĐÃ CHẠY] Hồi quy theo nhánh và 65 bài Flutter đạt khi chạy gộp.
- [CHƯA XÁC MINH] Camera, GPS và thư viện ảnh trên máy thật.

---

# Tổng hợp lỗi theo trạng thái

<table class="stats">
<thead><tr><th>Trạng thái</th><th>Critical</th><th>High</th><th>Medium</th><th>Low</th><th>Tổng</th></tr></thead>
<tbody>
<tr><td>Đã sửa trên nhánh</td><td>0</td><td>1</td><td>5</td><td>1</td><td>7</td></tr>
<tr><td>Open</td><td>0</td><td>1</td><td>0</td><td>0</td><td>1</td></tr>
<tr><td>Tổng</td><td>0</td><td>2</td><td>5</td><td>1</td><td>8</td></tr>
</tbody>
</table>

<p class="source">Đối chiếu trạng thái và mức độ trong báo cáo tổng hợp.</p>

---

# Hạn chế và bước tiếp theo

- [ĐÃ CHẠY] Smoke màn chào trên Edge ở bốn kích thước.
- [CHƯA XÁC MINH] Camera, GPS, giao diện và gián đoạn mạng.
- [CHƯA XÁC MINH] Firebase iOS sau khi có cấu hình.
- Ghi thiết bị và minh chứng theo từng mã test case.

---

<!-- _class: closing -->
<!-- _paginate: false -->

# Hỏi đáp

Kiểm thử Local Passport
