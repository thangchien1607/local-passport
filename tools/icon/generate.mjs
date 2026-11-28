// Vẽ icon app "Con dấu + Cầu Rồng" và xuất PNG bằng Chrome headless.
// Chạy: node tools/icon/generate.mjs  (rồi: dart run flutter_launcher_icons)
// Đổi đường dẫn Chrome bằng biến môi trường CHROME nếu cần.
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = join(root, 'assets/icon');
const tmp = join(here, '.build');
mkdirSync(out, { recursive: true });
mkdirSync(tmp, { recursive: true });

const chrome =
  process.env.CHROME ??
  'C:/Program Files/Google/Chrome/Application/chrome.exe';

const maroon = '#7C2D12';
const gold = '#E9C46A';
const cream = '#FBF6EC';

/** Con dấu: vòng vàng, Cầu Rồng uốn lượn trên mặt cầu, sóng sông Hàn. */
function stamp({ ring = gold, dragon = cream, deck = gold, mono = false }) {
  const water = mono ? ring : gold;
  return `
  <circle cx="512" cy="512" r="350" fill="none" stroke="${ring}" stroke-width="30"/>
  <circle cx="512" cy="512" r="304" fill="none" stroke="${ring}" stroke-width="12"
    stroke-dasharray="0 26" stroke-linecap="round"/>
  <path d="M512 236 l15 31 34 5 -25 23 6 34 -30 -16 -30 16 6 -34 -25 -23 34 -5z" fill="${ring}"/>
  <path d="M262 520 C262 560 282 586 312 586 C362 586 362 440 424 440
           C486 440 486 586 548 586 C610 586 606 452 662 452
           C700 452 712 494 724 506"
    fill="none" stroke="${dragon}" stroke-width="46" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M708 520 L742 470 L778 448 L812 462 L790 480 L818 500 L772 504 L744 528 Z"
    fill="${dragon}" stroke="${dragon}" stroke-width="10" stroke-linejoin="round"/>
  <path d="M756 462 L740 410 M776 452 L774 404" stroke="${dragon}" stroke-width="14" stroke-linecap="round"/>
  <circle cx="776" cy="472" r="8" fill="${mono ? 'none' : maroon}"/>
  <rect x="246" y="600" width="532" height="28" rx="14" fill="${deck}"/>
  <path d="M330 676 q30 -22 60 0 t60 0 t60 0 t60 0 t60 0 t60 0"
    fill="none" stroke="${water}" stroke-opacity="${mono ? 1 : 0.6}" stroke-width="16" stroke-linecap="round"/>
  <path d="M400 726 q30 -20 60 0 t60 0 t60 0 t60 0"
    fill="none" stroke="${water}" stroke-opacity="${mono ? 1 : 0.4}" stroke-width="14" stroke-linecap="round"/>`;
}

/** Icon nhỏ trên thanh thông báo: chỉ vòng dấu và rồng, nét dày để rõ ở 24dp. */
const statBody = `
  <circle cx="512" cy="512" r="400" fill="none" stroke="#fff" stroke-width="90"/>
  <path d="M250 560 C300 560 320 400 410 400 C500 400 500 600 600 600 C680 600 690 470 770 450"
    fill="none" stroke="#fff" stroke-width="110" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="230" y="660" width="564" height="80" rx="40" fill="#fff"/>`;

const svg = (body, bg = '') =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs><radialGradient id="bg" cx="50%" cy="42%" r="70%">
    <stop offset="0" stop-color="#93391A"/><stop offset="1" stop-color="#5A1F0B"/>
  </radialGradient></defs>${bg}${body}</svg>`;

const scaled = (body, k) =>
  `<g transform="translate(512 512) scale(${k}) translate(-512 -512)">${body}</g>`;

const icons = {
  // Icon đầy đủ: Android cũ, iOS, web.
  'icon.png': svg(scaled(stamp({}), 1.1), '<rect width="1024" height="1024" fill="url(#bg)"/>'),
  // Lớp trước của adaptive icon (Android 8+). flutter_launcher_icons tự chừa
  // lề 16% nên hình vẫn nằm trong vùng an toàn.
  'icon-foreground.png': svg(scaled(stamp({}), 1.1)),
  // Icon theo màu hình nền (Android 13+).
  'icon-monochrome.png': svg(
    scaled(stamp({ ring: '#fff', dragon: '#fff', deck: '#fff', mono: true }), 1.1),
  ),
  'stat.png': svg(statBody),
};

/** Xuất [content] (SVG 1024) thành PNG cạnh [size] px. */
function render(content, size, png) {
  const file = join(tmp, 'render.svg');
  writeFileSync(
    file,
    content.replace('width="1024" height="1024"', `width="${size}" height="${size}"`),
  );
  execFileSync(chrome, [
    '--headless=new',
    '--disable-gpu',
    '--hide-scrollbars',
    '--default-background-color=00000000',
    `--window-size=${size},${size}`,
    `--screenshot=${png}`,
    pathToFileURL(file).href,
  ], { stdio: 'ignore' });
  console.log('Đã vẽ', png);
}

// Nguồn cho flutter_launcher_icons.
for (const [name, content] of Object.entries(icons)) {
  render(content, 1024, join(out, name));
}

// Icon nhỏ trên thanh thông báo (Android dùng hình trắng trong suốt).
const densities = { mdpi: 24, hdpi: 36, xhdpi: 48, xxhdpi: 72, xxxhdpi: 96 };
for (const [d, size] of Object.entries(densities)) {
  const dir = join(root, `android/app/src/main/res/drawable-${d}`);
  mkdirSync(dir, { recursive: true });
  render(icons['stat.png'], size, join(dir, 'ic_stat_passport.png'));
}
