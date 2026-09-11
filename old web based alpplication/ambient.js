(function () {
  'use strict';
  // Wait for DOM and respect reduced-motion preference.
  var canvas = document.getElementById('ambientCanvas');
  if (!canvas) return;

  var prefersReduced = window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  var ctx = canvas.getContext('2d', { alpha: true });
  if (!ctx) return;

  var dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2));
  var w = 0, h = 0;
  var particles = [];
  var ripples = [];
  var pointer = { x: -9999, y: -9999, active: false };
  var rafId = null;
  var running = false;

  // Particle count is heavily throttled for calm, subtle effect.
  function targetCount() {
    var area = w * h;
    if (area < 200000) return 8;      // small phones — very subtle
    if (area < 500000) return 12;     // large phones
    return 16;                        // tablets / desktop preview
  }

  function resize() {
    var rect = canvas.getBoundingClientRect();
    w = Math.max(1, rect.width);
    h = Math.max(1, rect.height);
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // Rebuild particle pool on resize.
    var n = targetCount();
    if (particles.length !== n) {
      particles = [];
      for (var i = 0; i < n; i++) particles.push(makeParticle(true));
    }
  }

  function rand(min, max) { return Math.random() * (max - min) + min; }

  var palette = [
    { r: 0,   g: 229, b: 245 }, // teal
    { r: 56,  g: 189, b: 248 }, // cyan/blue
    { r: 99,  g: 102, b: 241 }, // indigo accent (subtle)
    { r: 0,   g: 198, b: 212 }  // deep teal
  ];

  function makeParticle(initial) {
    var c = palette[(Math.random() * palette.length) | 0];
    return {
      x: rand(0, w),
      y: initial ? rand(0, h) : h + rand(0, 40),
      r: rand(1.0, 2.6),                 // smaller bubbles
      vy: rand(-0.08, -0.20),            // much slower upward drift
      vx: rand(-0.04, 0.04),             // minimal horizontal sway
      wob: rand(0, Math.PI * 2),         // phase for wobble
      wobSpd: rand(0.002, 0.006),        // slower wobble
      alpha: rand(0.05, 0.18),           // much lower opacity — barely visible
      col: c
    };
  }

  function spawnRipple(x, y) {
    if (ripples.length > 6) ripples.shift();
    ripples.push({ x: x, y: y, r: 0, maxR: rand(60, 110), alpha: 0.55 });
  }

  function draw() {
    ctx.clearRect(0, 0, w, h);

    // Draw ripples (expanding rings on pointer interaction)
    for (var ri = ripples.length - 1; ri >= 0; ri--) {
      var rp = ripples[ri];
      rp.r += 1.4;
      rp.alpha *= 0.965;
      if (rp.alpha < 0.02 || rp.r > rp.maxR) {
        ripples.splice(ri, 1);
        continue;
      }
      ctx.beginPath();
      ctx.arc(rp.x, rp.y, rp.r, 0, Math.PI * 2);
      ctx.strokeStyle = 'rgba(0,229,245,' + rp.alpha.toFixed(3) + ')';
      ctx.lineWidth = 1.1;
      ctx.stroke();
    }

    // Draw bubbles
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      p.wob += p.wobSpd;
      // Gentle horizontal sway only — removed pointer repulsion (was causing jittery feeling)
      var sway = Math.sin(p.wob) * 0.15;
      // Friction + drift (calm, slow)
      p.vx *= 0.96;
      p.vy = p.vy * 0.98 + (-0.15) * 0.02; // gentle upward bias
      p.x += p.vx + sway;
      p.y += p.vy;

      // Wrap horizontally; recycle when above top
      if (p.x < -10) p.x = w + 10;
      else if (p.x > w + 10) p.x = -10;
      if (p.y < -10) {
        p.y = h + rand(5, 30);
        p.x = rand(0, w);
        p.vx = rand(-0.04, 0.04);
        p.vy = rand(-0.08, -0.20);
        p.alpha = rand(0.05, 0.18);
      }

      // Draw soft glowing bubble
      var col = p.col;
      var grad = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, p.r * 2.6);
      grad.addColorStop(0, 'rgba(' + col.r + ',' + col.g + ',' + col.b + ',' + (p.alpha * 0.9).toFixed(3) + ')');
      grad.addColorStop(0.5, 'rgba(' + col.r + ',' + col.g + ',' + col.b + ',' + (p.alpha * 0.35).toFixed(3) + ')');
      grad.addColorStop(1, 'rgba(' + col.r + ',' + col.g + ',' + col.b + ',0)');
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * 2.6, 0, Math.PI * 2);
      ctx.fill();

      // Bright core
      ctx.fillStyle = 'rgba(255,255,255,' + (p.alpha * 0.55).toFixed(3) + ')';
      ctx.beginPath();
      ctx.arc(p.x - p.r * 0.3, p.y - p.r * 0.3, p.r * 0.45, 0, Math.PI * 2);
      ctx.fill();
    }

    rafId = requestAnimationFrame(draw);
  }

  function start() {
    if (running || prefersReduced) return;
    running = true;
    rafId = requestAnimationFrame(draw);
  }
  function stop() {
    running = false;
    if (rafId) cancelAnimationFrame(rafId);
    rafId = null;
    ctx.clearRect(0, 0, w, h);
  }

  function onPointerMove(e) {
    if (!running) return;
    var rect = canvas.getBoundingClientRect();
    var t = (e.touches && e.touches[0]) ? e.touches[0] : e;
    if (!t) return;
    pointer.x = t.clientX - rect.left;
    pointer.y = t.clientY - rect.top;
    pointer.active = true;
  }
  function onPointerDown(e) {
    if (!running) return;
    var rect = canvas.getBoundingClientRect();
    var t = (e.touches && e.touches[0]) ? e.touches[0] : e;
    if (!t) return;
    var x = t.clientX - rect.left;
    var y = t.clientY - rect.top;
    spawnRipple(x, y);
    pointer.x = x; pointer.y = y; pointer.active = true;
  }
  function onPointerLeave() {
    pointer.active = false;
    pointer.x = -9999; pointer.y = -9999;
  }

  // Pause animation when tab hidden (battery / perf)
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) stop(); else start();
  });

  // Throttled resize
  var resizeTimer = null;
  window.addEventListener('resize', function () {
    if (resizeTimer) clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function () {
      resize();
      if (!prefersReduced && !running && !document.hidden) start();
    }, 180);
  });

  // Attach pointer listeners to window (canvas is pointer-events:none)
  window.addEventListener('pointermove', onPointerMove, { passive: true });
  window.addEventListener('pointerdown', onPointerDown, { passive: true });
  window.addEventListener('pointerup', onPointerLeave, { passive: true });
  window.addEventListener('pointerleave', onPointerLeave, { passive: true });
  window.addEventListener('touchend', onPointerLeave, { passive: true });

  // Respect dynamic reduced-motion preference changes
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    var handler = function (ev) {
      prefersReduced = ev.matches;
      if (prefersReduced) stop(); else start();
    };
    if (mq.addEventListener) mq.addEventListener('change', handler);
    else if (mq.addListener) mq.addListener(handler);
  }

  // Init once layout is ready
  function init() {
    resize();
    if (prefersReduced) return; // static (no animation)
    start();
    // Removed initValuePulseObserver() — it caused constant blinking by re-attaching every 2.5s
  }
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(init, 60);
  } else {
    window.addEventListener('DOMContentLoaded', function () { setTimeout(init, 60); });
  }

  // ── Value pulse observer REMOVED — was causing constant blinking by re-attaching
  // every 2.5s and triggering pulses on every stat element. Stats now stay calm. ──
})();
