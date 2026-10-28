// Tạo trang in mã QR check-in cho mọi địa điểm, đọc dữ liệu từ lib/data/routes.dart.
// Dùng (trong thư mục tools/qr):  npm install  →  npm run generate
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import QRCode from 'qrcode'

const here = dirname(fileURLToPath(import.meta.url))
const project = join(here, '..', '..')
const APP_URL = 'https://local-passport-danang.web.app/'

const dart = readFileSync(join(project, 'lib/data/routes.dart'), 'utf8')
const field = (block, name) => block.match(new RegExp(`${name}:\\s*'([^']*)'`))?.[1]

const routes = {}
for (const block of dart.split(/\bRouteInfo\(/).slice(2)) {
  const id = field(block, 'id')
  const color = block.match(/color:\s*Color\(0xFF([0-9A-Fa-f]{6})\)/)?.[1]
  if (id && color) routes[id] = { title: field(block, 'title'), color: `#${color}` }
}

const locations = dart
  .split(/\bLocation\(/)
  .slice(1)
  .map((b) => ({ id: field(b, 'id'), routeId: field(b, 'routeId'), name: field(b, 'name'), address: field(b, 'address'), secret: field(b, 'qrCodeSecret') }))
  .filter((l) => l.id && l.secret)

const orphan = locations.find((l) => !routes[l.routeId])
if (!locations.length || orphan) throw new Error(`parse lỗi: ${locations.length} địa điểm, tuyến không rõ: ${orphan?.routeId}`)

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const cards = []
for (const l of locations) {
  const url = `${APP_URL}?checkin=${l.id}&k=${encodeURIComponent(l.secret)}`
  const svg = await QRCode.toString(url, { type: 'svg', errorCorrectionLevel: 'Q', margin: 2, color: { dark: '#2B1810', light: '#FFFFFF' } })
  const r = routes[l.routeId]
  cards.push(`
  <article class="card" style="--route:${r.color}">
    <header class="band">${esc(r.title)}</header>
    <div class="body">
      <p class="eyebrow">Local Passport · Điểm check-in</p>
      <h2>${esc(l.name)}</h2>
      <p class="addr">${esc(l.address)}</p>
      <div class="qr">${svg}</div>
      <ol class="steps">
        <li>Mở camera điện thoại, quét mã này</li>
        <li>Đăng nhập Local Passport</li>
        <li>Cho phép vị trí để mở khóa câu chuyện, TimeLens &amp; dấu mộc</li>
      </ol>
    </div>
    <footer class="foot"><span>Mã: ${esc(l.id)}</span><span>Bán kính check-in 300 m</span></footer>
  </article>`)
}

const html = `<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Mã QR Check-in — Local Passport</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Playfair+Display:wght@600&display=swap" rel="stylesheet">
<style>
  :root { --paper:#FBF6EC; --ink:#2B1810; --soft:#6B5547; --line:#E8DCC8; --primary:#7C2D12; --gold:#E9C46A; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #E9DFCD; color: var(--ink); font-family: Inter, system-ui, sans-serif; }
  .toolbar { position: sticky; top: 0; z-index: 1; display: flex; flex-wrap: wrap; gap: 12px; align-items: center; justify-content: space-between;
    padding: 12px 16px; background: var(--primary); color: #FBF6EC; }
  .toolbar h1 { margin: 0; font: 600 18px/1.3 "Playfair Display", Georgia, serif; }
  .toolbar p { margin: 2px 0 0; font-size: 13px; opacity: .8; }
  .toolbar button { min-height: 44px; padding: 0 20px; border: 0; border-radius: 14px; background: var(--gold); color: var(--ink);
    font: 600 15px Inter, sans-serif; cursor: pointer; }
  .sheet { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 16px; padding: 16px; max-width: 1000px; margin: 0 auto; }
  .card { display: flex; flex-direction: column; background: var(--paper); border: 1.5px solid var(--line); border-radius: 16px; overflow: hidden;
    break-inside: avoid; page-break-inside: avoid; }
  .band { padding: 9px 14px; background: var(--route); color: #fff; text-align: center; white-space: nowrap;
    font-size: 11px; font-weight: 700; letter-spacing: .14em; text-transform: uppercase; }
  .body { flex: 1; padding: 14px 18px 8px; text-align: center; }
  .eyebrow { margin: 0; font-size: 11px; font-weight: 600; letter-spacing: .18em; text-transform: uppercase; color: var(--route); }
  h2 { margin: 4px 0 2px; font: 600 22px/1.2 "Playfair Display", Georgia, serif; }
  .addr { margin: 0; font-size: 12px; color: var(--soft); }
  .qr { width: 62mm; max-width: 100%; margin: 10px auto 6px; padding: 6px; background: #fff; border-radius: 12px; border: 3px solid var(--route); }
  .qr svg { display: block; width: 100%; height: auto; }
  .steps { margin: 6px auto 0; padding-left: 18px; max-width: 280px; text-align: left; font-size: 11.5px; line-height: 1.45; color: var(--ink); }
  .foot { display: flex; justify-content: space-between; padding: 8px 14px; border-top: 1px dashed var(--line); font-size: 10px; color: var(--soft); }

  @page { size: A4; margin: 10mm; }
  @media print {
    body { background: #fff; }
    .toolbar { display: none; }
    .sheet { grid-template-columns: 1fr 1fr; gap: 8mm; padding: 0; max-width: none; }
    .card { height: 133mm; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
  <div class="toolbar">
    <div>
      <h1>Mã QR check-in · ${locations.length} điểm</h1>
      <p>Mỗi trang A4 in 4 mã. Cắt theo viền, ép plastic rồi dán tại cổng di tích.</p>
    </div>
    <button type="button" onclick="window.print()">In / Lưu PDF</button>
  </div>
  <main class="sheet">${cards.join('')}
  </main>
</body>
</html>
`

const out = join(project, 'tools', 'qr')
mkdirSync(out, { recursive: true })
writeFileSync(join(out, 'qr_checkin.html'), html)
console.log('ok', locations.length, 'cards →', join(out, 'qr_checkin.html'))
for (const l of locations) console.log(`  ${l.id.padEnd(14)} ${APP_URL}?checkin=${l.id}&k=${encodeURIComponent(l.secret)}`)
