const { execFileSync } = require("node:child_process");
const { mkdtempSync, readFileSync, mkdirSync, copyFileSync } = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const assert = require("node:assert/strict");
const PptxGenJS = require("pptxgenjs");

const directory = __dirname;
const font = "Aptos";
const ink = "173038";
const muted = "526965";
const green = "0C6555";
const cream = "F5F4EB";
const white = "FFFFFF";
const pale = "E6EFE7";
const border = "C4D0C6";
const rust = "9A4436";
const slideWidth = 960;
const slideHeight = 540;
const left = 53;
const right = slideWidth - left;
const contentWidth = right - left;
const points = value => value / 72;

function readTable(name, prefix, columns) {
  const content = readFileSync(path.join(directory, name), "utf8");
  return content.split(/\r?\n/)
    .filter(line => line.startsWith("| " + prefix))
    .map(line => line.split(/(?<!\\)\|/).slice(1, -1).map(cell => cell.trim()))
    .filter(row => row.length === columns);
}

const testRows = readTable("02-bang-test-case.md", "TC-", 10);
const bugRows = readTable("03-bang-loi.md", "BUG-", 10);
const report = readFileSync(path.join(directory, "04-bao-cao-tong-hop.md"), "utf8");
const groupNames = {
  AUTH: "Tài khoản",
  MAP: "Khám phá và bản đồ",
  QR: "QR và GPS",
  REF: "Đóng dấu, cảm nhận, ảnh",
  COM: "Cộng đồng, xếp hạng",
  SYNC: "Đồng bộ và TimeLens",
  UI: "Đa kích thước màn hình",
  RULE: "Firestore Rules",
  AUTO: "Kiểm tra tự động",
};

const caseTypes = ["Nhập đúng", "Nhập sai", "Để trống", "Dữ liệu biên"];
const caseShort = ["Đúng", "Sai", "Trống", "Biên"];
const statusCounts = rows => [
  rows.length,
  ...["Pass", "Fail", "Chưa chạy"].map(status => rows.filter(row => row[7] === status).length),
];

const totals = statusCounts(testRows);
const fixed = bugRows.filter(row => row[7] === "Đã sửa trên nhánh").length;
const open = bugRows.filter(row => row[7] === "Open").length;
const manual = totals[3];
const baselineFlutter = report.match(/(?:\+\s*|\+\*\*)(\d+): All tests passed!/)?.[1];
const combinedFlutter = report.match(/combined-regression\.log[^\r\n]*?\+(\d+): All tests passed!/)?.[1];
const rulesCount = report.match(/pass (\d+).{0,50}fail 0/)?.[1];
assert(baselineFlutter && combinedFlutter && rulesCount, "Thiếu kết quả suite trong báo cáo.");
assert.equal(fixed + open, bugRows.length);
assert.equal(new Set(testRows.map(row => row[0])).size, totals[0]);
assert.equal(new Set(bugRows.map(row => row[0])).size, bugRows.length);
assert.equal(caseTypes.reduce((sum, type) => sum + testRows.filter(row => row[2] === type).length, 0) +
  testRows.filter(row => row[0].startsWith("TC-AUTO-")).length, totals[0]);

const pptx = new PptxGenJS();
pptx.defineLayout({ name: "QA_16_9", width: points(slideWidth), height: points(slideHeight) });
pptx.layout = "QA_16_9";
pptx.lang = "vi-VN";
pptx.title = "Kiểm thử và sửa lỗi Local Passport";
pptx.subject = "Báo cáo kiểm thử Local Passport";
pptx.theme = {
  headFontFace: font,
  bodyFontFace: font,
  lang: "vi-VN",
};

function position(x, y, w, h) {
  return { x: points(x), y: points(y), w: points(w), h: points(h) };
}

function text(slide, value, x, y, w, h, opts = {}) {
  slide.addText(value, {
    ...position(x, y, w, h),
    fontFace: font,
    fontSize: 22,
    color: ink,
    margin: 0,
    valign: "mid",
    breakLine: false,
    ...opts,
  });
}

function rect(slide, x, y, w, h, color, lineColor = color, lineWidth = 0) {
  slide.addShape(pptx.ShapeType.rect, {
    ...position(x, y, w, h),
    fill: { color },
    line: { color: lineColor, width: lineWidth },
  });
}

