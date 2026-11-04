// RUNTIME — point d'entrée. Enchaîne : écran-titre → chambre (première personne) → terminal sur le moniteur → fins.
import './style.css';
import * as THREE from 'three';
import { CSS3DRenderer } from 'three/examples/jsm/renderers/CSS3DRenderer.js';
import { Room } from './room/Room.js';
import { Player } from './room/Player.js';
import { PostFX } from './room/PostFX.js';
import { Interact } from './room/Interact.js';
import { Audio } from './audio/Audio.js';
import { Terminal } from './terminal/Terminal.js';
import { Events } from './events/Events.js';

const $ = s => document.querySelector(s);
const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
// ?lite : mode allégé (tests, machines faibles) : pas de post-traitement lourd, ombres réduites.
export const LITE = new URLSearchParams(location.search).has('lite');

const canvas = $('#gl');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(LITE ? 1 : Math.min(devicePixelRatio, 1.5));
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.0;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(68, 1, .04, 40);
scene.add(camera);
const css3d = new CSS3DRenderer({ element: $('#css3d') });

const audio = new Audio(camera);
const player = new Player(camera, canvas);
const room = new Room(scene, renderer, audio, { lite: LITE });
const interact = new Interact(player, room, audio);
const terminal = new Terminal({ audio, player, room });
const events = new Events({ room, player, audio, terminal });
let post = null;

const S = { phase: 'title', hasFloppy: false, t0: 0 };
window.__rt = { S, room, player, terminal, audio, events, interact, renderer, scene, camera, canvas, css3d, render: () => { if (post) post.render(S.t || 0); else renderer.render(scene, camera); css3d.render(scene, camera); } };

function resize() {
  const w = innerWidth, h = innerHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h; camera.updateProjectionMatrix();
  css3d.setSize(w, h);
  post && post.setSize(w, h);
}
addEventListener('resize', resize);

/* ---------- chargement ---------- */
const enterBtn = $('#enterBtn');
enterBtn.disabled = true;
room.load(p => { $('#loading').style.setProperty('--p', Math.round(p * 100) + '%'); }).then(() => {
  room.attachFlashlight(camera);
  player.colliders = room.colliders;
  player.yaw = .9; player.onStep = () => audio.step(Math.abs(player.pos.x - .1) < 1.3 && Math.abs(player.pos.z - .5) < .75);
  $('#loading').classList.add('done');
  enterBtn.disabled = false;
  const fins = terminal.getFins();
  if (fins.length) { const p = $('#fins'); p.hidden = false; p.textContent = `Fins découvertes : ${fins.length}/4`; }
}).catch(err => { console.error(err); $('#loading span').textContent = 'Erreur de chargement : ' + err.message; });

enterBtn.addEventListener('click', async () => {
  if (S.phase !== 'title') return;
  S.phase = 'room';
  await audio.init();
  if (!LITE) post = new PostFX(renderer, scene, camera, { high: $('#qualityHigh').checked && !reduce });
  resize();
  $('#title').classList.add('hidden');
  player.lock(); player.enabled = true;
  try { const fs = document.documentElement.requestFullscreen && document.documentElement.requestFullscreen(); fs && fs.catch && fs.catch(() => {}); } catch (e) {}
  $('#fade').style.opacity = 0;
  $('#objective').textContent = 'Trouve la disquette';
  $('#hint').textContent = 'ZQSD · souris · E pour agir · clic pour reprendre la souris';
  setTimeout(() => { $('#hint').style.opacity = 0; }, 9000);
  audio.roomTone(true);
  events.start();
  S.t0 = performance.now();
});
canvas.addEventListener('click', () => { if (S.phase === 'room' || S.phase === 'seated') player.lock(); });

/* ---------- interactions de la chambre ---------- */
interact.on('wardrobe', async () => {
  if (S.hasFloppy) return interact.say("Rien d'autre. Juste l'odeur.");
  await room.openWardrobe();
  S.hasFloppy = true; $('#hand').hidden = false;
  $('#objective').textContent = "Insère la disquette dans l'ordinateur";
  interact.say('Une disquette. Collée au fond, derrière les manteaux.');
  audio.whisper('insère-moi');
});
interact.on('pc', async () => {
  if (!S.hasFloppy) return interact.say("L'écran clignote. Il attend quelque chose.");
  S.phase = 'seated'; interact.enabled = false;
  $('#hand').hidden = true; $('#objective').textContent = ''; $('#prompt').hidden = true; $('#crosshair').hidden = true;
  await room.insertFloppy(player);
  terminal.show(room.screenAnchor, css3d);
  events.seated();
  await terminal.run(false);
});
terminal.on('leave', async () => {
  // fin de partie : on se lève, la porte s'ouvre enfin
  await room.tween(.8, k => { $('#fade').style.opacity = k; });
  terminal.hide(); room.screenOn();
  player.stand(); player.pos.set(1.3, 1.55, -.9); player.yaw = Math.PI;
  S.phase = 'room'; interact.enabled = true; events.phase = 'after'; $('#crosshair').hidden = false;
  $('#objective').textContent = 'La porte est ouverte';
  room.openDoor();
  await room.tween(1.2, k => { $('#fade').style.opacity = 1 - k; });
});
interact.on('exit', async () => {
  S.phase = 'end'; player.enabled = false;
  await room.tween(2.5, k => { $('#fade').style.opacity = k; });
  location.reload();
});
interact.on('note', () => interact.readPaper("ne pas jouer\naprès minuit.\n\nsi l'écran te parle,\nne réponds pas.\n\n— M."));
interact.on('clock', () => interact.say('3:12. Il est 3:12 depuis que tu es entré.'));
interact.on('door', () => { room.rattleDoor(); interact.say("Fermée. De l'extérieur."); });
interact.on('window', () => interact.say('Dehors, rien ne bouge. Pas même les branches.'));
interact.on('switch', () => room.lightSwitch());
interact.on('radio', () => room.radio());
interact.on('bed', () => interact.say("Pas maintenant. Tu n'as pas sommeil. Tu n'auras plus jamais sommeil."));

/* ---------- boucle ---------- */
const clock = new THREE.Clock();
function frame() {
  requestAnimationFrame(frame);
  const dt = Math.min(.1, clock.getDelta()), t = clock.elapsedTime;
  S.ft = clock.getDelta.length ? (performance.now() - (S._lf || performance.now())) : 0; S._lf = performance.now(); S.frames = (S.frames || 0) + 1;
  S.t = t;
  if (S.phase === 'title') return;
  player.update(dt, t);
  room.update(dt, t, player);
  interact.update(dt);
  events.update(dt, t);
  if (S.noRender) return;
  if (post) post.render(t); else renderer.render(scene, camera);
  if (S.phase === 'seated') css3d.render(scene, camera);
}
resize();
frame();
