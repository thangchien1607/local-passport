const { execFileSync } = require("node:child_process");
const { mkdtempSync, readFileSync, mkdirSync, copyFileSync, existsSync } = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const assert = require("node:assert/strict");
const PptxGenJS = require("pptxgenjs");

const directory = __dirname;
const evidence = path.join(directory, "evidence");
const font = "Aptos";
const ink = "173038";
const muted = "526965";
const green = "0C6555";
const cream = "F5F4EB";
const white = "FFFFFF";
const pale = "E6EFE7";
const border = "C4D0C6";
const rust = "9A4436";
const amber = "8A6212";
const slideWidth = 960;
const slideHeight = 540;
const left = 53;
const right = slideWidth - left;
const contentWidth = right - left;
const points = value => value / 72;

// ---------- Đọc số liệu từ các bảng Markdown ----------

function readTable(name, prefix, columns) {
  const content = readFileSync(path.join(directory, name), "utf8");
  return content.split(/\r?\n/)
    .filter(line => line.startsWith("| " + prefix))
    .map(line => line.split(/(?<!\\)\|/).slice(1, -1).map(cell => cell.trim()))
    .filter(row => row.length === columns);
}

const testRows = readTable("02-bang-test-case.md", "TC-", 11);
const bugRows = readTable("03-bang-loi.md", "BUG-", 10);
const report = readFileSync(path.join(directory, "04-bao-cao-tong-hop.md"), "utf8");

const groupNames = {
  AUTH: "Xác thực và tài khoản",
  MAP: "Khám phá và bản đồ",
  QR: "QR và GPS check-in",
  REF: "Đóng dấu, cảm nhận, ảnh",
  COM: "Cộng đồng, xếp hạng, thông báo",
  SYNC: "Đồng bộ, offline, TimeLens",
  UI: "Đa kích thước màn hình",
  RULE: "Firestore Rules",
  AUTO: "Kiểm tra tự động",
};
const owners = {
  AUTH: "Chiến Thắng", MAP: "Ngọc Anh", QR: "Chiến Thắng", REF: "Ngọc Anh",
  COM: "Minh Khoa", SYNC: "Minh Khoa", UI: "Minh Khoa", RULE: "Chiến Thắng", AUTO: "Cả nhóm",
};

const caseTypes = ["Nhập đúng", "Nhập sai", "Để trống", "Dữ liệu biên"];
const shortType = { "Nhập đúng": "Đúng", "Nhập sai": "Sai", "Để trống": "Trống", "Dữ liệu biên": "Biên" };
const statusCounts = rows => [
  rows.length,
  ...["Pass", "Fail", "Chưa chạy"].map(status => rows.filter(row => row[7] === status).length),
];

const ST_MERGED = "Đã sửa, đã gộp develop";
const ST_BRANCH = "Đã sửa trên nhánh";
const ST_OPEN = "Open";
const totals = statusCounts(testRows);
const merged = bugRows.filter(row => row[7] === ST_MERGED).length;
const onBranch = bugRows.filter(row => row[7] === ST_BRANCH).length;
const open = bugRows.filter(row => row[7] === ST_OPEN).length;
const realRows = testRows.filter(row => row[8].includes("Điện thoại thật"));
const avdRows = testRows.filter(row => row[8].includes("Android Emulator") && row[7] !== "Chưa chạy");
const baselineFlutter = report.match(/(?:\+\s*|\+\*\*)(\d+): All tests passed!/)?.[1];
const combinedFlutter = report.match(/combined-regression\.log[^\r\n]*?\+(\d+): All tests passed!/)?.[1];
const developFlutter = report.match(/develop` `478505e`: \*\*`\+(\d+): All tests passed!/)?.[1];
const rulesCount = report.match(/pass (\d+).{0,50}fail 0/)?.[1];

assert(baselineFlutter && combinedFlutter && developFlutter && rulesCount, "Thiếu kết quả suite trong báo cáo.");
assert.equal(totals[0], 79);
assert.equal(merged + onBranch + open, bugRows.length, "Có lỗi mang trạng thái lạ.");
assert.equal(new Set(testRows.map(row => row[0])).size, totals[0]);
assert.equal(new Set(bugRows.map(row => row[0])).size, bugRows.length);
assert.equal(caseTypes.reduce((sum, type) => sum + testRows.filter(row => row[2] === type).length, 0) +
  testRows.filter(row => row[0].startsWith("TC-AUTO-")).length, totals[0]);

// ---------- Hàm vẽ ----------

const pptx = new PptxGenJS();
pptx.defineLayout({ name: "QA_16_9", width: points(slideWidth), height: points(slideHeight) });
pptx.layout = "QA_16_9";
pptx.lang = "vi-VN";
pptx.title = "Kiểm thử và sửa lỗi Local Passport";
pptx.subject = "Báo cáo kiểm thử Local Passport";
pptx.theme = { headFontFace: font, bodyFontFace: font, lang: "vi-VN" };

function position(x, y, w, h) {
  return { x: points(x), y: points(y), w: points(w), h: points(h) };
}

function text(slide, value, x, y, w, h, opts = {}) {
  slide.addText(value, {
    ...position(x, y, w, h),
    fontFace: font, fontSize: 22, color: ink, margin: 0, valign: "mid", breakLine: false,
    ...opts,
  });
}

function rect(slide, x, y, w, h, color, lineColor = color, lineWidth = 0) {
  slide.addShape(pptx.ShapeType.rect, {
    ...position(x, y, w, h), fill: { color }, line: { color: lineColor, width: lineWidth },
  });
}

function rule(slide, x1, y1, x2, y2, color = border, width = 1, arrow = false) {
  slide.addShape(pptx.ShapeType.line, {
    ...position(x1, y1, x2 - x1, y2 - y1),
    line: { color, width, ...(arrow ? { endArrowType: "triangle" } : {}) },
  });
}

function section(title, kicker) {
  const slide = pptx.addSlide();
  slide.background = { color: cream };
  rect(slide, left, 36, 33, 4, green);
  if (kicker) text(slide, kicker, left + 45, 30, 600, 16, { fontSize: 12, color: green, bold: true });
  text(slide, title, left, 50, contentWidth, 52, { fontSize: 32, bold: true });
  rule(slide, left, 107, right, 107);
  text(slide, String(pptx._slides.length).padStart(2, "0"), 883, 506, 24, 17,
    { fontSize: 12, color: muted, align: "right" });
  return slide;
}

function note(slide, content, y = 484) {
  text(slide, content, left, y, 820, 24, { fontSize: 12, color: muted });
}

const statusColor = value => {
  if (/một phần|Bổ sung|^Chưa sửa/i.test(value)) return amber;
  if (/^Fail|Đỏ|Open|chưa gộp|chờ gộp/i.test(value)) return rust;
  if (/^Chưa chạy|^Chờ|thiếu/i.test(value)) return amber;
  if (/^Pass|Đạt|Xanh|đã gộp|^Đã sửa/i.test(value)) return green;
  return ink;
};

// Một ô có thể là chuỗi, hoặc mảng dòng {text, color, bold}.
function cellText(value) {
  if (Array.isArray(value)) {
    return value.map((line, index) => ({
      text: line.text,
      options: { color: line.color ?? ink, bold: line.bold ?? false, breakLine: index < value.length - 1 },
    }));
  }
  return String(value);
}

