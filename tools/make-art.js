// Generates all ocean artwork as SVG and renders it to transparent PNGs with headless Chrome.
//   node tools/make-art.js            -> render everything
//   node tools/make-art.js shark turtle_body   -> render only the named assets
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.join(ROOT, 'images', 'ocean');
const TMP = path.join(ROOT, 'out', 'art');
const CHROME = process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe';
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(TMP, { recursive: true });

// ---------- helpers ----------
function mulberry(s) {
  return function () {
    s |= 0; s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash(str) { let h = 2166136261; for (const c of str) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; }
let R = mulberry(1);
const rand = (a, b) => a + (b - a) * R();
const ri = (a, b) => Math.floor(rand(a, b + 1));
const pick = (arr) => arr[Math.floor(R() * arr.length)];
const f = (n) => Math.round(n * 10) / 10;
let idc = 0;
const uid = (p = 'u') => `${p}${++idc}`;

const blur = (id, sd) => `<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${sd}"/></filter>`;
const lin = (id, stops, x1 = 0, y1 = 0, x2 = 0, y2 = 1, extra = '') =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" ${extra}>${stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join('')}</linearGradient>`;
const rad = (id, stops, cx = 0.5, cy = 0.5, r = 0.5, extra = '') =>
  `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}" ${extra}>${stops.map(([o, c, a = 1]) => `<stop offset="${o}" stop-color="${c}" stop-opacity="${a}"/>`).join('')}</radialGradient>`;
const finRays = (id, op = 0.2, angle = 0, gap = 5) =>
  `<pattern id="${id}" width="${gap}" height="${gap}" patternUnits="userSpaceOnUse" patternTransform="rotate(${angle})"><rect width="1.3" height="${gap}" fill="#000" opacity="${op}"/></pattern>`;
const shadeDefs = (id = 'shade') => lin(id, [[0, '#001428', 0.38], [0.45, '#000', 0], [0.8, '#fff', 0.1], [1, '#fff', 0.22]]);
const fin = (d, fill, edge, ew = 3, rays = 'fr') =>
  `<path d="${d}" fill="${fill}"/><path d="${d}" fill="url(#${rays})"/>` +
  (edge ? `<path d="${d}" fill="none" stroke="${edge}" stroke-width="${ew}" stroke-linejoin="round"/>` : '');
const eye = (cx, cy, r, iris = '#f2c14e') =>
  `<circle cx="${cx}" cy="${cy}" r="${r + 1.2}" fill="#000" opacity=".5"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="${iris}"/>` +
  `<circle cx="${cx + r * 0.08}" cy="${cy}" r="${r * 0.62}" fill="#070707"/><circle cx="${cx + r * 0.3}" cy="${cy - r * 0.32}" r="${r * 0.24}" fill="#fff" opacity=".95"/>`;

// generic side-view fish body, facing right. x0 = tail base, len = to nose, h = height
function fishPath(x0, cy, len, h, o = {}) {
  const n = o.nose ?? 0.5, ped = o.ped ?? 0.12, top = o.top ?? 0.5, bot = o.bot ?? 0.45, hump = o.hump ?? 0.45;
  const X = (t) => f(x0 + len * t);
  return `M${X(1)},${f(cy)} C${X(1)},${f(cy - h * top * n)} ${X(0.82)},${f(cy - h * top)} ${X(hump)},${f(cy - h * top)} ` +
    `C${X(0.22)},${f(cy - h * top)} ${X(0.08)},${f(cy - h * ped * 1.7)} ${X(0)},${f(cy - h * ped)} L${X(0)},${f(cy + h * ped)} ` +
    `C${X(0.08)},${f(cy + h * ped * 1.7)} ${X(0.22)},${f(cy + h * bot)} ${X(hump)},${f(cy + h * bot)} ` +
    `C${X(0.82)},${f(cy + h * bot)} ${X(1)},${f(cy + h * bot * n)} ${X(1)},${f(cy)} Z`;
}

// polygon around a centre-line that tapers from w0 to w1
function taper(pts, w0, w1) {
  const L = [], Rt = [], n = pts.length;
  for (let i = 0; i < n; i++) {
    const p = pts[i], a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
    const nx = -dy / d, ny = dx / d, w = (w0 + (w1 - w0) * (i / (n - 1))) / 2;
    L.push([p[0] + nx * w, p[1] + ny * w]); Rt.push([p[0] - nx * w, p[1] - ny * w]);
  }
  return smooth(L.concat(Rt.reverse()), true);
}
// Catmull-Rom spline through points
function smooth(pts, closed = false) {
  const n = pts.length; if (n < 2) return '';
  const P = (i) => closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))];
  let d = `M${f(pts[0][0])},${f(pts[0][1])}`;
  const last = closed ? n : n - 1;
  for (let i = 0; i < last; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
    d += ` C${f(p1[0] + (p2[0] - p0[0]) / 6)},${f(p1[1] + (p2[1] - p0[1]) / 6)} ${f(p2[0] - (p3[0] - p1[0]) / 6)},${f(p2[1] - (p3[1] - p1[1]) / 6)} ${f(p2[0])},${f(p2[1])}`;
  }
  return d + (closed ? ' Z' : '');
}
// jittered quad mesh = reptile-skin scales, clipped by caller
function scales(x0, y0, w, h, cell, stroke, fills) {
  const cols = Math.ceil(w / cell) + 1, rows = Math.ceil(h / cell) + 1, P = [];
  for (let j = 0; j <= rows; j++) { P[j] = []; for (let i = 0; i <= cols; i++) P[j][i] = [x0 + i * cell + rand(-cell * 0.3, cell * 0.3) + (j % 2) * cell * 0.5, y0 + j * cell + rand(-cell * 0.3, cell * 0.3)]; }
  let s = '';
  for (let j = 0; j < rows; j++) for (let i = 0; i < cols; i++) {
    const q = [P[j][i], P[j][i + 1], P[j + 1][i + 1], P[j + 1][i]];
    s += `<path d="M${q.map((p) => f(p[0]) + ',' + f(p[1])).join(' L')} Z" fill="${pick(fills)}" stroke="${stroke}" stroke-width="${f(cell * 0.12)}" stroke-linejoin="round"/>`;
  }
  return s;
}
// recursive branching (coral, fans, far silhouettes)
function grow(x, y, ang, len, w, depth, o, out) {
  const bend = rand(-0.3, 0.3);
  const ex = x + Math.sin(ang) * len, ey = y - Math.cos(ang) * len;
  const mx = x + Math.sin(ang + bend) * len * 0.5, my = y - Math.cos(ang + bend) * len * 0.5;
  out.segs.push({ x, y, mx, my, ex, ey, w, depth });
  if (depth <= 0) { out.tips.push([ex, ey, w]); return; }
  const k = o.split || 2;
  for (let i = 0; i < k; i++) {
    const na = ang + (i - (k - 1) / 2) * o.spread + rand(-o.spread * 0.4, o.spread * 0.4) - ang * (o.upright || 0);
    grow(ex, ey, na, len * rand(o.lmin || 0.65, o.lmax || 0.85), w * (o.wk || 0.72), depth - 1, o, out);
  }
}
const segPath = (s, wAdd = 0, dx = 0, dy = 0) => `<path d="M${f(s.x + dx)},${f(s.y + dy)} Q${f(s.mx + dx)},${f(s.my + dy)} ${f(s.ex + dx)},${f(s.ey + dy)}" stroke-width="${f(Math.max(0.6, s.w + wAdd))}"/>`;
function branchy(x, y, o, colors) {
  const out = { segs: [], tips: [] };
  const trunks = o.trunks || 1;
  for (let t = 0; t < trunks; t++) grow(x + rand(-o.base || 0, o.base || 0), y, (t - (trunks - 1) / 2) * (o.fanOut || 0.4) + rand(-0.15, 0.15), o.len, o.w, o.depth, o, out);
  const [dark, mid, light, tip] = colors;
  let s = `<g fill="none" stroke-linecap="round">`;
  s += `<g stroke="${dark}">${out.segs.map((g) => segPath(g, 3)).join('')}</g>`;
  s += `<g stroke="${mid}">${out.segs.map((g) => segPath(g)).join('')}</g>`;
  if (light) s += `<g stroke="${light}" opacity=".7">${out.segs.map((g) => segPath({ ...g, w: g.w * 0.35 }, 0, -g.w * 0.18, -g.w * 0.12)).join('')}</g>`;
  s += `</g>`;
  if (tip) s += out.tips.map(([tx, ty, tw]) => `<circle cx="${f(tx)}" cy="${f(ty)}" r="${f(Math.max(1.2, tw * 0.7))}" fill="${tip}"/>`).join('');
  return { svg: s, out };
}

// ---------- reusable coral pieces ----------
function brainCoral(cx, cy, rx, ry, base, groove) {
  const g = uid('bg'), c = uid('bc');
  let maze = '';
  for (let k = 0; k < Math.floor(rx * ry / 260); k++) {
    let x = cx + rand(-rx, rx), y = cy - rand(0, ry), a = rand(0, Math.PI * 2); const pts = [[x, y]];
    for (let s = 0; s < 14; s++) { a += rand(-0.7, 0.7); x += Math.cos(a) * rx * 0.07; y += Math.sin(a) * ry * 0.07; pts.push([x, y]); }
    maze += `<path d="${smooth(pts)}"/>`;
  }
  const dome = `M${f(cx - rx)},${f(cy)} C${f(cx - rx)},${f(cy - ry * 1.3)} ${f(cx + rx)},${f(cy - ry * 1.3)} ${f(cx + rx)},${f(cy)} C${f(cx + rx * 0.6)},${f(cy + ry * 0.12)} ${f(cx - rx * 0.6)},${f(cy + ry * 0.12)} ${f(cx - rx)},${f(cy)} Z`;
  return `<defs>${rad(g, [[0, base[2]], [0.55, base[1]], [1, base[0]]], 0.4, 0.25, 0.85)}<clipPath id="${c}"><path d="${dome}"/></clipPath></defs>` +
    `<path d="${dome}" fill="url(#${g})"/><g clip-path="url(#${c})" fill="none" stroke-linecap="round">` +
    `<g stroke="${groove}" stroke-width="${f(rx * 0.05)}" opacity=".75">${maze}</g>` +
    `<g stroke="${base[2]}" stroke-width="${f(rx * 0.018)}" opacity=".55" transform="translate(-1.5,-1.5)">${maze}</g>` +
    `<path d="${dome}" fill="url(#${g}s)" /></g>` +
    `<defs>${lin(g + 's', [[0, '#000', 0], [0.6, '#000', 0], [1, '#001020', 0.45]])}</defs>`;
}
function tubeSponge(x, y, sc, colors) {
  let s = '';
  // drawn back to front: [x offset, height, lean, width]
  const tubes = [[-40, 0.72, -0.16, 0.95], [34, 0.62, 0.2, 0.9], [0, 1, 0.02, 1], [16, 0.38, 0.1, 0.8]];
  const hash = (n) => { const v = Math.sin(n * 127.1 + x * 0.37 + y * 0.11) * 43758.5; return v - Math.floor(v); };
  tubes.forEach(([dx, hk, lean, wk], ti) => {
    const g = uid('ts'), h = 260 * hk * sc, w = 34 * sc * wk, bx = x + dx * sc, tx = bx + lean * h, ty = y - h;
    const at = (t) => bx + (tx - bx) * t;            // tube centre at height fraction t (0 = base, 1 = lip)
    const wb = w * 0.9, wm = w * 0.8, wt = w * 1.06; // slight waist, flared lip
    const body = `M${f(bx - wb)},${f(y)} C${f(at(0.35) - wm)},${f(y - h * 0.35)} ${f(at(0.75) - wm)},${f(y - h * 0.75)} ${f(tx - wt)},${f(ty)}` +
      ` L${f(tx + wt)},${f(ty)} C${f(at(0.75) + wm)},${f(y - h * 0.75)} ${f(at(0.35) + wm)},${f(y - h * 0.35)} ${f(bx + wb)},${f(y)} Z`;
    let pores = '';
    for (let i = 0; i < Math.round(h / 16); i++) {
      const t = 0.08 + 0.84 * hash(ti * 50 + i), u = hash(ti * 50 + i + 0.5) * 1.5 - 0.75;
      const r = (1.4 + hash(ti * 50 + i + 0.25) * 1.8) * sc;
      pores += `<ellipse cx="${f(at(t) + u * wm)}" cy="${f(y - h * t)}" rx="${f(r * (1 - Math.abs(u) * 0.6))}" ry="${f(r * 0.8)}"/>`;
    }
    s += `<defs>${lin(g, [[0, colors[0]], [0.3, colors[2]], [0.62, colors[1]], [1, colors[0]]], 0, 0, 1, 0)}` +
      `${lin(g + 'v', [[0, '#000', 0], [0.55, '#000', 0], [1, '#200800', 0.45]])}` +
      `${rad(g + 'i', [[0, '#050200'], [0.7, '#1a0a03'], [1, '#4a2208']], 0.5, 0.35, 0.6)}</defs>` +
      `<path d="${body}" fill="url(#${g})"/>` +
      `<g fill="${colors[0]}" opacity=".45">${pores}</g>` +
      `<path d="${body}" fill="url(#${g}v)"/>` +
      `<ellipse cx="${f(tx)}" cy="${f(ty)}" rx="${f(wt)}" ry="${f(wt * 0.36)}" fill="${colors[1]}"/>` +
      `<ellipse cx="${f(tx)}" cy="${f(ty + 1)}" rx="${f(wt * 0.74)}" ry="${f(wt * 0.25)}" fill="url(#${g}i)"/>` +
      `<path d="M${f(tx - wt * 0.92)},${f(ty - wt * 0.04)} A${f(wt)},${f(wt * 0.36)} 0 0 1 ${f(tx + wt * 0.6)},${f(ty - wt * 0.3)}" fill="none" stroke="${colors[2]}" stroke-width="${f(2.2 * sc)}" stroke-linecap="round" opacity=".8"/>`;
  });
  return s;
}

