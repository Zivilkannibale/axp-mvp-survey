(() => {
  const container = document.getElementById("p6m-layer");
  if (!container) return;

  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  container.appendChild(canvas);

  const img = new Image();
  img.src = "circe-bg.png";

  const tol = 1;

  function resizeCanvas() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.style.width = `${window.innerWidth}px`;
    canvas.style.height = `${window.innerHeight}px`;
    canvas.width = Math.floor(window.innerWidth * dpr);
    canvas.height = Math.floor(window.innerHeight * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function drawP6mTile(i, j, width, height, row, srcX, srcY, srcW, srcH) {
    const offset = (row % 2) * width;
    const h075 = height * 0.75;

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i - tol, j - tol);
    ctx.lineTo(offset + i + width + tol, j + height * 0.5);
    ctx.lineTo(offset + i + width / 2, j + h075 + tol);
    ctx.closePath();
    ctx.clip();
    ctx.drawImage(img, srcX, srcY, srcW, srcH, offset + i - tol, j - tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i - tol, j - tol * 2);
    ctx.lineTo(offset + i + width / 2 + tol, j + h075);
    ctx.lineTo(offset + i - tol, j + height + tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i, j);
    ctx.rotate(-Math.PI / 3);
    ctx.scale(-1, 1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width + tol, j + height * 1.5 + tol);
    ctx.lineTo(offset + i - tol, j + height);
    ctx.lineTo(offset + i + width / 2, j + h075 - tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width, j + height * 1.5);
    ctx.rotate(Math.PI);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width + tol, j + height * 1.5 + tol * 2);
    ctx.lineTo(offset + i + width / 2 - tol, j + h075);
    ctx.lineTo(offset + i + width + tol, j + height / 2 - tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width, j + height * 1.5);
    ctx.rotate(-Math.PI / 3);
    ctx.scale(1, -1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i - tol * 2, j - tol);
    ctx.lineTo(offset + i + width + tol, j - tol);
    ctx.lineTo(offset + i + width + tol, j + height * 0.5 + tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i, j);
    ctx.rotate(Math.PI / 3);
    ctx.scale(1, -1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i - tol * 2, j + tol);
    ctx.lineTo(offset + i + width + tol, j + tol);
    ctx.lineTo(offset + i + width + tol, j - height * 0.5 - tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i, j);
    ctx.rotate(-Math.PI / 3);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width * 2 + tol * 2, j - tol);
    ctx.lineTo(offset + i + width - tol, j - tol);
    ctx.lineTo(offset + i + width - tol, j + height * 0.5 + tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width * 2, j);
    ctx.rotate((Math.PI / 3) * 2);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width * 2 + tol * 2, j + tol);
    ctx.lineTo(offset + i + width - tol, j + tol);
    ctx.lineTo(offset + i + width - tol, j - height * 0.5 - tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width * 2, j);
    ctx.rotate((Math.PI / 3) * -2);
    ctx.scale(1, -1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width - tol, j + height * 0.5);
    ctx.lineTo(offset + i + width * 2 + tol * 2, j - tol * 2);
    ctx.lineTo(offset + i + width * 1.5, j + h075 + tol);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width * 2, j);
    ctx.scale(-1, 1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width * 2 + tol, j + height + tol);
    ctx.lineTo(offset + i + width * 2 + tol, j - tol * 2);
    ctx.lineTo(offset + i + width * 1.5 - tol, j + h075);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width * 2, j);
    ctx.rotate(Math.PI / 3);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width - tol, j + height * 0.5 - tol * 2);
    ctx.lineTo(offset + i + width * 1.5 + tol, j + h075 - tol);
    ctx.lineTo(offset + i + width - tol, j + height * 1.5 + tol * 2);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width, j + height * 1.5);
    ctx.rotate((Math.PI / 3) * -2);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(offset + i + width * 2 + tol, j + height);
    ctx.lineTo(offset + i + width * 1.5, j + h075 - tol);
    ctx.lineTo(offset + i + width - tol * 2, j + height * 1.5 + tol * 2);
    ctx.closePath();
    ctx.clip();
    ctx.translate(offset + i + width, j + height * 1.5);
    ctx.rotate(Math.PI);
    ctx.scale(-1, 1);
    ctx.drawImage(img, srcX, srcY, srcW, srcH, -tol, -tol, width + tol * 2, h075 + tol * 2);
    ctx.restore();
  }

  let animationEnabled = true;
  let lastRender = 0;
  let mouse = { x: window.innerWidth * 0.5, y: window.innerHeight * 0.5 };
  let targetMouse = { x: window.innerWidth * 0.5, y: window.innerHeight * 0.5 };
  let hasMouse = false;
  const trail = [];
  const maxTrail = 140;
  const hoverRadius = 90;
  const sqrt3 = Math.sqrt(3);

  function smoothstep(edge0, edge1, x) {
    const t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
    return t * t * (3 - 2 * t);
  }

  function addTrailPoint(x, y, time, boost) {
    const now = time || 0;
    const energyBoost = boost === undefined ? 0.25 : boost;
    let closest = null;
    let bestDist = hoverRadius * 0.5;
    for (let i = trail.length - 1; i >= 0; i -= 1) {
      const p = trail[i];
      const dist = Math.hypot(p.x - x, p.y - y);
      if (dist < bestDist) {
        bestDist = dist;
        closest = p;
      }
    }

    if (!closest) {
      closest = {
        x,
        y,
        energy: 0.2,
        hueSeed: Math.random() * 360,
        lastSeen: now,
        radius: hoverRadius,
        bornAt: now
      };
      trail.push(closest);
      if (trail.length > maxTrail) {
        trail.shift();
      }
    } else {
      closest.x = x;
      closest.y = y;
      closest.energy = Math.min(1, closest.energy + energyBoost);
      closest.lastSeen = now;
    }
  }

  function render(time) {
    if (!img.complete || !img.width || !img.height) return;
    resizeCanvas();
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.fillStyle = "#f9f9fb";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.globalAlpha = 0.86;
    ctx.filter = "saturate(0.7)";

    const canvasWidth = window.innerWidth;
    const canvasHeight = window.innerHeight;

    const colwidth = canvasWidth / 4;
    const width = colwidth / 2;
    const height = (2 * width) / sqrt3;
    const rowheight = height * 1.5;
    const triHeight = height * 0.75;

    const columns = Math.ceil(canvasWidth / colwidth) + 2;
    const rows = Math.ceil(canvasHeight / rowheight) + 2;
    const t = (time || 0) * 0.001;
    if (hasMouse) {
      mouse.x += (targetMouse.x - mouse.x) * 0.12;
      mouse.y += (targetMouse.y - mouse.y) * 0.12;
      if (animationEnabled) {
        addTrailPoint(mouse.x, mouse.y, t, 0.06);
      }
    }

    let row = 0;
    for (let j = -rowheight; j < rows * rowheight; j += rowheight) {
      for (let i = -colwidth; i < columns * colwidth; i += colwidth) {
        const offset = (row % 2) * width;
        const cx = offset + i + width;
        const cy = j + height * 0.75;
        const dist = Math.hypot(cx - canvasWidth / 2, cy - canvasHeight / 2);
        const phase = dist * 0.02 - t * 0.8;
        const pulse = animationEnabled ? Math.sin(phase) : 0;
        const scale = 0.94 + pulse * 0.05;
        const srcW = img.width * scale;
        const srcH = img.height * scale;
        const wobbleX = Math.cos(phase) * img.width * 0.01;
        const wobbleY = Math.sin(phase * 0.9) * img.height * 0.01;
        let srcX = (img.width - srcW) / 2 + wobbleX;
        let srcY = (img.height - srcH) / 2 + wobbleY;
        const safeX = Math.max(2, img.width * 0.02);
        const safeY = Math.max(2, img.height * 0.02);
        srcX = Math.max(safeX, Math.min(img.width - srcW - safeX, srcX));
        srcY = Math.max(safeY, Math.min(img.height - srcH - safeY, srcY));
        srcX = Math.max(0, Math.min(img.width - srcW, srcX));
        srcY = Math.max(0, Math.min(img.height - srcH, srcY));

        drawP6mTile(i, j, width, height, row, srcX, srcY, srcW, srcH);
      }
      row += 1;
    }
    ctx.globalAlpha = 1;
    ctx.filter = "none";
    if (trail.length > 0) {
      ctx.save();
      ctx.globalCompositeOperation = "color";
      for (let i = trail.length - 1; i >= 0; i -= 1) {
        const p = trail[i];
        const since = t - p.lastSeen;
        const hovering = since < 0.35;
        const energyDecay = hovering ? 0.999 : 0.996;
        p.energy *= energyDecay;

        if (p.energy < 0.004) {
          trail.splice(i, 1);
          continue;
        }

        const age = Math.max(0, t - p.bornAt);
        const shrink = Math.max(0.25, 1 - age / 18);
        const hue = (t * 120 + p.hueSeed) % 360;
        const sat = hovering ? 95 : 70;
        const light = hovering ? 65 : 58;
        const hSpacing = triHeight;
        const v1 = p.y;
        const v2 = p.y - sqrt3 * p.x;
        const v3 = p.y + sqrt3 * p.x;
        const mod1 = ((v1 % hSpacing) + hSpacing) % hSpacing;
        const mod2 = ((v2 % (2 * hSpacing)) + 2 * hSpacing) % (2 * hSpacing);
        const mod3 = ((v3 % (2 * hSpacing)) + 2 * hSpacing) % (2 * hSpacing);
        const d1 = Math.min(mod1, hSpacing - mod1);
        const d2 = Math.min(mod2, 2 * hSpacing - mod2) * 0.5;
        const d3 = Math.min(mod3, 2 * hSpacing - mod3) * 0.5;
        const edgeDist = Math.min(d1, d2, d3);
        const edgeFactor = 1 - smoothstep(width * 0.15, width * 0.55, edgeDist);
        const edgeBoost = 0.85 + edgeFactor * 0.7;
        const bpm = 8;
        const beat = ((t * (bpm / 60)) % 1 + 1) % 1;
        const spike1 = Math.exp(-Math.pow(beat / 0.06, 2));
        const spike2 = Math.exp(-Math.pow((beat - 0.18) / 0.04, 2)) * 0.6;
        const pulse = hovering ? 1 + (spike1 + spike2) * 0.28 : 1;
        const radius = p.radius * (0.6 + p.energy * 0.9) * edgeBoost * shrink * pulse;
        const alpha = (hovering ? 0.7 : 0.4) * p.energy * edgeBoost;
        const grad = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
        grad.addColorStop(0, `hsla(${hue.toFixed(1)}, ${sat}%, ${light}%, ${alpha})`);
        grad.addColorStop(1, `hsla(${hue.toFixed(1)}, ${sat}%, ${light}%, 0)`);
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.globalCompositeOperation = "screen";
      for (let i = trail.length - 1; i >= 0; i -= 1) {
        const p = trail[i];
        const v1 = p.y;
        const v2 = p.y - sqrt3 * p.x;
        const v3 = p.y + sqrt3 * p.x;
        const mod1 = ((v1 % triHeight) + triHeight) % triHeight;
        const mod2 = ((v2 % (2 * triHeight)) + 2 * triHeight) % (2 * triHeight);
        const mod3 = ((v3 % (2 * triHeight)) + 2 * triHeight) % (2 * triHeight);
        const d1 = Math.min(mod1, triHeight - mod1);
        const d2 = Math.min(mod2, 2 * triHeight - mod2) * 0.5;
        const d3 = Math.min(mod3, 2 * triHeight - mod3) * 0.5;
        const edgeDist = Math.min(d1, d2, d3);
        const edgeFactor = 1 - smoothstep(width * 0.15, width * 0.55, edgeDist);
        const edgeBoost = 0.8 + edgeFactor * 0.8;
        const age = Math.max(0, t - p.bornAt);
        const shrink = Math.max(0.25, 1 - age / 18);
        const radius = p.radius * (0.5 + p.energy * 0.7) * edgeBoost * shrink;
        const glow = Math.min(0.35, p.energy * 0.28) * edgeBoost;
        if (glow <= 0) continue;
        const hue = (t * 120 + p.hueSeed) % 360;
        const grad = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, radius);
        grad.addColorStop(0, `hsla(${hue.toFixed(1)}, 90%, 70%, ${glow})`);
        grad.addColorStop(1, `hsla(${hue.toFixed(1)}, 90%, 70%, 0)`);
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    const veil = trail.length > 0 ? 0.22 : 0.35;
    ctx.fillStyle = `rgba(249, 249, 251, ${veil})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    if (animationEnabled) {
      requestAnimationFrame(render);
    } else if (time !== lastRender) {
      lastRender = time || 0;
    }
  }

  img.onload = () => requestAnimationFrame(render);
  window.addEventListener("resize", () => requestAnimationFrame(render));
  window.addEventListener("pointermove", (event) => {
    hasMouse = true;
    targetMouse.x = event.clientX;
    targetMouse.y = event.clientY;
    if (animationEnabled) {
      addTrailPoint(event.clientX, event.clientY, (event.timeStamp || 0) * 0.001, 0.2);
    }
  });
  window.addEventListener("pointerleave", () => {
    hasMouse = false;
  });

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("p6mToggle", (msg) => {
      animationEnabled = !!msg.enabled;
      requestAnimationFrame(render);
    });
  }
})();