function table(slide, headers, values, x, y, widths, rowHeight, size = 17, options = {}) {
  const center = new Set(options.center ?? []);
  const colored = new Set(options.colorStatus ?? []);
  const style = (row, header) => row.map((value, index) => ({
    text: header ? String(value) : cellText(value),
    options: {
      color: header ? white : (colored.has(index) && !Array.isArray(value) ? statusColor(String(value)) : ink),
      bold: header || (options.boldFirst && index === 0) || (colored.has(index) && !Array.isArray(value)),
      fill: { color: header ? green : white },
      margin: options.padding ?? [4, 7, 4, 7],
      align: center.has(index) ? "center" : "left",
      valign: "ctr",
      ...(header ? { fontSize: options.headerSize ?? size } : {}),
    },
  }));

  const rows = [style(headers, true), ...values.map((value, index) => {
    const row = style(value, false);
    if (index % 2 === 0) for (const cell of row) cell.options.fill = { color: pale };
    if (options.highlightLast && index === values.length - 1) {
      for (const cell of row) { cell.options.bold = true; cell.options.fill = { color: "D6E6DA" }; }
    }
    return row;
  })];

  const heights = Array.isArray(rowHeight)
    ? [options.headerHeight ?? 28, ...rowHeight]
    : rows.map((_, index) => index === 0 ? (options.headerHeight ?? rowHeight) : rowHeight);
  slide.addTable(rows, {
    x: points(x), y: points(y),
    w: points(widths.reduce((a, b) => a + b, 0)),
    h: points(heights.reduce((a, b) => a + b, 0)),
    colW: widths.map(points),
    rowH: heights.map(points),
    fontFace: font, fontSize: size, color: ink,
    border: { type: "solid", pt: 0.8, color: border },
    autoPage: false, valign: "ctr",
  });
}

function bodyPair(slide, x, y, width, label, detail, height = 80) {
  text(slide, label, x, y, width, 28, { fontSize: 21, color: green, bold: true });
  text(slide, detail, x, y + 32, width, height, { fontSize: 16, valign: "top" });
}

function pngSize(file) {
  const data = readFileSync(file);
  assert.equal(data.toString("ascii", 12, 16), "IHDR", "Không phải PNG: " + file);
  return { w: data.readUInt32BE(16), h: data.readUInt32BE(20) };
}

// Đặt ảnh vừa khung (giữ tỉ lệ, căn giữa) và vẽ viền.
function picture(slide, name, x, y, w, h, caption, color = border) {
  const file = path.join(evidence, name);
  assert(existsSync(file), "Thiếu ảnh minh chứng " + name);
  const size = pngSize(file);
  const scale = Math.min(w / size.w, h / size.h);
  const pw = size.w * scale;
  const ph = size.h * scale;
  rect(slide, x - 3, y - 3, w + 6, h + 6, white, color, 0.8);
  slide.addImage({ path: file, ...position(x + (w - pw) / 2, y + (h - ph) / 2, pw, ph) });
  if (caption) text(slide, caption, x - 3, y + h + 6, w + 6, 30, { fontSize: 11, color: muted, align: "center", valign: "top" });
}

function getCase(id) {
  const row = testRows.find(candidate => candidate[0] === id);
  assert(row, "Không tìm thấy " + id);
  return row;
}

function environment(row) {
  const env = row[8];
  if (env.includes("Điện thoại thật")) return "Máy thật";
  if (env.startsWith("RULES") || env.includes("Firestore Emulator")) return "Emulator";
  if (env.startsWith("CLI")) return "CLI";
  const web = env.includes("Web");
  const avd = env.includes("Android Emulator") && !/·.*Android Emulator/.test(env);
  if (web && avd) return "Web + AVD";
  if (avd) return "AVD";
  if (web) return "Web";
  return "—";
}

// Một nhóm chức năng = một dòng bảng, mỗi ca là một dòng chữ trong ô.
function caseGroup(name, ids, input, expected) {
  const rows = ids.map(getCase);
  assert.deepEqual(rows.slice(0, 4).map(row => row[2]), caseTypes, name + " thiếu loại ca.");
  assert.equal(input.length, ids.length, name + " thiếu dữ liệu vào.");
  assert.equal(expected.length, ids.length, name + " thiếu kết quả mong đợi.");
  const lines = values => values.map(value => ({ text: value }));
  return {
    size: ids.length,
    row: [
      rows.map(row => ({ text: row[0], bold: true })),
      name,
      lines(rows.map(row => shortType[row[2]])),
      lines(input),
      lines(expected),
      lines(rows.map(environment)),
      rows.map(row => ({ text: row[7], color: statusColor(row[7]), bold: true })),
    ],
  };
}

let caseSlideIndex = 0;
function caseSlide(title, groups) {
  caseSlideIndex += 1;
  const slide = section(title, "BƯỚC 2 · BẢNG TEST CASE " + caseSlideIndex + "/6");
  table(slide,
    ["Mã TC", "Chức năng", "Loại", "Dữ liệu vào", "Kết quả mong đợi", "Môi trường", "Trạng thái"],
    groups.map(group => group.row), left, 118,
    [92, 104, 50, 216, 216, 86, 90],
    groups.map(group => group.size === 5 ? 112 : 94), 13,
    { center: [2, 5, 6], padding: [3, 5, 3, 5], headerSize: 13.5, headerHeight: 26 });
  note(slide, "Trạng thái trên bản gốc 065103c · Web = Chrome 158 · AVD = Android 15 Emulator LP_390x844_API35 · Máy thật = điện thoại thật · Chi tiết, kết quả thực tế và minh chứng: docs/testing/02-bang-test-case.md");
}

const bugInfo = {
  "BUG-01": ["QR đúng điểm nhưng sai khóa k lại báo nhầm sang điểm khác",
    "Quét QR sai khóa (hoặc mở /?checkin=dien-hai&k=SAI) rồi đọc thông báo"],
  "BUG-02": ["Màn quét QR gọi setState sau khi đã đóng",
    "Quét mã hợp lệ, bấm Quay lại đúng lúc camera đang dừng, xem log"],
  "BUG-03": ["Bấm Demo liên tiếp xử lý và đóng màn quét 2 lần",
    "Mở màn quét, bấm nút Demo 2 lần thật nhanh"],
  "BUG-05": ["Nhấn Enter 2 lần gửi 2 yêu cầu đăng nhập",
    "Bật Slow 3G, nhập email/mật khẩu đúng, nhấn Enter 2 lần liên tiếp"],
  "BUG-06": ["Bấm “Bỏ ảnh mới” làm mất luôn ảnh cũ của bài",
    "Mở bài có ảnh → chọn ảnh mới → Bỏ ảnh mới → Lưu & chấm lại → mở lại"],
  "BUG-07": ["Bản iOS thiếu cấu hình Firebase, chỉ chạy cục bộ",
    "Chạy bản iOS trên Xcode/iPhone → không đăng nhập, không đồng bộ"],
  "BUG-11": ["Xóa ảnh kiểu photoUrl cũ nhưng máy chủ vẫn giữ URL",
    "Bài có photoUrl cũ → xóa ảnh, lưu, đồng bộ → phiên khác vẫn thấy ảnh"],
  "BUG-12": ["Chú thích bán kính ở màn QR tràn ngang khung hẹp",
    "Mở màn quét QR ở khung 430×900 → báo tràn 128 px bên phải"],
  "BUG-13": ["Tìm “Cầu Rồng” ra 7 điểm, 4 điểm không liên quan đứng trước",
    "Khám phá → gõ “Cầu Rồng” vào ô tìm kiếm (Web hoặc APK)"],
  "BUG-14": ["Đồng bộ mọi bài cảm nhận mới bị HTTP 403, phiên khác thấy 0 bài",
    "Tài khoản A đăng cảm nhận → báo “Chưa lưu được lên máy chủ” → mở phiên B"],
  "BUG-15": ["JPEG hỏng: khung xem trước trắng, lỗi bị che sau hộp thoại",
    "Đóng dấu xong → Viết cảm nhận → chọn tệp JPEG hỏng → Gửi"],
  "BUG-16": ["Đóng hộp thoại Đổi tên làm văng màn hình đỏ trên Android",
    "APK Android 15: Hộ chiếu → Đổi tên → Lưu (kể cả offline)"],
};

const shortStatus = status => ({
  [ST_MERGED]: "Đã sửa · đã gộp develop",
  [ST_BRANCH]: "Đã sửa trên nhánh · chờ gộp PR",
  [ST_OPEN]: "Open · cần cấu hình iOS",
})[status];

