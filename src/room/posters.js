// Images dessinées par le code : affiches, mot punaisé, réveil, écran d'attente de l'ordinateur.
export function drawPoster1(c, w, h) {
  const g = c.createLinearGradient(0, 0, 0, h); g.addColorStop(0, '#2a0b10'); g.addColorStop(.6, '#7a1b16'); g.addColorStop(1, '#0a0506'); c.fillStyle = g; c.fillRect(0, 0, w, h);
  c.fillStyle = '#05030a'; c.beginPath(); c.moveTo(0, h * .62); for (let x = 0; x <= w; x += 16) c.lineTo(x, h * .62 - Math.abs(Math.sin(x * .07)) * 40 - (x % 48 < 24 ? 18 : 0)); c.lineTo(w, h); c.lineTo(0, h); c.fill();
  c.fillStyle = '#0a0608'; c.beginPath(); c.ellipse(w * .5, h * .5, 26, 36, 0, 0, 7); c.fill(); c.fillRect(w * .5 - 40, h * .56, 80, 120);
  c.fillStyle = '#f2e4c8'; c.font = 'bold 52px Impact, "Arial Black", sans-serif'; c.textAlign = 'center'; c.fillText('CHOISIS', w / 2, 70); c.font = 'bold 30px Impact, "Arial Black", sans-serif'; c.fillText('OU SINON', w / 2, 108);
  c.font = '14px monospace'; c.fillStyle = '#c9b38a'; c.fillText('UN FILM DE J. MORVAN · 1983', w / 2, h - 22);
  for (let i = 0; i < 300; i++) { c.fillStyle = 'rgba(0,0,0,' + Math.random() * .25 + ')'; c.fillRect(Math.random() * w, Math.random() * h, 2, 2); }
}
export function drawPoster2(c, w, h) {
  c.fillStyle = '#111'; c.fillRect(0, 0, w, h);
  for (let i = 0; i < 12; i++) { c.strokeStyle = i % 2 ? '#e8e032' : '#1b1b1b'; c.lineWidth = 12; c.beginPath(); c.arc(w / 2, h / 2, 20 + i * 11, 0, 7); c.stroke(); }
  c.fillStyle = '#111'; c.fillRect(0, h * .38, w, h * .24);
  c.fillStyle = '#e8e032'; c.font = 'bold 40px Impact, "Arial Black", sans-serif'; c.textAlign = 'center'; c.fillText('LES SPECTRES', w / 2, h * .52); c.font = '16px monospace'; c.fillText('TOURNÉE 84 · COMPLET', w / 2, h * .58);
}
export function drawNote(c, w, h) {
  c.fillStyle = '#efe7d2'; c.fillRect(0, 0, w, h); c.strokeStyle = 'rgba(60,80,170,.3)'; for (let y = 24; y < h; y += 14) { c.beginPath(); c.moveTo(0, y); c.lineTo(w, y); c.stroke(); }
  c.fillStyle = '#26286a'; c.font = '26px "Reenie Beanie", cursive'; c.textAlign = 'center'; c.fillText('ne pas', w / 2, 64); c.fillText('jouer', w / 2, 96); c.fillText('après minuit', w / 2, 128);
}
export function drawClock(c, w, h, on = true) {
  c.fillStyle = '#0a0000'; c.fillRect(0, 0, w, h);
  c.fillStyle = '#ff2a1a'; c.font = 'bold 44px monospace'; c.textAlign = 'center'; c.shadowColor = '#ff2a1a'; c.shadowBlur = 10; c.fillText(on ? '3:12' : '3 12', w / 2, 48); c.shadowBlur = 0;
}
export function drawScreen(c, w, h, t) {
  c.fillStyle = '#040a05'; c.fillRect(0, 0, w, h);
  c.fillStyle = '#5cff6a'; c.font = '22px "VT323", monospace'; c.textAlign = 'left';
  c.fillText('RUNTIME BIOS v0.9', 14, 34); c.fillText('(C) 1984', 14, 58);
  c.fillText('LECTEUR A: VIDE', 14, 104);
  if (Math.floor(t * 1.6) % 2 === 0) c.fillText('> INSÉRER DISQUETTE', 14, 150);
  c.fillStyle = 'rgba(0,0,0,.35)'; for (let y = 0; y < h; y += 3) c.fillRect(0, y, w, 1);
}
