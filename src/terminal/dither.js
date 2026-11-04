// Moteur de tramage : une fonction de luminosité → image monochrome façon moniteur de 1984. Visage et décors des niveaux.
const B4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
const hash = (x, y, sd) => { const n = Math.sin(x * 12.9898 + y * 78.233 + sd * 37.17) * 43758.5453; return n - Math.floor(n); };
const clamp01 = x => x < 0 ? 0 : x > 1 ? 1 : x;

export function makeDither(W, H) {
  const off = document.createElement('canvas'); off.width = W; off.height = H;
  const ox = off.getContext('2d');
  return function render(ctx, fn, p) {
    const img = ox.createImageData(W, H), d = img.data, nz = p.noise == null ? .3 : p.noise, sd = p.seed || 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const u = (x - W / 2) / (W / 2), v = (y - H / 2) / (H / 2);
      let val = fn(u, v, p) + (hash(x, y, sd) - .5) * nz;
      let on = val > (B4[(y & 3) * 4 + (x & 3)] + .5) / 16;
      if (p.invert) on = !on;
      const i = (y * W + x) * 4;
      d[i] = on ? p.color[0] : 0; d[i + 1] = on ? p.color[1] : 0; d[i + 2] = on ? p.color[2] : 0; d[i + 3] = 255;
    }
    ox.putImageData(img, 0, 0);
    const cw = ctx.canvas.width, ch = ctx.canvas.height;
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, cw, ch);
    const sh = p.shake || 0, jx = (Math.random() - .5) * sh, jy = (Math.random() - .5) * sh;
    if (p.fit) { const sc = Math.min(cw / W, ch / H) * (p.scale || 1); ctx.drawImage(off, (cw - W * sc) / 2 + jx, (ch - H * sc) / 2 + jy, W * sc, H * sc); }
    else ctx.drawImage(off, jx, jy, cw, ch);
  };
}

export function faceFn(nx, ny, p) {
  const r2 = nx * nx + ny * ny, mouth = p.mouth || 0, eyes = p.eyes == null ? 1 : p.eyes;
  if (r2 >= 1) return .02;
  let v = .95 - r2 * .75 + Math.sin(ny * 40 + p.t * 2.5) * .03 + Math.sin(nx * 30) * .02;
  const ex = (nx + .4) / .27, ey = (ny + .22) / .3, fx = (nx - .4) / .27;
  if (ex * ex + ey * ey < 1 || fx * fx + ey * ey < 1) v *= (1 - eyes) * .3;
  if (Math.abs(nx) < .07 && ny > -.05 && ny < .25) v *= .55;
  const my = (ny - .45) / (.08 + .4 * mouth), mx = nx / (.22 + .14 * mouth);
  if (mx * mx + my * my < 1) v = (mouth > .3 && Math.abs(my) > .7 && (Math.floor(nx * 40) % 2 === 0)) ? .85 : .02;
  if (r2 > .82) v *= (1 - r2) * 5.5;
  return v;
}
const renderFace = makeDither(192, 240);
export const Face = { render(ctx, p) {
  const z = p.zoom || 1, dx = (p.dx || 0) / 96, dy = (p.dy || 0) / 120;
  renderFace(ctx, (u, v, q) => faceFn((u - dx) / (.72 * z), (v - dy) / (.84 * z), q), Object.assign({ fit: true }, p));
} };