// plate ("table") coral: thick wavy-edged plate on a stout trunk (no random calls, so reef layouts stay put)
function tableCoral(x, y, w, col) {
  const g = uid('tc'), top = y - 54, ry = w * 0.2;
  const rim = (r, yy, k) => {
    const p = [];
    for (let i = 0; i < 36; i++) {
      const a = (i / 36) * Math.PI * 2, m = 1 + 0.035 * Math.sin(a * 9 + x * 0.01) + 0.02 * Math.sin(a * 5 + 1);
      p.push([x + Math.cos(a) * r * m, yy + Math.sin(a) * r * k * m]);
    }
    return smooth(p, true);
  };
  let rings = '';
  for (const k of [0.75, 0.5, 0.27]) rings += `<ellipse cx="${f(x - w * 0.04)}" cy="${f(top - 2)}" rx="${f(w * k)}" ry="${f(ry * k * 0.85)}"/>`;
  return `<defs>${lin(g + 't', [[0, col[0]], [0.3, col[1]], [0.55, col[1]], [1, col[0]]], 0, 0, 1, 0)}` +
    `${rad(g, [[0, col[2]], [0.6, col[1]], [1, col[1]]], 0.42, 0.4, 0.65)}</defs>` +
    // trunk with two short limbs up to the plate
    `<path d="M${f(x - 9)},${f(y)} C${f(x - 6)},${f(y - 25)} ${f(x - 5)},${f(top + 20)} ${f(x - 14)},${f(top + 6)} L${f(x + 14)},${f(top + 6)} C${f(x + 5)},${f(top + 20)} ${f(x + 6)},${f(y - 25)} ${f(x + 9)},${f(y)} Z" fill="url(#${g}t)"/>` +
    `<path d="M${f(x - 4)},${f(top + 22)} Q${f(x - 18)},${f(top + 14)} ${f(x - 26)},${f(top + 5)}" stroke="${col[0]}" stroke-width="5" fill="none" stroke-linecap="round"/>` +
    `<path d="M${f(x + 4)},${f(top + 24)} Q${f(x + 20)},${f(top + 16)} ${f(x + 30)},${f(top + 6)}" stroke="${col[0]}" stroke-width="5" fill="none" stroke-linecap="round"/>` +
    // underside (gives the plate thickness), then the top surface
    `<path d="${rim(w, top + 5, 0.2)}" fill="${col[0]}"/>` +
    `<path d="${rim(w * 0.97, top + 6, 0.17)}" fill="#000" opacity=".22"/>` +
    `<path d="${rim(w, top, 0.2)}" fill="url(#${g})"/>` +
    `<g fill="none" stroke="${col[0]}" stroke-width="1.6" opacity=".35">${rings}</g>` +
    `<path d="${rim(w * 0.985, top - 1, 0.19)}" fill="none" stroke="${col[2]}" stroke-width="1.5" opacity=".6"/>`;
}

// ---------- asset registry ----------
const assets = [];
// res < 1 stores a soft/blurry image at lower resolution (the Roku scales it back up) to save texture memory
const asset = (name, w, h, fn, res = 1) => assets.push({ name, w, h, fn, res });

// ===== FISH =====
asset('clown_body', 235, 145, () => {
  const body = fishPath(18, 74, 205, 98, { top: 0.5, bot: 0.46, nose: 0.6, ped: 0.14, hump: 0.5 });
  const band = (d) => `<path d="${d}" fill="#fbfbf6" stroke="#111" stroke-width="5"/>`;
  return `<defs>${lin('or', [[0, '#f26a00'], [0.55, '#ff8f1f'], [1, '#ffb04f']])}${shadeDefs()}${finRays('fr', 0.18, 0, 5)}
    <clipPath id="bc"><path d="${body}"/></clipPath>${blur('b6', 6)}</defs>
  ${fin('M150,42 C146,10 118,4 96,16 C82,6 54,12 34,56 L110,64 Z', 'url(#or)', '#111', 3.5)}
  ${fin('M104,112 C100,134 76,142 52,134 C46,122 42,112 42,102 Z', 'url(#or)', '#111', 3.5)}
  <path d="${body}" fill="url(#or)"/>
  <g clip-path="url(#bc)">
    ${band('M182,0 C164,40 164,104 184,150 L162,150 C144,104 144,40 158,0 Z')}
    ${band('M120,0 C130,50 130,100 114,150 L92,150 C106,100 106,50 96,0 Z')}
    ${band('M46,0 C52,60 52,90 44,150 L28,150 C34,90 34,60 28,0 Z')}
    <path d="${body}" fill="url(#shade)"/>
    <ellipse cx="135" cy="44" rx="70" ry="9" fill="#fff" opacity=".35" filter="url(#b6)"/>
  </g>
  <path d="${body}" fill="none" stroke="#1a0a00" stroke-width="2" opacity=".7"/>
  ${''/* pelvic fin hangs below the belly under the head band; the pectoral fin is its own moving part (clown_pec) */}
  ${fin('M156,114 C154,128 146,138 134,142 C138,130 142,120 144,112 Z', '#ff8a1a', '#111', 2.5)}
  <path d="M220,78 C215,82 210,82 205,80" stroke="#5a2400" stroke-width="2" fill="none"/>
  ${eye(198, 60, 8, '#ff9d3c')}`;
});
// pectoral fin, drawn at the body's (126,74); it sits in the orange just behind the head band and paddles
asset('clown_pec', 32, 34, () => `<defs>${finRays('fr', 0.18, 0, 5)}</defs>
  ${fin('M25,4 C16,8 7,18 3,30 C14,30 23,24 27,18 Z', '#ff9a33', '#111', 2.5)}`);
asset('clown_tail', 72, 100,() => `<defs>${lin('or', [[0, '#f26a00'], [1, '#ffab45']])}${finRays('fr', 0.22, 90, 5)}</defs>
  ${fin('M70,40 C50,30 30,5 10,8 C2,30 2,70 10,92 C30,95 50,70 70,60 Z', 'url(#or)', '#111', 4)}
  <path d="M14,14 C7,35 7,65 14,86" stroke="#fff" stroke-width="3" fill="none" opacity=".8"/>`);

asset('tang_body', 262, 182, () => {
  const body = fishPath(30, 90, 220, 140, { top: 0.5, bot: 0.47, nose: 0.42, ped: 0.09, hump: 0.55 });
  return `<defs>${lin('bl', [[0, '#0f2f86'], [0.5, '#2459d6'], [1, '#4a86ff']])}${shadeDefs()}${finRays('fr', 0.22, 0, 5)}
    <clipPath id="bc"><path d="${body}"/></clipPath>${blur('b6', 6)}${blur('b1', 1.2)}</defs>
  ${fin('M216,32 C180,4 92,6 46,62 L200,64 Z', '#1a3fa8', '#05103a', 3)}
  <path d="M216,32 C180,4 92,6 46,62" fill="none" stroke="#6fb2ff" stroke-width="2" opacity=".8"/>
  ${fin('M196,150 C150,180 92,178 50,120 L190,120 Z', '#1a3fa8', '#05103a', 3)}
  <path d="M196,150 C150,180 92,178 50,120" fill="none" stroke="#6fb2ff" stroke-width="2" opacity=".8"/>
  <path d="${body}" fill="url(#bl)"/>
  <g clip-path="url(#bc)">
    <path d="M226,68 C180,44 110,46 62,84 C90,92 120,118 150,118 C175,118 186,96 172,74" fill="none" stroke="#070b1c" stroke-width="15" stroke-linecap="round" stroke-linejoin="round" filter="url(#b1)"/>
    <path d="M62,84 C50,92 42,96 30,92" fill="none" stroke="#070b1c" stroke-width="10" stroke-linecap="round"/>
    <path d="${body}" fill="url(#shade)"/>
    <ellipse cx="150" cy="46" rx="80" ry="10" fill="#fff" opacity=".3" filter="url(#b6)"/>
  </g>
  <path d="${body}" fill="none" stroke="#020a2a" stroke-width="2" opacity=".6"/>
  ${eye(224, 72, 7.5, '#1d2e70')}`;
});
// pectoral fins are separate moving parts, drawn at the offset given in Specs.brs
asset('tang_pec', 40, 36, () => `<defs>${finRays('fr', 0.22, 0, 5)}</defs>
  ${fin('M32,2 C14,10 4,24 2,34 C18,28 30,16 38,6 Z', '#ffd84a', '#7a5a00', 1.5)}`);
asset('tang_tail', 82, 112, () => `<defs>${lin('y', [[0, '#ffcf1a'], [1, '#ffe46b']])}${finRays('fr', 0.18, 90, 5)}</defs>
  ${fin('M80,47 L10,5 C22,40 22,72 10,107 L80,65 Z', 'url(#y)', null)}
  <path d="M80,47 L10,5" stroke="#08102a" stroke-width="8" stroke-linecap="round"/><path d="M10,107 L80,65" stroke="#08102a" stroke-width="8" stroke-linecap="round"/>`);

asset('ytang_body', 222, 202, () => {
  const body = 'M214,96 C206,78 190,56 160,42 C120,24 72,40 46,84 L30,94 L30,106 L46,116 C72,160 120,176 160,158 C190,144 206,118 214,104 Z';
  return `<defs>${lin('y', [[0, '#f2c200'], [0.5, '#ffdb1f'], [1, '#fff06e']])}${shadeDefs()}${finRays('fr', 0.16, 0, 5)}
    <clipPath id="bc"><path d="${body}"/></clipPath>${blur('b6', 6)}</defs>
  ${fin('M182,48 C150,6 84,6 46,80 L120,92 Z', '#ffd51a', '#c79a00', 2)}
  ${fin('M182,152 C150,196 84,194 46,120 L120,108 Z', '#ffd51a', '#c79a00', 2)}
  <path d="${body}" fill="url(#y)"/>
  <g clip-path="url(#bc)"><path d="${body}" fill="url(#shade)"/>
    <ellipse cx="130" cy="58" rx="60" ry="12" fill="#fff" opacity=".35" filter="url(#b6)"/></g>
  <path d="${body}" fill="none" stroke="#a87c00" stroke-width="1.8" opacity=".7"/>
  <ellipse cx="42" cy="100" rx="6" ry="2.5" fill="#fff"/>
  <path d="M214,100 L206,101" stroke="#7a5a00" stroke-width="2"/>
  ${eye(180, 74, 7, '#3b2a00')}`;
});
asset('ytang_pec', 34, 30, () => `<defs>${finRays('fr', 0.16, 0, 5)}</defs>
  ${fin('M26,2 C12,8 4,18 2,28 C16,22 26,12 32,4 Z', '#fff36b', '#c79a00', 1.4)}`);
asset('ytang_tail', 72, 110, () => `<defs>${lin('y', [[0, '#ffd000'], [1, '#ffe760']])}${finRays('fr', 0.16, 90, 5)}</defs>
  ${fin('M70,48 C50,40 30,10 8,6 C18,40 18,70 8,104 C30,100 50,70 70,62 Z', 'url(#y)', '#c79a00', 2)}`);

asset('angel_body', 250, 212, () => {
  const body = 'M228,104 C224,70 198,40 158,34 C112,28 68,52 48,92 L32,98 L32,112 L48,118 C68,160 112,182 158,176 C198,170 224,138 228,104 Z';
  let stripes = '';
  for (let i = -2; i < 13; i++) { const y0 = 20 + i * 14; stripes += `<path d="M20,${y0 + 24} C100,${y0 + 4} 160,${y0 - 2} 240,${y0 - 22}"/>`; }
  return `<defs>${lin('b', [[0, '#13226e'], [1, '#2a46b8']])}${lin('face', [[0, '#bcd4ff'], [1, '#f0f6ff']], 0, 0, 1, 0)}${shadeDefs()}${finRays('fr', 0.18, 0, 5)}
    <clipPath id="bc"><path d="${body}"/></clipPath><clipPath id="df"><path d="M192,42 C150,4 90,6 50,82 L120,92 Z"/></clipPath>${blur('b6', 6)}</defs>
  <path d="M192,42 C150,4 90,6 50,82 L120,92 Z" fill="url(#b)"/>
  <g clip-path="url(#df)" fill="none" stroke="#ffd23a" stroke-width="4">${stripes}</g>
  <path d="M192,42 C150,4 90,6 50,82" fill="none" stroke="#7fb0ff" stroke-width="2.5"/>
  ${fin('M192,168 C150,206 90,204 50,124 L120,118 Z', 'url(#b)', '#7fb0ff', 2.5)}
  <path d="M180,176 C140,198 96,190 64,140" fill="none" stroke="#7fb0ff" stroke-width="2" opacity=".7"/>
  <path d="${body}" fill="url(#b)"/>
  <g clip-path="url(#bc)">
    <g fill="none" stroke="#ffd23a" stroke-width="5.5" stroke-linecap="round">${stripes}</g>
    <path d="M196,0 L260,0 L260,212 L196,212 Z" fill="url(#face)"/>
    <path d="M202,36 C190,80 192,130 206,180 L182,180 C170,130 168,80 180,36 Z" fill="#0a1233" stroke="#6fa0ff" stroke-width="3"/>
    <path d="M168,30 C160,80 160,130 170,184 L156,184 C146,130 146,80 154,30 Z" fill="#0a1233" opacity=".9"/>
    <path d="${body}" fill="url(#shade)"/>
    <ellipse cx="120" cy="52" rx="60" ry="10" fill="#fff" opacity=".25" filter="url(#b6)"/>
  </g>
  <path d="${body}" fill="none" stroke="#050b2a" stroke-width="2" opacity=".7"/>
  ${eye(192, 84, 7, '#9fc4ff')}`;
});
asset('angel_pec', 38, 36, () => `<defs>${finRays('fr', 0.18, 0, 5)}</defs>
  ${fin('M30,2 C14,10 4,22 2,34 C18,28 30,16 36,6 Z', '#0a1233', '#ffd23a', 2)}`);
