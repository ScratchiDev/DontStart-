// Chaîne de post-traitement : rendu → occlusion ambiante → bloom → grain/vignettage/aberration → sortie.
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/examples/jsm/postprocessing/OutputPass.js';
import { SMAAPass } from 'three/examples/jsm/postprocessing/SMAAPass.js';
import { GTAOPass } from 'three/examples/jsm/postprocessing/GTAOPass.js';

const FilmShader = {
  uniforms: {
    tDiffuse: { value: null },
    time: { value: 0 },
    grain: { value: .07 },
    vignette: { value: 1.0 },
    aberration: { value: .045 },
    pulse: { value: 0 },      // 0..1 : battement rouge (corruption, screamer)
    blackout: { value: 0 },   // 0..1 : fondu au noir piloté par le jeu
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: /* glsl */`
    uniform sampler2D tDiffuse; uniform float time, grain, vignette, aberration, pulse, blackout;
    varying vec2 vUv;
    float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    void main() {
      vec2 d = vUv - .5; float r = dot(d, d);
      vec2 off = d * r * aberration * (1.0 + pulse * 3.0);
      vec3 c;
      c.r = texture2D(tDiffuse, vUv + off).r;
      c.g = texture2D(tDiffuse, vUv).g;
      c.b = texture2D(tDiffuse, vUv - off).b;
      c *= mix(1.0, smoothstep(1.15, .25, r * 1.8), vignette);
      c += (rnd(vUv * vec2(1.0, 1.9) + fract(time * 7.1)) - .5) * grain;
      c = mix(c, vec3(c.r * 1.2, c.g * .35, c.b * .3), pulse * .6);
      c *= 1.0 - blackout;
      gl_FragColor = vec4(c, 1.0);
    }`,
};

export class PostFX {
  constructor(renderer, scene, camera, { high = true } = {}) {
    this.renderer = renderer; this.scene = scene; this.camera = camera; this.high = high;
    const size = renderer.getSize(new THREE.Vector2());
    this.composer = new EffectComposer(renderer);
    this.composer.addPass(new RenderPass(scene, camera));
    if (high) {
      this.gtao = new GTAOPass(scene, camera, size.x, size.y);
      this.gtao.output = GTAOPass.OUTPUT.Default;
      this.gtao.updateGtaoMaterial({ radius: .35, distanceExponent: 1, thickness: 1, scale: 1.4, samples: 12, distanceFallOff: 1, screenSpaceRadius: false });
      this.gtao.updatePdMaterial({ lumaPhi: 10, depthPhi: 2, normalPhi: 3, radius: 4, radiusExponent: 1, rings: 2, samples: 16 });
      this.gtao.blendIntensity = .9;
      this.composer.addPass(this.gtao);
    }
    this.bloom = new UnrealBloomPass(size, high ? .55 : .35, .6, .86);
    this.composer.addPass(this.bloom);
    this.film = new ShaderPass(FilmShader);
    this.composer.addPass(this.film);
    this.composer.addPass(new OutputPass());
    if (high) { this.smaa = new SMAAPass(size.x, size.y); this.composer.addPass(this.smaa); }
  }
  setSize(w, h) {
    this.composer.setSize(w, h);
    if (this.gtao) this.gtao.setSize(w, h);
    if (this.smaa) this.smaa.setSize(w, h);
  }
  render(t) {
    this.film.uniforms.time.value = t;
    this.composer.render();
  }
  get u() { return this.film.uniforms; }
}
