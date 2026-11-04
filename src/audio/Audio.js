// Audio : synthèse Tone.js (musique, cœur, respiration, cris, chuchotements) + échantillons Kenney positionnés dans la pièce.
import * as THREE from 'three';
import * as T from 'tone';

const BASE = import.meta.env.BASE_URL + 'assets/audio/';
const SAMPLES = {
  footstep: ['footstep_wood_000', 'footstep_wood_001', 'footstep_wood_002', 'footstep_wood_003', 'footstep_wood_004'],
  carpet: ['footstep_carpet_000', 'footstep_carpet_001', 'footstep_carpet_002'],
  creak: ['creak1', 'creak2', 'creak3'],
  doorOpen: ['doorOpen_1'], doorClose: ['doorClose_1'], latch: ['metalLatch'], click: ['metalClick'],
  bookOpen: ['bookOpen'], bookClose: ['bookClose'], cloth: ['cloth1', 'cloth2'],
  glass: ['impactGlass_heavy_000', 'impactGlass_heavy_001'], thud: ['impactWood_heavy_000', 'impactWood_heavy_001', 'impactWood_heavy_002'],
  metal: ['impactMetal_heavy_000', 'impactMetal_heavy_001'], plate: ['impactPlate_heavy_000'],
};

export class Audio {
  constructor(camera) {
    this.camera = camera;
    this.listener = new THREE.AudioListener(); camera.add(this.listener);
    this.buffers = {}; this.ready = false; this.on = true;
    this.loader = new THREE.AudioLoader();
    this.corr = 0;
  }
  async init() {
    if (this.ready) return;
    try { await T.start(); } catch (e) {}
    try { if (this.listener.context.state !== 'running') await this.listener.context.resume(); } catch (e) {}
    this.synth();
    await this.loadSamples();
    this.ready = true;
  }
  async loadSamples() {
    const names = [...new Set(Object.values(SAMPLES).flat())];
    await Promise.all(names.map(n => new Promise(res => this.loader.load(BASE + n + '.ogg', b => { this.buffers[n] = b; res(); }, undefined, () => res()))));
  }
  buffer(kind) { const list = SAMPLES[kind] || [kind]; const n = list[Math.floor(Math.random() * list.length)]; return this.buffers[n]; }
  /** Son non positionné (joueur lui-même). */
  sample(kind, vol = 1, rate = 1) {
    const b = this.buffer(kind); if (!b || !this.on) return;
    const a = new THREE.Audio(this.listener); a.setBuffer(b); a.setVolume(vol); a.setPlaybackRate(rate * (0.94 + Math.random() * .12)); a.play();
    a.source.onended = () => { try { a.disconnect(); } catch (e) {} };
    return a;
  }
  /** Son positionné dans la pièce (x, y, z). */
  at(kind, pos, vol = 1, ref = 1.2, rate = 1) {
    const b = this.buffer(kind); if (!b || !this.on) return;
    const a = new THREE.PositionalAudio(this.listener); a.setBuffer(b); a.setRefDistance(ref); a.setRolloffFactor(1.6); a.setVolume(vol);
    a.setPlaybackRate(rate); a.panner.panningModel = 'HRTF';
    const o = new THREE.Object3D(); o.position.copy(pos); o.add(a); this.camera.parent.add(o); a.play();
    a.source.onended = () => { try { o.removeFromParent(); } catch (e) {} };
    return a;
  }
  click() { this.sample('click', .35, 1.2); }
  step(onRug) { this.sample(onRug ? 'carpet' : 'footstep', .22, .9); }