asset('angel_tail', 72, 100, () => `<defs>${lin('y', [[0, '#ffc21a'], [1, '#ffdf5a']])}${finRays('fr', 0.2, 90, 5)}</defs>
  ${fin('M70,40 C50,30 30,5 10,8 C2,30 2,70 10,92 C30,95 50,70 70,60 Z', 'url(#y)', '#b88400', 2)}`);

asset('school_fish', 122, 46, () => {
  const body = fishPath(24, 23, 92, 24, { top: 0.5, bot: 0.46, nose: 0.45, ped: 0.12, hump: 0.55 });
  return `<defs>${lin('s', [[0, '#16408a'], [0.35, '#3d86d8'], [0.6, '#bcd8f0'], [1, '#f4f9ff']])}<clipPath id="bc"><path d="${body}"/></clipPath>${lin('y', [[0, '#ffd23a'], [1, '#ffe98a']])}</defs>
  <path d="M28,20 L4,4 C10,14 12,19 14,23 C12,27 10,32 4,42 L28,26 Z" fill="url(#y)"/>
  <path d="${body}" fill="url(#s)"/>
  <g clip-path="url(#bc)"><path d="M112,16 C80,11 50,13 24,20" fill="none" stroke="#ffd84a" stroke-width="3.5"/></g>
  <path d="${body}" fill="none" stroke="#0b2450" stroke-width="1" opacity=".6"/>
  ${eye(105, 20, 3, '#e8e8e8')}`;
});

// ===== SHARK =====
asset('shark_body', 850, 320, () => {
  const body = 'M835,168 C832,150 800,128 745,118 C680,105 600,95 520,96 C400,98 250,118 150,135 C100,143 60,148 38,150 L38,182 C60,184 100,190 160,200 C260,214 420,228 560,226 C660,224 740,212 790,200 C815,193 834,182 835,168 Z';
  const tipGrad = (id, x1, y1, x2, y2) => lin(id, [[0, '#4d6679'], [0.72, '#3f5668'], [0.84, '#141c22'], [1, '#0a0f13']], x1, y1, x2, y2, 'gradientUnits="userSpaceOnUse"');
  let gills = '';
  for (let k = 0; k < 5; k++) { const x = 650 + k * 13; gills += `<path d="M${x},${142 + k * 2} C${x - 7},158 ${x - 7},172 ${x - 1},${190 - k}"/>`; }
  return `<defs>${lin('sk', [[0, '#34495a'], [0.45, '#5d7586'], [0.58, '#8fa3b0'], [0.66, '#e1e7eb'], [1, '#f5f7f8']])}
    ${tipGrad('dg', 525, 100, 462, 8)}${tipGrad('pg', 600, 205, 490, 306)}${tipGrad('fg', 610, 205, 570, 280)}
    <clipPath id="bc"><path d="${body}"/></clipPath>${blur('b10', 10)}${blur('b2', 2)}</defs>
  <path d="M235,132 C225,112 212,102 196,98 C200,112 200,124 192,138 Z" fill="#40576a"/>
  <path d="${body}" fill="url(#sk)"/>
  <g clip-path="url(#bc)">
    <ellipse cx="560" cy="112" rx="240" ry="16" fill="#fff" opacity=".22" filter="url(#b10)"/>
    <path d="M835,180 C700,215 400,230 160,205 L160,240 L835,240 Z" fill="#9fb4c2" opacity=".25" filter="url(#b10)"/>
    <g fill="none" stroke="#2a3a47" stroke-width="2.6" opacity=".55" stroke-linecap="round">${gills}</g>
  </g>
  <path d="${body}" fill="none" stroke="#1d2a33" stroke-width="1.5" opacity=".5"/>
  <path d="M300,212 C288,232 268,248 248,254 C258,238 262,226 262,212 Z" fill="#4a6273"/>
  <path d="M185,196 C175,212 162,222 148,226 C155,214 158,204 156,193 Z" fill="#4a6273"/>
  <path d="M800,190 C780,199 752,202 730,197" fill="none" stroke="#2a3540" stroke-width="2.2" opacity=".6"/>
  <circle cx="768" cy="146" r="6.5" fill="#0b1014"/><circle cx="770" cy="144" r="1.8" fill="#fff" opacity=".8"/>
  <path d="M808,152 C812,150 816,151 818,153" stroke="#1a232a" stroke-width="2" fill="none" opacity=".6"/>`;
});
// pectoral fins: near one (over the body) and far one (behind it), moving parts
const sharkTip = (id, x1, y1, x2, y2) => lin(id, [[0, '#4d6679'], [0.72, '#3f5668'], [0.84, '#141c22'], [1, '#0a0f13']], x1, y1, x2, y2, 'gradientUnits="userSpaceOnUse"');
asset('shark_pec', 134, 114, () => `<defs>${sharkTip('pg', 114, 9, 4, 110)}</defs>
  <path d="M129,4 C109,44 59,86 4,110 C36,66 44,36 42,16 Z" fill="url(#pg)"/>`);
// dorsal fin, behind the body; its base runs down into the body so no gap shows as it flexes
asset('shark_dorsal', 136, 120, () => `<defs>${sharkTip('dg', 81, 98, 18, 6)}</defs>
  <path d="M131,98 C101,43 61,16 18,4 C24,38 26,76 4,104 L4,118 L131,118 Z" fill="url(#dg)"/>`);
asset('shark_pecf', 78, 83, () => `<defs>${sharkTip('fg', 44, 4, 4, 79)}</defs>
  <path d="M74,4 C64,34 34,61 4,79 C19,49 24,27 24,11 Z" fill="url(#fg)" opacity=".9"/>`);
asset('shark_tail', 272, 320, () => `<defs>${lin('t', [[0, '#3b5163'], [0.6, '#52697b'], [1, '#2e3f4c']])}
  ${lin('tip', [[0, '#000', 0], [0.75, '#000', 0], [1, '#0a0f13', 0.9]], 1, 0, 0, 0)}</defs>
  <path d="M270,145 C210,120 110,50 20,8 C50,70 80,120 120,160 C90,200 70,250 65,295 C130,255 210,200 270,180 Z" fill="url(#t)"/>
  <path d="M270,145 C210,120 110,50 20,8 C50,70 80,120 120,160 C90,200 70,250 65,295 C130,255 210,200 270,180 Z" fill="url(#tip)"/>`);

// ===== SEA TURTLE =====
asset('turtle_body', 590, 270, () => {
  const xc = 255, a = 210, yTop = (x) => { const u = Math.min(1, Math.abs((x - xc) / a)); return 168 - 140 * Math.pow(1 - u * u, 0.75); };
  const yBot = (x) => { const u = Math.min(1, Math.abs((x - xc) / a)); return 160 + 16 * Math.sqrt(1 - u * u); };
  const top = [], bot = [];
  for (let i = 0; i <= 40; i++) { const x = xc - a + (2 * a * i) / 40; top.push([x, yTop(x)]); bot.push([x, yBot(x)]); }
  const shell = smooth(top.concat(bot.reverse()), true);
  const map = (u, v) => { const x = xc - a * 0.92 + u * a * 1.84; const t = yTop(x) + 8; return [x, t + v * (yBot(x) - t)]; };
  const cell = (u0, u1, v0, v1) => {
    const pts = []; const N = 5;
    for (let i = 0; i <= N; i++) pts.push(map(u0 + (u1 - u0) * i / N, v0));
    for (let i = 0; i <= N; i++) pts.push(map(u1, v0 + (v1 - v0) * i / N));
    for (let i = N; i >= 0; i--) pts.push(map(u0 + (u1 - u0) * i / N, v1));
    for (let i = N; i >= 0; i--) pts.push(map(u0, v0 + (v1 - v0) * i / N));
    return pts;
  };
  const toD = (pts) => 'M' + pts.map((p) => f(p[0]) + ',' + f(p[1])).join(' L') + ' Z';
  const shrink = (pts, k) => { const cx = pts.reduce((s, p) => s + p[0], 0) / pts.length, cy = pts.reduce((s, p) => s + p[1], 0) / pts.length; return pts.map((p) => [cx + (p[0] - cx) * k, cy + (p[1] - cy) * k]); };
  let scutes = '';
  const row = (n, v0, v1, off, rings) => {
    for (let i = 0; i < n; i++) {
      const u0 = (i + off) / (n + off * 2 > n ? n + off * 2 : n), u1 = (i + 1 + off) / (n + off * 2 > n ? n + off * 2 : n);
      const p = cell(u0, u1, v0, v1);
      scutes += `<path d="${toD(p)}" fill="url(#sc)" stroke="#2e2210" stroke-width="3.5" stroke-linejoin="round"/>`;
      if (rings) scutes += `<path d="${toD(shrink(p, 0.66))}" fill="none" stroke="#3a2a12" stroke-width="1.4" opacity=".45"/><path d="${toD(shrink(p, 0.34))}" fill="none" stroke="#3a2a12" stroke-width="1.2" opacity=".35"/>`;
    }
  };
  row(5, 0, 0.36, 0, true); row(4, 0.36, 0.8, 0.5, true); row(13, 0.8, 1, 0, false);
  const head = 'M430,152 C455,128 505,116 542,126 C568,134 578,158 560,174 C538,192 482,190 444,182 Z';
  return `<defs>${rad('sc', [[0, '#b48a45'], [0.6, '#7d5c2a'], [1, '#4a3416']], 0.45, 0.4, 0.7)}
    ${lin('skin', [[0, '#6f6c3c'], [1, '#bdb373']])}${rad('hl', [[0, '#fff', 0.35], [1, '#fff', 0]], 0.35, 0.2, 0.6)}
    ${lin('shellshade', [[0, '#000', 0], [0.6, '#000', 0], [1, '#1b1006', 0.5]])}
    <clipPath id="sh"><path d="${shell}"/></clipPath><clipPath id="hd"><path d="${head}"/></clipPath>${blur('b3', 3)}</defs>
  <path d="M40,168 C30,172 22,176 14,176 C24,170 32,164 44,160 Z" fill="url(#skin)"/>
  <path d="${head}" fill="url(#skin)"/>
  <g clip-path="url(#hd)">${scales(420, 110, 170, 90, 13, '#3a381e', ['#8e8a4e', '#a39c5c', '#7a7642', '#b3aa66'])}
    <path d="M430,178 C480,190 540,190 570,168 L570,200 L430,200 Z" fill="#e3d9a0" opacity=".7"/></g>
  <path d="${head}" fill="none" stroke="#2e2c16" stroke-width="2"/>
  <ellipse cx="258" cy="170" rx="198" ry="22" fill="#d9cf8e"/>
  <path d="${shell}" fill="#5a4220"/>
  <g clip-path="url(#sh)">${scutes}<path d="${shell}" fill="url(#hl)"/><path d="${shell}" fill="url(#shellshade)"/></g>
  <path d="${shell}" fill="none" stroke="#2a1d0b" stroke-width="3"/>
  <circle cx="527" cy="142" r="8" fill="#1c1208"/><circle cx="529" cy="140" r="2.4" fill="#fff" opacity=".85"/>
  <path d="M515,132 C522,126 534,126 540,132" stroke="#2e2c16" stroke-width="2.5" fill="none"/>
  <path d="M572,160 C564,164 556,166 548,166" stroke="#2e2c16" stroke-width="2" fill="none"/>`;
});
asset('turtle_flipper', 290, 160, () => {
  const d = 'M272,18 C228,0 120,40 10,140 C100,126 210,84 280,46 Z';
  return `<defs>${lin('skin', [[0, '#7c7844'], [1, '#b9af6c']])}<clipPath id="c"><path d="${d}"/></clipPath></defs>
  <path d="${d}" fill="url(#skin)"/>
  <g clip-path="url(#c)">${scales(0, 0, 290, 160, 15, '#3a381e', ['#8e8a4e', '#a39c5c', '#7a7642', '#b3aa66', '#c4bb78'])}
  <path d="M10,140 C100,126 210,84 280,46 L290,60 L10,160 Z" fill="#e8dfa8" opacity=".55"/></g>
  <path d="${d}" fill="none" stroke="#2e2c16" stroke-width="2.5"/>`;
});
asset('turtle_rear', 132, 84, () => {
  const d = 'M122,10 C96,2 40,24 8,66 C50,62 100,42 128,28 Z';
  return `<defs>${lin('skin', [[0, '#7c7844'], [1, '#b9af6c']])}<clipPath id="c"><path d="${d}"/></clipPath></defs>
  <path d="${d}" fill="url(#skin)"/><g clip-path="url(#c)">${scales(0, 0, 132, 84, 12, '#3a381e', ['#8e8a4e', '#a39c5c', '#7a7642', '#b3aa66'])}</g>
  <path d="${d}" fill="none" stroke="#2e2c16" stroke-width="2"/>`;
});

// ===== MANTA RAY (top view, head right) =====
asset('manta', 530, 420, () => {
  const d = 'M472,186 C430,150 362,90 262,12 C252,60 232,120 192,170 C152,190 102,200 64,205 L64,215 C102,220 152,230 192,250 C232,300 252,360 262,408 C362,330 430,270 472,234 C484,222 486,198 472,186 Z';
  return `<defs>${rad('m', [[0, '#3b4e60'], [0.6, '#24323f'], [1, '#141c25']], 0.7, 0.5, 0.7)}${blur('b4', 4)}<clipPath id="c"><path d="${d}"/></clipPath></defs>
  <path d="M70,207 L0,210 L70,213 Z" fill="#1a232c"/>
  <path d="M470,182 C500,174 518,184 516,194 C508,200 490,198 470,196 Z" fill="#202c38"/>
  <path d="M470,238 C500,246 518,236 516,226 C508,220 490,222 470,224 Z" fill="#202c38"/>
  <path d="${d}" fill="url(#m)"/>
  <g clip-path="url(#c)">
    <path d="M430,172 C390,140 340,104 296,72 C334,118 368,150 408,190 Z" fill="#e8eef2" opacity=".75" filter="url(#b4)"/>
    <path d="M430,248 C390,280 340,316 296,348 C334,302 368,270 408,230 Z" fill="#e8eef2" opacity=".75" filter="url(#b4)"/>
    <path d="M470,210 C380,206 280,206 120,210" stroke="#5d7488" stroke-width="5" opacity=".5" filter="url(#b4)"/>
  </g>
  <path d="${d}" fill="none" stroke="#0b1016" stroke-width="2" opacity=".6"/>`;
});

