// Interactions : on vise un objet (rayon depuis la caméra), l'invite « E » apparaît, E déclenche l'action.
import * as THREE from 'three';

const $ = s => document.querySelector(s);

export class Interact {
  constructor(player, room, audio) {
    this.player = player; this.room = room; this.audio = audio;
    this.handlers = {}; this.enabled = true; this.current = null;
    this.ray = new THREE.Raycaster(); this.ray.far = 2.6;
    this.sayTimer = 0; this.paperOpen = false;
    addEventListener('keydown', e => {
      if (e.code === 'KeyE' && this.current && this.enabled && !this.paperOpen) this.use(this.current);
      if (e.code === 'Escape' && this.paperOpen) this.closePaper();
    });
  }
  on(id, fn) { this.handlers[id] = fn; }
  use(it) {
    const fn = this.handlers[it.id];
    if (fn) { this.audio.click(); fn(it); }
  }
  say(text, ms = 3200) {
    const h = $('#hint'); h.textContent = text; h.style.opacity = 1;
    clearTimeout(this.sayTimer); this.sayTimer = setTimeout(() => { h.style.opacity = 0; }, ms);
  }
  readPaper(text) {
    this.paperOpen = true; this.player.lookEnabled = false; this.player.enabled = false;
    const p = $('#paper'); p.querySelector('.sheet').textContent = text; p.hidden = false;
    this.audio.sample('bookOpen', .6);
  }
  closePaper() {
    this.paperOpen = false; this.player.lookEnabled = true; this.player.enabled = true;
    $('#paper').hidden = true; this.audio.sample('bookClose', .5);
  }
  update() {
    if (!this.enabled || this.player.seated) { this.set(null); return; }
    const cam = this.player.camera;
    this.ray.set(cam.position, this.player.forward());
    const hits = this.ray.intersectObjects(this.room.interactables.map(i => i.object), true);
    let found = null;
    if (hits.length) {
      const obj = hits[0].object;
      found = this.room.interactables.find(i => i.object === obj || i.object.getObjectById(obj.id)) || null;
      if (found && hits[0].distance > (found.range || 2.2)) found = null;
    }
    this.set(found);
  }
  set(it) {
    if (it === this.current) return;
    this.current = it;
    const p = $('#prompt');
    if (it) { p.querySelector('span').textContent = it.label; p.hidden = false; $('#crosshair').classList.add('active'); }
    else { p.hidden = true; $('#crosshair').classList.remove('active'); }
  }
}