function bugTableRows(ids) {
  return ids.map(id => {
    const row = bugRows.find(candidate => candidate[0] === id);
    assert(row && bugInfo[id], "Thiếu thông tin cho " + id);
    const tcs = row[1].split(",").map(value => value.trim().replace("TC-", ""));
    return [
      id,
      tcs.slice(0, 2).join("\n") + (tcs.length > 2 ? "\n+" + (tcs.length - 2) + " ca" : ""),
      bugInfo[id][0],
      bugInfo[id][1],
      row[5],
      row[6],
      [{ text: shortStatus(row[7]), color: row[7] === ST_MERGED ? green : row[7] === ST_OPEN ? rust : amber, bold: true }],
    ];
  });
}

function addTypeChart(slide, x, y, w, h) {
  const rows = caseTypes.map(type => testRows.filter(row => row[2] === type));
  const series = ["Pass", "Fail", "Chưa chạy"].map(status => ({
    name: status,
    labels: caseTypes.map(type => shortType[type]),
    values: rows.map(list => list.filter(row => row[7] === status).length),
  }));
  slide.addChart(pptx.ChartType.bar, series, {
    ...position(x, y, w, h),
    barDir: "col", barGrouping: "stacked",
    chartColors: [green, rust, "C9A75A"],
    showTitle: false, showLegend: true, legendPos: "b", legendFontFace: font, legendFontSize: 11,
    showValue: true, dataLabelFormatCode: "0;;;", dataLabelColor: white, dataLabelFontFace: font, dataLabelFontSize: 11,
    catAxisLabelFontFace: font, catAxisLabelFontSize: 13, catAxisLabelColor: ink, catAxisLineColor: border,
    catAxisMajorTickMark: "none", valAxisMinVal: 0, valAxisMaxVal: 20, valAxisMajorUnit: 5,
    valAxisLabelFontFace: font, valAxisLabelFontSize: 10, valAxisLabelColor: muted, valAxisMajorTickMark: "none",
    valGridLine: { color: border, width: 0.5 },
    chartArea: { fill: { color: cream }, border: { color: cream, pt: 0 } },
    plotArea: { fill: { color: cream }, border: { color: cream, pt: 0 } },
  });
}

// ================= SLIDE =================

// 1. Tiêu đề
{
  const slide = pptx.addSlide();
  slide.background = { color: ink };
  rect(slide, 55, 108, 5, 145, "A9CABC");
  text(slide, "Kiểm thử và sửa lỗi\nLocal Passport", 78, 102, 805, 162, { fontSize: 57, bold: true, color: white });
  text(slide, "Hộ chiếu du lịch số Đà Nẵng · Bảng test case, danh sách lỗi và tình trạng xử lý", 81, 273, 800, 42,
    { fontSize: 21, color: "AECEBF" });
  rule(slide, 81, 371, 879, 371, "729487", 0.8);
  text(slide, "Chiến Thắng  •  Ngọc Anh  •  Minh Khoa    |    27/11/2026", 81, 387, 800, 55, { fontSize: 21, color: white });
}

// 2. Giới thiệu
{
  const slide = section("Giới thiệu và phạm vi");
  text(slide, "Hộ chiếu du lịch số", left, 140, 349, 49, { fontSize: 32, color: green, bold: true });
  text(slide, "Khám phá Đà Nẵng qua bản đồ, check-in bằng QR và GPS, nhận dấu, viết cảm nhận kèm ảnh, xem cộng đồng và bảng xếp hạng.",
    left, 195, 342, 130, { fontSize: 19, valign: "top" });
  text(slide, "Code kiểm thử: develop 065103c (bản gốc)\nCode mới nhất đối chiếu: develop 478505e", left, 340, 342, 60,
    { fontSize: 15, color: muted, valign: "top" });
  table(slide, ["Thành phần", "Phạm vi kiểm thử"], [
    ["Ứng dụng", "Flutter: Web, Android, iOS"],
    ["Bản đồ", "OpenStreetMap mặc định, Google Maps tùy chọn"],
    ["Dữ liệu", "Firebase Auth, Firestore, Firestore Rules"],
    ["Phần cứng", "Camera quét QR, GPS, chụp ảnh"],
    ["Trải nghiệm", "Đồng bộ, offline, TimeLens, đa màn hình"],
  ], 429, 140, [130, 348], 50, 17, { boldFirst: true });
}

// 3. Quy trình
{
  const slide = section("Quy trình kiểm thử 5 bước");
  const steps = [
    ["Lập kế hoạch\nkiểm thử", "Chức năng cần kiểm tra, tiêu chí đạt, môi trường"],
    ["Viết\ntest case", "79 dòng: đúng, sai, trống, biên"],
    ["Thực hiện\nkiểm thử", "Máy ảo, máy thật, nhiều màn hình, mất mạng"],
    ["Ghi nhận\nlỗi", "12 lỗi: mô tả, tái hiện, mức độ, phụ trách"],
    ["Sửa lỗi và\nkiểm thử lại", "Test tái hiện, retest, hồi quy"],
  ];
  steps.forEach(([step, detail], index) => {
    const x = left + index * 176;
    rect(slide, x, 170, 150, 100, index === 4 ? green : pale, border, 0.8);
    text(slide, step, x + 8, 180, 134, 80, { fontSize: 18, bold: true, color: index === 4 ? white : ink, align: "center" });
    text(slide, detail, x, 282, 150, 70, { fontSize: 14, color: muted, align: "center", valign: "top" });
    if (index < steps.length - 1) rule(slide, x + 152, 220, x + 173, 220, green, 1.6, true);
  });
  text(slide, "Mọi ca Pass/Fail đều gắn ảnh chụp hoặc log thật tại docs/testing/evidence/ (169 tệp).",
    left, 390, contentWidth, 40, { fontSize: 19, color: muted, align: "center" });
}

// 4. B1 – Chức năng cần kiểm tra
{
  const slide = section("Chức năng cần kiểm tra", "BƯỚC 1 · LẬP KẾ HOẠCH");
  const behaviors = {
    AUTH: "Đăng ký, đăng nhập, quên/đổi mật khẩu, đổi tên, Khách, xóa tài khoản",
    MAP: "Bản đồ OSM/Google, lọc tuyến, tìm kiếm, mở chi tiết",
    QR: "Đọc mã QR, khóa xác thực, quyền vị trí, bán kính 300 m, Demo",
    REF: "Nhiệm vụ, nhận dấu, viết/sửa cảm nhận, ảnh hợp lệ/hỏng",
    COM: "Bảng tin, ẩn danh, quyền sửa/xóa, xếp hạng, thông báo",
    SYNC: "Hai phiên, mất mạng khi lưu, mở app offline, TimeLens",
    UI: "360×640 → 1440×900, xoay ngang, cỡ chữ 130%, bàn phím",
    RULE: "Quyền chủ sở hữu, thiếu trường, giới hạn số ảnh",
  };
  table(slide, ["Phân hệ", "Hành vi cần kiểm tra", "Phụ trách", "Số ca"],
    Object.keys(behaviors).map(key => [
      groupNames[key], behaviors[key], owners[key],
      testRows.filter(row => row[0].startsWith("TC-" + key + "-")).length,
    ]), left, 120, [205, 450, 120, 79], 40, 14.5, { boldFirst: true, center: [3], headerHeight: 30 });
  note(slide, "Thêm 5 dòng kiểm tra tự động (format, analyze, flutter test, Rules, build web) · Kế hoạch đầy đủ: docs/testing/01-ke-hoach-kiem-thu.md", 488);
}