function rule(slide, x1, y1, x2, y2, color = border, width = 1, arrow = false) {
  slide.addShape(pptx.ShapeType.line, {
    ...position(x1, y1, x2 - x1, y2 - y1),
    line: { color, width, ...(arrow ? { endArrowType: "triangle" } : {}) },
  });
}

function section(title) {
  const slide = pptx.addSlide();
  slide.background = { color: cream };
  rect(slide, left, 36, 33, 4, green);
  text(slide, title, left, 54, contentWidth, 52, { fontSize: 36, bold: true });
  rule(slide, left, 113, right, 113);
  text(slide, String(pptx._slides.length).padStart(2, "0"), 883, 501, 24, 17,
    { fontSize: 12, color: muted, align: "right" });
  return slide;
}

function note(slide, content, y = 481) {
  text(slide, content, left, y, 802, 24, { fontSize: 13, color: muted });
}

function table(slide, headers, values, x, y, widths, rowHeight, size = 17, options = {}) {
  const center = new Set(options.center ?? []);
  const style = (row, columns) => row.map((value, index) => ({
    text: String(value),
    options: {
      color: columns ? white : ink,
      bold: columns || (options.boldFirst && index === 0),
      fill: { color: columns ? green : white },
      margin: options.padding ?? [4, 7, 4, 7],
      align: center.has(index) ? "center" : "left",
      valign: "ctr",
      ...(columns ? { fontSize: options.headerSize ?? size } : {}),
    },
  }));

  const rows = [style(headers, true), ...values.map((value, index) => {
    const row = style(value, false);
    if (index % 2 === 0) {
      for (const cell of row) cell.options.fill = { color: pale };
    }
    return row;
  })];

  slide.addTable(rows, {
    x: points(x),
    y: points(y),
    w: points(widths.reduce((a, b) => a + b, 0)),
    h: points(rowHeight * rows.length),
    colW: widths.map(points),
    rowH: points(rowHeight),
    fontFace: font,
    fontSize: size,
    color: ink,
    border: { type: "solid", pt: 0.8, color: border },
    autoPage: false,
    valign: "ctr",
  });
}

function bodyPair(slide, x, y, width, label, detail) {
  text(slide, label, x, y, width, 31, { fontSize: 23, color: green, bold: true });
  text(slide, detail, x, y + 37, width, 60, { fontSize: 19, valign: "top" });
}

function getCase(id) {
  const row = testRows.find(candidate => candidate[0] === id);
  assert(row, "Không tìm thấy " + id);
  return row;
}

function caseGroup(name, ids, input, expected) {
  const rows = ids.map(getCase);
  assert.deepEqual(rows.map(row => row[2]), caseTypes, name + " thiếu loại ca.");
  const status = [...new Set(rows.map(row => row[7]))];
  assert.equal(status.length, 1, name + " cần trình bày trạng thái từng ca.");
  return [
    ids.join("\n"),
    name,
    caseShort.join("\n"),
    input.join("\n"),
    expected.join("\n"),
    status[0] + "\n(cả nhóm)",
  ];
}

function caseSlide(title, groups) {
  const slide = section(title);
  table(slide, ["Mã TC", "Chức năng", "Loại case", "Dữ liệu vào", "Kết quả mong đợi", "Trạng thái"],
    groups, left, 141, [108, 115, 73, 215, 230, 113], groups.length === 3 ? 78 : 84, 14.2,
    { center: [2, 5], padding: [4, 6, 4, 6], headerSize: 15, boldFirst: true });
  note(slide, "Toàn bộ test case xem docs/testing/02-bang-test-case.md");
}

function sampleBugs(ids) {
  const description = {
    "BUG-01": "Báo sai lý do khi khóa QR sai",
    "BUG-02": "Gọi cập nhật sau khi đóng màn QR",
    "BUG-03": "Bấm Demo lặp, đóng route nhiều lần",
    "BUG-05": "Gửi đăng nhập hai lần khi còn chờ",
    "BUG-06": "Bỏ ảnh mới làm mất ảnh cũ",
    "BUG-07": "iOS thiếu cấu hình Firebase",
    "BUG-11": "Đồng bộ vẫn giữ URL ảnh đã xóa",
    "BUG-12": "Chú thích QR tràn ngang",
  };
  return ids.map(id => {
    const row = bugRows.find(candidate => candidate[0] === id);
    assert(row && description[id], "Thiếu bằng chứng cho " + id);
    return [id, description[id], row[5], row[7]];
  });
}