// ===== JELLYFISH =====
asset('jelly_bell', 200, 140, () => {
  const d = 'M10,110 C10,40 60,8 100,8 C140,8 190,40 190,110 C170,118 150,104 130,116 C110,104 90,104 70,116 C50,104 30,118 10,110 Z';
  return `<defs>${rad('j', [[0, '#ffe3f4', 0.75], [0.6, '#f0a6dc', 0.45], [1, '#c76fd0', 0.35]], 0.5, 0.25, 0.8)}${blur('b6', 6)}${blur('b2', 2)}</defs>
  <path d="${d}" fill="#ffc8f0" opacity=".35" filter="url(#b6)"/>
  <path d="${d}" fill="url(#j)"/>
  <g fill="none" stroke="#ff7fc8" stroke-width="7" opacity=".55" filter="url(#b2)">
    <path d="M70,70 C60,50 85,40 92,58"/><path d="M108,58 C115,40 140,50 130,70"/><path d="M76,88 C70,104 90,108 96,92"/><path d="M104,92 C110,108 130,104 124,88"/></g>
  <path d="${d}" fill="none" stroke="#ffe6f6" stroke-width="2.5" opacity=".8"/>
  <path d="M40,50 C60,22 90,14 110,16" fill="none" stroke="#fff" stroke-width="5" opacity=".5" filter="url(#b2)"/>`;
});
asset('jelly_tentacles', 200, 400, () => {
  let s = '';
  for (let i = 0; i < 16; i++) {
    const x0 = 18 + i * 10.5, len = rand(220, 390), ph = rand(0, 6), pts = [];
    for (let y = 0; y <= len; y += 12) pts.push([x0 + Math.sin(y / 38 + ph) * (4 + y * 0.04), y + 4]);
    s += `<path d="${smooth(pts)}" fill="none" stroke="#ffd2f0" stroke-width="${f(rand(1, 2))}" opacity="${f(rand(0.35, 0.6))}"/>`;
  }
  for (let i = 0; i < 4; i++) {
    const x0 = 78 + i * 15, len = rand(240, 300), ph = rand(0, 6), pts = [];
    for (let y = 0; y <= len; y += 10) pts.push([x0 + Math.sin(y / 30 + ph) * (6 + y * 0.03), y + 4]);
    s += `<path d="${smooth(pts)}" fill="none" stroke="#f59ad8" stroke-width="11" opacity=".32" filter="url(#b1)"/>` +
      `<path d="${smooth(pts)}" fill="none" stroke="#ffe1f5" stroke-width="3" stroke-dasharray="5 4" opacity=".55"/>`;
  }
  return `<defs>${blur('b1', 1.5)}</defs>${s}`;
});

// ===== WHALE (distant humpback) =====
asset('whale', 1300, 430, () => {
  const d = 'M1282,212 C1270,168 1200,138 1100,134 C950,126 800,132 650,150 C500,170 352,192 222,204 C152,209 92,212 62,211 L22,168 C40,194 44,206 50,213 C44,222 40,234 22,260 L62,224 C122,230 202,244 302,258 C452,282 652,306 852,310 C1002,312 1152,292 1232,264 C1270,250 1290,232 1282,212 Z';
  let grooves = '';
  for (let k = 0; k < 7; k++) grooves += `<path d="M${1230 - k * 6},${236 + k * 6} C1100,${262 + k * 4} 980,${276 + k * 2} 860,${282 + k}" />`;
  let knobs = '';
  for (let k = 0; k < 9; k++) knobs += `<circle cx="${1120 + k * 18}" cy="${f(166 + k * 2.6)}" r="4"/>`;
  return `<defs>${lin('w', [[0, '#1d3346'], [0.6, '#2c4659'], [1, '#6f8a9c']])}<clipPath id="c"><path d="${d}"/></clipPath>${blur('b1', 1.5)}</defs>
  <g filter="url(#b1)">
  ${''/* the humpback's low hump with a small swept-back dorsal fin on it (bases hidden behind the body) */}
  <path d="M640,156 C590,142 530,146 480,170 L640,172 Z" fill="#1f364a"/>
  <path d="M524,170 C500,162 468,146 436,134 C440,150 440,168 428,190 Z" fill="#1d3346"/>
  <path d="${d}" fill="url(#w)"/>
  <g clip-path="url(#c)"><g fill="none" stroke="#8aa3b3" stroke-width="2.5" opacity=".45">${grooves}</g><g fill="#2a4255">${knobs}</g></g>
  <circle cx="1180" cy="214" r="5" fill="#0e1a24"/></g>`;
}, 0.5);
// the humpback's long flipper, a moving part
asset('whale_fin', 328, 148, () => `<defs>${blur('b1', 1.5)}</defs>
  <path d="M324,6 C264,68 154,122 4,144 C84,108 184,56 234,4 Z" fill="#7d97a8" filter="url(#b1)"/>`, 0.5);

// ===== MORE CREATURES =====
function normalsOf(pts) {
  return pts.map((p, i) => {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], d = Math.hypot(dx, dy) || 1;
    return [-dy / d, dx / d];
  });
}
function taperW(pts, ws) {
  const N = normalsOf(pts), L = [], Rt = [];
  pts.forEach((p, i) => { const w = ws[i] / 2; L.push([p[0] + N[i][0] * w, p[1] + N[i][1] * w]); Rt.push([p[0] - N[i][0] * w, p[1] - N[i][1] * w]); });
  return smooth(L.concat(Rt.reverse()), true);
}

asset('seahorse', 130, 230, () => {
  const pts = [[62, 48], [52, 72], [46, 100], [48, 128], [56, 150], [62, 168], [60, 186], [52, 198], [42, 200], [36, 192], [40, 183], [48, 185]];
  const ws = [24, 32, 36, 35, 30, 22, 15, 11, 8, 7, 6, 5];
  const body = taperW(pts, ws), N = normalsOf(pts);
  let rings = '';
  for (let i = 1; i < pts.length - 1; i++) for (const t of [0, 0.5]) {
    const j = Math.min(pts.length - 1, i + 1);
    const p = [pts[i][0] + (pts[j][0] - pts[i][0]) * t, pts[i][1] + (pts[j][1] - pts[i][1]) * t], w = (ws[i] + (ws[j] - ws[i]) * t) / 2, n = N[i];
    rings += `<path d="M${f(p[0] + n[0] * w)},${f(p[1] + n[1] * w)} L${f(p[0] - n[0] * w)},${f(p[1] - n[1] * w)}"/>`;
  }
  const head = 'M50,42 C48,22 62,12 76,16 C86,19 90,28 88,34 L118,36 C123,37 123,43 118,44 L86,46 C80,54 64,58 54,54 Z';
  let dots = ''; for (let i = 0; i < 26; i++) dots += `<circle cx="${f(rand(30, 90))}" cy="${f(rand(20, 200))}" r="${f(rand(1, 2.4))}" fill="#fff6d0" opacity=".7"/>`;
  return `<defs>${lin('sh', [[0, '#b8650f'], [0.5, '#f2a93a'], [1, '#ffd98a']], 0, 0, 1, 0)}<clipPath id="c"><path d="${body}"/><path d="${head}"/></clipPath></defs>
  <path d="${body}" fill="url(#sh)"/><path d="${head}" fill="url(#sh)"/>
  <path d="M60,18 L57,5 L64,13 L68,3 L71,14 L77,8 L75,20 Z" fill="#e8962c" stroke="#7a3f08" stroke-width="1.2"/>
  <g clip-path="url(#c)"><g stroke="#7a3f08" stroke-width="1.6" opacity=".45">${rings}</g>${dots}</g>
  <path d="${body}" fill="none" stroke="#6a3505" stroke-width="1.6"/><path d="${head}" fill="none" stroke="#6a3505" stroke-width="1.6"/>
  ${eye(73, 30, 4.5, '#ffcf6a')}`;
});
asset('seahorse_fin', 44, 44, () => `<defs>${finRays('fr', 0.3, 90, 4)}</defs>
  <path d="M42,16 C30,4 10,4 4,14 C2,22 2,28 6,32 C14,40 32,38 42,28 Z" fill="#ffe08a" opacity=".75"/>
  <path d="M42,16 C30,4 10,4 4,14 C2,22 2,28 6,32 C14,40 32,38 42,28 Z" fill="url(#fr)"/>`);

asset('octo_body', 170, 150, () => {
  const mantle = 'M60,98 C48,52 88,14 128,18 C160,22 172,58 162,90 C152,114 122,124 96,120 C80,118 66,112 60,98 Z';
  const head = 'M26,104 C24,84 40,72 60,72 C82,72 96,88 94,106 C92,124 76,134 58,134 C40,134 28,122 26,104 Z';
  let spots = ''; for (let i = 0; i < 40; i++) spots += `<circle cx="${f(rand(25, 168))}" cy="${f(rand(18, 134))}" r="${f(rand(1.5, 5))}" fill="${pick(['#ffb08a', '#8a2a10', '#f08a5a'])}" opacity=".55"/>`;
  return `<defs>${rad('o', [[0, '#f59a62'], [0.55, '#d4552a'], [1, '#8a2a12']], 0.6, 0.3, 0.8)}<clipPath id="c"><path d="${mantle}"/><path d="${head}"/></clipPath>${blur('b6', 6)}</defs>
  <path d="${mantle}" fill="url(#o)"/><path d="${head}" fill="url(#o)"/>
  <g clip-path="url(#c)">${spots}<ellipse cx="120" cy="38" rx="34" ry="10" fill="#fff" opacity=".3" filter="url(#b6)"/></g>
  <path d="${mantle}" fill="none" stroke="#5a1a0a" stroke-width="1.6"/><path d="M30,96 C40,74 80,70 92,96" fill="none" stroke="#5a1a0a" stroke-width="1.4" opacity=".6"/>
  <path d="M30,118 C22,120 16,118 12,114" stroke="#a63c18" stroke-width="7" stroke-linecap="round" fill="none"/>
  <ellipse cx="62" cy="88" rx="11" ry="10" fill="#f6e6a6" stroke="#5a1a0a" stroke-width="1.5"/>
  <rect x="54" y="85" width="16" height="5.5" rx="2.5" fill="#0a0a0a"/><circle cx="66" cy="84" r="2" fill="#fff"/>
  <path d="M50,78 C56,72 68,72 74,78" stroke="#a63c18" stroke-width="4" fill="none" stroke-linecap="round"/>`;
});
asset('octo_arms', 300, 160, () => {
  let back = '', front = '';
  for (let i = 0; i < 8; i++) {
    const by = 56 + i * 7, L = rand(170, 240), ph = rand(0, 6), amp = rand(14, 30), curl = (i % 2 ? 1 : -1) * rand(0.6, 1.2), pts = [];
    for (let k = 0; k <= 16; k++) { const s = k / 16; pts.push([296 - s * L * (1 - 0.25 * s * s), by + Math.sin(s * Math.PI * 1.6 + ph) * amp * s + curl * s * s * s * 60]); }
    const isFront = i % 2 === 0;
    let s = `<path d="${taper(pts, 30, 3)}" fill="url(#${isFront ? 'arm' : 'armd'})" stroke="#5a1a0a" stroke-width="1"/>`;
    if (isFront) {
      const N = normalsOf(pts);
      for (let k = 2; k < 15; k++) { const t = k / 16, w = (30 - 27 * t) / 2 * 0.62; s += `<circle cx="${f(pts[k][0] - N[k][0] * w)}" cy="${f(pts[k][1] - N[k][1] * w)}" r="${f(Math.max(1, (30 - 27 * t) / 6))}" fill="#f6c9a8" stroke="#b5603a" stroke-width=".8"/>`; }
      front += s;
    } else back += s;
  }
  return `<defs>${lin('arm', [[0, '#c84a1e'], [1, '#e8743e']], 0, 0, 1, 0)}${lin('armd', [[0, '#8a2a12'], [1, '#b8441c']], 0, 0, 1, 0)}</defs>${back}${front}`;
});

asset('dolphin_body', 540, 200, () => {
  const body = 'M535,118 C528,108 505,100 485,98 C470,80 440,66 400,62 C330,56 240,64 160,84 C110,96 70,108 40,114 L40,128 C80,132 120,140 170,146 C260,158 360,160 430,150 C470,144 500,136 515,130 C525,126 534,124 535,118 Z';
  return `<defs>${lin('d', [[0, '#4a5c6b'], [0.5, '#748897'], [0.63, '#b3c2cc'], [0.72, '#e6ecf0'], [1, '#f4f7f8']])}${lin('fin', [[0, '#5d7080'], [1, '#3e4f5c']])}<clipPath id="c"><path d="${body}"/></clipPath>${blur('b8', 8)}</defs>
  <path d="${body}" fill="url(#d)"/>
  <g clip-path="url(#c)"><ellipse cx="360" cy="76" rx="150" ry="10" fill="#fff" opacity=".3" filter="url(#b8)"/></g>
  <path d="${body}" fill="none" stroke="#2c3a44" stroke-width="1.4" opacity=".55"/>
  <path d="M535,119 C515,124 495,126 476,121" fill="none" stroke="#2c3a44" stroke-width="2" opacity=".7"/>
  <circle cx="455" cy="108" r="4.5" fill="#0c1216"/><circle cx="456.5" cy="106.5" r="1.4" fill="#fff"/>
  <path d="M426,66 C430,64 434,64 438,66" stroke="#2c3a44" stroke-width="2" fill="none" opacity=".6"/>`;
});
asset('dolphin_dorsal', 70, 82, () => `<defs>${lin('fin', [[0, '#5d7080'], [1, '#3e4f5c']])}</defs>
  <path d="M66,62 C56,28 36,8 4,2 C16,24 18,44 6,66 L6,80 L66,80 Z" fill="url(#fin)"/>`);