// 5. B1 – Tiêu chí đạt yêu cầu
{
  const slide = section("Tiêu chí đạt yêu cầu", "BƯỚC 1 · LẬP KẾ HOẠCH");
  table(slide, ["Kết quả một ca", "Tiêu chí"], [
    ["Pass", "Kết quả thực tế khớp kết quả mong đợi, có ảnh/log minh chứng"],
    ["Fail", "Khác kết quả mong đợi → lập lỗi BUG gắn mã TC"],
    ["Chưa chạy", "Thiếu môi trường/dữ liệu, ghi rõ lý do"],
  ], left, 122, [120, 300], 52, 14.5, { boldFirst: true, colorStatus: [0] });
  table(slide, ["Điều kiện", "Nội dung"], [
    ["Bắt đầu", "Chốt commit gốc, tài khoản và dữ liệu thử riêng, mã QR đúng/sai/thiếu, ảnh hợp lệ/hỏng"],
    ["Hoàn thành", "Mỗi ca có kết quả hoặc lý do chưa chạy; format, analyze, test, Rules, build đều sạch"],
    ["Với lỗi", "Lỗi Critical/High được sửa hoặc nêu rõ; lỗi đã sửa phải có retest và hồi quy"],
    ["Tài liệu", "Bảng test case, bảng lỗi, báo cáo và slide dùng cùng số liệu"],
  ], 498, 122, [100, 309], 52, 13.5, { boldFirst: true });
  rect(slide, left, 336, 420, 120, pale, border, 0.8);
  text(slide, "Mức độ nghiêm trọng", left + 14, 344, 390, 26, { fontSize: 17, bold: true, color: green });
  text(slide, "Critical – chặn luồng chính diện rộng, mất dữ liệu\nHigh – chặn chức năng chính, văng màn hình\nMedium – một luồng con sai, phản hồi gây hiểu nhầm\nLow – phạm vi hẹp, có cách thao tác thay thế",
    left + 14, 372, 400, 80, { fontSize: 13.5, valign: "top" });
}

// 6. B1 – Môi trường kiểm thử
{
  const slide = section("Môi trường kiểm thử", "BƯỚC 1 · LẬP KẾ HOẠCH");
  table(slide, ["Mã", "Môi trường", "Cấu hình", "Dùng để kiểm tra", "Người chạy"], [
    ["WEB", "Chrome 158 trên Windows 11", "360×640, 390×844, 768×1024, 1440×900, ngang 844×390", "Luồng chính, đa màn hình, 2 phiên", "Cả nhóm"],
    ["AND-EM", "Máy ảo Android 15", "LP_390x844_API35, APK debug 27/11, chữ 130%", "Đăng ký, bản đồ, Demo QR, camera ảo, xoay", "Cả nhóm"],
    ["AND-REAL", "Điện thoại thật", "[Điền model · hệ điều hành]", "Camera quét QR, GPS thực địa, chụp ảnh", "Ngọc Anh"],
    ["NET", "Mất kết nối mạng", "DevTools Offline / Slow 3G, tắt Wi-Fi + dữ liệu trên máy ảo", "Lưu khi mất mạng, đồng bộ lại", "Minh Khoa"],
    ["RULES", "Firestore Emulator", "Project demo-local-passport", "Quyền truy cập, schema, giới hạn ảnh", "Chiến Thắng"],
    ["IOS", "iOS Simulator / iPhone", "Chưa có máy macOS", "Chế độ cục bộ (BUG-07)", "—"],
  ], left, 120, [80, 165, 270, 239, 100], 50, 12.5, { boldFirst: true, headerHeight: 28 });
}

// 7. B2 – Viết test case
{
  const slide = section("Cách viết test case", "BƯỚC 2 · VIẾT TEST CASE");
  table(slide, ["Loại ca", "Ý nghĩa", "Ví dụ", "Số ca"], [
    ["Nhập đúng", "Dữ liệu đủ và hợp lệ", "TC-AUTH-01 · email, tên, mật khẩu abc123", 18],
    ["Nhập sai", "Sai định dạng, sai khóa, sai quyền", "TC-QR-02 · đúng địa điểm, sai khóa QR", 18],
    ["Để trống", "Thiếu trường, không có dữ liệu, chưa cấp quyền", "TC-AUTH-03 · bỏ trống từng ô đăng ký", 18],
    ["Dữ liệu biên", "Sát ngưỡng giới hạn trong code", "TC-QR-08 · khoảng cách 299 / 300 / 301 m", 20],
  ], left, 120, [130, 285, 370, 69], 44, 15, { boldFirst: true, center: [3] });
  text(slide, "Mỗi test case ghi đủ 11 cột", left, 360, 400, 28, { fontSize: 19, bold: true, color: green });
  text(slide, "Mã TC · Chức năng · Loại case · Dữ liệu vào · Các bước · Kết quả mong đợi · Kết quả thực tế · Trạng thái · Môi trường · Ngày chạy · Người thực hiện",
    left, 392, contentWidth, 50, { fontSize: 15, valign: "top" });
  note(slide, "18 chức năng × 4 loại = 72 ca + 2 ca biên bổ sung (TC-QR-09, TC-REF-13) + 5 dòng kiểm tra tự động = 79 dòng.", 470);
}

// 8. Tổng quan bộ test case
{
  const slide = section("Tổng quan bộ test case", "BƯỚC 2 · VIẾT TEST CASE");
  const counts = Object.entries(groupNames).map(([key, label]) => [
    label, ...statusCounts(testRows.filter(row => row[0].startsWith("TC-" + key + "-"))),
  ]);
  table(slide, ["Phân hệ", "Tổng", "Pass", "Fail", "Chưa chạy"], [...counts, ["Tổng", ...totals]],
    left, 118, [215, 50, 50, 50, 80], 30, 13.5,
    { center: [1, 2, 3, 4], padding: [2, 6, 2, 6], highlightLast: true, headerHeight: 28 });
  text(slide, "Kết quả theo loại ca", 540, 118, 360, 28, { fontSize: 18, bold: true, color: green });
  addTypeChart(slide, 520, 146, 385, 250);
  text(slide, totals[1] + " Pass · " + totals[2] + " Fail · " + totals[3] + " Chưa chạy", 540, 404, 360, 30,
    { fontSize: 18, bold: true, align: "center" });
  note(slide, "10 ca Fail trên bản gốc đều gắn với lỗi đã xác minh · 10 ca Chưa chạy do thiếu hộp thư/OAuth thật, iOS và dữ liệu Firestore kiểm soát.", 480);
}

// 9–14. Bảng test case đầy đủ
caseSlide("Đăng ký, mật khẩu, đổi tên", [
  caseGroup("Đăng ký và đăng nhập", ["TC-AUTH-01", "TC-AUTH-02", "TC-AUTH-03", "TC-AUTH-04"],
    ["Email, tên hợp lệ, MK abc123", "Email abc@invalid, MK sai", "Bỏ trống từng ô, tên toàn dấu cách", "Tên 1/30/31, MK 5/6/64/65 ký tự"],
    ["Vào đúng hộ chiếu, không báo lỗi", "Báo lỗi tiếng Việt theo trường", "Báo đúng trường, giữ màn hình", "Nhận trong biên, chặn ngoài biên"]),
  caseGroup("Quên / đổi mật khẩu, xác minh email", ["TC-AUTH-05", "TC-AUTH-06", "TC-AUTH-07", "TC-AUTH-08"],
    ["Hộp thư thật, mật khẩu mới hợp lệ", "Email sai, MK hiện tại sai", "Ô email / 3 ô đổi MK để trống", "Slow 3G, nhấn Enter liên tiếp"],
    ["Đặt lại được, vào bằng MK mới", "Báo lỗi, MK cũ vẫn dùng được", "Chặn gửi, có hướng dẫn nhập", "Chỉ gửi 1 yêu cầu khi đang bận"]),
  caseGroup("Đổi tên hiển thị", ["TC-AUTH-09", "TC-AUTH-10", "TC-AUTH-11", "TC-AUTH-12"],
    ["Tên mới hợp lệ, có bài ẩn danh", "Tên dài 31 ký tự", "Tên rỗng / chỉ dấu cách", "Tên 1 và 30 ký tự"],
    ["Hồ sơ, bài, xếp hạng đổi tên", "Không lưu tên quá 30 ký tự", "Báo cần nhập tên, giữ tên cũ", "Lưu đúng, bỏ dấu cách hai đầu"]),
]);

