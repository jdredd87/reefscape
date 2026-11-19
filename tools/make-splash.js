// Builds the loading screen (splash) Roku shows when Reefscape is opened from a home-screen tile.
// Reefscape is a screensaver only (Roku's rules forbid an app entry point), so a tile that some Rokus
// show right after install can't start anything: this screen tells the viewer where to find it instead.
//   node tools/make-splash.js   ->  images/splash_fhd.jpg (1920x1080) and images/splash_hd.jpg (1280x720)
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'reef-splash-'));
const bg = 'file:///' + path.join(ROOT, 'store', 'screenshots', '1-reef-day.jpg').replace(/\\/g, '/');

function page(W, H) {
  const k = W / 1920;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
  html, body { margin: 0; width: ${W}px; height: ${H}px; overflow: hidden; background: #063a63; }
  .bg { position: absolute; inset: -${20 * k}px; background: url('${bg}') center / cover; filter: blur(${6 * k}px) brightness(0.7); }
  .shade { position: absolute; inset: 0; background: radial-gradient(ellipse at center, rgba(3, 30, 55, 0.55), rgba(3, 30, 55, 0.15) 70%); }
  .box { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); text-align: center; color: #fff;
         font-family: 'Segoe UI', Arial, sans-serif; text-shadow: 0 ${3 * k}px ${10 * k}px rgba(0, 0, 0, 0.6); white-space: nowrap; }
  h1 { margin: 0 0 ${26 * k}px; font-size: ${150 * k}px; font-weight: 600; letter-spacing: ${4 * k}px; }
  p { margin: ${12 * k}px 0; font-size: ${46 * k}px; }
  .path { display: inline-block; margin: ${18 * k}px 0; padding: ${16 * k}px ${40 * k}px; border-radius: ${18 * k}px;
          background: rgba(0, 20, 40, 0.55); font-size: ${50 * k}px; font-weight: 600; color: #ffe46b; }
  .small { font-size: ${38 * k}px; opacity: 0.9; }
  </style></head><body><div class="bg"></div><div class="shade"></div><div class="box">
  <h1>Reefscape</h1>
  <p>Reefscape is a screensaver. To turn it on, go to</p>
  <div class="path">Settings &rsaquo; Theme &rsaquo; Screensavers &rsaquo; Reefscape</div>
  <p class="small">Press Home to go back.</p>
  </div></body></html>`;
}

for (const [name, W, H] of [['splash_fhd', 1920, 1080], ['splash_hd', 1280, 720]]) {
  const html = path.join(TMP, name + '.html');
  const png = path.join(TMP, name + '.png');
  fs.writeFileSync(html, page(W, H));
  execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
    '--allow-file-access-from-files', `--user-data-dir=${path.join(TMP, 'profile')}`, `--window-size=${W},${H}`,
    `--screenshot=${png}`, 'file:///' + html.replace(/\\/g, '/')], { stdio: 'ignore', timeout: 60000 });
  // Roku splash images are JPEGs; convert with .NET (no extra npm packages needed)
  const jpg = path.join(ROOT, 'images', name + '.jpg');
  const ps = `Add-Type -AssemblyName System.Drawing; $i=[Drawing.Image]::FromFile('${png}');` +
    `$c=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|?{$_.MimeType -eq 'image/jpeg'};` +
    `$p=New-Object Drawing.Imaging.EncoderParameters 1;$p.Param[0]=New-Object Drawing.Imaging.EncoderParameter([Drawing.Imaging.Encoder]::Quality,[long]88);` +
    `$i.Save('${jpg}',$c,$p);$i.Dispose()`;
  execFileSync('powershell.exe', ['-NoProfile', '-Command', ps], { stdio: 'inherit' });
  console.log(name + '.jpg', fs.statSync(jpg).size, 'bytes');
}
fs.rmSync(TMP, { recursive: true, force: true });