const inR = (u, v, x0, x1, y0, y1) => u >= x0 && u <= x1 && v >= y0 && v <= y1;
const ell = (u, v, cx, cy, rx, ry) => { const a = (u - cx) / rx, b = (v - cy) / ry; return a * a + b * b; };
export const SCENES = {
  cuisine(u, v, p) {
    const t = p.t;
    const light = Math.pow(clamp01(1 - Math.hypot(u * .8, v + 1.05) / 1.7), 2);
    let b = v < .25 ? .06 + .3 * light : .28 + .22 * (1 - Math.abs(u)) - (v - .25) * .2;
    if (Math.abs(u) < .012 && v < -.78) b = .6;
    if (ell(u, v, 0, -.74, .24, .07) < 1) b = .9;
    if (ell(u, v, -.05, .28, .17, .035) < 1 || ell(u, v, .5, .28, .17, .035) < 1) b *= .3;
    for (const [cx, dark] of [[-.05, false], [.5, true]]) {
      const x0 = cx - .11, x1 = cx + .11;
      if (inR(u, v, x0 - .02, x1 + .02, -.34, .27)) {
        const lvl = dark ? -.08 - Math.min(.2, t * .008) + .015 * Math.sin(t * 2 + u * 25) : -.02 + .015 * Math.sin(t * 1.5 + u * 30);
        const wall = Math.abs(u - x0) < .016 || Math.abs(u - x1) < .016 || Math.abs(v + .34) < .014 || Math.abs(v - .26) < .014;
        if (wall) b = .9;
        else if (v > lvl) b = dark ? (Math.abs(v - lvl) < .02 ? .7 : .0) : Math.min(1, .45 + .15 * Math.sin(v * 50 + t) + .2 * (1 - Math.abs(u - cx) / .11));
        else b = b * .8 + .1;
      }
    }
    return b;
  },
  porte(u, v, p) {
    const t = p.t, g = .015 + Math.min(.14, t * .006) * (1 + .25 * Math.sin(t * .7));
    let b = v > .6 ? .2 - (v - .6) * .22 + .03 * Math.sin(v * 50) : .1 + .1 * (1 - Math.abs(u)) - (v + 1) * .03;
    if (inR(u, v, -.36, .36, -.9, .6)) {
      b = .45;
      if (inR(u, v, -.3, .3, -.85, .6)) {
        b = .22;
        if (inR(u, v, -.22, .22, -.72, -.15) || inR(u, v, -.22, .22, 0, .45)) b = .16;
        if (inR(u, v, -.2, .2, -.7, -.17) || inR(u, v, -.2, .2, .02, .43)) b = .2;
        if (ell(u, v, .2, -.05, .03, .04) < 1) b = .75;
        if (u > .3 - g) { b = .0; if (t > 6 && (ell(u, v, .3 - g * .5 - .012, -.3, .012, .016) < 1 || ell(u, v, .3 - g * .5 + .012, -.3, .012, .016) < 1)) b = .95; }
        if (v > .56 && v < .6) b = .8 + .15 * Math.sin(t * 27);
      }
    }
    return b;
  },
  prix(u, v, p) {
    const t = p.t;
    let b = v > .3 ? .13 + .02 * Math.sin(v * 70) : .07;
    if (inR(u, v, .3, .9, -.92, -.1)) { b = .6 + .08 * Math.sin(v * 20 + t * .5); if (Math.abs(u - .6) < .015 || Math.abs(v + .51) < .015) b = .04; }
    if (v > .3 && u > .2 && u < 1 && Math.abs(u - .6 - (v - .3) * .3) < .35) b += .1;
    if (v > .1) { const w = .32 + (v - .1) * .45; if (Math.abs(u - .05) < w) {
      b = .3 - (v - .1) * .1;
      if (v < .3) b = .5;
      if (ell(u, v, .05, .5, w * .45, .42) < 1) b = .42;
      if (ell(u, v, .05, .2, .085, .085) < 1) b = .55;
    } }
    const fx = .6 - Math.min(.2, t * .01), sc = 1 + Math.min(.5, t * .02);
    if (ell(u, v, fx, -.45, .09 * sc, .11 * sc) < 1) { b = 0; if (t > 5 && (ell(u, v, fx - .03 * sc, -.46, .012, .015) < 1 || ell(u, v, fx + .03 * sc, -.46, .012, .015) < 1)) b = .9; }
    else if (v > -.36 && Math.abs(u - fx) < .12 * sc * (1 + (v + .36) * .3)) b = 0;
    return b;
  },
  reflet(u, v, p) {
    const t = p.t;
    let b = .03;
    if (inR(u, v, -.5, .5, -.95, .95)) {
      b = .5;
      if (inR(u, v, -.46, .46, -.9, .9)) {
        b = .08 + .06 * (v + 1) / 2;
        const d = ell(u, v, 0, .1, .3, .36);
        if (v > .4 && Math.abs(u) < .7) b = .22 + .2 * (v - .4);
        if (d < 1) b = .12 + .45 * Math.pow(d, 3);
        const r = t > 2.5 ? .06 + Math.min(.2, (t - 2.5) * .012) : 0;
        if (r > 0) {
          const cx = -.28, cy = -.2 + r * .4;
          const f = ell(u, v, cx, cy, r, r * 1.25);
          if (f < 1) {
            b = .8 - f * .25;
            if (ell(u, v, cx - r * .4, cy - r * .3, r * .22, r * .3) < 1 || ell(u, v, cx + r * .4, cy - r * .3, r * .22, r * .3) < 1) b = .0;
            if (ell(u, v, cx, cy + r * .6, r * .28, r * .2) < 1) b = .0;
          }
        }
      }
    }
    return b;
  },
  sortie(u, v, p) {
    u -= .3;
    const t = p.t, au = Math.abs(u), a = .78, fl = .9 + .1 * Math.sin(t * 23) * Math.sin(t * 7);
    let b, z;
    if (v > a * au) { z = .32 / v; b = .34 * (1 - Math.min(1, z / 7)); if (((z * 2) % 1) < .1) b += .12; }
    else if (v < -a * au) { z = .32 / -v; b = .07; if (((z + .5) % 1) < .12 && au < .06 * z * .5 + .01) b = .6; }
    else { z = .32 / au; b = .13 + .12 * (1 - Math.min(1, z / 7)); const k = (z * 1.4) % 1; if (k > .3 && k < .6 && v > -.5 / Math.max(1, z * .6) && v < .35 / Math.max(1, z * .6)) b = .04; }
    if (inR(u, v, -.17, .17, -.27, .27)) b = .3;
    if (inR(u, v, -.13, .13, -.22, .22)) b = .95 * fl;
    const sc = 1 + Math.min(2.6, t * .08), fy = .22 * sc;
    if (Math.abs(u) < .045 * sc && v > -.14 * sc && v < fy) b = .0;
    if (ell(u, v, 0, -.18 * sc, .045 * sc, .055 * sc) < 1) b = .0;
    if (v > fy && au < (.02 + (v - fy) * .25)) b = .02;
    return b;
  },
  aube(u, v, p) {
    const t = p.t, rise = Math.min(1, t * .04);
    let b = .18 + .06 * rise;
    if (inR(u, v, -.55, .55, -.85, .45)) {
      b = .5 + .4 * rise + .08 * Math.sin(u * 6 + t * .2) - (v + .85) * .15;
      if (Math.abs(u) < .018 || Math.abs(v + .2) < .018) b = .08;
      if (Math.abs(u) > .5 || Math.abs(v - (-.2)) > .62) b = .3;
    }
    if (v > .45 && v < .5 && Math.abs(u) < .6) b = .45;
    return b;
  }
};
export const renderScene = makeDither(256, 160);