caseSlide("Tài khoản Khách, bản đồ, tìm kiếm", [
  caseGroup("Khách, Google/Apple, xóa tài khoản", ["TC-AUTH-13", "TC-AUTH-14", "TC-AUTH-15", "TC-AUTH-16"],
    ["Khách có dấu → nâng cấp; OAuth", "Email đã dùng, MK xác thực sai", "Bỏ trống MK xác nhận xóa", "Ngắt mạng giữa bước xóa"],
    ["Giữ UID và dấu; xóa sạch dữ liệu", "Báo lỗi, giữ phiên và dữ liệu", "Không thực hiện xóa", "Không báo xóa xong khi lỗi"]),
  caseGroup("Bản đồ và lọc tuyến", ["TC-MAP-01", "TC-MAP-02", "TC-MAP-03", "TC-MAP-04"],
    ["Bản đồ mặc định, chọn marker", "SDK Google Maps bị chặn", "Chưa chọn tuyến hoặc điểm", "Đổi tuyến, kéo gần biên"],
    ["Mở đúng điểm trên OSM", "Tự quay về bản đồ OSM", "Hiện OSM và bộ lọc Tất cả", "Bỏ chọn cũ, tâm đúng khung"]),
  caseGroup("Tìm kiếm địa điểm", ["TC-MAP-05", "TC-MAP-06", "TC-MAP-07", "TC-MAP-08"],
    ["Từ khóa “Cầu Rồng”", "Từ khóa “xyz987@@@”", "Ô rỗng / chỉ dấu cách", "“  CAU   RONG  ”, 2 từ khóa"],
    ["Chỉ ra điểm khớp, mở đúng điểm", "Hiện “không tìm thấy”", "Thoát tìm kiếm, giữ bộ lọc", "Bỏ dấu, hoa/thường; khớp đủ từ"]),
]);

caseSlide("QR, vị trí GPS, nhận dấu", [
  caseGroup("Đọc và xác thực QR", ["TC-QR-01", "TC-QR-02", "TC-QR-03", "TC-QR-04"],
    ["QR đúng (mới + cũ), GPS hợp lệ", "ID đúng, sai khóa k", "Thiếu k / checkin rỗng", "Đóng màn khi camera đang dừng"],
    ["Mở khóa đúng địa điểm", "Báo “mã xác thực không hợp lệ”", "Từ chối, cho quét lại", "Không lỗi, mở lại camera được"]),
  caseGroup("Vị trí và chế độ Demo", ["TC-QR-05", "TC-QR-06", "TC-QR-07", "TC-QR-08", "TC-QR-09"],
    ["Mã đúng, đứng trong 300 m", "Ngoài 300 m / từ chối quyền", "Tắt GPS khi quét", "Khoảng cách 299 / 300 / 301 m", "Bấm Demo nhiều lần thật nhanh"],
    ["Check-in thực địa thành công", "Báo ngoài bán kính / thiếu quyền", "Báo cần bật định vị, cho thử lại", "≤ 300 m nhận, > 300 m từ chối", "Chỉ xử lý và đóng màn 1 lần"]),
  caseGroup("Nhận dấu", ["TC-REF-01", "TC-REF-02", "TC-REF-03", "TC-REF-04"],
    ["Đã xong mọi nhiệm vụ", "Làm nhiệm vụ khi điểm còn khóa", "Còn nhiệm vụ / thiếu ảnh", "Còn 1 nhiệm vụ, thử lại lần 2"],
    ["Nhận đúng 1 dấu, cộng XP", "Không ghi nhiệm vụ, chỉ cách mở", "Chưa cấp dấu, giữ tiến độ", "Không cấp dấu / XP lần hai"]),
]);

caseSlide("Cảm nhận, ảnh, cộng đồng", [
  caseGroup("Viết / sửa cảm nhận", ["TC-REF-05", "TC-REF-06", "TC-REF-07", "TC-REF-08"],
    ["Nội dung hợp lệ, ảnh tùy chọn", "19 / 601 ký tự; API chấm lỗi 500", "Nội dung rỗng / chỉ dấu cách", "Đúng 20 và 600 ký tự"],
    ["Bài hiện đúng, lưu lên máy chủ", "Chặn ngoài biên; chấm dự phòng", "Không tạo bài trống", "Qua kiểm tra, điểm 0–100"]),
  caseGroup("Ảnh nhiệm vụ và ảnh cảm nhận", ["TC-REF-09", "TC-REF-10", "TC-REF-11", "TC-REF-12", "TC-REF-13"],
    ["Chụp bằng camera, JPEG hợp lệ", "Tệp JPEG hỏng", "Hủy camera / không chọn ảnh", "Chọn ảnh mới → “Bỏ ảnh mới”", "Xóa ảnh kiểu photoUrl cũ"],
    ["Ảnh lưu và mở lại được", "Báo lỗi rõ, giữ ảnh đã lưu", "Không thêm ảnh rỗng", "Giữ ảnh cũ; tối đa 3 ảnh", "URL cũ mất cả trên máy chủ"]),
  caseGroup("Cộng đồng", ["TC-COM-01", "TC-COM-02", "TC-COM-03", "TC-COM-04"],
    ["2 tài khoản, có bài đã lưu", "Bài của A khi đang dùng B", "Bộ lọc không có kết quả", "19 / 20 / 21 bài"],
    ["Bài hiện đúng tên / ẩn danh", "B không sửa, xóa được bài A", "Hiện trạng thái trống", "Nạp thêm trang, không trùng"]),
]);

caseSlide("Xếp hạng, thông báo, đồng bộ", [
  caseGroup("Bảng xếp hạng", ["TC-COM-05", "TC-COM-06", "TC-COM-07", "TC-COM-08"],
    ["Nhiều tài khoản có XP", "Dữ liệu sai chủ/kiểu; mất mạng", "Tài khoản 0 XP; dưới 3 người", "49 / 50 / 51 mục"],
    ["Thứ hạng, XP, số dấu đúng", "Rules từ chối; UI cho thử lại", "Hiện 0, không vỡ giao diện", "Giới hạn 50 mục từ xa"]),
  caseGroup("Thông báo", ["TC-COM-09", "TC-COM-10", "TC-COM-11", "TC-COM-12"],
    ["Có thông báo nhận dấu", "Đăng xuất A, đăng nhập B", "Không có thông báo nào", "9 / 10 thông báo chưa đọc"],
    ["Badge, đã đọc, mở đúng điểm", "B không thấy thông báo của A", "Danh sách và chuông trống", "Hiện 9 và 9+, đọc xong thì hết"]),
  caseGroup("Đồng bộ và dữ liệu cục bộ", ["TC-SYNC-01", "TC-SYNC-02", "TC-SYNC-03", "TC-SYNC-04"],
    ["Cùng tài khoản ở 2 phiên", "Mất mạng đúng lúc lưu", "Mở app khi offline; bản iOS", "Slow 3G, rớt mạng rồi nối lại"],
    ["Hai phiên thấy cùng dữ liệu", "Không mất dữ liệu, đồng bộ lại", "Đọc được dữ liệu đã lưu", "Thử lại không tạo bản trùng"]),
]);