function addTypeChart(slide, x, y, w, h) {
  const values = caseTypes.map(type => testRows.filter(row => row[2] === type).length);
  slide.addChart(pptx.ChartType.bar, [{ name: "Số ca", labels: caseShort, values }], {
    ...position(x, y, w, h),
    barDir: "col",
    barGrouping: "clustered",
    chartColors: [green],
    showTitle: false,
    showLegend: false,
    showValue: true,
    dataLabelPosition: "outEnd",
    dataLabelFormatCode: "0",
    dataLabelFormatColor: ink,
    dataLabelFontFace: font,
    dataLabelFontSize: 15,
    catAxisLabelFontFace: font,
    catAxisLabelFontSize: 15,
    catAxisLabelColor: ink,
    catAxisLineColor: border,
    catAxisMajorTickMark: "none",
    valAxisMinVal: 0,
    valAxisMaxVal: Math.ceil((Math.max(...values) + 4) / 5) * 5,
    valAxisLabelFontFace: font,
    valAxisLabelFontSize: 10,
    valAxisLabelColor: muted,
    valAxisMajorTickMark: "none",
    valGridLine: { color: border, width: 0.5 },
    showCatName: false,
    showCatNameInLegend: false,
    chartArea: { fill: { color: cream }, border: { color: cream, pt: 0 } },
    plotArea: { fill: { color: cream }, border: { color: cream, pt: 0 } },
  });
}

// 1. Tiêu đề
{
  const slide = pptx.addSlide();
  slide.background = { color: ink };
  rect(slide, 55, 108, 5, 145, "A9CABC");
  text(slide, "Kiểm thử và sửa lỗi\nLocal Passport", 78, 102, 805, 162,
    { fontSize: 57, bold: true, color: white });
  text(slide, "Hộ chiếu du lịch số Đà Nẵng", 81, 273, 800, 42,
    { fontSize: 27, color: "AECEBF" });
  rule(slide, 81, 371, 879, 371, "729487", 0.8);
  text(slide, "Nhóm [ĐIỀN]    •    Thành viên [ĐIỀN]    •    Giảng viên [ĐIỀN]",
    81, 387, 800, 55, { fontSize: 21, color: white });
}

// 2. Giới thiệu
{
  const slide = section("Giới thiệu và phạm vi");
  text(slide, "Hộ chiếu du lịch số", left, 150, 349, 49,
    { fontSize: 34, color: green, bold: true });
  text(slide, "Khám phá Đà Nẵng qua bản đồ, check-in QR/GPS, nhận dấu và chia sẻ cảm nhận.",
    left, 207, 342, 100, { fontSize: 24, valign: "top" });
  table(slide, ["Thành phần", "Phạm vi kiểm thử"], [
    ["Ứng dụng", "Flutter trên Web, Android và iOS"],
    ["Bản đồ", "OpenStreetMap mặc định"],
    ["Dữ liệu", "Firebase Auth, Firestore, đồng bộ và Rules"],
    ["Trải nghiệm", "Cộng đồng, TimeLens, kích thước màn hình"],
  ], 429, 156, [130, 348], 53, 18, { boldFirst: true });
}

// 3. Sơ đồ quy trình
{
  const slide = section("Quy trình kiểm thử và sửa lỗi");
  const steps = [
    "Lập kế hoạch\nkiểm thử",
    "Viết\ntest case",
    "Thực hiện\nkiểm thử",
    "Ghi nhận\nlỗi",
    "Sửa lỗi và\nkiểm thử lại",
  ];
  steps.forEach((step, index) => {
    const x = left + index * 176;
    rect(slide, x, 209, 150, 115, index === 4 ? green : pale, border, 0.8);
    text(slide, step, x + 8, 221, 134, 90,
      { fontSize: 19, bold: true, color: index === 4 ? white : ink, align: "center" });
    if (index < steps.length - 1) rule(slide, x + 152, 266, x + 173, 266, green, 1.6, true);
  });
  text(slide, "Dùng mã ca để đối chiếu kết quả, lỗi và bằng chứng kiểm thử lại.",
    left, 373, contentWidth, 48, { fontSize: 22, color: muted, align: "center" });
}

