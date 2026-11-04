// Événements de la chambre : ce qui se passe dans la pièce, hors de l'écran, pendant l'exploration puis pendant la partie.
import * as THREE from 'three';

export class Events {
  constructor({ room, player, audio, terminal }) {
    this.room = room; this.player = player; this.audio = audio; this.terminal = terminal;
    this.t = 0; this.phase = 'idle'; this.timers = []; this.wardCreep = 0; this.lastCreak = 0;
    terminal.on('level', n => this.onLevel(n));
    terminal.on('corruption', c => { room.setCorruption(c); audio.setCorr(c); });
    terminal.on('burst', () => room.burst(1.2));
    terminal.on('scream', o => this.screamInRoom(o && o.turned));
    terminal.on('knock', () => this.knock());
    terminal.on('end', id => this.onEnd(id));
  }
  start() { this.phase = 'explore'; }
  seated() { this.phase = 'seated'; }
  later(sec, fn) { this.timers.push({ at: this.t + sec, fn }); }
  update(dt, t) {
    this.t = t;
    for (let i = this.timers.length - 1; i >= 0; i--) if (t >= this.timers[i].at) { const f = this.timers[i].fn; this.timers.splice(i, 1); f(); }
    if (this.phase === 'explore') {
      // de temps en temps, un craquement quelque part derrière le joueur
      if (t - this.lastCreak > 14 + Math.random() * 10) {
        this.lastCreak = t;
        const p = this.player.pos.clone(); const a = this.player.yaw + Math.PI + (Math.random() - .5);
        p.x += -Math.sin(a) * 2.2; p.z += -Math.cos(a) * 2.2; p.y = .3;
        this.audio.at('creak', p, .35, 1.5, .7 + Math.random() * .3);
      }
    }
    if (this.phase === 'seated' && this.room.wardrobeOpen === false && this.wardCreep > 0) {
      // l'armoire s'entrouvre un peu plus pendant que le joueur regarde l'écran
      const d = this.room.wardDoorR; if (d) d.rotation.y = Math.max(-2.0, d.rotation.y - dt * .02 * this.wardCreep);
    }
  }
  onLevel(n) {
    if (n === 2) this.later(8, () => this.knock());
    if (n === 3) {
      this.wardCreep = 1;
      this.later(5, () => { const p = new THREE.Vector3(-2.4, 1.2, -1.9); this.audio.at('creak', p, .8, 1.5, .6); });
      // quelqu'un, dehors, derrière la vitre, pendant quelques secondes
      this.later(14, () => { this.room.silhouette(true); this.audio.at('glass', new THREE.Vector3(-3.2, 1.6, -.6), .25, 1.5, .5); this.later(6, () => this.room.silhouette(false)); });
    }
    if (n === 4) {
      // le plafonnier s'allume tout seul, vacille, puis claque
      this.later(3, () => { if (!this.room.dead && !this.room.ceilingOn) this.room.lightSwitch(); });
      this.later(26, () => { const p = new THREE.Vector3(-2.4, 1.2, -1.9); this.audio.at('creak', p, 1, 1.5, .5); });
    }
    if (n === 5) this.later(4, () => this.audio.at('cloth', new THREE.Vector3(1.9, .6, -1.2), .5, 1.2));
  }
  knock() {
    const p = this.room.door.position.clone(); p.y = 1.1;
    this.audio.knock(3, p);
    this.room.rattleDoor();
  }
  /** Le screamer, dans la pièce : le visage surgit juste derrière l'épaule gauche, dans le dos du joueur. */
  screamInRoom(turned) {
    const cam = this.player.camera;
    const dir = new THREE.Vector3(); cam.getWorldDirection(dir);
    let pos;
    if (turned) { pos = cam.position.clone().addScaledVector(dir, .55); pos.y -= .04; }   // il est là, à dix centimètres de ton nez
    else { pos = cam.position.clone().addScaledVector(dir, -.5); pos.add(new THREE.Vector3(dir.z, 0, -dir.x).multiplyScalar(.35)); pos.y -= .05; } // par-dessus l'épaule gauche
    this.room.showFace(pos, cam.position, 1);
    this.room.burst(1.3);
    this.later(1.4, () => this.room.hideFace());
  }
  onEnd(id) { this.phase = 'ended'; }
}