caseSlide("TimeLens, giao diện, Firestore Rules", [
  caseGroup("TimeLens (ảnh xưa và nay)", ["TC-SYNC-05", "TC-SYNC-06", "TC-SYNC-07", "TC-SYNC-08"],
    ["Chọn điểm có ảnh xưa/nay", "Kéo ra ngoài ảnh, đổi điểm", "Chưa đăng nhập, bản demo", "Kéo sát 2 mép; offline"],
    ["Ảnh, tên, chú thích đổi đúng", "Không văng, dữ liệu điểm mới", "Mở được, không đòi đăng nhập", "Vạch nằm trong khung"]),
  caseGroup("Hiển thị và điều hướng", ["TC-UI-01", "TC-UI-02", "TC-UI-03", "TC-UI-04"],
    ["390×844, màn hình dọc", "Xoay khi đang mở bàn phím", "Form rỗng ở 360×640", "4 kích thước, chữ 130%, xoay"],
    ["Đọc và dùng được nút chính", "Cuộn tới được ô nhập và nút", "Hiện đủ gợi ý và chú thích", "Không tràn, cuộn được"]),
  caseGroup("Quyền và schema Firestore", ["TC-RULE-01", "TC-RULE-02", "TC-RULE-03", "TC-RULE-04"],
    ["Chủ hộ chiếu, schema đúng", "UID khác chủ hộ chiếu", "Thiếu passportNo", "taskPhotos có 3 hoặc 4 mục"],
    ["Cho phép ghi", "Từ chối đọc và ghi", "Từ chối ghi", "Nhận 3 mục, từ chối 4 mục"]),
]);

// 15. B3 – Kiểm tra tự động
{
  const slide = section("Kiểm tra tự động", "BƯỚC 3 · THỰC HIỆN KIỂM THỬ");
  table(slide, ["Mã", "Lệnh", "Kết quả trên bản gốc", "Trạng thái"], [
    ["TC-AUTO-01", "dart format --set-exit-if-changed lib test", "0 tệp cần sửa", "Pass"],
    ["TC-AUTO-02", "flutter analyze", "No issues found!", "Pass"],
    ["TC-AUTO-03", "flutter test", "+" + baselineFlutter + ": All tests passed!", "Pass"],
    ["TC-AUTO-04", "npm test (rules_tests/)", rulesCount + "/12 bài Firestore Rules", "Pass"],
    ["TC-AUTO-05", "flutter build web --release", "Built build\\web", "Pass"],
  ], left, 120, [110, 330, 300, 114], 38, 14.5, { boldFirst: true, colorStatus: [3], center: [3] });
  rect(slide, left, 362, contentWidth, 100, pale, border, 0.8);
  text(slide, "Số bài flutter test tăng dần theo quá trình sửa lỗi", left + 16, 372, 600, 26, { fontSize: 16, bold: true, color: green });
  text(slide, "Bản gốc: +" + baselineFlutter + "   →   Gộp 11 bản vá: +" + combinedFlutter + "   →   Code mới nhất (develop 478505e + tài liệu): +" + developFlutter,
    left + 16, 402, 820, 26, { fontSize: 17, bold: true });
  text(slide, "Tất cả đều “All tests passed!”, exit 0. Build APK debug mới ngày 27/11/2026 thành công.",
    left + 16, 430, 820, 22, { fontSize: 13, color: muted });
}

// 16. B3 – Máy ảo, máy thật, màn hình, mạng
{
  const slide = section("Máy ảo, máy thật, nhiều màn hình, mất mạng", "BƯỚC 3 · THỰC HIỆN KIỂM THỬ");
  const realPass = realRows.filter(row => row[7] === "Pass").length;
  table(slide, ["Hình thức", "Đã chạy", "Kết quả"], [
    ["Web Chrome 158", "Hầu hết các luồng, 2 phiên đăng nhập độc lập, endpoint lỗi HTTP 500", "Lộ 7 lỗi: BUG-01, 05, 06, 11, 13, 14, 15"],
    ["Máy ảo Android 15 (AVD)", "Đăng ký, bản đồ, tìm kiếm, Demo QR, camera ảo, chụp ảnh, xoay, chữ 130%", avdRows.filter(r => r[7] === "Pass").length + " Pass, " + avdRows.filter(r => r[7] === "Fail").length + " Fail (BUG-13, BUG-16)"],
    ["Điện thoại thật", "Quét QR bằng camera, GPS thực địa (trong/ngoài 300 m, tắt GPS), chụp ảnh nhiệm vụ", realPass + "/" + realRows.length + " ca Pass"],
    ["Nhiều kích thước màn hình", "360×640, 390×844, 768×1024, 1440×900, xoay ngang 844×390, chữ 130%", "Đạt; BUG-12 tràn chữ đã sửa"],
    ["Mất kết nối mạng", "DevTools Offline / Slow 3G; tắt Wi-Fi + dữ liệu di động trên máy ảo; mở app khi offline", "Đạt; lộ BUG-05, BUG-16"],
    ["Firestore Emulator", "Quyền chủ sở hữu, thiếu trường, giới hạn 3 ảnh", rulesCount + "/12 Pass"],
  ], left, 118, [190, 480, 184], 52, 13.5, { boldFirst: true, colorStatus: [2], headerHeight: 28 });
  note(slide, "Chưa có máy macOS/iPhone nên phần iOS (TC-SYNC-03, BUG-07) chưa chạy.", 486);
}

// 17. B3 – Ca chạy trên điện thoại thật
{
  const slide = section("Kết quả trên điện thoại thật", "BƯỚC 3 · THỰC HIỆN KIỂM THỬ");
  const content = {
    "TC-QR-01": "Quét QR đúng (mới và cũ) trong bán kính → mở khóa",
    "TC-QR-03": "Mã thiếu k / checkin rỗng → từ chối, cho quét lại",
    "TC-QR-04": "Quét rồi bấm Back ngay → không văng, mở lại camera được",
    "TC-QR-05": "Đứng trong 300 m, quét mã đúng → check-in thực địa",
    "TC-QR-06": "Ngoài 300 m / từ chối quyền → báo đúng, không mở khóa",
    "TC-QR-07": "Tắt GPS khi quét → báo cần định vị, bật lại thì được",
    "TC-QR-08": "Trong bán kính nhận, vượt 300 m bị từ chối",
    "TC-REF-09": "Chụp ảnh nhiệm vụ bằng camera thật → lưu, mở lại được",
  };
  table(slide, ["Mã TC", "Nội dung kiểm tra", "Kết quả", "Minh chứng"],
    realRows.map(row => [row[0], content[row[0]] ?? row[1], row[7], "[Bổ sung ảnh]"]),
    left, 118, [100, 520, 90, 144], 33, 13.5, { boldFirst: true, colorStatus: [2, 3], center: [2, 3], headerHeight: 28 });
  text(slide, "Thiết bị: [Điền model · Android/iOS bản mấy] · Người chạy: Ngọc Anh · Ngày: [Điền ngày]", left, 438, contentWidth, 24,
    { fontSize: 14, bold: true, color: amber });
  note(slide, "Ảnh chụp màn hình máy thật lưu vào docs/testing/evidence/<MãTC>-real.png rồi thay ô “[Bổ sung ảnh]”.", 466);
}

// 18. Minh chứng đa màn hình và mất mạng
{
  const slide = section("Minh chứng: nhiều màn hình và mất mạng", "BƯỚC 3 · THỰC HIỆN KIỂM THỬ");
  picture(slide, "TC-UI-04-360x640.png", 60, 122, 118, 300, "Web 360×640");
  picture(slide, "TC-UI-04-768x1024.png", 200, 122, 200, 300, "Web 768×1024");
  picture(slide, "TC-UI-04-1440x900.png", 422, 122, 236, 300, "Web 1440×900");
  picture(slide, "TC-UI-04-android-130-map.png", 680, 122, 100, 300, "Android chữ 130%");
  picture(slide, "TC-SYNC-02-android-offline.png", 800, 122, 100, 300, "Android offline");
  note(slide, "Ảnh chụp thật tại docs/testing/evidence/ (TC-UI-04, TC-SYNC-02).", 486);
}

