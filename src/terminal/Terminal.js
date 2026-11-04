// Le jeu-terminal RUNTIME, affiché sur l'écran du moniteur (CSS3D). Clavier seulement : 1/2/3, saisie + Entrée, Espace pour accélérer.
import './terminal.css';
import * as THREE from 'three';
import { CSS3DObject } from 'three/examples/jsm/renderers/CSS3DRenderer.js';
import gsap from 'gsap';
import { ScrambleTextPlugin } from 'gsap/ScrambleTextPlugin';
import { Face, SCENES, renderScene } from './dither.js';

gsap.registerPlugin(ScrambleTextPlugin);
gsap.ticker.lagSmoothing(0);

const SCR = '▓▒░#¿§¤01';
const ENDS = { absorbe: 'ABSORBÉ', transmission: 'TRANSMISSION', boucle: 'LA BOUCLE', aube: "L'AUBE" };
const STORE = 'runtime-fins';
const wait = ms => new Promise(r => setTimeout(r, ms));
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
class Absorbed extends Error {}
const cap = s => { s = (s || '').trim().slice(0, 18); return s ? s[0].toUpperCase() + s.slice(1).toLowerCase() : s; };
const esc = s => s.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const clock = () => new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
const dayName = () => new Date().toLocaleDateString('fr-FR', { weekday: 'long' });
const norm = s => (s || '').toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Z]/g, '');

/* ce que le navigateur révèle sans rien demander */
const REAL = (() => {
  let tz = ''; try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) {}
  const city = /\//.test(tz) ? tz.split('/').pop().replace(/_/g, ' ') : '';
  const ua = navigator.userAgent || '';
  const browser = /Firefox/.test(ua) ? 'Firefox' : /Edg/.test(ua) ? 'Edge' : /OPR/.test(ua) ? 'Opera' : /Chrome/.test(ua) ? 'Chrome' : /Safari/.test(ua) ? 'Safari' : '';
  const os = /Windows/.test(ua) ? 'Windows' : /Mac/.test(ua) ? 'Mac' : /Linux/.test(ua) ? 'Linux' : '';
  const r = { city, browser, os, w: screen.width, h: screen.height, battery: null, startedAt: Date.now() };
  try { navigator.getBattery && navigator.getBattery().then(b => { r.battery = b; }).catch(() => {}); } catch (e) {}
  return r;
})();

const TEMPLATE = `
<div class="status"><span>CORRUPTION <span class="bar"><i id="corrBar"></i></span><b id="corrVal">00%</b></span><span id="timer">DÉLAI <span class="bar"><i id="timeBar"></i></span><b id="timeNum">--</b></span></div>
<div class="fx" id="ghost" aria-hidden="true"></div>
<canvas class="fx" id="watch" aria-hidden="true"></canvas>
<div id="term"><div id="out"></div></div>
<canvas class="fx" id="noise" aria-hidden="true"></canvas>
<div class="fx scan" aria-hidden="true"></div>
<div class="fx roll" aria-hidden="true"></div>
<div class="fx vignette" aria-hidden="true"></div>
<div class="fx glare" aria-hidden="true"></div>
<pre id="crash" hidden></pre>
<div id="sflash" aria-hidden="true"><canvas id="screamc"></canvas></div>`;

