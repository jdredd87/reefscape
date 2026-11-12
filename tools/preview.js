// Builds a contact sheet of the artwork (assembled like on the Roku) and screenshots it to out/preview.png
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..');
const IMG = 'file:///' + path.join(ROOT, 'images', 'ocean').replace(/\\/g, '/') + '/';
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const mode = process.argv[2] || 'parts';

const im = (n, x, y, extra = '') => `<img src="${IMG}${n}.png" style="position:absolute;left:${x}px;top:${y}px;${extra}">`;
const grp = (x, y, s, inner) => `<div style="position:absolute;left:${x}px;top:${y}px;transform:scale(${s});transform-origin:0 0">${inner}</div>`;

let html;
if (mode === 'parts') {
  html = [
    grp(80, 40, 1, im('clown_tail', -48, 24) + im('clown_body', 0, 0)),
    grp(420, 30, 1, im('tang_tail', -46, 34) + im('tang_body', 0, 0)),
    grp(780, 20, 1, im('ytang_tail', -36, 45) + im('ytang_body', 0, 0)),
    grp(1120, 20, 1, im('angel_tail', -34, 55) + im('angel_body', 0, 0)),
    grp(1450, 60, 1.4, im('school_fish', 0, 0) + im('school_fish', 60, 50) + im('school_fish', 130, 10)),
    grp(260, 260, 0.8, im('shark_tail', -220, 4) + im('shark_body', 0, 0)),
    grp(1060, 240, 0.75, im('turtle_flipper', 153, 134, 'filter:brightness(.6)') + im('turtle_rear', -22, 158) + im('turtle_body', 0, 0) + im('turtle_flipper', 128, 146)),
    grp(1560, 230, 0.6, im('manta', 0, 0)),
    grp(40, 560, 0.6, im('whale', 0, 0)),
    grp(860, 520, 1, im('jelly_tentacles', 0, 98) + im('jelly_bell', 0, 0)),
    grp(1100, 520, 0.7, im('coral_brain', 0, 200) + im('coral_stag', 330, 60) + im('coral_stag2', 720, 100) + im('seafan', 1060, -20)),
    grp(40, 860, 0.7, im('sponge', 0, 0) + im('anemone', 240, 90) + im('seagrass', 580, 90) + im('rock', 820, 80) + im('kelp', 1290, -300) + im('bubble', 1480, 100) + im('particle', 1560, 120)),
  ].join('');
} else if (mode === 'new') {
  html = [
    grp(60, 40, 1.2, im('seahorse_fin', -10, 78) + im('seahorse', 0, 0)),
    grp(260, 40, 1.2, im('seahorse_fin_l', 96, 78) + im('seahorse_l', 0, 0)),
    grp(720, 60, 1, im('octo_arms', -244, 20) + im('octo_body', 0, 0)),
    grp(1100, 40, 1, im('dolphin_tail', -88, 59) + im('dolphin_body', 0, 0)),
    grp(140, 420, 1.2, im('lion_tail', -34, 75) + im('lion_body', 0, 0) + im('lion_fin', -20, 110)),
    grp(720, 420, 1.2, im('crab_legs', -41, 72) + im('crab_legs_l', 161, 72) + im('crab_body', 0, 0)),
    grp(1150, 420, 1.2, im('seastar', 0, 0)),
    grp(1400, 300, 1, im('rock', 0, 0) + im('eel_jaw', 0 + 60, 64 + 130) + im('eel', 60, 130)),
    grp(300, 760, 1.2, im('diver_leg', -104, 42, 'filter:brightness(.6)') + im('diver_leg', -96, 46) + im('diver_body', 0, 0)) + grp(900, 740, 2, im('hook', 0, 0) + im('bait', 0, 0)),
    grp(1450, 640, 1, im('jelly_glow', -30, -40) + im('jelly_tentacles', 0, 98) + im('jelly_bell', 0, 0)),
  ].join('');
} else {
  html = [
    im('bg_water', 0, 0, 'width:1920px;height:1080px'),
    im('surface', -100, 0), im('ray', 300, -20, 'opacity:.35;transform:rotate(12deg)'), im('ray', 900, -20, 'opacity:.3;transform:rotate(8deg)'),
    im('whale', 200, 260, 'transform:scale(.45);opacity:.5;filter:brightness(.8)'),
    im('reef_far', -90, 560),
    '<div style="position:absolute;inset:0;background:#0f6798;opacity:.35"></div>',
    im('reef_mid', -100, 600),
    '<div style="position:absolute;inset:0;background:#0f6798;opacity:.15"></div>',
    im('sand', -160, 820), im('rock', 1400, 690), im('coral_stag', 120, 560), im('seafan', 1650, 440), im('anemone', 700, 700), im('kelp', 20, 120), im('coral_brain', 1000, 700), im('sponge', 450, 560),
    im('vignette', 0, 0, 'width:1920px;height:1080px'),
  ].join('');
}
const W = 1920, H = mode === 'parts' ? 1160 : 1080;
const file = path.join(ROOT, 'out', `preview-${mode}.html`);
fs.writeFileSync(file, `<!doctype html><html><body style="margin:0;width:${W}px;height:${H}px;position:relative;overflow:hidden;background:#0d5a86">${html}</body></html>`);
const png = path.join(ROOT, 'out', `preview-${mode}.png`);
execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--allow-file-access-from-files',
  `--user-data-dir=${path.join(ROOT, 'out', 'art', 'chrome-profile')}`, `--window-size=${W},${H}`, `--screenshot=${png}`, 'file:///' + file.replace(/\\/g, '/')], { stdio: 'ignore' });
console.log(png);