// 19. B4 – Ghi nhận lỗi
{
  const slide = section("Mẫu ghi nhận lỗi", "BƯỚC 4 · GHI NHẬN LỖI");
  table(slide, ["Trường", "Nội dung cần ghi"], [
    ["Mã lỗi, TC liên quan", "BUG-xx gắn với mã test case bị Fail"],
    ["Mô tả", "Triệu chứng thấy được và hành vi đúng mong đợi"],
    ["Cách tái hiện", "Môi trường, các bước thao tác, ảnh/log minh chứng"],
    ["Vị trí trong code", "File, hàm, dòng gây lỗi"],
    ["Mức độ nghiêm trọng", "Critical / High / Medium / Low"],
    ["Người phụ trách", "Chiến Thắng, Ngọc Anh hoặc Minh Khoa"],
    ["Tình trạng", "Open → Đã sửa trên nhánh → Đã gộp develop"],
    ["Commit, retest", "Commit sửa, test tái hiện trước/sau, kết quả retest"],
  ], left, 118, [210, 420], 39, 14.5, { boldFirst: true, headerHeight: 28 });
  text(slide, "Nguồn phát hiện", 720, 118, 190, 26, { fontSize: 17, bold: true, color: green });
  text(slide, "4 lỗi từ chạy thủ công trên Web và máy ảo (BUG-13 → 16)\n\n6 lỗi từ rà code (BUG-01, 02, 03, 05, 06, 11), có test tái hiện\n\n1 lỗi từ log widget test (BUG-12)\n\n1 lỗi cấu hình iOS (BUG-07)",
    720, 150, 190, 300, { fontSize: 13.5, valign: "top" });
}

// 20–21. Danh sách lỗi đầy đủ
{
  const ids = bugRows.map(row => row[0]);
  const half = Math.ceil(ids.length / 2);
  [ids.slice(0, half), ids.slice(half)].forEach((part, index) => {
    const slide = section("Danh sách lỗi đã phát hiện (" + (index + 1) + "/2)", "BƯỚC 4 · GHI NHẬN LỖI");
    table(slide, ["Mã", "TC", "Mô tả", "Cách tái hiện", "Mức độ", "Phụ trách", "Tình trạng"],
      bugTableRows(part), left, 116, [60, 70, 200, 250, 64, 82, 128], 54, 11.5,
      { boldFirst: true, center: [4], padding: [3, 5, 3, 5], headerSize: 12.5, headerHeight: 26 });
    note(slide, "Chi tiết vị trí code, commit sửa và kết quả retest: docs/testing/03-bang-loi.md", 486);
  });
}

// 22. Thống kê lỗi
{
  const slide = section("Thống kê lỗi theo mức độ và tình trạng", "BƯỚC 4 · GHI NHẬN LỖI");
  const severity = ["Critical", "High", "Medium", "Low"];
  const count = (level, status) => bugRows.filter(row => (!level || row[5] === level) && (!status || row[7] === status)).length;
  table(slide, ["Mức độ", "Đã sửa, đã gộp develop", "Đã sửa trên nhánh, chờ gộp", "Open", "Tổng"], [
    ...severity.map(level => [level, count(level, ST_MERGED), count(level, ST_BRANCH), count(level, ST_OPEN), count(level)]),
    ["Tổng", merged, onBranch, open, bugRows.length],
  ], left, 122, [150, 200, 220, 120, 164], 40, 16,
  { boldFirst: true, center: [1, 2, 3, 4], highlightLast: true });
  bodyPair(slide, left, 380, 400, "Lỗi nặng nhất", "BUG-14 (Critical): mọi bài cảm nhận mới không đồng bộ được lên máy chủ.", 50);
  bodyPair(slide, 495, 380, 410, "Theo người phụ trách", "Chiến Thắng 5 lỗi · Ngọc Anh 4 lỗi · Minh Khoa 3 lỗi", 50);
}

// 23. Demo BUG-06
{
  const slide = section("Ví dụ một lỗi: BUG-06 giữ ảnh cũ", "BƯỚC 4–5 · LỖI VÀ CÁCH SỬA");
  table(slide, ["Trước khi sửa", "Nguyên nhân", "Cách sửa", "Sau khi sửa"], [[
    "Bỏ ảnh mới làm mất ảnh cũ. Test tái hiện +5 -1.",
    "Nút “Bỏ ảnh mới” bật luôn cờ xóa ảnh cũ.",
    "Chỉ bỏ ảnh vừa chọn, giữ ảnh cũ trừ khi bấm Xóa ảnh.",
    "Ảnh cũ còn nguyên trước và sau khi lưu. Test +6.",
  ]], left, 116, [213.5, 213.5, 213.5, 213.5], 52, 13.5, { headerHeight: 26 });
  rect(slide, left, 236, 412, 240, white, rust, 1.2);
  text(slide, "Trước sửa (065103c · TC-REF-12.png)", left + 12, 242, 388, 22, { fontSize: 13.5, bold: true, color: rust });
  picture(slide, "TC-REF-12.png", left + 14, 270, 104, 196, null, white);
  text(slide, "Bài có ảnh Cầu Rồng.\n\nChọn ảnh mới rồi bấm “Bỏ ảnh mới”: hộp thoại mất ảnh, chuyển thành “Thêm ảnh”. Lưu xong ảnh cũ bị xóa.",
    left + 130, 274, 270, 180, { fontSize: 14, valign: "top" });
  rect(slide, 495, 236, 412, 240, white, green, 1.2);
  text(slide, "Sau sửa (ed949dc · RETEST-BUG-06.png)", 507, 242, 388, 22, { fontSize: 13.5, bold: true, color: green });
  picture(slide, "RETEST-BUG-06.png", 509, 270, 104, 196, null, white);
  text(slide, "Cùng thao tác trên bản Web gộp bản vá.\n\nẢnh cũ vẫn hiện với nút “Đổi ảnh” cả trước và sau khi bấm “Lưu & chấm lại”.",
    625, 274, 270, 180, { fontSize: 14, valign: "top" });
}

// 24. B5 – Quy trình sửa và kiểm thử lại
{
  const slide = section("Quy trình sửa lỗi và kiểm thử lại", "BƯỚC 5 · SỬA LỖI VÀ KIỂM THỬ LẠI");
  const steps = [
    ["1. Tái hiện", "Viết test tự động cho lỗi, chạy trên bản gốc → đỏ"],
    ["2. Sửa", "Mỗi lỗi một nhánh fix/... từ develop, một commit"],
    ["3. Retest", "Chạy lại test tái hiện → xanh; thao tác lại trên Web/máy"],
    ["4. Hồi quy", "Chạy lại toàn bộ flutter test, Rules, build web"],
    ["5. Gộp", "Mở PR vào develop, 2 check CI xanh thì merge"],
  ];
  steps.forEach(([title, detail], index) => {
    const x = left + index * 176;
    rect(slide, x, 130, 150, 120, index === 4 ? pale : white, border, 0.8);
    text(slide, title, x + 8, 138, 134, 28, { fontSize: 17, bold: true, color: green, align: "center" });
    text(slide, detail, x + 10, 170, 130, 74, { fontSize: 13, align: "center", valign: "top" });
    if (index < steps.length - 1) rule(slide, x + 152, 190, x + 173, 190, green, 1.6, true);
  });
  text(slide, baselineFlutter, left, 280, 180, 80, { fontSize: 64, bold: true, color: green, align: "center" });
  text(slide, combinedFlutter, 390, 280, 180, 80, { fontSize: 64, bold: true, color: green, align: "center" });
  text(slide, "0", 727, 280, 180, 80, { fontSize: 64, bold: true, color: green, align: "center" });
  rule(slide, 240, 320, 380, 320, green, 2.2, true);
  text(slide, "bài flutter test\ntrên bản gốc", left, 362, 180, 44, { fontSize: 14, align: "center", valign: "top" });
  text(slide, "bài khi gộp đủ " + (merged + onBranch) + " bản vá\n(Rules " + rulesCount + "/12, build web đạt)", 390, 362, 180, 44, { fontSize: 14, align: "center", valign: "top" });
  text(slide, "bài hồi quy bị đỏ\nsau khi gộp bản vá", 727, 362, 180, 44, { fontSize: 14, align: "center", valign: "top" });
  note(slide, "Smoke trên bản Web gộp: đăng ký → tìm kiếm → QR sai khóa → check-in Demo → ảnh hỏng → cảm nhận có ảnh → sửa bài → offline/online → phiên khác.", 446);
}

