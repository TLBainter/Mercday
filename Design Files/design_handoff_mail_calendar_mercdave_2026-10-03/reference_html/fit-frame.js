// Standalone preview only: the game screen never scrolls. Locks page scroll and scales the root 1280×720 frame to fit the viewport.
// Embedded screens (inside Game HUD windows) are left alone; only the outermost [data-screen-label] frame is fitted.
(function () {
  if (window.__fitFrame) return; window.__fitFrame = true;
  const css = document.createElement('style');
  css.textContent = 'html,body{overflow:hidden !important;height:100%}';
  document.head.appendChild(css);
  function fit() {
    const frames = [...document.querySelectorAll('[data-screen-label]')];
    const root = frames.find(f => !f.parentElement || !f.parentElement.closest('[data-screen-label]'));
    if (!root) return false;
    const wrap = root.parentElement, W = root.offsetWidth, H = root.offsetHeight;
    if (!W || !H) return false;
    const s = Math.min(1, (innerWidth - 24) / W, (innerHeight - 24) / H);
    // Scale from the top-left and collapse the layout box to the scaled size, then center it with margins.
    root.style.transformOrigin = 'top left';
    root.style.transform = 'scale(' + s + ')'; // always set: makes the frame the containing block for position:fixed popups
    root.style.marginRight = s < 1 ? (-(W * (1 - s))) + 'px' : '';
    root.style.marginBottom = s < 1 ? (-(H * (1 - s))) + 'px' : '';
    root.style.alignSelf = 'flex-start';
    root.style.marginLeft = Math.max(0, (innerWidth - 24 - W * s) / 2) + 'px';
    if (wrap) { wrap.style.padding = '12px'; wrap.style.minHeight = '100vh'; wrap.style.overflow = 'hidden'; wrap.style.alignItems = 'flex-start'; wrap.style.justifyContent = 'center'; }
    return true;
  }
  let tries = 0; const iv = setInterval(() => { if (fit() || ++tries > 60) clearInterval(iv); }, 150);
  addEventListener('resize', fit);
})();
