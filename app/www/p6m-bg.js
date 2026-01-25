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
    const height = (2 * width) / Math.sqrt(3);
    const rowheight = height * 1.5;

    const columns = Math.ceil(canvasWidth / colwidth) + 2;
    const rows = Math.ceil(canvasHeight / rowheight) + 2;
    const t = (time || 0) * 0.001;
    if (hasMouse) {
      mouse.x += (targetMouse.x - mouse.x) * 0.12;
      mouse.y += (targetMouse.y - mouse.y) * 0.12;
    }

    let row = 0;
    for (let j = -rowheight; j < rows * rowheight; j += rowheight) {
      for (let i = -colwidth; i < columns * colwidth; i += colwidth) {
        const offset = (row % 2) * width;
        const cx = offset + i + width;
        const cy = j + height * 0.75;
        const dist = Math.hypot(cx - canvasWidth / 2, cy - canvasHeight / 2);
        const phase = dist * 0.02 - t * 0.8;
        let ripple = 0;
        if (animationEnabled && hasMouse) {
          const md = Math.hypot(cx - mouse.x, cy - mouse.y);
          ripple = Math.sin(md * 0.1 - t * 3.5) * Math.exp(-md * 0.01);
        }
        const pulse = animationEnabled ? Math.sin(phase) + ripple * 0.9 : 0;
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
    ctx.fillStyle = "rgba(249, 249, 251, 0.45)";
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
  });

  if (window.Shiny) {
    Shiny.addCustomMessageHandler("p6mToggle", (msg) => {
      animationEnabled = !!msg.enabled;
      requestAnimationFrame(render);
    });
  }
})();
