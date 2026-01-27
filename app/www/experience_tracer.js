(() => {
  const tracers = new Map();

  function clamp(v, min, max) {
    return Math.max(min, Math.min(max, v));
  }

  function getNumberAttr(el, name, fallback) {
    const raw = el.getAttribute(name);
    if (raw === null || raw === undefined || raw === "") return fallback;
    const num = parseFloat(raw);
    return Number.isNaN(num) ? fallback : num;
  }

  function resizeCanvas(canvas, pad) {
    const ratio = Math.max(window.devicePixelRatio || 1, 1);
    const rect = canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    canvas.width = rect.width * ratio;
    canvas.height = rect.height * ratio;
    const ctx = canvas.getContext("2d");
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.scale(ratio, ratio);
    if (pad && pad._data && pad._data.length) {
      pad.fromData(pad._data);
    }
  }

  function flattenPoints(strokes, canvas) {
    const pts = [];
    const rect = canvas.getBoundingClientRect();
    const w = rect.width || 1;
    const h = rect.height || 1;
    strokes.forEach((stroke) => {
      stroke.points.forEach((pt) => {
        const x = clamp(pt.x / w, 0, 1);
        const y = clamp(1 - pt.y / h, 0, 1);
        pts.push({
          x,
          y,
          t: pt.time || null
        });
      });
    });
    return pts;
  }

  function emitValue(inputId, payload) {
    if (window.Shiny && window.Shiny.setInputValue) {
      window.Shiny.setInputValue(inputId, payload, { priority: "event" });
    }
  }

  function updateStatus(wrapper, hasPoints) {
    const status = wrapper.querySelector(".experience-tracer-status");
    if (!status) return;
    status.textContent = hasPoints ? "Trace recorded" : "No trace yet";
  }

  function buildPayload(wrapper, pad) {
    const inputId = wrapper.dataset.inputId;
    const duration = getNumberAttr(wrapper, "data-duration", null);
    const yMin = getNumberAttr(wrapper, "data-y-min", 0);
    const yMax = getNumberAttr(wrapper, "data-y-max", 100);
    const samples = getNumberAttr(wrapper, "data-samples", 101);
    const canvas = wrapper.querySelector("canvas");
    const strokes = pad.toData();
    const points = flattenPoints(strokes, canvas);

    const payload = {
      version: 1,
      points,
      strokes,
      meta: {
        n_points: points.length,
        canvas_w: canvas.width,
        canvas_h: canvas.height,
        client_ts: Date.now(),
        duration_seconds: duration,
        y_min: yMin,
        y_max: yMax,
        samples
      }
    };

    updateStatus(wrapper, points.length > 0);
    emitValue(inputId, payload);
  }

  function initTracer(wrapper) {
    if (wrapper.dataset.tracerInit === "1") return;
    wrapper.dataset.tracerInit = "1";

    const canvas = wrapper.querySelector("canvas");
    if (!canvas || !window.SignaturePad) return;

    const pad = new window.SignaturePad(canvas, {
      minWidth: 1,
      maxWidth: 3,
      penColor: "#6b3df0",
      throttle: 16,
      minDistance: 2
    });

    resizeCanvas(canvas, pad);

    pad.onEnd = () => buildPayload(wrapper, pad);

    const clearBtn = wrapper.querySelector(".tracer-clear");
    const undoBtn = wrapper.querySelector(".tracer-undo");

    if (clearBtn) {
      clearBtn.addEventListener("click", () => {
        pad.clear();
        buildPayload(wrapper, pad);
      });
    }

    if (undoBtn) {
      undoBtn.addEventListener("click", () => {
        const data = pad.toData();
        data.pop();
        pad.fromData(data);
        buildPayload(wrapper, pad);
      });
    }

    tracers.set(wrapper, pad);
  }

  function initAll() {
    document.querySelectorAll(".experience-tracer").forEach(initTracer);
  }

  document.addEventListener("DOMContentLoaded", initAll);
  document.addEventListener("shiny:connected", initAll);
  document.addEventListener("shiny:idle", initAll);

  const observer = new MutationObserver(() => {
    initAll();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });

  window.addEventListener("resize", () => {
    tracers.forEach((pad, wrapper) => {
      const canvas = wrapper.querySelector("canvas");
      resizeCanvas(canvas, pad);
    });
  });
})();