asset('dolphin_pec', 68, 58, () => `<defs>${lin('fin', [[0, '#5d7080'], [1, '#3e4f5c']])}</defs>
  <path d="M64,2 C54,27 29,47 2,54 C16,32 24,17 26,2 Z" fill="url(#fin)"/>`);
asset('dolphin_tail', 140, 130, () => `<defs>${lin('t', [[0, '#55697a'], [1, '#3c4c58']])}</defs>
  <path d="M136,55 C110,50 70,30 20,6 C30,30 50,50 60,62 C50,74 30,94 20,118 C70,94 110,74 136,69 Z" fill="url(#t)"/>`);

asset('lion_body', 280, 220, () => {
  const body = fishPath(40, 120, 200, 82, { top: 0.5, bot: 0.45, nose: 0.5, ped: 0.15, hump: 0.5 });
  let spines = '', mem = [];
  for (let k = 0; k < 13; k++) {
    const bx = 205 - k * 11, by = 86 + Math.pow((k - 6) / 6, 2) * 16, tx = bx - 28 - k * 2, ty = 8 + rand(-6, 6) + k * 2.5;
    mem.push([bx, by + 6], [bx + (tx - bx) * 0.7, by + (ty - by) * 0.7]);
    spines += `<path d="M${f(bx)},${f(by)} L${f(tx)},${f(ty)}" stroke="#f6e7d4" stroke-width="3"/><path d="M${f(bx)},${f(by)} L${f(tx)},${f(ty)}" stroke="#8a2416" stroke-width="3" stroke-dasharray="7 6"/>`;
  }
  const memD = smooth(mem.filter((_, i) => i % 2 === 1).concat(mem.filter((_, i) => i % 2 === 0).reverse()), true);
  let stripes = '';
  for (let k = -2; k < 16; k++) { const x = 30 + k * 14; stripes += `<path d="M${x},0 C${x + 7},60 ${x - 7},140 ${x + 4},220" stroke-width="${k % 2 ? 4 : 8}"/>`; }
  let anal = '';
  for (let k = 0; k < 4; k++) { const bx = 120 - k * 10; anal += `<path d="M${bx},156 L${bx - 26},${196 + k * 3}" stroke="#f6e7d4" stroke-width="2.5"/><path d="M${bx},156 L${bx - 26},${196 + k * 3}" stroke="#8a2416" stroke-width="2.5" stroke-dasharray="6 5"/>`; }
  return `<defs><clipPath id="c"><path d="${body}"/></clipPath>${shadeDefs()}</defs>
  <path d="${memD}" fill="#d0604a" opacity=".5"/>${spines}${anal}
  <path d="${body}" fill="#f4e2cc"/>
  <g clip-path="url(#c)"><g fill="none" stroke="#7a2416">${stripes}</g><path d="${body}" fill="url(#shade)"/></g>
  <path d="${body}" fill="none" stroke="#4a160c" stroke-width="1.6"/>
  <path d="M210,92 C206,78 214,70 220,74 M218,90 C220,78 228,74 232,80" stroke="#c8604a" stroke-width="3" fill="none"/>
  ${eye(214, 104, 6.5, '#d8a040')}`;
});
asset('lion_fin', 200, 160, () => {
  let rays = '', ends = [];
  for (let k = 0; k <= 10; k++) {
    const a = (100 + k * 9) * Math.PI / 180, r = rand(130, 160), ex = 190 + Math.cos(a) * r, ey = 20 + Math.sin(a) * r * 0.85;
    ends.push([ex, ey]);
    rays += `<path d="M190,20 L${f(ex)},${f(ey)}" stroke="#f6e7d4" stroke-width="2.6"/><path d="M190,20 L${f(ex)},${f(ey)}" stroke="#8a2416" stroke-width="2.6" stroke-dasharray="8 7"/>`;
  }
  const mem = smooth([[190, 20], ...ends.map(([x, y]) => [190 + (x - 190) * 0.9, 20 + (y - 20) * 0.9])], true);
  return `<defs>${finRays('fr', 0.18, 30, 6)}</defs><path d="${mem}" fill="#d8644a" opacity=".6"/><path d="${mem}" fill="url(#fr)"/>${rays}`;
});
asset('lion_tail', 80, 90, () => {
  let spots = ''; for (let i = 0; i < 18; i++) spots += `<circle cx="${f(rand(10, 60))}" cy="${f(rand(12, 78))}" r="${f(rand(1.2, 2.4))}" fill="#8a2416" opacity=".7"/>`;
  return `<defs>${finRays('fr', 0.2, 90, 5)}<clipPath id="c"><path d="M78,38 C60,30 34,8 10,12 C2,30 2,60 10,78 C34,82 60,60 78,52 Z"/></clipPath></defs>
  <path d="M78,38 C60,30 34,8 10,12 C2,30 2,60 10,78 C34,82 60,60 78,52 Z" fill="#f4e2cc" opacity=".6"/><g clip-path="url(#c)">${spots}<rect width="80" height="90" fill="url(#fr)"/></g>`;
});

asset('crab_body', 220, 140, () => {
  const shell = 'M45,85 C45,50 80,40 110,40 C140,40 175,50 175,85 C175,105 145,118 110,118 C75,118 45,105 45,85 Z';
  const claw = (s) => { const t = (x) => (s > 0 ? x : 220 - x);
    return `<path d="M${t(58)},92 C${t(44)},90 ${t(36)},80 ${t(34)},70" stroke="#b83a20" stroke-width="12" stroke-linecap="round" fill="none"/>` +
      `<path d="M${t(10)},42 C${t(0)},62 ${t(12)},86 ${t(36)},84 C${t(52)},82 ${t(58)},70 ${t(52)},58 C${t(46)},52 ${t(40)},58 ${t(36)},64 C${t(30)},56 ${t(32)},44 ${t(42)},36 C${t(30)},28 ${t(16)},32 ${t(10)},42 Z" fill="url(#cr)" stroke="#6a1a0a" stroke-width="2"/>`; };
  let bumps = ''; for (let i = 0; i < 18; i++) bumps += `<circle cx="${f(rand(60, 160))}" cy="${f(rand(48, 100))}" r="${f(rand(1.5, 3.5))}" fill="#ff9a70" opacity=".6"/>`;
  return `<defs>${rad('cr', [[0, '#f27a4a'], [0.6, '#d2452a'], [1, '#8a2412']], 0.45, 0.3, 0.8)}<clipPath id="c"><path d="${shell}"/></clipPath>${blur('b4', 4)}</defs>
  ${claw(1)}${claw(-1)}
  <path d="M96,48 L92,22 M124,48 L128,22" stroke="#b83a20" stroke-width="5" stroke-linecap="round"/>
  <circle cx="92" cy="20" r="6.5" fill="#111"/><circle cx="128" cy="20" r="6.5" fill="#111"/><circle cx="94" cy="18" r="2" fill="#fff"/><circle cx="130" cy="18" r="2" fill="#fff"/>
  <path d="${shell}" fill="url(#cr)"/><g clip-path="url(#c)">${bumps}<ellipse cx="105" cy="55" rx="40" ry="8" fill="#fff" opacity=".3" filter="url(#b4)"/></g>
  <path d="${shell}" fill="none" stroke="#6a1a0a" stroke-width="2"/>
  <path d="M100,104 C106,108 114,108 120,104" stroke="#6a1a0a" stroke-width="2" fill="none"/>`;
});
asset('crab_legs', 100, 80, () => {
  let s = '';
  for (let k = 0; k < 3; k++) { const y0 = 10 + k * 10; s += `<path d="M96,${y0} L56,${y0 - 12 + k * 4} L${18 + k * 8},${y0 + 44}" stroke="#6a1a0a" stroke-width="10" stroke-linecap="round" stroke-linejoin="round" fill="none"/><path d="M96,${y0} L56,${y0 - 12 + k * 4} L${18 + k * 8},${y0 + 44}" stroke="#d2452a" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`; }
  return s;
});
asset('seastar', 130, 130, () => {
  const p = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, r = i % 2 ? 22 : 60; p.push([65 + Math.cos(a) * r, 65 + Math.sin(a) * r]); }
  let bumps = ''; for (let i = 0; i < 5; i++) { const a = -Math.PI / 2 + (i * 2 * Math.PI) / 5; for (let k = 1; k <= 5; k++) bumps += `<circle cx="${f(65 + Math.cos(a) * k * 10)}" cy="${f(65 + Math.sin(a) * k * 10)}" r="${f(3.4 - k * 0.4)}" fill="#ffd9a0"/>`; }
  return `<defs>${rad('s', [[0, '#ffa860'], [0.7, '#e2582a'], [1, '#b03a16']])}</defs><path d="${smooth(p, true)}" fill="url(#s)" stroke="#7a2a0e" stroke-width="2"/>${bumps}`;
});

// crawling sea star: five copies of one arm, rotated round a centre disc that hides their roots
asset('seastar_arm', 50, 66, () => {
  let bumps = ''; for (let k = 0; k < 5; k++) bumps += `<circle cx="25" cy="${f(52 - k * 10)}" r="${f(3.4 - k * 0.4)}" fill="#ffd9a0"/>`;
  return `<defs>${lin('a', [[0, '#b03a16'], [0.35, '#e2582a'], [1, '#e2582a']])}</defs>
  <path d="M3,66 C5,44 14,20 20,8 C22,3 28,3 30,8 C36,20 45,44 47,66 Z" fill="url(#a)" stroke="#7a2a0e" stroke-width="2"/>${bumps}`;
});
asset('seastar_disc', 60, 60, () => {
  let bumps = ''; for (let i = 0; i < 5; i++) { const a = -Math.PI / 2 + (i * 2 * Math.PI) / 5; bumps += `<circle cx="${f(30 + Math.cos(a) * 12)}" cy="${f(30 + Math.sin(a) * 12)}" r="3.4" fill="#ffd9a0"/>`; }
  return `<defs>${rad('d', [[0, '#ffa860'], [0.75, '#e86a34'], [1, '#e2582a']])}</defs><circle cx="30" cy="30" r="27" fill="url(#d)"/>${bumps}<circle cx="30" cy="30" r="3" fill="#c84a1e"/>`;
});

asset('eel', 260, 120, () => {
  const body = 'M260,50 C210,40 160,34 120,38 C90,40 62,38 40,44 C20,50 8,60 10,70 L92,70 C120,80 160,94 200,100 C226,104 244,106 260,108 Z';
  let teeth = ''; for (let x = 16; x < 84; x += 8) teeth += `<path d="M${x},70 L${x + 3},76 L${x + 6},70 Z" fill="#f4f0e0"/>`;
  return `<defs>${lin('e', [[0, '#5d6f1e'], [0.6, '#8ea03a'], [1, '#c7cf72']])}${lin('dk', [[0, '#020506', 0], [0.5, '#020506', 0], [0.92, '#020506', 0.95], [1, '#020506', 1]], 0, 0, 1, 0)}<clipPath id="c"><path d="${body}"/></clipPath></defs>
  <path d="${body}" fill="url(#e)"/>
  <g clip-path="url(#c)">${scales(0, 30, 260, 90, 11, '#26300c', ['#7c8f2a', '#8fa232', '#6b7c22', '#a0b040'])}</g>
  <path d="M260,48 C210,36 160,30 120,34 C90,36 62,34 40,42" fill="none" stroke="#3a4610" stroke-width="5" stroke-linecap="round"/>
  <path d="${body}" fill="url(#dk)"/><path d="${body}" fill="none" stroke="#26300c" stroke-width="1.8"/>${teeth}
  <circle cx="50" cy="52" r="6" fill="#e8d860"/><circle cx="50" cy="52" r="3.4" fill="#0a0a0a"/><circle cx="51" cy="50.5" r="1.2" fill="#fff"/>
  <circle cx="20" cy="58" r="2" fill="#26300c"/>`;
});
asset('eel_jaw', 100, 40, () => {
  let teeth = ''; for (let x = 10; x < 80; x += 8) teeth += `<path d="M${x},9 L${x + 3},3 L${x + 6},9 Z" fill="#f4f0e0"/>`;
  return `<defs>${lin('j', [[0, '#a8b44a'], [1, '#d7dc8a']])}</defs>
  <path d="M92,6 C70,6 30,7 6,10 C10,22 30,28 60,26 C76,24 88,18 94,10 Z" fill="url(#j)" stroke="#26300c" stroke-width="1.6"/>${teeth}`;
});

