import * as THREE from "https://unpkg.com/three@0.161.0/build/three.module.js";

const container = document.getElementById("bg-layer");
if (!container) {
  throw new Error("Background container not found.");
}

let enabled = true;
container.style.display = "block";

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setClearColor(0x000000, 0);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
container.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

const uniforms = {
  u_time: { value: 0 },
  u_tex: { value: null },
  u_screenAspect: { value: window.innerWidth / window.innerHeight },
  u_imageAspect: { value: 1.0 },
  u_amp: { value: 0.015 },
  u_freq: { value: 3.0 },
  u_ripple: { value: 0.0 },
  u_glitch: { value: 0.0 },
  u_mouse: { value: new THREE.Vector2(0.5, 0.5) }
};

const geometry = new THREE.PlaneGeometry(2, 2);

const material = new THREE.ShaderMaterial({
  uniforms,
  transparent: true,
  vertexShader: `
    varying vec2 vUv;
    void main(){
      vUv = uv;
      gl_Position = vec4(position.xy, 0.0, 1.0);
    }
  `,
  fragmentShader: `
    precision highp float;
    varying vec2 vUv;

    uniform sampler2D u_tex;
    uniform float u_time;
    uniform float u_screenAspect;
    uniform float u_imageAspect;
    uniform float u_amp;
    uniform float u_freq;
    uniform float u_ripple;
    uniform float u_glitch;
    uniform vec2 u_mouse;

    vec2 coverUV(vec2 uv, float screenAspect, float imageAspect){
      vec2 outUV = uv;
      if(screenAspect > imageAspect){
        float scale = screenAspect / imageAspect;
        outUV.y = (uv.y - 0.5) * scale + 0.5;
      } else {
        float scale = imageAspect / screenAspect;
        outUV.x = (uv.x - 0.5) * scale + 0.5;
      }
      return outUV;
    }

    float hash(vec2 p){
      p = fract(p * vec2(123.34, 456.21));
      p += dot(p, p + 34.345);
      return fract(p.x * p.y);
    }

    void main(){
      vec2 uv = vUv;
      vec2 cuv = coverUV(uv, u_screenAspect, u_imageAspect);

      float t = u_time;
      float w1 = sin((cuv.y * u_freq) + t * 0.8);
      float w2 = sin((cuv.x * (u_freq * 0.7)) - t * 0.6);
      vec2 disp = vec2(w1, w2) * u_amp * 0.5;

      vec2 m = u_mouse;
      float d = distance(uv, m);
      float ripple = sin(d * (u_freq * 10.0) - t * 3.0) * exp(-d * 6.0);
      disp += normalize(uv - m + 1e-6) * ripple * u_ripple;

      if(u_glitch > 0.0){
        float band = floor(uv.y * 120.0);
        float n = hash(vec2(band, floor(t * 20.0)));
        disp.x += (n - 0.5) * u_glitch;
      }

      vec2 suv = cuv + disp;
      suv = clamp(suv, 0.001, 0.999);

      vec4 col = texture2D(u_tex, suv);
      gl_FragColor = vec4(col.rgb, 0.35);
    }
  `
});

const mesh = new THREE.Mesh(geometry, material);
scene.add(mesh);

const loader = new THREE.TextureLoader();
loader.load(
  "circe-bg.png",
  (tex) => {
    tex.minFilter = THREE.LinearFilter;
    tex.magFilter = THREE.LinearFilter;
    tex.generateMipmaps = false;

    uniforms.u_tex.value = tex;

    const img = tex.image;
    if (img && img.width && img.height) {
      uniforms.u_imageAspect.value = img.width / img.height;
    }
  }
);

window.addEventListener("pointermove", (e) => {
  uniforms.u_mouse.value.set(e.clientX / window.innerWidth, 1.0 - e.clientY / window.innerHeight);
});

if (window.Shiny) {
  Shiny.addCustomMessageHandler("bgParams", (msg) => {
    if (typeof msg.amp === "number") uniforms.u_amp.value = msg.amp;
    if (typeof msg.freq === "number") uniforms.u_freq.value = msg.freq;
    if (typeof msg.ripple === "number") uniforms.u_ripple.value = msg.ripple;
    if (typeof msg.glitch === "number") uniforms.u_glitch.value = msg.glitch;
  });

  Shiny.addCustomMessageHandler("bgToggle", (msg) => {
    enabled = !!msg.enabled;
    container.style.display = enabled ? "block" : "none";
  });
}

window.addEventListener("resize", () => {
  renderer.setSize(window.innerWidth, window.innerHeight);
  uniforms.u_screenAspect.value = window.innerWidth / window.innerHeight;
});

const clock = new THREE.Clock();
function animate() {
  uniforms.u_time.value = clock.getElapsedTime();
  if (enabled && uniforms.u_tex.value) renderer.render(scene, camera);
  requestAnimationFrame(animate);
}
animate();