// 4. Lập kế hoạch
{
  const slide = section("Bước 1 - Lập kế hoạch kiểm thử");
  table(slide, ["Nội dung", "Điểm kiểm tra"], [
    ["Luồng cốt lõi", "Tài khoản, bản đồ, QR/GPS, dấu và cảm nhận có ảnh"],
    ["Dữ liệu và hiển thị", "Cộng đồng, đồng bộ, TimeLens, Rules và đa màn hình"],
    ["Điều kiện bắt đầu", "Xác định commit, dựng môi trường và chuẩn bị dữ liệu thử"],
    ["Điều kiện kết thúc", "Có kết quả đối chiếu từng ca và retest cho lỗi đã sửa"],
  ], left, 150, [238, 616], 60, 21, { boldFirst: true });
}

// 5. Thiết kế ca
{
  const slide = section("Bước 2 - Viết test case");
  table(slide, ["Loại case", "Ý nghĩa", "Ví dụ trong bảng test case"], [
    ["Nhập đúng", "Dữ liệu đủ và hợp lệ", "TC-AUTH-01   Email và mật khẩu hợp lệ"],
    ["Nhập sai", "Dữ liệu sai khóa hoặc định dạng", "TC-QR-02   Đúng địa điểm, sai khóa QR"],
    ["Để trống", "Thiếu trường hoặc trạng thái rỗng", "TC-RULE-03   Thiếu passportNo"],
    ["Dữ liệu biên", "Kiểm tra sát ngưỡng giới hạn", "TC-REF-08   Cảm nhận 20 hoặc 600 ký tự"],
  ], left, 149, [142, 280, 432], 60, 19, { boldFirst: true });
}

// 6. Tổng quan
{
  const slide = section("Tổng quan bộ test case");
  const counts = Object.entries(groupNames).map(([key, label]) => [
    label,
    ...statusCounts(testRows.filter(row => row[0].startsWith("TC-" + key + "-"))),
  ]);
  const headings = ["Phân hệ", "Tổng", "Pass", "Fail", "Chưa chạy"];
  const sizes = [190, 43, 45, 43, 94];
  table(slide, headings, counts.slice(0, 5), left, 130, sizes, 28, 14,
    { center: [1, 2, 3, 4], padding: [3, 5, 3, 5] });
  table(slide, headings, [...counts.slice(5), ["Tổng toàn bộ", ...totals]],
    492, 130, sizes, 28, 14, { center: [1, 2, 3, 4], padding: [3, 5, 3, 5] });
  text(slide, "Phân bố bốn loại ca dữ liệu", left, 308, 319, 40,
    { fontSize: 23, color: green, bold: true });
  text(slide, "5 dòng kiểm tra lệnh được thống kê riêng.", left, 354, 299, 81,
    { fontSize: 18, color: muted, valign: "top" });
  addTypeChart(slide, 370, 311, 525, 171);
}

// 7–9. Test case tiêu biểu
caseSlide("Test case tài khoản, bản đồ và QR", [
  caseGroup("Tài khoản", ["TC-AUTH-01", "TC-AUTH-02", "TC-AUTH-03", "TC-AUTH-04"],
    ["Email và mật khẩu hợp lệ", "Email sai định dạng", "Thiếu trường bắt buộc", "Mật khẩu 5, 6, 64, 65 ký tự"],
    ["Mở đúng hộ chiếu", "Báo lỗi nhập liệu", "Báo đúng trường còn trống", "Nhận biên đúng, chặn ngoài biên"]),
  caseGroup("Bản đồ", ["TC-MAP-01", "TC-MAP-02", "TC-MAP-03", "TC-MAP-04"],
    ["Bản mặc định, chọn marker", "SDK Maps JS bị chặn", "Chưa chọn tuyến hoặc điểm", "Đổi tuyến, kéo gần biên"],
    ["Mở đúng điểm trên OSM", "Quay về bản đồ OSM", "Hiện OSM và bộ lọc Tất cả", "Bỏ chọn cũ, tâm ở đúng khung"]),
  caseGroup("QR và GPS", ["TC-QR-01", "TC-QR-02", "TC-QR-03", "TC-QR-04"],
    ["QR đúng, GPS trong bán kính", "ID đúng, sai khóa k", "Thiếu k hoặc chưa có mã", "Đóng màn khi camera dừng"],
    ["Mở khóa địa điểm", "Báo mã không hợp lệ", "Chờ hoặc cho quét lại", "Mở lại và dùng được camera"]),
]);