// snapping (pistol) shrimp, drawn head-up so it can pop out of a sponge tube; the big claw's
// movable finger is a separate image (shrimp_finger) hinged at local [84,36]
asset('shrimp', 120, 200, () => {
  const dk = '#8e1f10', wh = '#fff1e4';
  let abd = '';
  for (let i = 0; i < 6; i++) {
    const y0 = 106 + i * 14, w = 15 - i * 1.4;
    abd += `<rect x="${f(60 - w)}" y="${y0}" width="${f(w * 2)}" height="17" rx="${f(w * 0.7)}" fill="url(#bd)" stroke="${dk}" stroke-width="1.2"/>`;
    if (i % 2 === 0) abd += `<rect x="${f(60 - w + 2)}" y="${y0 + 6}" width="${f(w * 2 - 4)}" height="4" rx="2" fill="${wh}" opacity=".85"/>`;
  }
  return `<defs>${lin('bd', [[0, dk], [0.3, '#e0442c'], [0.5, '#ff8a66'], [0.7, '#e0442c'], [1, dk]], 0, 0, 1, 0)}
    ${lin('pm', [[0, '#b22a16'], [0.45, '#f05a3a'], [0.8, '#ff9a78'], [1, '#c8341c']], 0, 0, 1, 0)}</defs>
  <g fill="none" stroke-linecap="round">
    <path d="M54,58 C40,30 22,14 4,2" stroke="${dk}" stroke-width="2.2"/><path d="M54,58 C40,30 22,14 4,2" stroke="${wh}" stroke-width="1" stroke-dasharray="5 4"/>
    <path d="M66,58 C80,28 98,16 116,4" stroke="${dk}" stroke-width="2.2"/><path d="M66,58 C80,28 98,16 116,4" stroke="${wh}" stroke-width="1" stroke-dasharray="5 4"/>
    <path d="M57,54 C52,40 46,34 38,30" stroke="#e0442c" stroke-width="1.6"/><path d="M63,54 C68,40 74,34 82,32" stroke="#e0442c" stroke-width="1.6"/>
    <g stroke="#d03a24" stroke-width="2.4"><path d="M47,96 L34,110"/><path d="M47,102 L36,118"/><path d="M73,96 L86,110"/><path d="M73,102 L84,118"/></g>
    <path d="M47,88 L37,72 L35,60" stroke="#d03a24" stroke-width="3.2"/><path d="M35,60 L31,50 M35,60 L38,50" stroke="#d03a24" stroke-width="2.2"/>
    <path d="M73,90 C82,86 86,80 86,72" stroke="#c8341c" stroke-width="6"/>
  </g>
  ${abd}
  <path d="M44,110 C41,90 43,73 51,65 L60,45 L69,65 C77,73 79,90 76,110 Z" fill="url(#bd)" stroke="${dk}" stroke-width="1.4"/>
  <path d="M46,88 C54,85 66,85 74,88 L74,93 C66,90 54,90 46,93 Z" fill="${wh}" opacity=".85"/>
  <path d="M52,72 C56,68 64,68 68,72" fill="none" stroke="#ffb59a" stroke-width="2" opacity=".7"/>
  <path d="M78,72 C74,56 76,40 84,34 C88,28 94,26 97,24 C99,34 100,48 99,58 C98,70 92,76 86,76 Z" fill="url(#pm)" stroke="${dk}" stroke-width="1.4"/>
  <path d="M88,40 C92,36 95,32 97,26" fill="none" stroke="${wh}" stroke-width="2.4" stroke-linecap="round" opacity=".9"/>
  <g stroke="${dk}" stroke-width="1.6"><path d="M55,64 L49,57"/><path d="M65,64 L71,57"/></g>
  <circle cx="48" cy="56" r="5.2" fill="#111"/><circle cx="72" cy="56" r="5.2" fill="#111"/>
  <circle cx="46.6" cy="54.4" r="1.7" fill="#fff"/><circle cx="70.6" cy="54.4" r="1.7" fill="#fff"/>`;
});
asset('shrimp_finger', 24, 30, () => `<path d="M3,28 C0,18 3,8 11,2 C15,6 14,14 11,28 Z" fill="#e0442c" stroke="#8e1f10" stroke-width="1.4"/>
  <path d="M10,4 C8,8 7,12 7,16" fill="none" stroke="#fff1e4" stroke-width="2" stroke-linecap="round"/>`);

// garden eels: drawn standing up out of the sand, base centre at [18,240], head curled forward (to the right)
function gardenEel(kind) {
  const pts = [[18, 240], [18, 200], [17, 160], [17, 122], [18, 90], [20, 64], [24, 44], [30, 32], [38, 25], [46, 23]];
  const ws = [11, 11, 11, 11, 11, 10.5, 10, 9.5, 9, 8];
  const body = taperW(pts, ws), N = normalsOf(pts);
  const head = 'M38,18 C46,14 56,17 57,24 C57,30 50,32 42,31 C38,30 35,26 35,23 Z';
  let marks = '';
  if (kind === 'a') {
    // spotted garden eel: pale with fine dark speckles and a black blotch at the gill
    for (let i = 0; i < 70; i++) marks += `<circle cx="${f(rand(8, 56))}" cy="${f(rand(14, 240))}" r="${f(rand(0.7, 1.6))}" fill="#2b2418" opacity=".75"/>`;
    marks += '<ellipse cx="26" cy="47" rx="6" ry="7.5" fill="#15110a"/>';
  } else {
    // splendid garden eel: orange with white rings
    for (let i = 1; i < pts.length - 2; i++) for (const t of [0.15, 0.6]) {
      const j = i + 1, p = [pts[i][0] + (pts[j][0] - pts[i][0]) * t, pts[i][1] + (pts[j][1] - pts[i][1]) * t], n = N[i], w = 7;
      marks += `<path d="M${f(p[0] + n[0] * w)},${f(p[1] + n[1] * w)} L${f(p[0] - n[0] * w)},${f(p[1] - n[1] * w)}" stroke="#fff4e6" stroke-width="4.5"/>`;
    }
  }
  const c = kind === 'a' ? ['#cbbd98', '#f4ecd6', '#d8caa6'] : ['#d4560e', '#ff9a3c', '#e2661a'];
  const edge = kind === 'a' ? '#6d6045' : '#8a3204';
  return `<defs>${lin('g', [[0, c[0]], [0.5, c[1]], [1, c[2]]], 0, 0, 1, 0)}<clipPath id="c"><path d="${body}"/><path d="${head}"/></clipPath></defs>
  <path d="${body}" fill="url(#g)"/><path d="${head}" fill="url(#g)"/>
  <g clip-path="url(#c)">${marks}</g>
  <path d="${body}" fill="none" stroke="${edge}" stroke-width="1.4"/><path d="${head}" fill="none" stroke="${edge}" stroke-width="1.4"/>
  <path d="M50,28 C53,28 55,27 56,25" fill="none" stroke="${edge}" stroke-width="1.3" stroke-linecap="round"/>
  <path d="M28,52 C34,50 37,54 34,58 Z" fill="${c[1]}" stroke="${edge}" stroke-width="1"/>
  ${eye(46, 21, 3.2, kind === 'a' ? '#f2e2a0' : '#ffe08a')}`;
}
asset('geel_a', 60, 240, () => gardenEel('a'));
asset('geel_b', 60, 240, () => gardenEel('b'));
// the burrow each garden eel lives in
asset('geel_hole', 40, 14, () => `<defs>${rad('h', [[0, '#1d1708', 0.9], [0.55, '#3a2f16', 0.6], [1, '#6b5a30', 0]])}</defs><ellipse cx="20" cy="7" rx="20" ry="7" fill="url(#h)"/>`);
// coral spawn bundles (full-moon nights) and the moon's glow through the surface
asset('spawn_dot', 24, 24, () => `<defs>${rad('s', [[0, '#fff3f6', 1], [0.35, '#ffa3c0', 0.95], [0.7, '#ff6f9a', 0.35], [1, '#ff6f9a', 0]])}</defs><circle cx="12" cy="12" r="12" fill="url(#s)"/>`);
asset('moon_glow', 128, 128, () => `<defs>${rad('m', [[0, '#f6fcff', 0.95], [0.3, '#dff2ff', 0.5], [1, '#bfe6ff', 0]])}</defs><circle cx="64" cy="64" r="64" fill="url(#m)"/>`);

// settings screen icons (checkbox / radio button, normal and focused-row colors)
for (const [suf, c] of [['', '#e6f4fa'], ['_f', '#062038']]) {
  asset('ui_check_on' + suf, 36, 36, () => `<rect x="3" y="3" width="30" height="30" rx="4" fill="none" stroke="${c}" stroke-width="3"/><path d="M9,18 L16,25 L28,10" fill="none" stroke="${c}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>`);
  asset('ui_check_off' + suf, 36, 36, () => `<rect x="3" y="3" width="30" height="30" rx="4" fill="none" stroke="${c}" stroke-width="3"/>`);
  asset('ui_radio_on' + suf, 36, 36, () => `<circle cx="18" cy="18" r="14.5" fill="none" stroke="${c}" stroke-width="3"/><circle cx="18" cy="18" r="7.5" fill="${c}"/>`);
  asset('ui_radio_off' + suf, 36, 36, () => `<circle cx="18" cy="18" r="14.5" fill="none" stroke="${c}" stroke-width="3"/>`);
}

// darkness inside the rock cave, drawn over the eel so it fades into the hole (matches the cave in 'rock')
asset('eel_cave', 170, 130, () => `<defs>${rad('cave', [[0, '#010304'], [0.7, '#081114'], [1, '#1c2c30']])}
  ${lin('ml', [[0, '#fff', 0], [0.22, '#fff', 0], [0.64, '#fff', 1], [1, '#fff', 1]], 0, 0, 1, 0)}
  <mask id="m"><rect width="170" height="130" fill="url(#ml)"/></mask></defs>
  <ellipse cx="85" cy="65" rx="75.4" ry="57.2" fill="url(#cave)" mask="url(#m)"/>`);

asset('diver_body', 300, 130, () => {
  const torso = 'M90,64 C96,44 140,40 200,44 C230,46 250,52 258,64 C252,84 230,94 200,96 C150,98 110,94 92,86 Z';
  return `<defs>${lin('tank', [[0, '#ffd84a'], [0.5, '#f2b51e'], [1, '#a87808']])}${lin('suit', [[0, '#2c3e50'], [0.6, '#16202a'], [1, '#0a0f14']])}<clipPath id="c"><path d="${torso}"/></clipPath></defs>
  <path d="M286,78 C270,96 250,70 240,32" fill="none" stroke="#1a1a1a" stroke-width="3"/>
  <rect x="100" y="16" width="138" height="30" rx="15" fill="url(#tank)" stroke="#6a4a04" stroke-width="2"/>
  <rect x="236" y="22" width="12" height="12" rx="3" fill="#9aa4ac" stroke="#4a5258" stroke-width="1.5"/>
  <path d="${torso}" fill="url(#suit)"/>
  <g clip-path="url(#c)"><path d="M92,74 C140,70 200,70 258,66" stroke="#1e88c8" stroke-width="6" fill="none"/><rect x="112" y="40" width="12" height="60" fill="#3a444c"/><rect x="110" y="62" width="16" height="12" fill="#9aa4ac"/></g>
  <path d="M236,62 L204,88 L172,96" fill="none" stroke="#141c24" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="170" cy="97" r="7" fill="#22303c"/>
  <path d="M163,93 L181,97 L183,95 L187,103 L182,104 L181,102 L162,99 Z" fill="#f2b51e" stroke="#6a4a04" stroke-width="1.2"/>
  <circle cx="272" cy="62" r="19" fill="#141c24"/>
  <rect x="274" y="50" width="22" height="18" rx="5" fill="#8fdcff" opacity=".9" stroke="#0a0a0a" stroke-width="3"/>
  <path d="M279,54 L286,54" stroke="#fff" stroke-width="2" opacity=".8"/>
  <circle cx="290" cy="77" r="6" fill="#1a1a1a"/>`;
});
asset('diver_leg', 200, 60, () => `<defs>${finRays('fr', 0.25, 0, 6)}</defs>
  <path d="M196,30 L130,32 L64,34" fill="none" stroke="#141c24" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M68,24 L4,8 C0,22 0,40 4,54 L68,44 Z" fill="#1e88c8" stroke="#0c4a70" stroke-width="2"/>
  <path d="M68,24 L4,8 C0,22 0,40 4,54 L68,44 Z" fill="url(#fr)"/>`);

// Scuba Steve's torch beam at night (drawn above the night shade): a soft cone from his hand, aimed ahead and a little down
asset('diver_beam', 640, 300, () => `<defs>${blur('b', 7)}<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="6" y1="90" x2="590" y2="204"><stop offset="0" stop-color="#f4fbff" stop-opacity=".75"/><stop offset=".25" stop-color="#dff3ff" stop-opacity=".42"/><stop offset=".7" stop-color="#c8eaff" stop-opacity=".14"/><stop offset="1" stop-color="#c8eaff" stop-opacity="0"/></linearGradient>${rad('s', [[0, '#ffffff', 1], [0.4, '#eaf7ff', 0.7], [1, '#eaf7ff', 0]])}</defs>
  <path d="M6,86 L620,128 C640,170 640,250 610,286 L6,94 Z" fill="url(#g)" filter="url(#b)"/>
  <circle cx="12" cy="91" r="11" fill="url(#s)"/>`, 0.5);
asset('hook', 60, 120, () => `
  <circle cx="30" cy="8" r="5" fill="none" stroke="#c8d0d8" stroke-width="3"/>
  <path d="M30,13 L30,78 C30,104 6,104 6,82 L6,66 L13,75" fill="none" stroke="#5a646c" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M30,13 L30,78 C30,104 6,104 6,82 L6,66 L13,75" fill="none" stroke="#d8e0e6" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M29,16 L29,74" stroke="#fff" stroke-width="1" opacity=".8"/>`);
asset('bait', 60, 120, () => {
  const pts = [[24, 58], [15, 70], [10, 84], [17, 97], [29, 96], [36, 104], [31, 114], [21, 113]];
  const ws = [8, 9, 9.5, 9.5, 9, 8, 7, 5], N = normalsOf(pts);
  let rings = ''; for (let i = 1; i < pts.length - 1; i++) { const w = ws[i] / 2, n = N[i]; rings += `<path d="M${f(pts[i][0] + n[0] * w)},${f(pts[i][1] + n[1] * w)} L${f(pts[i][0] - n[0] * w)},${f(pts[i][1] - n[1] * w)}"/>`; }
  return `<defs>${lin('w', [[0, '#e88a8a'], [1, '#a84a5a']], 0, 0, 1, 0)}</defs><path d="${taperW(pts, ws)}" fill="url(#w)" stroke="#7a2a3a" stroke-width="1.2"/>
  <g stroke="#7a2a3a" stroke-width="1" opacity=".5">${rings}</g>`;
});

asset('jelly_glow', 260, 260, () => `<defs>${rad('g', [[0, '#ffb3ec', 0.7], [0.45, '#e070d0', 0.25], [1, '#c060d0', 0]])}</defs><circle cx="130" cy="130" r="130" fill="url(#g)"/>`);
asset('glow_dot', 32, 32, () => `<defs>${rad('g', [[0, '#e8ffff', 1], [0.25, '#7ff0ff', 0.75], [1, '#40d8ff', 0]])}</defs><circle cx="16" cy="16" r="16" fill="url(#g)"/>`);
asset('warm_grad', 64, 540, () => `<defs>${lin('w', [[0, '#ff8a3d', 0.95], [0.45, '#ff7a5a', 0.4], [1, '#ff7a5a', 0]])}</defs><rect width="64" height="540" fill="url(#w)"/>`);

