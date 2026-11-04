// Contrôleur à la première personne : souris capturée, ZQSD/WASD, collisions contre des boîtes, position assise.
import * as THREE from 'three';

const EYE = 1.55;
const RADIUS = .28;

export class Player {
  constructor(camera, dom) {
    this.camera = camera; this.dom = dom;
    this.pos = new THREE.Vector3(2.3, EYE, 1.9);
    this.yaw = Math.PI * .85; this.pitch = 0;
    this.keys = {};
    this.locked = false;
    this.enabled = false;      // peut marcher
    this.lookEnabled = true;   // peut tourner la tête
    this.seated = null;        // { pos, yaw, pitch, yawRange, pitchRange }
    this.bob = 0; this.moving = false; this.speed = 1.9;
    this.colliders = [];       // [x0, x1, z0, z1]
    this.bounds = { x0: -3.1, x1: 3.1, z0: -2.5, z1: 2.5 };
    this.onStep = null;
    this.lastStep = 0;
    this.lean = new THREE.Vector3();
    this.tmpDir = new THREE.Vector3();

    addEventListener('keydown', e => { this.keys[e.code] = true; });
    addEventListener('keyup', e => { this.keys[e.code] = false; });
    addEventListener('blur', () => { this.keys = {}; });
    document.addEventListener('pointerlockchange', () => { this.locked = document.pointerLockElement === dom; });
    document.addEventListener('mousemove', e => {
      if (!this.locked || !this.lookEnabled) return;
      const s = .0022;
      this.yaw -= e.movementX * s; this.pitch -= e.movementY * s;
      this.clampLook();
    });
  }
  lock() { try { this.dom.requestPointerLock && this.dom.requestPointerLock(); } catch (e) {} }
  unlock() { try { document.exitPointerLock && document.exitPointerLock(); } catch (e) {} }
  clampLook() {
    const s = this.seated;
    if (s) {
      let d = this.yaw - s.yaw; d = Math.atan2(Math.sin(d), Math.cos(d));
      d = Math.max(-s.yawRange, Math.min(s.yawRange, d)); this.yaw = s.yaw + d;
      this.pitch = Math.max(s.pitch - s.pitchRange, Math.min(s.pitch + s.pitchRange, this.pitch));
    } else this.pitch = Math.max(-1.35, Math.min(1.35, this.pitch));
  }
  /** Angle (rad) entre le regard et un point, dans le plan horizontal. */
  yawTo(x, z) { const a = Math.atan2(-(x - this.pos.x), -(z - this.pos.z)); let d = a - this.yaw; return Math.atan2(Math.sin(d), Math.cos(d)); }
  /** Combien le joueur s'est détourné de sa position assise (0..π). */
  turnedAway() { if (!this.seated) return 0; let d = this.yaw - this.seated.yaw; return Math.abs(Math.atan2(Math.sin(d), Math.cos(d))); }
  sit(pos, yaw, pitch = -.08, yawRange = Math.PI, pitchRange = .6) {
    this.seated = { pos: pos.clone(), yaw, pitch, yawRange, pitchRange };
    this.enabled = false;
  }
  stand() { if (!this.seated) return; this.pos.copy(this.seated.pos); this.pos.y = EYE; this.seated = null; this.enabled = true; this.targetFov = 68; }
  collide(nx, nz) {
    const r = RADIUS, b = this.bounds;
    nx = Math.max(b.x0 + r, Math.min(b.x1 - r, nx)); nz = Math.max(b.z0 + r, Math.min(b.z1 - r, nz));
    for (const [x0, x1, z0, z1] of this.colliders) {
      if (nx > x0 - r && nx < x1 + r && nz > z0 - r && nz < z1 + r) {
        const dx = Math.min(nx - (x0 - r), (x1 + r) - nx), dz = Math.min(nz - (z0 - r), (z1 + r) - nz);
        if (dx < dz) nx = (nx - (x0 - r) < (x1 + r) - nx) ? x0 - r : x1 + r;
        else nz = (nz - (z0 - r) < (z1 + r) - nz) ? z0 - r : z1 + r;
      }
    }
    return [nx, nz];
  }
  update(dt, t) {
    const k = this.keys;
    if (this.seated) {
      const s = this.seated;
      this.camera.position.copy(s.pos);
      this.camera.position.y += Math.sin(t * 1.1) * .004;  // respiration
      this.camera.position.x += Math.sin(t * .7) * .003;
    } else {
      let f = 0, sd = 0;
      if (this.enabled) {
        f = (k.KeyW || k.KeyZ || k.ArrowUp ? 1 : 0) - (k.KeyS || k.ArrowDown ? 1 : 0);
        sd = (k.KeyD || k.ArrowRight ? 1 : 0) - (k.KeyA || k.KeyQ || k.ArrowLeft ? 1 : 0);
      }
      const len = Math.hypot(f, sd); if (len > 1) { f /= len; sd /= len; }
      this.moving = len > .1;
      if (this.moving) {
        const sp = this.speed * (k.ShiftLeft ? 1.35 : 1) * dt;
        const nx = this.pos.x + (-Math.sin(this.yaw) * f + Math.cos(this.yaw) * sd) * sp;
        const nz = this.pos.z + (-Math.cos(this.yaw) * f - Math.sin(this.yaw) * sd) * sp;
        [this.pos.x, this.pos.z] = this.collide(nx, nz);
        this.bob += dt * (k.ShiftLeft ? 11 : 8.5);
        if (Math.sin(this.bob) < -.95 && t - this.lastStep > .3) { this.lastStep = t; this.onStep && this.onStep(); }
      } else this.bob = Math.round(this.bob / Math.PI) * Math.PI + (this.bob - Math.round(this.bob / Math.PI) * Math.PI) * Math.max(0, 1 - dt * 8);
      this.camera.position.set(this.pos.x, EYE + Math.sin(this.bob) * .028 + Math.sin(t * 1.3) * .004, this.pos.z);
      this.camera.position.x += Math.cos(this.bob * .5) * .012 * (this.moving ? 1 : 0);
    }
    if (this.targetFov && Math.abs(this.camera.fov - this.targetFov) > .05) { this.camera.fov += (this.targetFov - this.camera.fov) * Math.min(1, dt * 2.5); this.camera.updateProjectionMatrix(); }
    this.camera.rotation.set(0, 0, 0, 'YXZ');
    this.camera.rotation.y = this.yaw; this.camera.rotation.x = this.pitch;
    this.camera.rotation.z = this.moving ? Math.sin(this.bob * .5) * .006 : 0;
  }
  forward() { return this.camera.getWorldDirection(this.tmpDir); }
}
