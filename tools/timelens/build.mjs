// Build bản demo public chỉ gồm trang TimeLens (lib/main_timelens.dart) vào build/timelens,
// rồi đổi tiêu đề / mô tả / chữ màn chờ trong index.html (web/index.html của app chính giữ nguyên).
//
//   node tools/timelens/build.mjs
//   firebase.cmd deploy --only hosting --config firebase.timelens.json
import { execSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const out = join(root, 'build', 'timelens');

execSync(`flutter build web --release -t lib/main_timelens.dart -o "${out}"`, {
  cwd: root,
  stdio: 'inherit',
  shell: true,
});

const title = 'TimeLens — Lăng kính thời gian | Local Passport';
const description =
  'Bản demo Lăng kính thời gian của Local Passport: kéo thanh trượt để so sánh di tích Đà Nẵng xưa và nay.';

const indexPath = join(out, 'index.html');
let html = readFileSync(indexPath, 'utf8');
const patches = [
  [/<title>[^<]*<\/title>/, `<title>${title}</title>`],
  [/(<meta name="description" content=")[^"]*/, `$1${description}`],
  [/(<meta name="apple-mobile-web-app-title" content=")[^"]*/, '$1TimeLens'],
  [/(<div id="splash" role="status" aria-label=")[^"]*/, '$1Đang tải TimeLens'],
  [/(<div class="hint">)[^<]*/, '$1Đang mở Lăng kính thời gian…'],
];
for (const [pattern, replacement] of patches) {
  // Báo lỗi ngay nếu web/index.html đổi cấu trúc, tránh deploy nhầm tiêu đề của app chính.
  if (!pattern.test(html)) throw new Error(`Không tìm thấy ${pattern} trong ${indexPath}`);
  html = html.replace(pattern, replacement);
}
writeFileSync(indexPath, html);

console.log(`\nĐã build bản demo TimeLens: ${out}`);