// ===== ENVIRONMENT =====
asset('bg_water', 8, 1080, () => `<defs>${lin('w', [[0, '#5ccbe2'], [0.16, '#2aa2c9'], [0.45, '#126d9f'], [0.75, '#0a4a78'], [1, '#063a63']])}</defs><rect width="8" height="1080" fill="url(#w)"/>`);

asset('surface', 2048, 320, () => {
  let lines = '';
  for (let set = 0; set < 3; set++) {
    for (let k = 0; k < 9; k++) {
      const per = 2048 / ri(5, 14), amp = rand(8, 26), y0 = 20 + k * 26 + set * 9, ph = rand(0, 6.28), pts = [];
      for (let x = -32; x <= 2080; x += 32) pts.push([x, y0 + Math.sin((x / per) * 6.283 + ph) * amp + Math.sin((x / (per / 2.7)) * 6.283) * amp * 0.3]);
      lines += `<path d="${smooth(pts)}" stroke-width="${f(rand(2, 5))}" opacity="${f(rand(0.25, 0.6))}"/>`;
    }
  }
  return `<defs>${lin('fade', [[0, '#fff'], [0.55, '#fff', 0.4], [1, '#fff', 0]])}<mask id="m"><rect width="2048" height="320" fill="url(#fade)"/></mask>
    ${lin('top', [[0, '#d8fbff', 0.85], [0.3, '#a8eef8', 0.35], [1, '#a8eef8', 0]])}${blur('b3', 3)}</defs>
  <g mask="url(#m)"><rect width="2048" height="320" fill="url(#top)"/><g fill="none" stroke="#e9ffff" filter="url(#b3)">${lines}</g></g>`;
}, 0.5);

asset('ray', 400, 1100, () => `<defs>${lin('r', [[0, '#eaffff', 0.65], [0.5, '#c8f4ff', 0.25], [1, '#c8f4ff', 0]])}${blur('b', 22)}</defs>
  <path d="M175,-20 L225,-20 L340,1100 L60,1100 Z" fill="url(#r)" filter="url(#b)"/>`, 0.5);

asset('reef_far', 2000, 440, () => {
  const pts = [[0, 440]]; const p = [rand(0, 6), rand(0, 6), rand(0, 6)];
  const bumps = Array.from({ length: 7 }, () => [rand(0, 2000), rand(60, 150), rand(40, 120)]);
  for (let x = 0; x <= 2000; x += 15) {
    let y = 300 - 40 * Math.sin(x / 260 + p[0]) - 25 * Math.sin(x / 97 + p[1]) - 10 * Math.sin(x / 31 + p[2]);
    for (const [bx, bh, bw] of bumps) y -= bh * Math.exp(-((x - bx) ** 2) / (2 * bw * bw));
    pts.push([x, y]);
  }
  pts.push([2000, 440]);
  let deco = '';
  for (let i = 0; i < 26; i++) {
    const idx = ri(2, pts.length - 3), [x, y] = pts[idx];
    if (R() < 0.5) deco += branchy(x, y + 4, { len: rand(18, 34), w: rand(4, 7), depth: 4, spread: 0.45, split: 2, trunks: ri(1, 3), fanOut: 0.5 }, ['#164d72', '#164d72']).svg;
    else deco += branchy(x, y + 4, { len: rand(26, 50), w: 3, depth: 5, spread: 0.32, split: 2, upright: 0.2 }, ['#164d72', '#164d72']).svg;
  }
  return `<defs>${lin('g', [[0, '#1a5f88'], [1, '#0d4166']])}${blur('b', 1.4)}</defs><g filter="url(#b)"><path d="${smooth(pts)}" fill="url(#g)"/>${deco.replace(/#164d72/g, '#195a83')}</g>`;
}, 0.5);

asset('reef_mid', 2048, 520, () => {
  const W = 2048, H = 520; let rocks = '', corals = '';
  const mounds = [];
  for (let x = -60; x < W + 60; x += rand(150, 260)) mounds.push([x, rand(250, 360), rand(120, 220), rand(80, 170)]);
  for (const [x, y, rx, ry] of mounds) {
    const g = uid('rk'), pts = [];
    for (let i = 0; i < 18; i++) { const a = Math.PI + (i / 17) * Math.PI; pts.push([x + Math.cos(a) * rx * rand(0.85, 1.1), y + Math.sin(a) * ry * rand(0.8, 1.1)]); }
    pts.push([x + rx, H + 10], [x - rx, H + 10]);
    rocks += `<defs>${rad(g, [[0, '#4f7f8b'], [0.7, '#2f5b68'], [1, '#1d4250']], 0.4, 0.2, 0.9)}</defs><path d="${smooth(pts, true)}" fill="url(#${g})"/>`;
    for (let k = 0; k < 10; k++) rocks += `<ellipse cx="${f(x + rand(-rx, rx) * 0.8)}" cy="${f(y + rand(-ry * 0.6, ry))}" rx="${f(rand(3, 12))}" ry="${f(rand(2, 6))}" fill="#173844" opacity=".35"/>`;
  }
  const palette = [['#a8505e', '#c77b8a', '#e7a9b4'], ['#a8682e', '#d29a5a', '#f2c690'], ['#5c4787', '#8a6bb0', '#b9a0dc'], ['#3d7564', '#6aa08c', '#9fd0bb'], ['#9c8636', '#c9b062', '#ecd894']];
  const tops = mounds.map(([x, y, rx, ry]) => [x, y - ry]);
  for (let i = 0; i < 26; i++) {
    const [mx, my] = pick(tops), x = mx + rand(-110, 110), y = my + rand(30, 90), col = pick(palette), t = R();
    if (x < -40 || x > W + 40) continue;
    if (t < 0.25) corals += brainCoral(x, y, rand(40, 75), rand(30, 50), col, col[0]);
    else if (t < 0.5) corals += branchy(x, y, { len: rand(26, 40), w: rand(7, 11), depth: 4, spread: 0.5, split: 2, trunks: ri(2, 4), fanOut: 0.45, base: 20 }, [col[0], col[1], col[2], col[2]]).svg;
    else if (t < 0.7) corals += branchy(x, y, { len: rand(40, 60), w: 4, depth: 6, spread: 0.3, split: 2, upright: 0.25, lmin: 0.7, lmax: 0.85 }, [col[0], col[1]]).svg;
    else if (t < 0.85) corals += tubeSponge(x, y, rand(0.35, 0.55), col);
    else corals += tableCoral(x, y, rand(70, 120), col);
  }
  return `${rocks}${corals}`;
});

asset('sand', 2048, 300, () => {
  const W = 2048, H = 300, top = [];
  for (let x = 0; x <= W; x += 20) top.push([x, 70 + 18 * Math.sin(x / 210 + 1) + 10 * Math.sin(x / 83)]);
  const shape = smooth([[0, H + 5], ...top, [W, H + 5]], false) + ' Z';
  let ripples = '';
  for (let y = 95; y < H; y += 13) {
    const pts = []; const ph = rand(0, 6);
    for (let x = -20; x <= W + 20; x += 30) pts.push([x, y + Math.sin(x / 45 + ph) * 3.5 + Math.sin(x / 210) * 6]);
    ripples += `<path d="${smooth(pts)}" stroke="#7a6d4c" stroke-width="2.2" opacity=".22"/><path d="${smooth(pts.map(([a, b]) => [a, b - 3]))}" stroke="#fff6d8" stroke-width="1.6" opacity=".25"/>`;
  }
  let peb = '';
  for (let i = 0; i < 160; i++) { const x = rand(0, W), y = rand(95, H); peb += `<ellipse cx="${f(x)}" cy="${f(y)}" rx="${f(rand(2, 7))}" ry="${f(rand(1.5, 4))}" fill="${pick(['#8f8466', '#b5a882', '#6e6650', '#d6ccaa'])}" opacity=".8"/>`; }
  const star = (cx, cy, r, rot, col) => { const p = []; for (let i = 0; i < 10; i++) { const a = rot + (i * Math.PI) / 5, rr = i % 2 ? r * 0.42 : r; p.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * 0.55]); } return `<path d="${smooth(p, true)}" fill="${col}" stroke="#8a3410" stroke-width="2"/>`; };
  const shell = (cx, cy, r) => { let s = `<path d="M${cx - r},${cy} A${r},${r * 0.8} 0 0 1 ${cx + r},${cy} L${cx + r * 0.3},${cy + r * 0.35} L${cx - r * 0.3},${cy + r * 0.35} Z" fill="#f2dcc6" stroke="#a88a70" stroke-width="1.5"/>`; for (let k = -3; k <= 3; k++) s += `<path d="M${cx},${cy + r * 0.3} L${f(cx + k * r * 0.3)},${f(cy - r * 0.7 + Math.abs(k) * r * 0.12)}" stroke="#b9967a" stroke-width="1.2"/>`; return s; };
  return `<defs>${lin('s', [[0, '#d7d0a6'], [0.4, '#c3b98d'], [1, '#8f876a']])}<clipPath id="c"><path d="${shape}"/></clipPath>${lin('edge', [[0, '#000', 0], [0.12, '#000', 0], [0.35, '#000', 0.0], [1, '#0a2030', 0.35]])}</defs>
  <path d="${shape}" fill="url(#s)"/><g clip-path="url(#c)" fill="none">${ripples}</g><g clip-path="url(#c)">${peb}
  ${shell(1100, 160, 14)}${shell(320, 150, 11)}${shell(1820, 170, 12)}
  <rect width="${W}" height="${H}" fill="url(#edge)"/></g>`;
});

asset('sand_front', 2048, 200, () => {
  const W = 2048, H = 200, top = [];
  for (let x = 0; x <= W; x += 20) top.push([x, 22 + 7 * Math.sin(x / 150 + 2) + 4 * Math.sin(x / 47)]);
  const shape = smooth([[0, H + 5], ...top, [W, H + 5]], false) + ' Z';
  let ripples = '';
  for (let y = 40; y < H; y += 13) {
    const pts = []; const ph = rand(0, 6);
    for (let x = -20; x <= W + 20; x += 30) pts.push([x, y + Math.sin(x / 45 + ph) * 3.5 + Math.sin(x / 210) * 6]);
    ripples += `<path d="${smooth(pts)}" stroke="#7a6d4c" stroke-width="2.2" opacity=".22"/><path d="${smooth(pts.map(([a, b]) => [a, b - 3]))}" stroke="#fff6d8" stroke-width="1.6" opacity=".25"/>`;
  }
  let peb = '';
  for (let i = 0; i < 120; i++) peb += `<ellipse cx="${f(rand(0, W))}" cy="${f(rand(40, H))}" rx="${f(rand(2, 8))}" ry="${f(rand(1.5, 4.5))}" fill="${pick(['#8f8466', '#b5a882', '#6e6650', '#d6ccaa'])}" opacity=".8"/>`;
  const star = (cx, cy, r, rot, col) => { const p = []; for (let i = 0; i < 10; i++) { const a = rot + (i * Math.PI) / 5, rr = i % 2 ? r * 0.42 : r; p.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr * 0.55]); } return `<path d="${smooth(p, true)}" fill="${col}" stroke="#8a3410" stroke-width="2"/>`; };
  return `<defs>${lin('s', [[0, '#c9bf93'], [0.5, '#b0a67e'], [1, '#8f876a']])}<clipPath id="c"><path d="${shape}"/></clipPath>${lin('edge', [[0, '#000', 0], [1, '#0a2030', 0.3]])}${lin('lip', [[0, '#fff8dc', 0.5], [1, '#fff8dc', 0]])}</defs>
  <path d="${shape}" fill="url(#s)"/><g clip-path="url(#c)" fill="none">${ripples}</g><g clip-path="url(#c)">${peb}
  ${star(520, 110, 28, 0.3, '#f07a2c')}${star(1560, 150, 24, 1.1, '#e85a3a')}
  <rect y="10" width="${W}" height="30" fill="url(#lip)"/><rect width="${W}" height="${H}" fill="url(#edge)"/></g>`;
});