  /* ---------- synthèse ---------- */
  synth() {
    const master = new T.Volume(-4).connect(new T.Limiter(-1).toDestination()); this.master = master;
    this.keyS = new T.Synth({ oscillator: { type: 'square' }, envelope: { attack: .001, decay: .025, sustain: 0, release: .01 }, volume: -32 }).connect(master);
    this.beep = new T.Synth({ oscillator: { type: 'square' }, envelope: { attack: .002, decay: .12, sustain: 0, release: .05 }, volume: -22 }).connect(master);
    this.noise = new T.NoiseSynth({ noise: { type: 'white' }, envelope: { attack: .001, decay: .25, sustain: 0 }, volume: -18 }).connect(master);
    this.thump = new T.MembraneSynth({ pitchDecay: .05, octaves: 4, envelope: { attack: .001, decay: .35, sustain: 0 }, volume: -10 }).connect(master);
    this.filt = new T.Filter(380, 'lowpass').connect(master);
    this.d1 = new T.Oscillator(55, 'sawtooth').connect(this.filt); this.d2 = new T.Oscillator(55.6, 'sawtooth').connect(this.filt);
    this.d1.volume.value = -80; this.d2.volume.value = -80; this.d1.start(); this.d2.start();
    const dist = new T.Distortion(.9).connect(master);
    this.screams = [3.3, 2.7, 4.1].map(h => new T.FMSynth({ harmonicity: h, modulationIndex: 30, envelope: { attack: .004, decay: .3, sustain: .85, release: .3 }, modulationEnvelope: { attack: .01, decay: .2, sustain: 1, release: .3 }, volume: -20 }).connect(dist));
    this.sub = new T.Synth({ oscillator: { type: 'sine' }, envelope: { attack: .01, decay: .2, sustain: 1, release: .6 }, volume: -4 }).connect(master);
    this.heart = new T.MembraneSynth({ pitchDecay: .08, octaves: 2, envelope: { attack: .001, decay: .3, sustain: 0 }, volume: -60 }).connect(new T.Filter(120, 'lowpass').connect(master));
    this.hbLoop = new T.Loop(time => { try { this.heart.triggerAttackRelease('G0', '16n', time, 1); this.heart.triggerAttackRelease('F0', '16n', time + .19, .6); } catch (e) {} }, 1.2).start(0);
    this.breathPan = new T.Panner3D({ panningModel: 'HRTF', positionX: 0, positionY: 0, positionZ: 1.2, rolloffFactor: .5 }).connect(master);
    this.breath = new T.NoiseSynth({ noise: { type: 'brown' }, envelope: { attack: 1.1, decay: 1.6, sustain: 0 }, volume: -70 }).connect(new T.Filter(420, 'bandpass').connect(this.breathPan));
    this.brLoop = new T.Loop(time => { try { const a = Math.random() * Math.PI * 2; this.breathPan.positionX.setValueAtTime(Math.sin(a) * 1.2, time); this.breathPan.positionZ.setValueAtTime(.4 + Math.abs(Math.cos(a)), time); this.breath.triggerAttackRelease(2.4, time); } catch (e) {} }, 4.6).start(0);
    this.hissPan = new T.Panner3D({ panningModel: 'HRTF', positionX: 1, positionY: .2, positionZ: 1, rolloffFactor: .4 }).connect(new T.PingPongDelay(.23, .35).connect(master));
    this.hissF = new T.Filter(1400, 'bandpass'); this.hissF.Q.value = 6; this.hissF.connect(this.hissPan);
    this.hiss = new T.NoiseSynth({ noise: { type: 'pink' }, envelope: { attack: .03, decay: .14, sustain: 0 }, volume: -16 }).connect(this.hissF);
    // bruit de fond de la pièce : souffle très grave + filtre qui respire
    this.roomF = new T.Filter(160, 'lowpass').connect(master);
    this.room = new T.Noise('brown').connect(this.roomF); this.room.volume.value = -80; this.room.start();
    this.roomLfo = new T.LFO(.07, 120, 260).start(); this.roomLfo.connect(this.roomF.frequency);
    this.music = makeMusic(T, master);
    T.Transport.start('+0.05');
  }
  t() { return T.now() + .01; }
  safe(f) { if (!this.ready || !this.on) return; try { f(); } catch (e) {} }
  toggle() { this.on = !this.on; if (this.master) this.master.mute = !this.on; if (!this.on) try { speechSynthesis.cancel(); } catch (e) {} return this.on; }
  roomTone(v) { this.safe(() => this.room.volume.rampTo(v ? -38 : -80, 3)); }
  key() { const n = performance.now(); if (n - (this._lk || 0) < 38) return; this._lk = n; this.safe(() => this.keyS.triggerAttackRelease(1700 + Math.random() * 900, .02, this.t())); }
  select() { this.safe(() => { this.beep.triggerAttackRelease(990, .05, this.t()); this.beep.triggerAttackRelease(660, .07, this.t() + .08); }); }
  tick(hot) { this.safe(() => { this.thump.triggerAttackRelease(hot ? 'E1' : 'C1', .2, this.t()); if (hot) this.beep.triggerAttackRelease(1320, .05, this.t() + .02); }); }
  glitch(i = .5) { this.safe(() => this.noise.triggerAttackRelease(.05 + .3 * i, this.t())); }
  seek() { this.safe(() => { for (let k = 0; k < 4; k++) this.noise.triggerAttackRelease(.012, this.t() + k * .07); }); }
  sting() { this.safe(() => { this.noise.triggerAttackRelease(.7, this.t()); this.thump.triggerAttackRelease('A0', .8, this.t()); this.beep.triggerAttackRelease(93, .6, this.t()); }); }
  scream() { this.safe(() => {
    const n = this.t();
    this.sub.triggerAttack(95, n); this.sub.frequency.exponentialRampTo(26, 1.3, n); this.sub.triggerRelease(n + 1.3);
    [1700, 2400, 1100].forEach((f, i) => { const sc = this.screams[i]; sc.triggerAttack(f, n + i * .035); sc.frequency.exponentialRampTo(f * .09, 1.05, n + i * .035); sc.triggerRelease(n + 1.15); });
    this.noise.triggerAttackRelease(1.1, n); this.thump.triggerAttackRelease('A0', 1.2, n);
    for (let k = 0; k < 6; k++) this.noise.triggerAttackRelease(.04, n + .15 + k * .09);
  }); }
  silence() { this.safe(() => { this.d1.volume.rampTo(-80, .4); this.d2.volume.rampTo(-80, .4); this.heart.volume.rampTo(-60, .3); this.breath.volume.rampTo(-70, .3); this.room.volume.rampTo(-80, .3); }); }
  drone(onOff) { this.safe(() => { this.d1.volume.rampTo(onOff ? -27 : -80, 1.5); this.d2.volume.rampTo(onOff ? -27 : -80, 1.5); if (onOff) this.setCorr(this.corr); }); }
  setCorr(c) {
    this.corr = c;
    this.safe(() => {
      this.d2.frequency.rampTo(55.6 + c * 7, 2); this.filt.frequency.rampTo(380 + c * 1500, 2);
      this.hbLoop.interval = 1.25 - c * .7; this.heart.volume.rampTo(c < .15 ? -60 : -30 + c * 14, 2);
      this.brLoop.interval = 4.8 - c * 2.2; this.breath.volume.rampTo(c < .35 ? -70 : -34 + (c - .35) * 20, 2);
    });
    this.music.setCorr(c);
  }
  knock(times = 3, pos) { this.safe(() => { for (let k = 0; k < times; k++) setTimeout(() => this.at('thud', pos, .9, 1.5, .8), k * 420); }); }
  hissWords(text) { this.safe(() => {
    const syl = Math.max(2, Math.round((text || '').length / 2.5));
    const side = Math.random() < .5 ? -1 : 1; this.hissPan.positionX.value = side; this.hissPan.positionZ.value = .6 + Math.random();
    this.hissPan.positionX.rampTo(-side * .6, syl * .13);
    for (let k = 0; k < syl; k++) { const n = this.t() + k * .13; this.hissF.frequency.setValueAtTime(700 + Math.random() * 2600, n); this.hiss.triggerAttackRelease(.09, n); }
  }); }
  whisper(text) {
    if (!this.on) return;
    this.hissWords(text);
    try {
      const u = new SpeechSynthesisUtterance(text); u.lang = 'fr-FR'; u.pitch = .1; u.rate = .6; u.volume = .4;
      const v = speechSynthesis.getVoices().find(v => v.lang && v.lang.startsWith('fr')); if (v) u.voice = v;
      speechSynthesis.speak(u);
    } catch (e) {}
  }
}