caseSlide("Test case đóng dấu, cộng đồng và đồng bộ", [
  caseGroup("Dấu, cảm nhận và ảnh", ["TC-REF-01", "TC-REF-06", "TC-REF-07", "TC-REF-08"],
    ["Đã hoàn tất nhiệm vụ", "Cảm nhận 19 hoặc 601 ký tự", "Nội dung rỗng, ảnh tùy chọn", "Cảm nhận 20 hoặc 600 ký tự"],
    ["Nhận đúng một dấu mới", "Chặn nội dung ngoài biên", "Báo nhập thêm, giữ bài cũ", "Qua kiểm tra độ dài"]),
  caseGroup("Cộng đồng", ["TC-COM-01", "TC-COM-02", "TC-COM-03", "TC-COM-04"],
    ["Có bài ở tài khoản thử", "Bài thuộc tài khoản khác", "Không có bài theo bộ lọc", "19, 20, 21 bài thử"],
    ["Bài đúng xuất hiện", "Giới hạn sửa và xóa theo chủ", "Hiện trạng thái trống", "Nạp thêm đúng trang"]),
  caseGroup("Đồng bộ", ["TC-SYNC-01", "TC-SYNC-02", "TC-SYNC-03", "TC-SYNC-04"],
    ["Cùng tài khoản ở hai phiên", "Mất mạng trong lúc lưu", "Mở app khi offline", "Slow 3G rồi kết nối lại"],
    ["Hai phiên thấy dữ liệu đã lưu", "Thử lại sau khi có mạng", "Đọc được dữ liệu đã lưu", "Thử lại không tạo bản trùng"]),
]);

caseSlide("Test case giao diện và Firestore Rules", [
  caseGroup("Giao diện", ["TC-UI-01", "TC-UI-02", "TC-UI-03", "TC-UI-04"],
    ["390×844, màn hình dọc", "Xoay khi mở bàn phím", "Form rỗng ở 360×640", "Cỡ chữ 130% và xoay"],
    ["Đọc và dùng được nút chính", "Cuộn tới được trường và nút", "Hiện gợi ý và chú thích QR", "Nội dung vừa khung và cuộn được"]),
  caseGroup("Firestore Rules", ["TC-RULE-01", "TC-RULE-02", "TC-RULE-03", "TC-RULE-04"],
    ["Chủ hộ chiếu, schema đúng", "UID khác chủ hộ chiếu", "Thiếu passportNo", "taskPhotos có 3 hoặc 4 mục"],
    ["Cho phép ghi", "Từ chối đọc và ghi", "Từ chối ghi", "Nhận 3 mục, từ chối 4 mục"]),
]);

// 10. Thực hiện
{
  const slide = section("Bước 3 - Thực hiện kiểm thử");
  table(slide, ["Kiểm tra tự động", "Kết quả"], [
    ["Dart format", "Pass, không đổi tệp"],
    ["Flutter analyze", "Pass, không có lỗi"],
    ["Flutter test", "Pass, " + baselineFlutter + " bài"],
    ["Firestore Rules", "Pass, " + rulesCount + " bài"],
    ["Build web release", "Pass, đã tạo build"],
  ], left, 143, [194, 220], 42, 17, { boldFirst: true });
  table(slide, ["Môi trường thủ công", "Trạng thái"], [
    ["Máy ảo Android và iOS", "Chưa chạy"],
    ["Điện thoại thật, camera và GPS", "Chưa chạy"],
    ["360×640, 390×844, 768×1024, 1440×900", "Chưa chạy"],
    ["Offline, Slow 3G, rớt mạng", "Chưa chạy"],
  ], 491, 143, [288, 128], 49, 16, { boldFirst: true });
  note(slide, "Quan sát màn chào trên Edge ở cả 4 viewport. Luồng thủ công đầy đủ còn chờ.", 420);
}

