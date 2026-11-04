// La chambre : murs et sol texturés, meubles Kenney, fenêtre sur la nuit, lumières avec ombres, objets interactifs.
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js';
import { drawPoster1, drawPoster2, drawNote, drawClock, drawScreen } from './posters.js';

const BASE = import.meta.env.BASE_URL + 'assets/';
export const ROOM = { W: 6.4, D: 5.2, H: 2.6 };
const MODELS = ['bedSingle', 'desk', 'computerScreen', 'computerKeyboard', 'computerMouse', 'chairDesk', 'bookcaseClosedDoors', 'cabinetBedDrawerTable',
  'lampRoundTable', 'lampSquareCeiling', 'rugRectangle', 'radio', 'books', 'cardboardBoxOpen', 'cardboardBoxClosed', 'coatRackStanding', 'bear', 'plantSmall2',
  'trashcan', 'doorway', 'speaker', 'televisionVintage', 'pillow', 'bookcaseOpen', 'lampRoundFloor'];

export class Room {
  constructor(scene, renderer, audio, { lite = false } = {}) {
    this.scene = scene; this.renderer = renderer; this.audio = audio; this.lite = lite; this.sm = lite ? 256 : 2048;
    this.interactables = []; this.colliders = []; this.gltf = {}; this.tex = {}; this.mats = {};
    this.anims = []; this.corr = 0; this.burstT = 0; this.t = 0;
    this.screenAnchor = new THREE.Object3D();
    this.phos = new THREE.Color(0x55ff66);
    this.wardrobeOpen = false; this.ceilingOn = false; this.dead = false;
  }

  /* ---------- chargement ---------- */
  async load(onProgress) {
    const total = MODELS.length + 12; let done = 0; const tick = () => onProgress && onProgress(++done / total);
    const tl = new THREE.TextureLoader(), gl = new GLTFLoader(), hl = new RGBELoader();
    const t = (name, srgb = true, rep = [1, 1]) => new Promise((res, rej) => tl.load(BASE + 'textures/' + name, tx => {
      tx.wrapS = tx.wrapT = THREE.RepeatWrapping; tx.repeat.set(rep[0], rep[1]); tx.anisotropy = 8;
      if (srgb) tx.colorSpace = THREE.SRGBColorSpace; tick(); res(tx);
    }, undefined, rej));
    const [floorC, floorB, floorR, wallC, wallN, wallR, hdr] = await Promise.all([
      t('hardwood2_diffuse.jpg', true, [3, 2.4]), t('hardwood2_bump.jpg', false, [3, 2.4]), t('hardwood2_roughness.jpg', false, [3, 2.4]),
      t('wall_plaster_dirty_color.jpg', true, [2.6, 1]), t('wall_plaster_dirty_normalgl.jpg', false, [2.6, 1]), t('wall_plaster_dirty_roughness.jpg', false, [2.6, 1]),
      new Promise((res, rej) => hl.load(BASE + 'hdr/moonless_golf_1k.hdr', tx => { tx.mapping = THREE.EquirectangularReflectionMapping; tick(); res(tx); }, undefined, rej)),
    ]);
    this.tex = { floorC, floorB, floorR, wallC, wallN, wallR, hdr };
    const woodC = floorC.clone(); woodC.repeat.set(1.2, 1.2); woodC.needsUpdate = true;
    const woodB = floorB.clone(); woodB.repeat.set(1.2, 1.2); woodB.needsUpdate = true;
    this.tex.woodC = woodC; this.tex.woodB = woodB;
    await Promise.all(MODELS.map(m => new Promise((res, rej) => gl.load(BASE + 'models/kenney/' + m + '.glb', g => { this.gltf[m] = g; tick(); res(); }, undefined, rej))));
    await new Promise((res) => gl.load(BASE + 'models/face/LeePerrySmith.glb', g => { this.gltf.face = g; tick(); res(); }, undefined, () => res()));
    const [faceC, faceN] = await Promise.all([t('../models/face/Map-COL.jpg', true), t('../models/face/Infinite-Level_02_Tangent_SmoothUV.jpg', false)]).catch(() => [null, null]);
    this.tex.faceC = faceC; this.tex.faceN = faceN;
    tick(); tick();
    this.build();
  }