// near-layer decorations (full colour)
asset('coral_brain', 320, 200, () => brainCoral(160, 190, 150, 120, ['#7a6a2e', '#b59a4a', '#e4cf86'], '#5e4f1c'));
asset('coral_stag', 380, 340, () => branchy(190, 335, { len: 64, w: 15, depth: 5, spread: 0.55, split: 2, trunks: 4, fanOut: 0.42, base: 40, wk: 0.74 }, ['#a2481e', '#f0884b', '#ffc49a', '#ffe1c8']).svg);
asset('coral_stag2', 340, 300, () => branchy(170, 296, { len: 56, w: 13, depth: 5, spread: 0.6, split: 2, trunks: 3, fanOut: 0.5, base: 30 }, ['#5b2f86', '#9a5fd0', '#d2b0f5', '#f0e0ff']).svg);
asset('seafan', 380, 420, () => {
  const { svg, out } = branchy(190, 415, { len: 70, w: 9, depth: 7, spread: 0.36, split: 2, upright: 0.18, lmin: 0.72, lmax: 0.86, wk: 0.68 }, ['#5a1f6e', '#a2399e', '#e07ad4']);
  let lattice = '';
  const pts = out.segs.map((s) => [s.ex, s.ey]);
  for (let i = 0; i < 260; i++) { const a = pick(pts), b = pick(pts); if (Math.hypot(a[0] - b[0], a[1] - b[1]) < 38) lattice += `<path d="M${f(a[0])},${f(a[1])} L${f(b[0])},${f(b[1])}"/>`; }
  return `<g stroke="#c45cbc" stroke-width="1.3" opacity=".55">${lattice}</g>${svg}`;
});
asset('sponge', 300, 340, () => tubeSponge(150, 336, 1.15, ['#b2620e', '#f2a22a', '#ffd27a']));
asset('anemone', 320, 240, () => {
  let t = '';
  const arr = [];
  for (let i = 0; i < 46; i++) {
    const a = -Math.PI + (i / 45) * Math.PI, bx = 160 + Math.cos(a) * 80, by = 168 + Math.sin(a) * 18;
    const len = rand(70, 110), lean = Math.cos(a) * 1.1 + rand(-0.3, 0.3), pts = [];
    for (let k = 0; k <= 8; k++) { const s = k / 8; pts.push([bx + Math.sin(lean * s * 1.2) * len * s, by - Math.cos(lean * s * 0.9) * len * s + s * s * 10]); }
    arr.push({ d: taper(pts, 13, 5), tip: pts[8], z: Math.sin(a) });
  }
  arr.sort((p, q) => q.z - p.z);
  for (const a of arr) t += `<path d="${a.d}" fill="url(#tg)" stroke="#a03a72" stroke-width="1"/><circle cx="${f(a.tip[0])}" cy="${f(a.tip[1])}" r="5" fill="#ffd9f0"/>`;
  return `<defs>${lin('tg', [[0, '#ff9fd1'], [1, '#e04f9a']])}${lin('col', [[0, '#c23b6e'], [1, '#6e1f43']])}</defs>
  <path d="M90,236 C88,200 92,180 82,166 C120,150 200,150 238,166 C228,180 232,200 230,236 Z" fill="url(#col)"/>${t}`;
});
asset('kelp', 170, 1000, () => {
  const stem = [];
  for (let y = 1000; y >= 30; y -= 30) stem.push([85 + Math.sin(y / 140) * 18, y]);
  let blades = '';
  stem.forEach(([x, y], i) => {
    if (i < 2 || i % 1) return;
    const side = i % 2 ? 1 : -1, len = rand(70, 110) * (0.6 + 0.4 * (1 - y / 1000)), ang = side * rand(0.5, 0.9);
    const pts = []; for (let k = 0; k <= 6; k++) { const s = k / 6; pts.push([x + Math.sin(ang) * len * s, y - Math.cos(ang) * len * s * 0.7 - s * 18]); }
    blades += `<path d="${taper(pts, 6, 3)}" fill="none"/>` +
      `<path d="M${f(x)},${f(y)} C${f(x + side * len * 0.3)},${f(y - 30)} ${f(x + side * len * 0.9)},${f(y - len * 0.5)} ${f(pts[6][0])},${f(pts[6][1])} C${f(x + side * len * 0.5)},${f(y - len * 0.2)} ${f(x + side * 10)},${f(y)} ${f(x)},${f(y)} Z" fill="url(#bl)" stroke="#4d5a18" stroke-width="1.2"/>` +
      `<circle cx="${f(x + side * 6)}" cy="${f(y - 4)}" r="6" fill="#9b8a2e" stroke="#5a4f18" stroke-width="1"/>`;
  });
  return `<defs>${lin('bl', [[0, '#7c8a2c', 0.95], [1, '#b5b546', 0.8]], 0, 0, 1, 0)}</defs>
  <path d="${smooth(stem)}" fill="none" stroke="#5a5a1e" stroke-width="7"/>${blades}`;
});
asset('seagrass', 220, 240, () => {
  let s = '';
  for (let i = 0; i < 16; i++) {
    const bx = 60 + i * 6.5 + rand(-4, 4), h = rand(110, 230), lean = rand(-0.6, 0.6), pts = [];
    for (let k = 0; k <= 8; k++) { const t = k / 8; pts.push([bx + Math.sin(lean * t) * h * t * 0.6, 238 - h * t]); }
    s += `<path d="${taper(pts, 9, 1.5)}" fill="${pick(['#3f8a3a', '#5aa04a', '#2f6e34', '#79b55a'])}" stroke="#1f4a22" stroke-width="1"/>`;
  }
  return s;
});
// drawn in 440x250 units and scaled up 1.3x; the cave is big enough for the moray eel to vanish into
asset('rock', 572, 325, () => {
  const pts = [[10, 248]]; for (let i = 0; i <= 12; i++) { const a = Math.PI + (i / 12) * Math.PI; pts.push([220 + Math.cos(a) * 205 * rand(0.9, 1.05), 238 + Math.sin(a) * 200 * rand(0.85, 1.05)]); } pts.push([430, 248]);
  let spots = ''; for (let k = 0; k < 40; k++) spots += `<ellipse cx="${f(rand(40, 400))}" cy="${f(rand(60, 240))}" rx="${f(rand(3, 14))}" ry="${f(rand(2, 7))}" fill="${pick(['#2a3c40', '#5d7470', '#7b5a6a', '#8a7a4a'])}" opacity=".5"/>`;
  return `<defs>${rad('r', [[0, '#6f8a88'], [0.7, '#3f5658'], [1, '#22343a']], 0.35, 0.2, 0.9)}<clipPath id="c"><path d="${smooth(pts, true)}"/></clipPath>${rad('cave', [[0, '#010304'], [0.7, '#081114'], [1, '#1c2c30']])}</defs>
  <g transform="scale(1.3)">
  ${''/* purple tube sponges growing behind the rock's crown: the rock hides their bases */}
  ${tubeSponge(150, 92, 0.3, ['#3b2370', '#7d55c8', '#c3a6ff'])}
  <path d="${smooth(pts, true)}" fill="url(#r)"/><g clip-path="url(#c)">${spots}
    <ellipse cx="119" cy="170" rx="64" ry="49" fill="#2a3c40" opacity=".8"/><ellipse cx="120" cy="172" rx="58" ry="44" fill="url(#cave)"/>
    <path d="M62,166 C72,126 162,122 180,162" fill="none" stroke="#8fa8a6" stroke-width="4" opacity=".5"/></g>

  ${branchy(312, 112, { len: 22, w: 6, depth: 3, spread: 0.5, split: 2, trunks: 3, fanOut: 0.5 }, ['#7a2a4a', '#d0507c', '#ff9fc0', '#ffd0e0']).svg}</g>`;
});

asset('bubble', 64, 64, () => `<defs>${rad('b', [[0, '#fff', 0.05], [0.75, '#dff8ff', 0.18], [0.95, '#fff', 0.85], [1, '#fff', 0]])}</defs>
  <circle cx="32" cy="32" r="30" fill="url(#b)"/><ellipse cx="23" cy="21" rx="8" ry="5" fill="#fff" opacity=".85" transform="rotate(-35 23 21)"/>`);
asset('particle', 32, 32, () => `<defs>${rad('p', [[0, '#fff', 0.9], [0.4, '#e8fbff', 0.5], [1, '#fff', 0]])}</defs><circle cx="16" cy="16" r="16" fill="url(#p)"/>`);
asset('vignette', 480, 270, () => `<defs>${rad('v', [[0, '#000', 0], [0.55, '#00101e', 0], [1, '#000814', 0.75]], 0.5, 0.45, 0.75)}</defs><rect width="480" height="270" fill="url(#v)"/>`);

// ---------- raster textures (computed per pixel, written straight to PNG) ----------
const zlib = require('zlib');
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc32 = (b) => { let c = -1; for (const x of b) c = CRC[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function writePNG(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const td = Buffer.concat([Buffer.from(type), data]); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(td)); return Buffer.concat([len, td, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}
// Seamless caustic light network: Voronoi cell borders (F2 - F1) with a wavy domain warp.
function caustics(name, seed) {
  R = mulberry(seed);
  const W = 1024, H = 512, pts = [];
  for (let i = 0; i < 70; i++) pts.push([R() * W, R() * H]);
  const buf = Buffer.alloc(W * H * 4), TAU = Math.PI * 2;
  for (let y = 0; y < H; y++) {
    const fade = Math.min(1, y / (H * 0.3));
    for (let x = 0; x < W; x++) {
      const wx = x + 9 * Math.sin((y / H) * TAU * 3) + 5 * Math.sin((y / H) * TAU * 7);
      const wy = y + 9 * Math.sin((x / W) * TAU * 4) + 5 * Math.sin((x / W) * TAU * 9);
      let d1 = 1e9, d2 = 1e9;
      for (const [px, py] of pts) {
        let dx = Math.abs(wx - px); dx = Math.min(dx, W - dx);
        let dy = Math.abs(wy - py); dy = Math.min(dy, H - dy);
        const d = Math.sqrt(dx * dx + dy * dy);
        if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) d2 = d;
      }
      const e = d2 - d1;
      const v = Math.exp(-e / 2.6) * 0.95 + Math.exp(-e / 9) * 0.25;
      const o = (y * W + x) * 4;
      buf[o] = 225; buf[o + 1] = 252; buf[o + 2] = 255; buf[o + 3] = Math.min(255, Math.round(v * 255 * fade));
    }
  }
  // the Roku shows caustics squashed to 45% height, so store them at half height (averaging row pairs)
  const half = Buffer.alloc(W * (H / 2) * 4);
  for (let y = 0; y < H / 2; y++) for (let x = 0; x < W * 4; x++) half[y * W * 4 + x] = (buf[(2 * y) * W * 4 + x] + buf[(2 * y + 1) * W * 4 + x]) >> 1;
  writePNG(path.join(OUT, name + '.png'), W, H / 2, half);
  console.log(`${name.padEnd(16)} ${W}x${H / 2}`);
}

// ---------- render ----------
const only = process.argv.slice(2).filter((a) => a !== 'sizes');
const sizesOnly = process.argv.includes('sizes') && !only.length;
const list = sizesOnly ? [] : only.length ? assets.filter((a) => only.includes(a.name)) : assets;
if ((!only.length && !sizesOnly) || only.includes('caustics')) { caustics('caustics_a', 11); caustics('caustics_b', 29); }
const profile = path.join(TMP, 'chrome-profile');
// Roku can't mirror images with negative scale, so creatures also get a pre-flipped "_l" (facing left) copy.
const MIRROR = new Set(['clown_body', 'clown_tail', 'clown_pec', 'seagrass', 'tang_pec', 'ytang_pec', 'angel_pec', 'shark_pec', 'shark_pecf', 'shark_dorsal', 'dolphin_pec', 'dolphin_dorsal', 'whale_fin', 'tang_body', 'tang_tail', 'ytang_body', 'ytang_tail', 'angel_body', 'angel_tail',
  'school_fish', 'shark_body', 'shark_tail', 'turtle_body', 'turtle_flipper', 'turtle_rear', 'manta', 'whale',
  'octo_body', 'octo_arms', 'dolphin_body', 'dolphin_tail', 'lion_body', 'lion_fin', 'lion_tail', 'seahorse', 'seahorse_fin', 'crab_legs', 'diver_body', 'diver_leg', 'diver_beam', 'shrimp', 'shrimp_finger']);
const jobs = [];
for (const a of list) {
  R = mulberry(hash(a.name)); idc = 0;
  const inner = a.fn();
  jobs.push({ ...a, inner });
  if (MIRROR.has(a.name)) jobs.push({ ...a, name: a.name + '_l', inner: `<g transform="translate(${a.w},0) scale(-1,1)">${inner}</g>` });
}
for (const a of jobs) {
  const W = Math.round(a.w * a.res), H = Math.round(a.h * a.res);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${a.w} ${a.h}">${a.inner}</svg>`;
  const svgFile = path.join(TMP, a.name + '.svg');
  const png = path.join(OUT, a.name + '.png');
  fs.writeFileSync(svgFile, svg);
  const html = path.join(TMP, a.name + '.html');
  fs.writeFileSync(html, `<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}svg{display:block}</style></head><body>${svg}</body></html>`);
  // headless Chrome now and then hangs on a screenshot: give up after 30 s and try again with a fresh
  // profile (the hung instance keeps the old one locked)
  for (let attempt = 1; ; attempt++) {
    try {
      execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
        '--default-background-color=00000000', `--user-data-dir=${attempt === 1 ? profile : profile + '-retry' + attempt}`, `--window-size=${W},${H}`,
        `--screenshot=${png}`, 'file:///' + html.replace(/\\/g, '/')], { stdio: 'ignore', timeout: 30000 });
      break;
    } catch (e) {
      if (attempt >= 3) throw e;
      console.log(`${a.name}: Chrome timed out, retrying`);
    }
  }
  const buf = fs.readFileSync(png);
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
  console.log(`${a.name.padEnd(16)} ${w}x${h}${w !== W || h !== H ? '  <-- SIZE MISMATCH' : ''}`);
}

// ---------- lossless recompression (same pixels, smaller files: the package must stay under Roku's 4 MB) ----------
// Slow for the big backgrounds (a full render takes a long time); skip with NOOPT=1 while iterating on art.
if (jobs.length && !process.env.NOOPT) {
  const files = jobs.map((a) => path.join(OUT, a.name + '.png'));
  if (list.length === assets.length || only.includes('caustics')) files.push(path.join(OUT, 'caustics_a.png'), path.join(OUT, 'caustics_b.png'));
  try { execFileSync('python', [path.join(__dirname, 'optimize-png.py'), ...files], { stdio: 'inherit' }); }
  catch (e) { console.log('PNG optimisation skipped (needs: python -m pip install pyoxipng pillow)'); }
}

// ---------- image size table for the Roku code (components/ImageSizes.brs) ----------
// Used on 720p Rokus to decode big images at 2/3 size while still drawing them at full size.
{
  const rows = fs.readdirSync(OUT).filter((n) => n.endsWith('.png')).sort().map((n) => {
    const b = fs.readFileSync(path.join(OUT, n));
    return `        "${n.slice(0, -4)}": [${b.readUInt32BE(16)}, ${b.readUInt32BE(20)}]`;
  });
  fs.writeFileSync(path.join(ROOT, 'components', 'ImageSizes.brs'),
    `' Generated by tools/make-art.js - stored size of every image in images/ocean\r\nfunction imageSizes() as object\r\n    return {\r\n${rows.join('\r\n')}\r\n    }\r\nend function\r\n`);
  console.log(`ImageSizes.brs: ${rows.length} images`);
}