// 11. Ghi nhận
{
  const slide = section("Bước 4 - Ghi nhận lỗi");
  table(slide, ["Trường", "Nội dung cần ghi"], [
    ["Mô tả", "Triệu chứng quan sát được và hành vi mong đợi"],
    ["Cách tái hiện", "Mã TC, điều kiện, bước thực hiện và minh chứng"],
    ["Mức độ nghiêm trọng", "Ảnh hưởng tới luồng chính hoặc dữ liệu"],
    ["Người phụ trách", "[Tên thành viên]"],
  ], left, 139, [195, 279], 49, 16, { boldFirst: true, padding: [4, 7, 4, 7] });
  table(slide, ["Mức độ", "Cách phân loại"], [
    ["Critical", "Luồng chính hoặc dữ liệu bị ảnh hưởng trên diện rộng"],
    ["High", "Chặn chức năng chính, văng màn hoặc có nguy cơ mất dữ liệu"],
    ["Medium", "Một luồng con xử lý hoặc phản hồi sai"],
    ["Low", "Phạm vi hẹp, ảnh hưởng thao tác phụ"],
  ], 550, 139, [93, 264], 49, 15.6, { boldFirst: true });
}

// 12. Lỗi tiêu biểu
{
  const slide = section("Lỗi tiêu biểu");
  table(slide, ["Mã", "Mô tả", "Mức độ", "Trạng thái"],
    sampleBugs(["BUG-02", "BUG-06", "BUG-07", "BUG-12"]),
    left, 147, [103, 466, 100, 185], 60, 20,
    { boldFirst: true, center: [2] });
}

// 13. Danh sách đầy đủ
{
  const slide = section("Danh sách lỗi đã phát hiện");
  const allIds = bugRows.map(row => row[0]);
  const sizes = [69, 167, 65, 114];
  const headings = ["Mã", "Mô tả", "Mức độ", "Trạng thái"];
  table(slide, headings, sampleBugs(allIds.slice(0, 4)), left, 133, sizes, 46, 14,
    { headerSize: 14.4, boldFirst: true, padding: [3, 5, 3, 5] });
  table(slide, headings, sampleBugs(allIds.slice(4)), 492, 133, sizes, 46, 14,
    { headerSize: 14.4, boldFirst: true, padding: [3, 5, 3, 5] });
  const severity = ["Critical", "High", "Medium", "Low"];
  const severityCounts = status => severity.map(level =>
    bugRows.filter(row => row[5] === level && (!status || row[7] === status)).length);
  table(slide, ["Trạng thái", ...severity, "Tổng"], [
    ["Đã sửa trên nhánh", ...severityCounts("Đã sửa trên nhánh"), fixed],
    ["Open", ...severityCounts("Open"), open],
    ["Tổng", ...severityCounts(), bugRows.length],
  ], left, 379, [276, 120, 120, 120, 120, 98], 24, 14,
  { center: [1, 2, 3, 4, 5], padding: [2, 5, 2, 5], boldFirst: true });
  note(slide, "Chi tiết xem docs/testing/03-bang-loi.md", 480);
}

// 14. Demo lỗi
{
  const slide = section("Demo BUG-06 - Giữ ảnh cũ");
  table(slide, ["Trước khi sửa", "Nguyên nhân", "Cách sửa", "Sau khi sửa"], [[
    "Bỏ ảnh mới làm mất Base64 cũ. Tệp test có 5 Pass, 1 Fail.",
    "Nút bỏ ảnh mới bật cả cờ xóa ảnh cũ.",
    "Bỏ ảnh mới chỉ xóa ảnh vừa chọn.",
    "Widget test giữ lại ảnh cũ. Cùng tệp có 6 Pass.",
  ]], left, 144, [213.5, 213.5, 213.5, 213.5], 85, 17);
  rect(slide, left, 336, contentWidth, 112, cream, border, 1.3);
  text(slide, "[Chèn ảnh: BUG-06 trước sửa và sau retest]", left + 15, 359, contentWidth - 30, 66,
    { fontSize: 19, color: muted, align: "center" });
}

// 15. Retest và hồi quy
{
  const slide = section("Bước 5 - Sửa lỗi và kiểm thử lại");
  text(slide, baselineFlutter, left, 152, 225, 104, { fontSize: 86, bold: true, color: green });
  text(slide, combinedFlutter, 502, 152, 225, 104, { fontSize: 86, bold: true, color: green });
  rule(slide, 343, 210, 434, 210, green, 2.2, true);
  text(slide, "Flutter test đạt trên bản gốc", left, 261, 349, 49, { fontSize: 23 });
  text(slide, "Flutter test đạt khi gộp bản vá cục bộ", 502, 261, 395, 49, { fontSize: 23 });
  rule(slide, left, 346, right, 346);
  text(slide, fixed + " nhánh sửa có retest, hồi quy, Rules và build web đạt.",
    left, 364, contentWidth, 35, { fontSize: 20, bold: true });
  text(slide, "Luồng đầu-cuối trên thiết bị và kịch bản mạng còn chờ.", left, 412, contentWidth, 37,
    { fontSize: 19, color: muted });
}