  /* ---------- matériaux ---------- */
  makeMaterials() {
    const T = this.tex;
    const M = this.mats;
    M.floor = new THREE.MeshStandardMaterial({ map: T.floorC, bumpMap: T.floorB, bumpScale: .9, roughnessMap: T.floorR, roughness: .85, color: 0x6e5a46, envMapIntensity: .25 });
    M.wall = new THREE.MeshStandardMaterial({ map: T.wallC, normalMap: T.wallN, roughnessMap: T.wallR, roughness: 1, color: 0x8a7d5e, envMapIntensity: .12 });
    M.ceil = new THREE.MeshStandardMaterial({ map: T.wallC, normalMap: T.wallN, roughness: 1, color: 0x6f6a60, envMapIntensity: .08 });
    M.wood = new THREE.MeshStandardMaterial({ map: T.woodC, bumpMap: T.woodB, bumpScale: .5, roughness: .55, color: 0x7d5c40, envMapIntensity: .35 });
    M.woodDark = new THREE.MeshStandardMaterial({ map: T.woodC, bumpMap: T.woodB, bumpScale: .5, roughness: .6, color: 0x4a3324, envMapIntensity: .3 });
    M.paint = new THREE.MeshStandardMaterial({ color: 0xd8d0bf, roughness: .55, envMapIntensity: .3 });
    M.metal = new THREE.MeshStandardMaterial({ color: 0x8c8780, roughness: .4, metalness: .75, envMapIntensity: .8 });
    M.dark = new THREE.MeshStandardMaterial({ color: 0x1a1715, roughness: .8 });
    M.beige = new THREE.MeshStandardMaterial({ color: 0xa99e83, roughness: .8, envMapIntensity: .2 });
    M.glass = this.lite ? new THREE.MeshStandardMaterial({ color: 0xaac4e8, roughness: .05, transparent: true, opacity: .18 })
      : new THREE.MeshPhysicalMaterial({ color: 0xaac4e8, roughness: .05, metalness: 0, transmission: .9, thickness: .02, transparent: true, opacity: .35, envMapIntensity: 1 });
    M.curtain = new THREE.MeshStandardMaterial({ color: 0x4a1f26, roughness: 1, side: THREE.DoubleSide });
    M.fabric = new THREE.MeshStandardMaterial({ color: 0x55596a, roughness: 1 });
  }
  /** Remplace les aplats Kenney par des matières éclairables (bois texturé, métal, tissu, verre). */
  remap(mat) {
    const n = (mat.name || '').toLowerCase(), c = mat.color ? mat.color.clone() : new THREE.Color(0x888888);
    if (n === 'wood') return this.mats.wood;
    if (n === 'wooddark') return this.mats.woodDark;
    if (n.startsWith('metal')) { const m = this.mats.metal.clone(); m.color.copy(c).multiplyScalar(.9); if (n === 'metaldark') { m.color.set(0x24221f); m.metalness = .4; m.roughness = .6; } return m; }
    if (n.startsWith('carpet')) { const col = this._tint && this._tint[n] != null ? new THREE.Color(this._tint[n]) : c.multiplyScalar(.55); return new THREE.MeshStandardMaterial({ color: col, roughness: 1 }); }
    if (n === 'glass') return this.mats.glass;
    if (n === 'lamp') return new THREE.MeshStandardMaterial({ color: 0xf2e9d2, roughness: .7, emissive: 0x2a2416, emissiveIntensity: .4 });
    if (n === 'fur') return new THREE.MeshStandardMaterial({ color: 0x5a4330, roughness: 1 });
    if (n === 'plant') return new THREE.MeshStandardMaterial({ color: 0x2f4a2a, roughness: 1 });
    const m = new THREE.MeshStandardMaterial({ color: c.multiplyScalar(.8), roughness: .9 }); return m;
  }
  place(name, { x = 0, y = 0, z = 0, ry = 0, scale = 1, solid = true, shrink = 0, tint = null } = {}) {
    const src = this.gltf[name]; if (!src) return null; this._tint = tint;
    const g = src.scene.clone(true);
    g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; o.material = this.remap(o.material); } });
    g.scale.setScalar(scale); g.rotation.y = ry;
    // on pose le modèle de sorte que le centre de sa base soit en (x, y, z)
    g.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(g); const c = box.getCenter(new THREE.Vector3());
    g.position.set(x - c.x, y - box.min.y, z - c.z);
    this.scene.add(g); g.updateMatrixWorld(true);
    if (solid) { const b = new THREE.Box3().setFromObject(g); this.colliders.push([b.min.x + shrink, b.max.x - shrink, b.min.z + shrink, b.max.z - shrink]); }
    g.name = name; return g;
  }
  box(w, h, d, x, y, z, mat, ry = 0, shadow = true) {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.position.set(x, y, z); m.rotation.y = ry; m.castShadow = shadow; m.receiveShadow = true; this.scene.add(m); return m;
  }
  plane(w, h, mat, x, y, z, rx = 0, ry = 0) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat); m.position.set(x, y, z); m.rotation.set(rx, ry, 0); m.receiveShadow = true; this.scene.add(m); return m;
  }
  canvasTex(w, h, draw) {
    const cv = document.createElement('canvas'); cv.width = w; cv.height = h; const cx = cv.getContext('2d'); draw(cx, w, h);
    const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return { t, cv, cx };
  }
  inter(id, label, object, range = 2.2) { this.interactables.push({ id, label, object, range }); }

  /* ---------- construction ---------- */
  build() {
    const S = this.scene, { W, D, H } = ROOM;
    this.makeMaterials(); const M = this.mats;
    // environnement de nuit : reflets discrets, et le dehors visible par la fenêtre
    const pm = new THREE.PMREMGenerator(this.renderer); S.environment = pm.fromEquirectangular(this.tex.hdr).texture; pm.dispose();
    S.background = this.tex.hdr; S.backgroundIntensity = .22; S.backgroundBlurriness = .02;
    S.fog = new THREE.FogExp2(0x040308, .085);
    // sol, plafond, murs (le mur gauche est percé pour la fenêtre)
    this.plane(W, D, M.floor, 0, 0, 0, -Math.PI / 2);
    this.plane(W, D, M.ceil, 0, H, 0, Math.PI / 2);
    this.plane(W, H, M.wall, 0, H / 2, -D / 2);
    this.plane(W, H, M.wall, 0, H / 2, D / 2, 0, Math.PI);
    this.plane(D, H, M.wall, W / 2, H / 2, 0, 0, -Math.PI / 2);
    const wx = -W / 2, wz0 = -1.3, wz1 = .1, wy0 = .95, wy1 = 2.25, fz = (wz0 + wz1) / 2, fw = wz1 - wz0, fh = wy1 - wy0, fy = (wy0 + wy1) / 2;
    this.box(.12, wy0, D, wx, wy0 / 2, 0, M.wall); this.box(.12, H - wy1, D, wx, (H + wy1) / 2, 0, M.wall);
    this.box(.12, fh, wz0 + D / 2, wx, fy, (wz0 - D / 2) / 2, M.wall); this.box(.12, fh, D / 2 - wz1, wx, fy, (wz1 + D / 2) / 2, M.wall);
    // fenêtre
    this.box(.14, .06, fw + .14, wx, wy0 - .03, fz, M.paint); this.box(.14, .06, fw + .14, wx, wy1 + .03, fz, M.paint); this.box(.14, fh, .06, wx, fy, wz0 - .03, M.paint); this.box(.14, fh, .06, wx, fy, wz1 + .03, M.paint);
    this.box(.05, fh, .04, wx + .02, fy, fz, M.paint); this.box(.05, .04, fw, wx + .02, fy, fz, M.paint);
    this.box(.24, .04, fw + .34, wx + .1, wy0 - .02, fz, M.wood);
    const glass = this.plane(fw, fh, M.glass, wx + .045, fy, fz, 0, Math.PI / 2); glass.castShadow = false; this.inter('window', 'Regarder dehors', glass, 1.6);
    for (const side of [-1, 1]) {
      const g = new THREE.PlaneGeometry(.6, fh + .5, 14, 1), pa = g.attributes.position;
      for (let i = 0; i < pa.count; i++) pa.setZ(i, Math.sin(pa.getX(i) * 20) * .04);
      g.computeVertexNormals();
      const cm = new THREE.Mesh(g, M.curtain); cm.position.set(wx + .17, fy + .1, fz + side * (fw / 2 + .08)); cm.rotation.y = Math.PI / 2; cm.castShadow = true; S.add(cm);
    }
    this.box(.05, .04, fw + .6, wx + .17, wy1 + .3, fz, M.metal);
    for (let i = 0; i < 9; i++) this.box(.08, .55, .07, wx + .14, .5, fz - .5 + i * .125, M.paint);
    // plinthes, interrupteur
    this.box(W, .1, .03, 0, .05, -D / 2 + .015, M.woodDark); this.box(W, .1, .03, 0, .05, D / 2 - .015, M.woodDark); this.box(.03, .1, D, W / 2 - .015, .05, 0, M.woodDark);
    const sw = this.box(.02, .12, .08, W / 2 - .02, 1.25, .45, M.paint); this.inter('switch', 'Interrupteur', sw, 1.6);
    const swb = this.box(.015, .05, .03, W / 2 - .035, 1.25, .45, M.paint); this.switchBtn = swb;
    // porte (verrouillée)
    this.door = this.place('doorway', { x: W / 2 - .08, z: 1.2, ry: -Math.PI / 2, scale: 2.0, solid: false });
    this.doorNode = this.door.getObjectByName('door');
    this.inter('door', 'Ouvrir la porte', this.door, 2.0);
    this.colliders.push([W / 2 - .3, W / 2, .6, 1.8]);
    // bureau et ordinateur (mur du fond)
    const desk = this.place('desk', { x: 1.3, z: -2.1, scale: 1.9 }); this.desk = desk;
    const dtop = new THREE.Box3().setFromObject(desk).max.y;
    const pc = new THREE.Group(); S.add(pc); this.pc = pc;
    const unit = this.box(.56, .13, .46, 1.3, dtop + .065, -2.22, M.beige); pc.add(unit.clone()); unit.removeFromParent(); pc.add(unit);
    this.box(.22, .016, .01, 1.21, dtop + .085, -1.985, M.dark);
    this.led = new THREE.Mesh(new THREE.BoxGeometry(.016, .016, .006), new THREE.MeshStandardMaterial({ color: 0x3b2b12, emissive: 0x000000 })); this.led.position.set(1.08, dtop + .1, -1.985); S.add(this.led);
    const mon = this.place('computerScreen', { x: 1.3, y: dtop + .13, z: -2.22, scale: 1.8, solid: false }); pc.add(mon); this.monitor = mon;
    const mb = new THREE.Box3().setFromObject(mon); const mc = mb.getCenter(new THREE.Vector3());
    // écran : une face noire + la texture « insérer disquette » ; l'ancre CSS3D est au même endroit
    const sw_ = (mb.max.x - mb.min.x) * .78, sh_ = (mb.max.y - mb.min.y) * .62;
    this.screenSize = [sw_, sh_];
    this.screenIdle = this.canvasTex(256, 192, (c, w, h) => drawScreen(c, w, h, 0));
    const scr = new THREE.Mesh(new THREE.PlaneGeometry(sw_, sh_), new THREE.MeshBasicMaterial({ map: this.screenIdle.t, toneMapped: false }));
    scr.position.set(mc.x, mc.y + sh_ * .04, mb.max.z + .003); S.add(scr); this.screenMesh = scr;
    this.screenAnchor.position.copy(scr.position); this.screenAnchor.position.z += .002; S.add(this.screenAnchor);
    this.screenPos = scr.position.clone();
    const pcHit = new THREE.Mesh(new THREE.BoxGeometry(.95, .75, .75), new THREE.MeshBasicMaterial({ visible: false })); pcHit.position.set(1.3, dtop + .36, -2.05); S.add(pcHit); pc.add(pcHit);
    this.inter('pc', 'Insérer la disquette', pc, 2.2);
    this.colliders.push([.6, 2.0, -2.6, -1.55]);
    this.place('computerKeyboard', { x: 1.3, y: dtop, z: -1.78, scale: 1.6, solid: false });
    this.place('computerMouse', { x: 1.62, y: dtop, z: -1.8, ry: .3, scale: 1.5, solid: false });
    this.place('books', { x: .85, y: dtop, z: -2.3, ry: .2, scale: 1.8, solid: false });
    this.place('lampRoundTable', { x: .72, y: dtop, z: -2.1, scale: 1.25, solid: false });
    this.place('chairDesk', { x: 1.9, z: -1.25, ry: -.7, scale: 1.4, shrink: .05, tint: { carpet: 0x2b2f3a } });
    this.place('trashcan', { x: .45, z: -2.1, scale: 1.1 });
    this.place('speaker', { x: 2.35, z: -2.3, scale: 1.4 });
    // lit, chevet, réveil, lampe, nounours
    const bed = this.place('bedSingle', { x: -2.55, z: .75, ry: Math.PI / 2, scale: 1.78, tint: { carpet: 0x3d2a34, carpetwhite: 0x9a948a } }); this.inter('bed', 'Se coucher', bed, 2.0);
    this.place('bear', { x: -2.4, y: .64, z: 1.3, ry: 2.4, scale: 1.0, solid: false });
    const ns = this.place('cabinetBedDrawerTable', { x: -2.8, z: -.95, scale: 2.0 }); const nst = new THREE.Box3().setFromObject(ns).max.y;
    this.place('lampRoundFloor', { x: -2.7, z: 2.2, scale: 1.9 });
    this.place('radio', { x: -2.75, y: nst, z: -1.1, ry: .4, scale: 1.1, solid: false }).traverse(o => { if (o.isMesh) o.userData.radio = true; });
    this.inter('radio', 'Allumer la radio', this.scene.getObjectByName('radio'), 1.8);
    const clk = this.box(.2, .09, .09, -2.72, nst + .045, -.72, M.dark); this.clockTex = this.canvasTex(128, 64, drawClock);
    const clkFace = new THREE.Mesh(new THREE.PlaneGeometry(.17, .07), new THREE.MeshBasicMaterial({ map: this.clockTex.t, toneMapped: false })); clkFace.position.set(-2.72, nst + .05, -.674); S.add(clkFace);
    this.inter('clock', 'Regarder le réveil', clk, 1.6);
    // armoire (porte entrouverte), carton, portemanteau
    const ward = this.place('bookcaseClosedDoors', { x: -2.4, z: -2.25, scale: 2.8 }); this.wardrobe = ward;
    this.wardDoorL = ward.getObjectByName('doorLeft'); this.wardDoorR = ward.getObjectByName('doorRight');
    if (this.wardDoorR) this.wardDoorR.rotation.y = -.35;
    this.inter('wardrobe', "Ouvrir l'armoire", ward, 2.2);
    const wb = new THREE.Box3().setFromObject(ward);
    this.floppy = new THREE.Mesh(new THREE.BoxGeometry(.09, .005, .09), M.dark); this.floppy.position.set(wb.min.x + .4, wb.min.y + 1.0, wb.max.z - .3); this.floppy.rotation.set(0, .3, 0); this.floppy.castShadow = true; S.add(this.floppy);
    const lab = new THREE.Mesh(new THREE.PlaneGeometry(.07, .028), new THREE.MeshStandardMaterial({ color: 0xefe7d2, roughness: 1 })); lab.rotation.x = -Math.PI / 2; lab.position.set(0, .0031, -.025); this.floppy.add(lab);
    this.place('cardboardBoxOpen', { x: -1.3, z: -2.25, ry: .4, scale: 1.6 });
    this.place('cardboardBoxClosed', { x: -1.0, z: -2.35, ry: -.2, scale: 1.4 });
    this.place('coatRackStanding', { x: 2.75, z: 2.1, scale: 2.2 });
    this.place('plantSmall2', { x: wx + .1, y: wy0, z: fz + .45, scale: 2.4, solid: false });
    const shelf = this.place('bookcaseOpen', { x: 2.6, z: -2.45, scale: 2.2 }); const st = new THREE.Box3().setFromObject(shelf).max.y;
    this.place('televisionVintage', { x: 2.6, y: st, z: -2.45, scale: 1.3, solid: false });
    this.place('rugRectangle', { x: .1, y: .004, z: .5, scale: 1.6, solid: false, tint: { carpet: 0x4a2326, carpetdarker: 0x2a1416 } });
    this.place('pillow', { x: -2.55, y: .62, z: -.1, ry: 1.2, scale: 2.0, solid: false, tint: { carpet: 0x9a948a } });
    // plafonnier et interrupteur
    this.ceilLamp = this.place('lampSquareCeiling', { x: 0, y: H - .46, z: .2, scale: 2.0, solid: false });
    this.ceilLight = new THREE.PointLight(0xffd9a0, 0, 7, 1.5); this.ceilLight.position.set(0, H - .5, .2); S.add(this.ceilLight);
    // affiches
    const p1 = this.canvasTex(256, 368, drawPoster1), p2 = this.canvasTex(256, 256, drawPoster2), nt = this.canvasTex(128, 160, drawNote);
    this.plane(.7, 1.0, new THREE.MeshStandardMaterial({ map: p1.t, roughness: 1 }), -.5, 1.6, -D / 2 + .005);
    this.plane(.5, .5, new THREE.MeshStandardMaterial({ map: p2.t, roughness: 1 }), 2.6, 1.9, -D / 2 + .005);
    const note = this.plane(.28, .35, new THREE.MeshStandardMaterial({ map: nt.t, roughness: 1 }), .55, 1.45, -D / 2 + .006); note.rotation.z = .06; this.inter('note', 'Lire le mot', note, 1.8);
    // lumières : clair de lune, lueur de l'écran, lampe de poche
    const moon = new THREE.SpotLight(0x8fa6d6, 220, 16, .4, .55, 1.2); moon.position.set(wx - 2.6, 3.0, fz + .2); moon.target.position.set(-.3, 0, .9); moon.castShadow = !this.lite;
    moon.shadow.mapSize.set(this.sm, this.sm); moon.shadow.bias = -.0004; moon.shadow.normalBias = .02; S.add(moon, moon.target);
    this.glow = new THREE.PointLight(0x55ff66, 2.2, 3.4, 1.7); this.glow.position.set(1.3, dtop + .4, -1.75); S.add(this.glow);
    this.glowS = new THREE.SpotLight(0x55ff66, 2.2, 6, .5, .9, 1.4); this.glowS.position.set(1.3, dtop + .35, -1.95); this.glowS.target.position.set(1.1, .5, 1.6); this.glowS.castShadow = !this.lite; this.glowS.shadow.mapSize.set(1024, 1024); this.glowS.shadow.bias = -.0005; S.add(this.glowS, this.glowS.target);
    S.add(new THREE.AmbientLight(0x0b0a12, .9));
    // poussière
    const N = 600, dp = new Float32Array(N * 3); for (let i = 0; i < N; i++) { dp[i * 3] = (Math.random() - .5) * 6; dp[i * 3 + 1] = Math.random() * 2.5; dp[i * 3 + 2] = (Math.random() - .5) * 5; }
    const dg = new THREE.BufferGeometry(); dg.setAttribute('position', new THREE.BufferAttribute(dp, 3)); this.dust = dg;
    S.add(new THREE.Points(dg, new THREE.PointsMaterial({ color: 0xffe9c0, size: .012, transparent: true, opacity: .3, depthWrite: false, blending: THREE.AdditiveBlending })));
    // une silhouette, dehors, derrière la vitre (invisible tant que le jeu ne l'appelle pas)
    const sil = new THREE.Group(); const silM = new THREE.MeshStandardMaterial({ color: 0x020203, roughness: 1 });
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(.22, 1.1, 4, 10), silM); body.position.y = .85; sil.add(body);
    const head = new THREE.Mesh(new THREE.SphereGeometry(.13, 12, 10), silM); head.position.y = 1.72; sil.add(head);
    sil.position.set(wx - .55, 0, fz + .15); sil.visible = false; S.add(sil); this.sil = sil;
    // le visage (screamer) : invisible tant que le jeu ne l'appelle pas
    this.buildFace();
  }
  buildFace() {
    const g = this.gltf.face; if (!g) return;
    const mesh = g.scene.getObjectByProperty('isMesh', true); if (!mesh) return;
    const mat = new THREE.MeshStandardMaterial({ map: this.tex.faceC, normalMap: this.tex.faceN, color: 0x9a8f88, roughness: .55 });
    this.face = new THREE.Mesh(mesh.geometry, mat);
    const b = new THREE.Box3().setFromObject(this.face); const h = b.max.y - b.min.y; this.face.scale.setScalar(.26 / h);
    this.face.visible = false; this.face.castShadow = true; this.scene.add(this.face);
    this.faceLight = new THREE.PointLight(0xff3b24, 0, 3, 2); this.scene.add(this.faceLight);
  }
  attachFlashlight(camera) {
    const spot = new THREE.SpotLight(0xffe2b0, 11, 14, .42, .9, 1.6); camera.add(spot); spot.position.set(.18, -.18, 0); spot.target.position.set(0, -.05, -1); camera.add(spot.target);
    spot.castShadow = true; spot.shadow.mapSize.set(this.sm, this.sm); spot.shadow.bias = -.0004; spot.shadow.normalBias = .02; spot.shadow.camera.near = .1; spot.shadow.camera.far = 14;
    this.flash = spot;
    const cone = new THREE.Mesh(new THREE.ConeGeometry(1.5, 6, 24, 1, true), new THREE.MeshBasicMaterial({ color: 0xffe2b0, transparent: true, opacity: .01, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
    cone.rotation.x = Math.PI / 2; cone.position.set(.18, -.18, -3.2); camera.add(cone);
  }

  /* ---------- état piloté par le jeu ---------- */
  setCorruption(c) {
    this.corr = c; const col = new THREE.Color().setHSL((118 - 118 * c) / 360, 1, .62 - .12 * c); this.phos.copy(col);
    this.glow.color.copy(col); this.glowS.color.copy(col);
  }
  burst(sec) { this.burstT = sec; }
  screenOff() { this.screenMesh.visible = false; }
  screenOn() { this.screenMesh.visible = true; }
  async openWardrobe() {
    if (this.wardrobeOpen) return; this.wardrobeOpen = true;
    const wb = new THREE.Box3().setFromObject(this.wardrobe); const c = wb.getCenter(new THREE.Vector3());
    this.audio.at('creak', new THREE.Vector3(c.x, 1.2, wb.max.z), .9, 1.2, .8);
    await this.tween(1.3, k => { if (this.wardDoorL) this.wardDoorL.rotation.y = -1.9 * k; if (this.wardDoorR) this.wardDoorR.rotation.y = -.35 - 1.5 * k; });
    this.audio.at('latch', new THREE.Vector3(c.x, 1.2, wb.max.z), .5, 1.2);
  }
  async insertFloppy(player) {
    // le joueur s'assoit : la caméra glisse jusqu'à la chaise, face à l'écran
    const seat = new THREE.Vector3(this.screenPos.x, this.screenPos.y + .1, this.screenPos.z + .82);
    const from = player.pos.clone(); from.y = 1.55; const fy = player.yaw, fp = player.pitch;
    player.enabled = false; player.lookEnabled = false;
    await this.tween(1.6, k => {
      const e = k * k * (3 - 2 * k);
      player.camera.position.lerpVectors(from, seat, e);
      let d = 0 - fy; d = Math.atan2(Math.sin(d), Math.cos(d)); player.yaw = fy + d * e; player.pitch = fp * (1 - e) - .06 * e;
      player.camera.rotation.set(player.pitch, player.yaw, 0, 'YXZ');
    });
    player.sit(seat, 0, -.04, Math.PI, .5); player.lookEnabled = true; player.targetFov = 50; this.flashOn = false;
    // la disquette quitte la main, entre dans le lecteur
    this.floppy.visible = true; this.floppy.rotation.set(.2, 0, 0);
    const start = new THREE.Vector3(seat.x + .25, seat.y - .25, seat.z - .3), end = new THREE.Vector3(1.21, this.led.position.y - .015, -1.9);
    await this.tween(1.1, k => { const e = k * k; this.floppy.position.lerpVectors(start, end, e); this.floppy.rotation.x = .2 * (1 - e); });
    await this.tween(.5, k => { this.floppy.position.z = -1.9 - .14 * k; });
    this.floppy.visible = false;
    this.led.material.color.set(0xffb52e); this.led.material.emissive.set(0xffb52e); this.led.material.emissiveIntensity = 2.5;
    this.audio.seek(); this.audio.at('click', end, .4, 1);
    await this.tween(.9, () => {});
    this.screenOff();
  }
  openDoor() {
    const n = this.doorNode; if (!n || this.doorOpen) return; this.doorOpen = true;
    const p = this.door.position.clone(); p.y = 1.0; this.audio.at('latch', p, .8, 1.5);
    setTimeout(() => this.audio.at('doorOpen', p, .9, 1.5, .9), 300);
    this.tween(2.2, k => { n.rotation.y = -1.7 * k * k; });
    // une sortie : franchir la porte termine la partie
    const exit = new THREE.Mesh(new THREE.BoxGeometry(.6, 2.0, .3), new THREE.MeshBasicMaterial({ visible: false })); exit.position.set(ROOM.W / 2 - .1, 1, 1.2); this.scene.add(exit);
    this.interactables.length = 0; this.inter('exit', 'Sortir', exit, 1.6);
    const i = this.colliders.findIndex(c => c[0] === ROOM.W / 2 - .3); if (i >= 0) this.colliders.splice(i, 1);
  }
  rattleDoor() {
    const p = this.door.position.clone(); p.y = 1.0;
    this.audio.at('latch', p, .9, 1.5); setTimeout(() => this.audio.at('thud', p, .7, 1.5, 1.2), 350);
    const n = this.doorNode; if (!n) return;
    this.tween(.6, k => { n.rotation.y = Math.sin(k * 40) * .012 * (1 - k); });
  }
  lightSwitch() {
    if (this.dead) { this.audio.at('click', this.ceilLight.position, .3); return; }
    this.audio.click();
    if (this.ceilingOn) { this.ceilingOn = false; this.ceilLight.intensity = 0; return; }
    this.ceilingOn = true;
    const p = this.ceilLight.position.clone();
    this.tween(2.6, k => { this.ceilLight.intensity = (Math.random() < .5 ? 18 : 2) * (k < .9 ? 1 : 0); }).then(() => {
      this.ceilLight.intensity = 40; setTimeout(() => { this.ceilLight.intensity = 0; this.dead = true; this.audio.at('glass', p, 1, 1.5); this.audio.at('metal', p, .5, 1.5, .7); }, 120);
    });
  }
  radio() {
    const r = this.scene.getObjectByName('radio'); const p = r ? r.position.clone() : new THREE.Vector3(-2.75, .8, -1.1);
    this.audio.click(); this.audio.at('cloth', p, .4, 1); this.audio.whisper("c'est toi. c'est toi. c'est toi.");
  }
  /** Le visage surgit à une position (monde), orienté vers le joueur. */
  showFace(pos, lookAt, scale = 1) {
    if (!this.face) return; this.face.visible = true; this.face.position.copy(pos); this.face.lookAt(lookAt); this.face.scale.multiplyScalar(1).setScalar(this.face.scale.x);
    this.faceLight.position.copy(pos).add(new THREE.Vector3(0, .1, 0)); this.faceLight.intensity = 6 * scale;
  }
  silhouette(show) { if (this.sil) this.sil.visible = show; }
  hideFace() { if (!this.face) return; this.face.visible = false; this.faceLight.intensity = 0; }
  tween(dur, fn) { return new Promise(res => this.anims.push({ t: 0, dur, fn, res })); }

  update(dt, t, player) {
    this.t = t;
    for (let i = this.anims.length - 1; i >= 0; i--) { const a = this.anims[i]; a.t += dt; const k = Math.min(1, a.t / a.dur); a.fn(k); if (k >= 1) { this.anims.splice(i, 1); a.res(); } }
    // lampe de poche qui vit, lueur de l'écran qui respire, rouge sur burst
    if (this.flash) this.flash.intensity = (this.flashOn === false ? 0 : 11) * (1 + Math.sin(t * 23) * Math.sin(t * 7.1) * .06) * (Math.random() < .004 ? .2 : 1);
    const b = this.burstT > 0; if (b) this.burstT -= dt;
    this.glow.intensity = b ? 30 : 2.2 + Math.sin(t * 3) * .4 + this.corr * 1.5;
    this.glowS.intensity = b ? 40 : 2.2 + this.corr * 3;
    if (b) { this.glow.color.set(0xff2010); this.glowS.color.set(0xff2010); } else { this.glow.color.copy(this.phos); this.glowS.color.copy(this.phos); }
    if (this.screenMesh.visible && Math.floor(t * 10) % 3 === 0) { drawScreen(this.screenIdle.cx, 256, 192, t); this.screenIdle.t.needsUpdate = true; }
    if (Math.floor(t * 2) % 2 === 0 !== this._clkOn) { this._clkOn = !this._clkOn; drawClock(this.clockTex.cx, 128, 64, this._clkOn); this.clockTex.t.needsUpdate = true; }
    const dp = this.dust.attributes.position.array; for (let i = 0; i < dp.length; i += 3) { dp[i + 1] += (.02 + this.corr * .2) * dt; dp[i] += Math.sin(t * .4 + i) * .003; if (dp[i + 1] > 2.5) dp[i + 1] = 0; } this.dust.attributes.position.needsUpdate = true;
    if (this.face && this.face.visible) this.face.rotation.z = Math.sin(t * 30) * .04;
  }
}