/* ---------- la berceuse de boîte à musique qui se dérègle ---------- */
function makeMusic(T, master) {
  let ready = false, corr = 0, dawn = false;
  const MEL = ['A4', null, 'D5', null, 'F5', null, 'E5', null, null, null, 'D5', null, 'C#5', null, 'D5', null, 'E5', null, 'A4', null, null, null, null, null,
    'Bb4', null, 'D5', null, 'G5', null, 'F5', null, 'E5', null, 'D5', null, 'C#5', null, 'E5', null, 'A4', null, 'D5', null, null, null, null, null];
  const CH = [['0:0', '2m', ['D3', 'F3', 'A3']], ['2:0', '2m', ['C#3', 'E3', 'A3']], ['4:0', '1m', ['Bb2', 'D3', 'F3']], ['5:0', '1m', ['G2', 'Bb2', 'D3']], ['6:0', '1m', ['A2', 'C#3', 'E3']], ['7:0', '1m', ['D3', 'F3', 'A3']]];
  const BASS = ['D2', 'D2', 'A1', 'A1', 'Bb1', 'G1', 'A1', 'D2'];
  const maj = n => dawn ? n.replace(/^F(\d)$/, 'F#$1').replace(/^Bb(\d)$/, 'B$1') : n;
  const bpm = () => dawn ? 54 : 64 - corr * 18;
  let bus, vib, box, pad, padF, bass;
  try {
    bus = new T.Volume(-80).connect(master);
    const rev = new T.Reverb({ decay: 9, preDelay: .04, wet: .45 }).connect(bus);
    vib = new T.Vibrato({ frequency: 4.5, depth: .03 }).connect(rev);
    box = new T.PolySynth(T.FMSynth, { harmonicity: 3.01, modulationIndex: 12, envelope: { attack: .002, decay: 1.6, sustain: 0, release: 1.6 }, modulationEnvelope: { attack: .002, decay: .25, sustain: 0, release: .2 } }).connect(vib); box.volume.value = -12;
    padF = new T.Filter(900, 'lowpass').connect(rev);
    pad = new T.PolySynth(T.AMSynth, { harmonicity: 1.5, envelope: { attack: 2.5, decay: 1, sustain: .8, release: 5 }, modulationEnvelope: { attack: 2, decay: 1, sustain: 1, release: 4 } }).connect(padF); pad.volume.value = -21;
    bass = new T.MonoSynth({ oscillator: { type: 'triangle' }, envelope: { attack: .02, decay: 1.2, sustain: .15, release: 1 }, filterEnvelope: { attack: .01, decay: .4, sustain: .2, baseFrequency: 70, octaves: 2 } }).connect(bus); bass.volume.value = -12;
    T.Transport.timeSignature = 3; T.Transport.bpm.value = 64;
    new T.Sequence((time, n) => { if (!n) return; try {
      let note = maj(n);
      if (!dawn && Math.random() < corr * .45) note = T.Frequency(note).transpose(Math.random() < .5 ? -1 : 1).toNote();
      box.triggerAttackRelease(note, '4n', time, .45 + Math.random() * .3);
      if (!dawn && corr > .55 && Math.random() < corr * .3) box.triggerAttackRelease(T.Frequency(note).transpose(-13).toNote(), '2n', time + .03, .35);
    } catch (e) {} }, MEL, '8n').start(0);
    const part = new T.Part((time, c) => { try { pad.triggerAttackRelease(c.notes.map(maj), c.dur, time, .55); } catch (e) {} }, CH.map(([time, dur, notes]) => ({ time, dur, notes })));
    part.loop = true; part.loopEnd = '8m'; part.start(0);
    new T.Sequence((time, n) => { try { bass.triggerAttackRelease(maj(n), '2n', time, .8); } catch (e) {} }, BASS, '1m').start(0);
    ready = true;
  } catch (e) { ready = false; }
  const safe = f => { if (!ready) return; try { f(); } catch (e) {} };
  return {
    start(fade = 4) { safe(() => { T.Transport.bpm.rampTo(bpm(), 1); if (T.Transport.state !== 'started') T.Transport.start('+0.1'); bus.volume.cancelScheduledValues(T.now()); bus.volume.rampTo(-8, fade); }); },
    stop(fade = 2) { safe(() => bus.volume.rampTo(-80, fade)); },
    cut() { safe(() => { bus.volume.cancelScheduledValues(T.now()); bus.volume.setValueAtTime(-80, T.now()); }); },
    tension(on) { safe(() => { box.volume.rampTo(on ? -36 : -12, .8); padF.frequency.rampTo(on ? 380 : 900, 1); }); },
    windDown(sec) { safe(() => { T.Transport.bpm.rampTo(16, sec); bus.volume.rampTo(-24, sec); }); },
    setCorr(c) { corr = c; safe(() => { T.Transport.bpm.rampTo(bpm(), 3); vib.depth.rampTo(dawn ? 0 : .03 + c * .5, 2); }); },
    setDawn(v) { dawn = v; if (v) corr = 0; safe(() => { vib.depth.rampTo(v ? 0 : .03, 1); T.Transport.bpm.rampTo(bpm(), 2); }); },
  };
}