// 16. Kết quả cuối
{
  const slide = section("Kết quả cuối");
  table(slide, ["Đầu ra", "Kết quả"], [
    ["Bảng test case", totals[0] + " dòng (" + totals[1] + " Pass, " + totals[2] + " Fail, " + manual + " Chưa chạy)"],
    ["Danh sách lỗi", bugRows.length + " lỗi có bằng chứng từ code hoặc kiểm thử"],
    ["Tình trạng xử lý", fixed + " đã sửa trên nhánh, " + open + " Open"],
  ], left, 162, [280, 574], 76, 23, { boldFirst: true });
}

// 17. Hạn chế và hướng đi
{
  const slide = section("Hạn chế và hướng phát triển");
  bodyPair(slide, left, 152, 365, "Hạn chế",
    "Thiết bị thật, camera/GPS, luồng offline và mạng chậm còn chờ kiểm thử.");
  bodyPair(slide, left, 303, 365, "Việc cần xác nhận",
    "Cấu hình Firebase iOS và chạy lại ca đồng bộ trên thiết bị.");
  rule(slide, 457, 156, 457, 444);
  bodyPair(slide, 495, 152, 407, "Bài học",
    "Dùng mã TC và log để sửa đúng hành vi. Tách kết quả của test tự động và quan sát thực tế.");
  bodyPair(slide, 495, 303, 407, "Hướng phát triển",
    "Hoàn tất kiểm thử đầu-cuối, chụp minh chứng và bổ sung ca tự động cho lỗi tái diễn.");
}

// 18. Hỏi đáp
{
  const slide = pptx.addSlide();
  slide.background = { color: ink };
  rect(slide, 435, 163, 90, 5, "A9CABC");
  text(slide, "Hỏi đáp", left, 190, contentWidth, 115,
    { fontSize: 76, bold: true, color: white, align: "center" });
  text(slide, "Local Passport", left, 328, contentWidth, 39,
    { fontSize: 27, color: "A9CABC", align: "center" });
}

function exportPowerPoint(ppt, pdf, qaDir) {
  const psString = value => "'" + value.replaceAll("'", "''") + "'";
  const script = [
    "$ErrorActionPreference = 'Stop'",
    "$existing = @(Get-Process POWERPNT -ErrorAction SilentlyContinue)",
    "$app = New-Object -ComObject PowerPoint.Application",
    "try {",
    "  $deck = $app.Presentations.Open(" + psString(ppt) + ", -1, 0, 0)",
    "  try {",
    "    $deck.SaveAs(" + psString(pdf) + ", 32)",
    ...(qaDir ? ["    $deck.Export(" + psString(qaDir) + ", 'PNG', 1280, 720)"] : []),
    "  } finally { $deck.Close() }",
    "} finally {",
    "  if (!$existing.Count) { $app.Quit() }",
    "  [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($app)",
    "}",
  ].join("\n");
  const command = Buffer.from(script, "utf16le").toString("base64");
  execFileSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-EncodedCommand", command],
    { stdio: "inherit", windowsHide: true });
}

async function main() {
  assert.equal(pptx._slides.length, 18);
  const staging = mkdtempSync(path.join(os.tmpdir(), "local-passport-slide-"));
  const qaDir = process.env.LOCAL_PASSPORT_SLIDE_QA_DIR;
  if (qaDir) mkdirSync(qaDir, { recursive: true });
  const ppt = path.join(staging, "slide.pptx");
  const pdf = path.join(staging, "slide.pdf");
  await pptx.writeFile({ fileName: ppt });
  exportPowerPoint(ppt, pdf, qaDir);
  copyFileSync(ppt, path.join(directory, "slide.pptx"));
  copyFileSync(pdf, path.join(directory, "slide.pdf"));
  console.log("Đã tạo slide.pptx và xuất trực tiếp slide.pdf bằng PowerPoint.");
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