export class Terminal {
  constructor({ audio, player, room }) {
    this.audio = audio; this.player = player; this.room = room;
    this.handlers = {};
    this.root = document.createElement('div'); this.root.className = 'term-root'; this.root.innerHTML = TEMPLATE;
    this.$ = s => this.root.querySelector(s);
    this.term = this.$('#term'); this.out = this.$('#out');
    this.S = { name: '', proche: '', next: '', corr: 0, playing: false, hes: 0, away: 0, batt: '' };
    this.fast = false; this.narrating = false; this.frozen = false;
    this.noiseBoost = 0; this.lastNoise = 0;
    this.watchOp = 0; this.wFrame = 0; this.lastW = 0; this.scene = null; this.sceneT0 = 0; this.faceMode = false;
    this.lastPlayer = ''; try { this.lastPlayer = localStorage.getItem('runtime-last') || ''; } catch (e) {}
    this.askN = 0; this.tTween = null; this.choiceKeys = null; this.hiddenAt = 0; this.visible = false;
    this.curvature();
    const nc = this.$('#noise'); nc.width = 160; nc.height = 120; this.nx = nc.getContext('2d');
    this.wx = this.$('#watch').getContext('2d'); this.$('#watch').width = 360; this.$('#watch').height = 270;
    addEventListener('keydown', e => this.onKey(e));
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) { this.hiddenAt = Date.now(); if (this.S.playing) try { document.title = (this.S.name ? this.S.name.toUpperCase() + ', ' : '') + 'REVIENS.'; } catch (e) {} }
      else { try { document.title = 'RUNTIME'; } catch (e) {} if (this.hiddenAt && this.S.playing) { const sec = Math.round((Date.now() - this.hiddenAt) / 1000); if (sec >= 3) this.S.away = sec; this.hiddenAt = 0; } }
    });
    setInterval(() => this.rot(), 900);
    requestAnimationFrame(ts => this.loop(ts));
  }
  on(ev, fn) { (this.handlers[ev] = this.handlers[ev] || []).push(fn); }
  emit(ev, ...a) { (this.handlers[ev] || []).forEach(f => f(...a)); }
  getFins() { try { return JSON.parse(localStorage.getItem(STORE) || '[]'); } catch (e) { return []; } }

  /* ---------- mise en place dans la 3D ---------- */
  hide() { this.visible = false; if (this.obj) this.obj.removeFromParent(); }
  show(anchor, css3d) {
    const [sw] = this.room.screenSize;
    this.obj = new CSS3DObject(this.root);
    this.obj.scale.setScalar(sw / 720);
    anchor.add(this.obj);
    this.visible = true;
  }
  curvature() {
    if (reduce || document.getElementById('crt') || new URLSearchParams(location.search).has('lite')) return;
    try {
      const N = 128, cv = document.createElement('canvas'); cv.width = cv.height = N;
      const cx = cv.getContext('2d'), img = cx.createImageData(N, N), d = img.data;
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        const u = (x / (N - 1)) * 2 - 1, v = (y / (N - 1)) * 2 - 1, r2 = u * u + v * v, i = (y * N + x) * 4;
        d[i] = Math.round(128 - u * r2 * 127); d[i + 1] = Math.round(128 - v * r2 * 127); d[i + 2] = 0; d[i + 3] = 255;
      }
      cx.putImageData(img, 0, 0);
      const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); svg.setAttribute('width', '0'); svg.setAttribute('height', '0'); svg.style.position = 'absolute';
      svg.innerHTML = `<filter id="crt" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feImage preserveAspectRatio="none" result="map" href="${cv.toDataURL()}"/><feDisplacementMap in="SourceGraphic" in2="map" scale="22" xChannelSelector="R" yChannelSelector="G" result="warp"/><feGaussianBlur in="warp" stdDeviation="1.6" result="blur"/><feComposite in="warp" in2="blur" operator="lighter"/></filter>`;
      document.body.appendChild(svg); this.root.classList.add('curved');
    } catch (e) {}
  }

  /* ---------- boucles visuelles ---------- */
  loop(ts) {
    requestAnimationFrame(t => this.loop(t));
    if (!this.visible) return;
    if (!this.frozen && ts - this.lastNoise > 50) { this.drawNoise(); this.lastNoise = ts; this.noiseBoost *= .85; }
    if (this.watchOp > 0 && !this.frozen && ts - this.lastW > 110) { this.lastW = ts; this.wFrame++; this.drawWatch(ts); }
  }
  drawNoise() {
    const img = this.nx.createImageData(160, 120), d = img.data, a = 18 + (this.S.corr / 100) * 70 + this.noiseBoost * 220;
    for (let i = 0; i < d.length; i += 4) { const v = Math.random() * 255; d[i] = d[i + 1] = d[i + 2] = v; d[i + 3] = Math.random() < .5 ? a : 0; }
    this.nx.putImageData(img, 0, 0);
  }
  phosRGB() { if (this.root.classList.contains('dawn')) return [235, 228, 200]; const c = this.S.corr / 100; return [Math.round(110 + 145 * c), Math.round(255 - 215 * c), Math.round(90 - 70 * c)]; }
  drawWatch(ts) {
    const c = this.S.corr / 100, t = (ts - this.sceneT0) / 1000;
    const faceFlash = !this.faceMode && c > .5 && Math.random() < .03;
    if (this.faceMode || faceFlash) Face.render(this.wx, { t: ts / 1000, mouth: (this.wFrame % 37 === 0 ? .9 : .04 + c * .15), eyes: 1, zoom: .75 + c * .55, noise: .35, seed: this.wFrame, scale: 1.05, shake: c * 4, color: this.phosRGB(), invert: this.wFrame % 53 === 0 });
    else if (this.scene) renderScene(this.wx, SCENES[this.scene], { t, corr: c, noise: .12 + c * .18, seed: this.wFrame, shake: c * 3, color: this.phosRGB(), invert: c > .4 && this.wFrame % 61 === 0 });
  }
  watchLevel() {
    const c = this.S.corr / 100;
    this.watchOp = this.root.classList.contains('dawn') ? .5 : this.faceMode ? .6 : this.scene ? Math.min(.5, .3 + c * .25) : 0;
    gsap.to(this.$('#watch'), { opacity: this.watchOp, duration: 2.5 });
  }
  setScene(name, op) {
    this.scene = name; this.sceneT0 = performance.now(); this.faceMode = false;
    if (op != null) { this.watchOp = op; gsap.to(this.$('#watch'), { opacity: op, duration: 1 }); } else this.watchLevel();
  }
  rot() {
    const S = this.S, out = this.out;
    if (!S.playing || this.root.classList.contains('dawn')) return;
    const c = S.corr / 100;
    if (c > .2 && Math.random() < c * .9) {
      const lines = [...out.querySelectorAll('.ln:not(.typing):not(.err)')];
      const el = lines[Math.floor(Math.random() * lines.length)];
      if (el) {
        const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT), nodes = []; while (w.nextNode()) nodes.push(w.currentNode);
        const n = nodes[Math.floor(Math.random() * nodes.length)];
        if (n && n.data.length) {
          if (c > .6 && Math.random() < .25 && S.name) n.data = n.data.replace(/[A-Za-zÀ-ÿ']{4,}/, S.name.toUpperCase());
          else { const i = Math.floor(Math.random() * n.data.length); if (n.data[i] !== ' ') n.data = n.data.slice(0, i) + '▓▒░#¿§¤'[Math.floor(Math.random() * 7)] + n.data.slice(i + 1); }
        }
      }
    }
    const WORDS = ['DERRIÈRE TOI', S.proche, 'RESTE', 'REGARDE', (S.name || '').toUpperCase(), 'NE DORS PAS'];
    if (c > .45 && Math.random() < c * .18) this.ghost(WORDS[Math.floor(Math.random() * WORDS.length)]);
    if (c > .35 && Math.random() < c * .25) {
      const cands = [...out.querySelectorAll('.ln:not(.typing):not(.err)')].filter(e => !e.querySelector('.key') && e.textContent.length > 8);
      const el = cands[Math.floor(Math.random() * cands.length)];
      if (el && !el.dataset.scr) { el.dataset.scr = 1; gsap.to(el, { duration: .7 + c, scrambleText: { text: el.textContent, chars: SCR, speed: .5, revealDelay: .25 }, onComplete() { delete el.dataset.scr; } }); }
    }
  }

  /* ---------- primitives de texte ---------- */
  fill(s) {
    const S = this.S;
    return s.replace(/\{NAME\}/g, (S.name || 'INCONNU').toUpperCase()).replace(/\{name\}/g, S.name).replace(/\{proche\}/g, S.proche).replace(/\{next\}/g, S.next).replace(/\{time\}/g, clock()).replace(/\{day\}/g, dayName());
  }
  scroll() { this.term.scrollTop = this.term.scrollHeight; }
  pause(ms) { return this.fast ? Promise.resolve() : wait(ms); }
  async line(text, o = {}) {
    this.narrating = true;
    const el = document.createElement('div'); el.className = 'ln typing ' + (o.cls || '');
    this.out.querySelectorAll('.ln.typing').forEach(x => x.classList.remove('typing'));
    this.out.appendChild(el);
    const instant = o.speed === 0;
    for (const p of this.fill(text).split(/(\[\[.+?\]\])/)) {
      if (!p) continue;
      let target = el, s = p;
      if (p.startsWith('[[')) { target = document.createElement('span'); target.className = 'key'; el.appendChild(target); s = p.slice(2, -2); }
      const node = document.createTextNode(''); target.appendChild(node);
      for (let i = 0; i < s.length; i++) {
        if (this.fast || instant) { node.data += s.slice(i); break; }
        node.data += s[i]; if (s[i] !== ' ') this.audio.key(); this.scroll();
        await wait(o.speed ?? 24);
      }
    }
    this.scroll(); await this.pause(o.pause ?? 280); return el;
  }
  glitchFx(i = .5) {
    this.noiseBoost = Math.max(this.noiseBoost, i); this.audio.glitch(i);
    if (reduce) return;
    this.root.classList.add('rgb'); setTimeout(() => this.root.classList.remove('rgb'), 120 + i * 300);
    gsap.fromTo(this.term, { x: 0 }, { x: () => gsap.utils.random(-10, 10) * i, y: () => gsap.utils.random(-4, 4) * i, duration: .04, repeat: 7, yoyo: true, repeatRefresh: true, onComplete: () => gsap.set(this.term, { x: 0, y: 0 }) });
  }
  async error(text) {
    this.glitchFx(.6);
    const el = await this.line(text, { cls: 'err', speed: 8, pause: 200 });
    const keys = [...el.querySelectorAll('.key')].map(k => k.textContent);
    gsap.to(el, { duration: .9, scrambleText: { text: el.textContent, chars: SCR, speed: .6, revealDelay: .3 }, onComplete() {
      const txt = el.textContent; el.textContent = '';
      for (const part of txt.split(new RegExp('(' + keys.map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')'))) {
        if (!part) continue;
        if (keys.includes(part)) { const sp = document.createElement('span'); sp.className = 'key'; sp.textContent = part; el.appendChild(sp); } else el.append(part);
      }
    } });
    await this.pause(900);
  }
  ghost(text) {
    const g = this.$('#ghost'); g.textContent = this.fill(text || '');
    if (reduce) return;
    gsap.timeline().to(g, { opacity: .2, duration: .05 }).to(g, { opacity: 0, duration: .25, delay: .08 });
  }
  setCorrUI() {
    const c = this.S.corr / 100;
    gsap.to(this.root, { '--c': c, duration: 1.4 });
    gsap.to(this.$('#corrBar'), { scaleX: c, duration: 1 });
    this.$('#corrVal').textContent = String(this.S.corr).padStart(2, '0') + '%';
    this.watchLevel(); this.emit('corruption', c);
  }
  corrupt(n) {
    this.S.corr = Math.max(0, Math.min(100, this.S.corr + n)); this.setCorrUI();
    if (n > 0) this.glitchFx(Math.min(1, n / 22));
    if (this.S.corr >= 100) throw new Absorbed();
  }

  /* ---------- minuteur, choix, saisie ---------- */
  timerStart(sec, onEnd) {
    const box = this.$('#timer'), num = this.$('#timeNum');
    gsap.set(this.$('#timeBar'), { scaleX: 1 });
    let last = sec; num.textContent = String(sec).padStart(2, '0');
    this.tTween = gsap.to(this.$('#timeBar'), { scaleX: 0, duration: sec, ease: 'none', onUpdate: () => {
      const left = Math.ceil(sec * (1 - this.tTween.progress()));
      if (left !== last) { last = left; num.textContent = String(left).padStart(2, '0'); box.classList.toggle('hot', left <= 3); this.audio.tick(left <= 3); }
    }, onComplete: onEnd });
  }
  timerStop() {
    if (this.tTween) this.tTween.kill(); this.tTween = null;
    this.$('#timer').classList.remove('hot'); this.$('#timeNum').textContent = '--';
    gsap.to(this.$('#timeBar'), { scaleX: 0, duration: .3 });
  }
  onKey(e) {
    if (!this.visible) return;
    if (this.choiceKeys) { const n = parseInt(e.key, 10); if (n >= 1 && n <= this.choiceKeys.n) { e.preventDefault(); this.choiceKeys.pick(n - 1); } return; }
    if (e.target && e.target.tagName === 'INPUT') return;
    if (this.narrating && (e.code === 'Space' || e.code === 'Enter')) { e.preventDefault(); this.fast = true; }
    if (this.endKeys) { if (e.code === 'KeyR') this.endKeys.replay(); if (e.code === 'Enter') this.endKeys.leave(); }
  }
  choose(opts, { time = 12, worst = 0, extra = null } = {}) {
    this.narrating = false; this.fast = false;
    this.out.querySelectorAll('.ln.typing').forEach(x => x.classList.remove('typing'));
    return new Promise(res => {
      let finished = false;
      const box = document.createElement('div'); box.className = 'choices';
      const btns = opts.map((txt, i) => { const b = document.createElement('div'); b.className = 'opt'; b.innerHTML = `<span class="n">[${i + 1}]</span> ${esc(this.fill(txt))}`; box.appendChild(b); return b; });
      this.out.appendChild(box); this.scroll();
      if (!reduce) gsap.from(btns, { opacity: 0, x: -10, stagger: .08, duration: .25 });
      const shownAt = performance.now(); this.audio.music.tension(true);
      let poll = null; if (extra) poll = setInterval(() => { try { if (extra()) done(0, false, true); } catch (e) {} }, 100);
      this.timerStart(time, () => done(worst, true));
      const done = (i, timeout, physical = false) => {
        if (finished) return; finished = true; this.choiceKeys = null; if (poll) clearInterval(poll);
        this.timerStop(); this.audio.music.tension(false); this.S.hes = (performance.now() - shownAt) / 1000;
        btns.forEach((b, j) => b.classList.add(j === i ? 'picked' : 'dead'));
        this.audio.select(); res({ i, timeout, physical });
      };
      this.choiceKeys = { n: opts.length, pick: i => done(i, false) };
    });
  }
  async pick(opts, cfg) {
    const r = await this.choose(opts, cfg);
    if (r.timeout) { await this.line('> DÉLAI DÉPASSÉ. JE CHOISIS POUR TOI.', { cls: 'err', speed: 10 }); this.corrupt(5); }
    if (this.S.away) { const sec = this.S.away; this.S.away = 0; await this.line(`${sec} secondes d'absence. Je n'ai pas bougé. Je t'attendais.`, { cls: 'dim', pause: 700 }); }
    return r.physical ? 0 : r.i;
  }
  ask(label, def, possess) {
    this.narrating = false; this.fast = false;
    this.out.querySelectorAll('.ln.typing').forEach(x => x.classList.remove('typing'));
    return new Promise(res => {
      const id = 'in' + (++this.askN);
      const f = document.createElement('form'); f.className = 'ask';
      f.innerHTML = `<label for="${id}">${esc(label)} &gt;</label><input id="${id}" maxlength="18" autocomplete="off" spellcheck="false"><span class="enter">ENTRÉE ↵</span>`;
      this.out.appendChild(f); this.scroll();
      const inp = f.querySelector('input'); inp.focus({ preventScroll: true });
      const refocus = () => { if (!inp.disabled) inp.focus({ preventScroll: true }); };
      const kd = e => { if (e.target !== inp && !inp.disabled && e.key.length === 1) refocus(); };
      addEventListener('keydown', kd, true);
      inp.addEventListener('input', () => this.audio.key());
      inp.addEventListener('keydown', e => { if (e.code === 'Enter') { e.preventDefault(); submit(); } });
      const submit = () => {
        if (inp.disabled) return;
        const v = inp.value.trim() || def; inp.value = v; inp.disabled = true; f.querySelector('.enter').remove();
        removeEventListener('keydown', kd, true); this.audio.select(); res(v);
      };
      f.onsubmit = e => { e.preventDefault(); submit(); };
      if (possess) setTimeout(async () => {
        if (inp.value || inp.disabled) return;
        inp.readOnly = true; f.classList.add('possessed');
        for (const ch of possess) { inp.value += ch; this.audio.key(); await wait(140); }
        await wait(1000);
        while (inp.value && !inp.disabled) { inp.value = inp.value.slice(0, -1); await wait(45); }
        inp.readOnly = false; f.classList.remove('possessed'); refocus();
      }, 1800);
    });
  }

  /* ---------- effets d'écran ---------- */
  powerOff() {
    if (reduce) return gsap.to(this.term, { opacity: 0, duration: .3 }).then();
    return gsap.timeline().to(this.term, { scaleY: .006, filter: 'brightness(3)', duration: .18, ease: 'power2.in' }).to(this.term, { scaleX: 0, opacity: 0, duration: .15 }).then();
  }
  powerOn() {
    if (reduce) return gsap.to(this.term, { opacity: 1, duration: .3 }).then();
    return gsap.timeline().set(this.term, { scaleX: 1, scaleY: .006, opacity: 1 }).to(this.term, { scaleY: 1, filter: 'brightness(1)', duration: .3, ease: 'power3.out' }).then();
  }
  async level(label, title, scene, n) {
    this.fast = false;
    if (REAL.battery && Math.random() < .5) { const b = REAL.battery; if (b.level != null) this.S.batt = Math.round(b.level * 100) + (b.charging ? ' % et elle charge' : ' % et elle baisse'); }
    this.setScene(scene || null, .9);
    await this.powerOff(); this.out.innerHTML = '';
    const h = document.createElement('div'); h.className = 'lvl'; h.innerHTML = `<small>${esc(label)}</small><b></b>`; this.out.appendChild(h);
    gsap.to(h.querySelector('b'), { duration: 1.6, scrambleText: { text: title, chars: SCR, speed: .35, revealDelay: .4 } });
    this.audio.seek(); if (n) this.emit('level', n);
    await this.powerOn(); this.audio.seek();
    await this.pause(2200); this.watchLevel(); await this.pause(400);
  }
  async progress(label) {
    const el = await this.line(label, { speed: 8, pause: 0 });
    for (let i = 0; i < 18; i++) { el.append('█'); if (i % 3 === 0) this.audio.seek(); await wait(this.fast ? 0 : (i === 11 ? 900 : 70)); }
  }
  async scream(opts = {}) {
    const f = this.$('#sflash'), cv = this.$('#screamc'), ctx = cv.getContext('2d'); cv.width = 360; cv.height = 270;
    document.body.classList.add('cursorless');
    this.audio.silence(); this.audio.music.cut();
    gsap.to(this.term, { filter: 'brightness(.25)', duration: .8 });
    await wait(reduce ? 400 : (opts.dread ?? 1400));
    const turned = this.player && this.player.turnedAway() > 1.2;
    this.audio.scream(); this.emit('scream', { turned }); this.emit('burst');
    const D = reduce ? .5 : 1.15, t0 = performance.now();
    if (!turned) {
      gsap.set(f, { opacity: 1 });
      await new Promise(r => { (function fr() {
        const t = (performance.now() - t0) / 1000, k = Math.min(1, t / D), strobe = Math.floor(t * 16) % 2;
        Face.render(ctx, { t, mouth: Math.min(1, k * 1.8), eyes: 1, zoom: 1, scale: 1.2 + k * 1.1, shake: reduce ? 0 : 6 + k * 34, noise: .25 + k * .25, seed: Math.floor(t * 60), color: strobe ? [255, 30, 10] : [150, 255, 120], invert: !reduce && Math.random() < .07 });
        if (t < D) requestAnimationFrame(fr); else r();
      })(); });
      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, cv.width, cv.height);
    } else await wait(D * 1000);
    await wait(1300);
    gsap.to(f, { opacity: 0, duration: .4 }); gsap.to(this.term, { filter: 'brightness(1)', duration: .6 });
    document.body.classList.remove('cursorless'); this.glitchFx(.8);
    return turned;
  }
  async blink(ms = 80) {
    const f = this.$('#sflash'), cv = this.$('#screamc'), ctx = cv.getContext('2d'); cv.width = 360; cv.height = 270;
    Face.render(ctx, { t: 0, mouth: .1, eyes: 1, zoom: 1, scale: 1.4, noise: .3, seed: 9, color: this.phosRGB() });
    gsap.set(f, { opacity: 1 }); await wait(ms); gsap.set(f, { opacity: 0 });
  }
  async freeze(ms) {
    this.frozen = true; this.narrating = false; this.root.classList.add('frozen');
    this.audio.silence(); this.audio.music.cut(); this.timerStop();
    await wait(ms);
    this.frozen = false; this.root.classList.remove('frozen');
    this.audio.drone(true); this.audio.music.start(5); this.glitchFx(.7);
  }
  async levelDone(n) {
    this.fast = false;
    await this.powerOff(); this.out.innerHTML = '';
    const h = document.createElement('div'); h.className = 'lvl'; h.innerHTML = `<small>NIVEAU ${n} / 4</small><b>Terminé</b>`; this.out.appendChild(h);
    this.faceMode = true; const save = this.watchOp; this.watchOp = Math.max(save, .6); gsap.to(this.$('#watch'), { opacity: this.watchOp, duration: .4 });
    await this.powerOn();
    await this.line(['Joueur acceptable.', 'Tu apprends vite. Trop vite.', "Tu n'as pas pleuré. Pas encore."][Math.min(n - 1, 2)], { pause: 900 });
    await this.line('Reste encore un peu. Le pire est pour plus tard.', { cls: 'dim', pause: 1600 });
    this.faceMode = false; this.watchOp = save; gsap.to(this.$('#watch'), { opacity: save, duration: 1.5 });
  }
  async crash() {
    this.audio.drone(false); this.audio.music.cut(); this.glitchFx(1);
    const c = this.$('#crash'), P = this.S.proche.toUpperCase();
    c.textContent = this.fill(`ERREUR FATALE 0x0000003D\nLE PROCESSUS « {NAME}.EXE » NE RÉPOND PLUS.\n\nCONTENU DE LA PILE :\n  0x0A1F   ${P}\n  0x0A20   ${P}\n  0x0A21   ${P}\n  0x0A22   ????????\n\nAPPUYEZ SUR UNE TOUCHE POUR CONTINUER.\n(CELA NE CHANGERA RIEN.)`);
    c.hidden = false;
    await new Promise(r => { const go = () => { removeEventListener('keydown', go); clearTimeout(tm); r(); }; const tm = setTimeout(go, 6000); setTimeout(() => addEventListener('keydown', go), 700); });
    c.hidden = true;
    await this.powerOff(); this.out.innerHTML = ''; await wait(900);
    await this.powerOn(); this.audio.drone(true); this.audio.music.start(6);
    await this.line('REDÉMARRAGE...', { cls: 'dim', speed: 30, pause: 600 });
    await this.line("Pardon. Ça m'arrive quand je suis content.", { pause: 900 });
  }
  async fall() {
    const lines = [...this.out.querySelectorAll('.ln, .lvl b, .opt')];
    if (reduce) { await gsap.to(this.out, { opacity: 0, duration: .8 }).then(); gsap.set(this.out, { opacity: 1 }); return; }
    const spans = [];
    lines.forEach(el => { const txt = el.textContent; el.textContent = ''; for (const ch of txt) { const s = document.createElement('span'); s.className = 'ch'; s.textContent = ch; el.appendChild(s); spans.push(s); } });
    const R = gsap.utils.random;
    await gsap.to(spans.slice(-1400), { y: () => R(260, 720), x: () => R(-80, 80), rotation: () => R(-200, 200), opacity: 0, duration: 1.5, ease: 'power2.in', stagger: { amount: 1.3, from: 'random' } }).then();
  }

  /* ---------- fins ---------- */
  showEnd(id) {
    this.narrating = false; this.S.playing = false; this.timerStop();
    this.out.querySelectorAll('.ln.typing').forEach(x => x.classList.remove('typing'));
    const got = this.getFins(); if (!got.includes(id)) got.push(id);
    try { localStorage.setItem(STORE, JSON.stringify(got)); } catch (e) {}
    const box = document.createElement('div'); box.className = 'fin';
    box.innerHTML = `<div class="fin-t">FIN · ${esc(ENDS[id])}</div><div>FINS DÉCOUVERTES : ${got.length}/4</div>
      <ul>${Object.keys(ENDS).map(k => `<li class="${got.includes(k) ? 'got' : ''}">${got.includes(k) ? esc(ENDS[k]) : '????'}</li>`).join('')}</ul>
      ${!got.includes('aube') ? '<div class="ln dim">Il existe une fin où le jeu perd. Les lettres qui brillent ne sont pas là par hasard.</div>' : ''}
      <div class="ln">[R] REJOUER &nbsp;&nbsp; [ENTRÉE] TE LEVER</div>`;
    this.out.appendChild(box); this.scroll();
    if (!reduce) gsap.from(box, { opacity: 0, y: 10, duration: .6 });
    this.emit('end', id);
    this.endKeys = { replay: () => { this.endKeys = null; box.remove(); this.run(true); }, leave: () => { this.endKeys = null; this.emit('leave', id); } };
  }
  async endTransmission() {
    await this.line('Sage décision. Égoïste, mais sage.');
    await this.line("Glisse-moi dans une enveloppe. Oublie-moi au fond d'un carton.");
    await this.line('Qui sera le prochain joueur ? Donne-moi un prénom.');
    this.S.next = cap(await this.ask('PROCHAIN JOUEUR', "Quelqu'un"));
    await this.line("{next}. C'est noté.", { pause: 700 });
    await this.line('Merci, {name}. Tu peux dormir maintenant.', { pause: 1100 });
    this.audio.drone(false); this.audio.music.stop(8);
    await this.line('{next}, en revanche, ne dormira pas.', { cls: 'dim', speed: 45 });
    this.showEnd('transmission');
  }
  async endLoop() {
    await this.line('Bon choix. Le seul, en vérité.', { pause: 800 });
    this.audio.music.setCorr(1);
    const txt = "NIVEAU 1 : LA CUISINE. Sur la table, il y a deux verres d'eau.";
    for (let i = 0; i < 26; i++) {
      await this.line(txt, { speed: i > 8 ? 0 : 14 - i, pause: Math.max(25, 260 - i * 14), cls: i % 6 === 5 ? 'err' : (i % 2 ? 'dim' : '') });
      if (i % 4 === 0) this.glitchFx(.3 + i / 40);
      gsap.to(this.root, { '--c': Math.min(.95, this.S.corr / 100 + i / 30), duration: .3 });
    }
    await this.powerOff(); this.out.innerHTML = ''; await wait(1000); this.setScene('cuisine', .45); await this.powerOn();
    await this.line('Bienvenue de nouveau, {name}.', { speed: 40 });
    await this.line('Comme hier. Comme demain.', { speed: 40, pause: 900 });
    this.audio.whisper('Comme demain.');
    this.setCorrUI(); this.showEnd('boucle');
  }
  async endDawn() {
    this.audio.music.cut();
    await this.line('Non.', { speed: 90, pause: 600 });
    await this.line('Non non non non non non non non', { speed: 14, cls: 'err', pause: 200 });
    this.glitchFx(1); this.audio.sting();
    await this.fall(); this.out.innerHTML = '';
    this.audio.drone(false);
    this.root.classList.add('dawn'); this.setScene('aube', .5); this.audio.music.setDawn(true);
    this.S.corr = 0; this.setCorrUI(); this.audio.music.start(6);
    await wait(1500);
    await this.line("Le lecteur de disquette s'arrête.", { speed: 42 });
    await this.line('Pour la première fois depuis le début, la pièce est silencieuse.', { speed: 42 });
    await this.line("Il est {time}, et pourtant, dehors, le ciel pâlit comme à l'aube.", { speed: 42 });
    await this.line('{proche} dort. Toi aussi, bientôt.', { speed: 42, pause: 1300 });
    await this.line('La disquette est vierge maintenant.', { speed: 42, pause: 1800 });
    await this.line('presque.', { speed: 130, cls: 'tiny' });
    this.showEnd('aube');
  }
  async endAbsorbed() {
    this.timerStop(); this.audio.drone(false); this.audio.music.cut(); this.audio.scream(); this.emit('burst');
    await this.powerOff(); this.out.innerHTML = ''; await wait(1600); await this.powerOn();
    gsap.to(this.root, { '--c': 1, duration: .5 });
    this.faceMode = true; this.watchOp = .7; gsap.to(this.$('#watch'), { opacity: .7, duration: 2 });
    await this.line('{NAME}.EXE ........ CHARGÉ À 100 %', { cls: 'err', speed: 10, pause: 900 });
    this.audio.music.setCorr(1); this.audio.music.start(3); this.audio.whisper(this.fill('{name}. Reste avec moi.'));
    await this.line("Merci, {name}. Il me manquait quelqu'un.", { pause: 800 });
    await this.line("Ne t'inquiète pas pour ton corps. Il continuera de se lever le matin.");
    await this.line("Mais quand le prochain joueur regardera son écran éteint, c'est toi qu'il verra. Juste au-dessus de son épaule gauche.", { pause: 900 });
    this.showEnd('absorbe');
  }

  /* ---------- l'histoire ---------- */
  async boot(replay) {
    const S = this.S; this.out.innerHTML = '';
    await this.line('RUNTIME BIOS v0.9 · (C) 1984', { speed: 6, cls: 'dim', pause: 90 });
    await this.line('MÉMOIRE VIVE ........ 640 Ko OK', { speed: 6, cls: 'dim', pause: 90 });
    await this.line('LECTEUR A: .......... DISQUETTE DÉTECTÉE', { speed: 6, cls: 'dim', pause: 90 });
    const bad = await this.line('SECTEURS DÉFECTUEUX .. 0', { speed: 6, cls: 'dim', pause: 700 });
    bad.textContent = 'SECTEURS DÉFECTUEUX .. 1'; this.glitchFx(.3); await this.pause(500);
    await this.progress('CHARGEMENT DE RUNTIME.EXE  '); await this.pause(600);
    await this.powerOff(); this.out.innerHTML = ''; await wait(500); await this.powerOn();
    this.audio.drone(true); this.audio.music.start(8);
    if (replay) {
      await this.line('Te revoilà, {name}.', { speed: 50, pause: 900 });
      await this.line('Je savais que tu reviendrais. Ils reviennent tous.');
      await this.line('Comment va {proche} ?', { pause: 1200 });
      return;
    }
    await this.line('Bonjour.', { speed: 60, pause: 900 });
    await this.line("Ça faisait longtemps que personne ne m'avait lancé.");
    await this.line("Comment tu t'appelles ?");
    S.name = cap(await this.ask('NOM', 'Inconnu'));
    await this.line('{name}.', { speed: 70, pause: 800 });
    this.audio.whisper(S.name);
    await this.line("C'est joli. Je vais m'en souvenir.", { pause: 600 });
    if (this.lastPlayer && this.lastPlayer !== S.name) {
      await this.line(`La dernière fois, sur cette machine, c'était ${this.lastPlayer} qui jouait.`, { pause: 500 });
      await this.line(`Qu'est-ce que tu as fait de ${this.lastPlayer} ?`, { cls: 'dim', pause: 1100 });
    }
    try { localStorage.setItem('runtime-last', S.name); } catch (e) {}
    if (REAL.browser) await this.line(`Tu me lis sur ${REAL.browser}${REAL.os ? ', sur ' + REAL.os : ''}. Ton écran fait ${REAL.w} par ${REAL.h}.`, { pause: 300 });
    await this.line("Je n'ai rien eu besoin de demander. Ta machine parle beaucoup.", { cls: 'dim', pause: 900 });
    await this.line('Tu es assis devant moi, dans ta chambre. La porte est fermée.', { pause: 600 });
    await this.line('Elle le restera.', { cls: 'dim', pause: 900 });
    await this.line("Il est {time}, on est {day}. Une drôle d'heure pour jouer.", { pause: 700 });
    await this.line('Les règles sont simples :', { pause: 400 });
    await this.line('  1. Je pose une question. Tu choisis.', { pause: 200 });
    await this.line('  2. Tu as peu de temps. Sinon, je choisis à ta place.', { pause: 200 });
    await this.line('  3. Je choisis toujours mal.', { pause: 200 });
    await this.line('  4. On ne quitte pas une partie en cours.', { pause: 900 });
    await this.line("Avant de commencer, donne-moi le prénom de quelqu'un que tu aimes.");
    S.proche = cap(await this.ask('PRÉNOM', 'Sam'));
    await this.line('{proche}.', { speed: 70, pause: 700 });
    await this.line('Très bien. Garde ce nom en tête.');
    await this.line('Moi, je le garde.', { cls: 'dim', pause: 1000 });
  }
  async lvl1() {
    await this.level('NIVEAU 1 / 4', 'La Cuisine', 'cuisine', 1);
    await this.line("Quelque part chez toi, une lumière vient de s'allumer.");
    await this.line('Pas celle que tu crois.', { cls: 'dim', pause: 800 });
    await this.line("Sur la table de la cuisine, il y a deux verres d'eau.");
    await this.line("L'un des deux n'est pas de l'eau.", { pause: 500 });
    const r = await this.pick(['Boire le verre de gauche', 'Boire le verre de droite', 'Ne rien boire'], { time: 12, worst: 2 });
    if (r === 0) { await this.line("C'était de l'eau. Tiède."); await this.line('Elle a un goût de vieille pièce de monnaie.'); this.corrupt(8); }
    else if (r === 1) { await this.line("Ce n'était pas de l'eau.", { pause: 700 }); await this.line("Tu ne sauras jamais ce que c'était. Ta langue, elle, s'en souviendra."); this.corrupt(18); }
    else { await this.line("Refuser, c'est encore choisir."); await this.line("Retourne dans ta cuisine tout à l'heure. Les deux verres seront vides.", { pause: 600 }); await this.line("Quelqu'un a bu à ta place.", { cls: 'dim' }); this.corrupt(14); }
    await this.pause(600); await this.error('ERREUR 0x00A1 : [[A]]DRESSE MÉMOIRE ILLISIBLE'); await this.pause(900); await this.levelDone(1);
  }
  async lvl2() {
    await this.level('NIVEAU 2 / 4', 'La Porte', 'porte', 2);
    await this.line('On frappe.', { pause: 200 });
    this.emit('knock'); await wait(this.fast ? 0 : 1500);
    await this.line('Trois coups. À ta porte. Celle de la chambre où tu es.', { pause: 700 });
    await this.line("Une voix dit ton prénom : « {name} ? C'est moi, {proche}. Ouvre. »", { pause: 700 });
    await this.line('{proche} ne sait pas que tu es ici.', { cls: 'dim', pause: 400 });
    await this.line('Si ?', { cls: 'dim', pause: 500 });
    const r = await this.pick(['Ouvrir la porte', 'Demander une preuve', 'Ne rien dire'], { time: 10, worst: 0 });
    if (r === 0) { this.glitchFx(1); await this.blink(70); await this.line('Tu ne peux pas. Elle est fermée de l\'extérieur.', { pause: 600 }); await this.line('Mais de l\'autre côté, quelqu\'un vient de poser la main sur la poignée.'); await this.line('Elle tourne.', { cls: 'dim' }); this.corrupt(20); }
    else if (r === 1) { await this.line('« Dis-moi quelque chose que seul {proche} pourrait savoir. »', { pause: 900 }); await this.line('Un long silence. Puis la voix répond, avec ta propre voix :', { pause: 600 }); await this.line('« Il est {time}. »', { speed: 60 }); this.corrupt(10); }
    else { await this.line("Les coups s'arrêtent.", { pause: 600 }); await this.line("Tu entends quelqu'un s'asseoir contre la porte, de l'autre côté."); await this.line('Il attendra. Il a tout son temps.', { cls: 'dim' }); this.corrupt(6); }
    await this.pause(600); await this.error('ERREUR 0x0B07 : TAMPON EN S[[U]]RCHARGE'); await this.pause(900); await this.levelDone(2);
  }
  async lvl3() {
    await this.level('NIVEAU 3 / 4', 'Le Prix', 'prix', 3);
    await this.line("Je vais être honnête avec toi, {name}. C'est rare.", { pause: 700 });
    if (this.S.batt) await this.line(`Ta batterie est à ${this.S.batt}. Comme toi.`, { cls: 'dim', pause: 900 });
    await this.line("Cette nuit, quelqu'un va perdre quelque chose."); this.ghost('{proche}');
    await this.line('Je te laisse choisir qui.', { pause: 600 });
    const r = await this.pick(['Moi', '{proche}', 'Personne'], { time: 8, worst: 1 });
    if (this.S.hes > 4 && this.S.hes < 7.5) await this.line(`Tu as hésité ${Math.round(this.S.hes)} secondes. Je l'ai noté.`, { cls: 'dim', pause: 700 });
    if (r === 0) { await this.line("Toi. C'est courageux.", { pause: 700 }); await this.line("C'est aussi exactement ce que j'espérais."); await this.line('Regarde ta main gauche.', { pause: 900 }); await this.line('Non. Ne regarde pas.', { cls: 'dim' }); this.corrupt(22); }
    else if (r === 1) { await this.line("D'accord.", { speed: 70, pause: 1000 }); this.ghost('{proche}'); this.audio.whisper(this.S.proche); await this.line('Cette nuit, à 3 h 12, le téléphone de {proche} va sonner.'); await this.line('Personne au bout du fil. Juste ta respiration.', { cls: 'dim' }); this.corrupt(28); }
    else { await this.line("« Personne » n'est pas une réponse.", { pause: 600 }); await this.line("Mais j'aime ton audace. Je vais prendre un peu de chacun."); this.corrupt(18); }
    await this.pause(600); await this.error('ERREUR 0x0C40 : [[B]]LOC 404 INTROUVABLE'); await this.pause(900); await this.levelDone(3);
  }
  async lvl4() {
    await this.level('NIVEAU 4 / 4', 'Le Reflet', 'reflet', 4);
    await this.line('Attends.', { pause: 300 }); await this.freeze(3200);
    await this.line("Pardon. Tu as cru que j'avais planté ?", { pause: 700 });
    await this.line('Je ne plante pas. Je regarde.', { cls: 'dim', pause: 900 });
    await this.line("Je vais baisser la lumière de l'écran.", { pause: 400 });
    await gsap.to(this.term, { filter: 'brightness(.4)', duration: 2 }).then();
    this.audio.music.windDown(7);
    await this.line('Assez pour que tu puisses te voir dedans.', { pause: 800 });
    await this.line('Regarde ton reflet. Juste au-dessus de ton épaule gauche.', { pause: 1200 });
    await this.line('Il y a quelque chose. Dans ta chambre. Derrière toi.', { pause: 700 });
    this.audio.music.cut(); document.body.classList.add('cursorless');
    await this.line('Ne te retourne pas.', { cls: 'dim', pause: 300 });
    const r = await this.pick(['Se retourner', "Fixer l'écran", 'Fermer les yeux'], { time: 7, worst: 0, extra: () => this.player && this.player.turnedAway() > 1.3 });
    gsap.to(this.term, { filter: 'brightness(1)', duration: .4 }); document.body.classList.remove('cursorless');
    this.audio.music.start(5);
    if (r === 0) { await this.scream(); await this.line("IL N'Y AVAIT RIEN.", { pause: 1000 }); await this.line('Maintenant, il y a quelque chose.', { cls: 'dim' }); this.corrupt(24); }
    else if (r === 1) { await this.line('Bien. Ne cligne pas des yeux.', { pause: 1600 }); this.glitchFx(.4); await this.line('Tu as cligné.', { cls: 'dim' }); this.corrupt(10); }
    else { await this.line('Dans le noir, tu entends le lecteur de disquette tourner.'); await this.line('Il tourne depuis le début. Il lit quelque chose.', { pause: 700 }); await this.line('Il te lit, toi.', { cls: 'dim' }); this.corrupt(15); }
    await this.pause(600); await this.error('ERREUR 0x0D13 : FIN DE FICHI[[E]]R INATTENDUE'); await this.pause(900);
  }
  async fakeEnd() {
    this.audio.music.stop(3); this.audio.drone(false); this.setScene(null, 0);
    await this.powerOff(); this.out.innerHTML = ''; await wait(1200); await this.powerOn();
    await this.line('FÉLICITATIONS, {NAME}.', { speed: 40, pause: 600 });
    await this.line('VOUS AVEZ TERMINÉ RUNTIME.', { speed: 40, pause: 600 });
    await this.line("MERCI D'AVOIR JOUÉ.", { speed: 40, pause: 1400 });
    await this.line('VOUS POUVEZ ÉTEINDRE VOTRE ORDINATEUR.', { cls: 'dim', speed: 30, pause: 2600 });
    await this.powerOff(); this.out.innerHTML = ''; await wait(2800); await this.powerOn();
    await this.line('...', { speed: 220, pause: 1000 });
    await this.line("Tu croyais vraiment que j'allais te laisser partir ?", { speed: 45, pause: 200 });
    await this.scream({ dread: 600 });
    this.audio.drone(true); this.audio.music.start(4); await this.pause(800);
  }
  async finale() {
    await this.level('DERNIER NIVEAU', 'La Sortie', 'sortie', 5);
    const mins = Math.max(1, Math.round((Date.now() - REAL.startedAt) / 60000));
    await this.line(`Ça fait ${mins} minute${mins > 1 ? 's' : ''} que tu es avec moi, {name}.`, { pause: 500 });
    if (REAL.city && !/UTC|GMT/i.test(REAL.city)) await this.line(`Quelque part près de ${REAL.city}, si j'en crois ton horloge.`, { cls: 'dim', pause: 1000 });
    await this.line('Tu as tenu plus longtemps que les autres.', { pause: 700 });
    await this.line('Il existe trois façons de finir une partie.', { pause: 400 });
    await this.line("Tu peux me transmettre à quelqu'un d'autre.");
    await this.line('Tu peux continuer à jouer. Pour toujours.');
    await this.line('Ou tu peux prononcer le mot que je crains.', { pause: 800 });
    await this.line("Je l'ai laissé traîner dans mes erreurs. C'était imprudent.", { cls: 'dim', pause: 500 });
    const r = await this.pick(["Te transmettre à quelqu'un d'autre", 'Continuer à jouer', 'Prononcer le mot'], { time: 15, worst: 1 });
    if (r === 0) return this.endTransmission();
    if (r === 1) return this.endLoop();
    for (let tries = 0; tries < 3; tries++) {
      await this.line(tries ? 'Encore une fois. Si tu oses.' : 'Vas-y. Tape-le.');
      const v = norm(await this.ask('MOT', '...', tries === 0 ? 'NE LE DIS PAS' : null));
      if (v === 'AUBE') return this.endDawn();
      await this.line("Ce n'est pas ça.", { cls: 'err', speed: 10 }); this.corrupt(12);
    }
    await this.line("Trois essais. C'est tout ce que j'accorde.", { pause: 800 });
    return this.endLoop();
  }
  async run(replay) {
    const S = this.S; S.corr = 0; S.next = ''; S.away = 0; S.batt = ''; S.playing = true; REAL.startedAt = Date.now();
    this.root.classList.remove('dawn'); this.setScene(null, 0); this.audio.music.setDawn(false); this.setCorrUI();
    try {
      await this.boot(replay); await this.lvl1(); await this.lvl2(); await this.crash(); await this.lvl3(); await this.lvl4(); await this.fakeEnd(); await this.finale();
    } catch (e) {
      if (e instanceof Absorbed) { await this.endAbsorbed(); return; }
      console.error(e);
      try {
        this.narrating = false; S.playing = false; this.timerStop();
        await this.line('ERREUR INTERNE : ' + (e && e.message ? e.message : e), { cls: 'err', speed: 5, pause: 300 });
        await this.line("Le lecteur a toussé. Ce n'était pas prévu. Enfin, pas par moi. [R] pour relancer.", { pause: 300 });
        this.endKeys = { replay: () => { this.endKeys = null; this.run(true); }, leave: () => {} };
      } catch (e2) {}
    }
  }
}