// 25. B5 – Kết quả retest từng lỗi
{
  const slide = section("Kết quả kiểm thử lại từng lỗi", "BƯỚC 5 · SỬA LỖI VÀ KIỂM THỬ LẠI");
  const detail = {
    "BUG-01": ["ffb6ca5", "-1 → +1", "Web: Pass (ảnh)"],
    "BUG-02": ["669046d", "-2 → +2", "Widget test"],
    "BUG-03": ["4151d38", "-1 → +1", "Web + AVD: Pass"],
    "BUG-05": ["434063a", "-1 → +1", "Widget test"],
    "BUG-06": ["ed949dc", "-1 → +6", "Web: Pass (ảnh)"],
    "BUG-07": ["—", "—", "Chờ macOS / iPhone"],
    "BUG-11": ["3917368", "-1 → +4", "Unit test đồng bộ"],
    "BUG-12": ["c5bfc47 · 28d3f16", "-1 → +1", "360×640, chữ 130%"],
    "BUG-13": ["8f3f293", "-1 → +8", "Web: Pass (ảnh)"],
    "BUG-14": ["9ff91be · PR #43", "-1 → +4", "2 phiên Web: Pass"],
    "BUG-15": ["a339bb8", "-1 → +1", "Web: Pass (ảnh)"],
    "BUG-16": ["17e86fc", "-1 → +1", "Widget test"],
  };
  table(slide, ["Mã", "Mức độ", "Commit sửa", "Test tái hiện", "Hồi quy", "Retest thực tế", "Trên develop mới nhất"],
    bugRows.map(row => {
      const [commit, repro, retest] = detail[row[0]];
      const develop = row[7] === ST_MERGED ? "Xanh · hết lỗi" : row[7] === ST_OPEN ? "Chưa sửa" : "Đỏ · chờ gộp";
      return [row[0], row[5], commit, repro, row[7] === ST_OPEN ? "—" : "Đạt", retest, develop];
    }), left, 114, [70, 72, 150, 100, 70, 186, 206], 27, 12,
    { boldFirst: true, center: [1, 3, 4], colorStatus: [4, 6], padding: [2, 5, 2, 5], headerHeight: 26 });
  note(slide, "Hồi quy mỗi nhánh: flutter test +58/+59, Rules " + rulesCount + "/12, build web đạt · “Trên develop mới nhất”: chạy test tái hiện trên develop 478505e (RETEST-DEVELOP-478505e.txt).", 476);
}

// 26. Tình trạng xử lý trên code mới nhất
{
  const slide = section("Tình trạng xử lý trên code mới nhất", "BƯỚC 5 · SỬA LỖI VÀ KIỂM THỬ LẠI");
  const ids = status => bugRows.filter(row => row[7] === status).map(row => row[0]).join(", ");
  const card = (x, color, number, title, detail) => {
    rect(slide, x, 122, 270, 250, white, color, 1.4);
    text(slide, String(number), x + 18, 130, 90, 66, { fontSize: 52, bold: true, color });
    text(slide, title, x + 18, 200, 240, 28, { fontSize: 17, bold: true, color });
    text(slide, detail, x + 18, 232, 240, 134, { fontSize: 13, valign: "top" });
  };
  card(left, green, merged, "Đã sửa, đã gộp develop", ids(ST_MERGED) + "\n\nĐã có trong develop/main qua PR #41 và PR #43. Test tái hiện chạy trên develop đã xanh.");
  card(345, amber, onBranch, "Đã sửa, chờ gộp PR", ids(ST_BRANCH) + "\n\nCó bản sửa, test và retest đạt trên nhánh fix/ngocanh-*, nhưng chưa mở PR nên code chung vẫn còn lỗi.");
  card(637, rust, open, "Open", ids(ST_OPEN) + "\n\nCần tạo ứng dụng iOS trên Firebase Console, GoogleService-Info.plist, macOS/Xcode và iPhone để xác nhận.");
  text(slide, "Việc tiếp theo: mở PR cho " + onBranch + " nhánh sửa còn lại vào develop, chạy lại toàn bộ test và cài APK mới lên máy thật để kiểm lại.",
    left, 392, contentWidth, 50, { fontSize: 17, bold: true });
  note(slide, "Kiểm tra ngày 27/11/2026 trên origin/develop 478505e (= main 2d4e489).", 476);
}

// 27. Đánh giá theo yêu cầu
{
  const slide = section("Đối chiếu với 5 yêu cầu của đồ án");
  table(slide, ["Yêu cầu", "Đã làm", "Đánh giá"], [
    ["Lập kế hoạch kiểm thử", "8 phân hệ, tiêu chí Pass/Fail, điều kiện bắt đầu/hoàn thành, ma trận môi trường", "Đạt"],
    ["Viết test case", "79 dòng; mỗi chức năng đủ nhập đúng, nhập sai, để trống, dữ liệu biên", "Đạt"],
    ["Thực hiện kiểm thử", "Máy ảo Android 15, điện thoại thật, 5 kích thước + chữ 130%, Offline / Slow 3G; còn 10 ca thiếu điều kiện", "Đạt"],
    ["Ghi nhận lỗi", bugRows.length + " lỗi có mô tả, cách tái hiện, mức độ, người phụ trách, vị trí code", "Đạt"],
    ["Sửa lỗi và kiểm thử lại", (merged + onBranch) + " lỗi có bản sửa, test tái hiện, retest, hồi quy +" + combinedFlutter + "; " + onBranch + " bản sửa chưa gộp develop", "Đạt một phần"],
  ], left, 120, [200, 534, 120], 58, 14.5, { boldFirst: true, colorStatus: [2], center: [2] });
}

// 28. Hạn chế và hướng phát triển
{
  const slide = section("Hạn chế và hướng phát triển");
  bodyPair(slide, left, 135, 380, "Hạn chế",
    "Chưa có macOS/iPhone (BUG-07, TC-SYNC-03). Chưa có hộp thư và OAuth thật (3 ca). Chưa dựng Firestore riêng cho ca phân trang (3 ca). Ca máy thật chưa có ảnh đính kèm.", 120);
  bodyPair(slide, left, 305, 380, "Bài học",
    "Chạy thủ công thật phát hiện 4 lỗi mà test tự động gốc bỏ sót, nặng nhất là BUG-14 (Critical) và BUG-16 (High).", 100);
  rule(slide, 457, 140, 457, 450);
  bodyPair(slide, 495, 135, 410, "Việc cần làm tiếp",
    "Mở PR gộp " + onBranch + " nhánh sửa vào develop. Cấu hình Firebase iOS. Chạy nốt 10 ca còn lại.", 100);
  bodyPair(slide, 495, 305, 410, "Hướng phát triển",
    "Đưa Firestore Rules vào CI, thêm kiểm thử E2E chạy trên nhiều thiết bị.", 100);
}

// 29. Hỏi đáp
{
  const slide = pptx.addSlide();
  slide.background = { color: ink };
  rect(slide, 435, 163, 90, 5, "A9CABC");
  text(slide, "Hỏi đáp", left, 190, contentWidth, 115, { fontSize: 76, bold: true, color: white, align: "center" });
  text(slide, "Local Passport  •  Chiến Thắng · Ngọc Anh · Minh Khoa", left, 328, contentWidth, 39,
    { fontSize: 24, color: "A9CABC", align: "center" });
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
  assert.equal(pptx._slides.length, 29);
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
