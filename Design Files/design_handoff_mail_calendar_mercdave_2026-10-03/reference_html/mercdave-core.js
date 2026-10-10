// Mercdave core (hint markers). Godot: Mercdave autoload. All text comes from mercdave.tsv:
//   ctx  — page name per context      help — one hint per data-help target (row order = priority)
//   more — Tell Me More text (a help row's `next` points at it)      sys — button labels / empty-state text
//   face — Guild Opinion expression (−5…+5) on his screen while that row shows (blank = 2)
// Rules: hints come only from the topmost scope (window root or dialog); max 3 markers, unread only.
// The card auto-opens once per scope the first time it has unread hints. Ok = mark read + close. Next Hint = cycle. Tab click toggles.
(function () {
  if (window.MercdayAssistant) return;
  const parseTSV = txt => { const lines = txt.replace(/\r/g, '').split('\n').filter(l => l.trim()); const head = lines[0].split('\t');
    return lines.slice(1).map(l => { const c = l.split('\t'), o = {}; head.forEach((h, i) => { o[h] = (c[i] || '').trim(); }); return o; }); };
  const LS = 'mercday_hints_read', MAX = 3;
  let read = {}; try { read = JSON.parse(localStorage.getItem(LS) || '{}'); } catch (e) {}
  const A = window.__assistant = {
    subs: new Set(), rows: {}, prio: {}, ready: false, error: null, ctx: 'hud', open: null,
    read, scope: null, unread: [], marks: [], hint: null, more: false, card: false, autoShown: {},
    emit() { this.subs.forEach(f => f()); },
    load(base) { if (this._loading) return this._loading;
      return (this._loading = fetch((base || './') + 'mercdave.tsv').then(r => r.text()).then(t => { parseTSV(t).forEach((r, i) => { this.rows[r.id] = r; this.prio[r.id] = i; }); this.ready = true; this.emit(); })
        .catch(e => { this.error = String(e); this.emit(); })); },
    label(id) { return (this.rows[id] || {}).label || id; },
    page() { return (this.rows['ctx_' + this.ctx] || {}).label || 'Mercday'; },
    faceOf(r) { const v = r && r.face !== '' && r.face != null ? parseInt(r.face, 10) : NaN; return isNaN(v) ? 2 : Math.max(-5, Math.min(5, v)); },
    faceColors: { '-5': '#e8583f', '-4': '#ec6a36', '-3': '#ef7c2f', '-2': '#f28c28', '-1': '#f2a033', '0': '#f2b33d', '1': '#5aa6e8', '2': '#5fb0b8', '3': '#64b98c', '4': '#6cc36a', '5': '#3fae5a' },
    faceId(lv) { return 'face_' + (lv === 0 ? '0' : (lv < 0 ? 'm' : 'p') + Math.abs(lv)); },
    // Mercdave = blank monitor (mercdave_screen, add-on atlas) + the Guild Opinion face icon (face_m5…face_p5, 12×12) tinted with that
    // opinion's color, drawn 1:1 on the screen at (2, 1). Godot: TextureRect screen + TextureRect face (modulate = faceColors[lv]).
    faceUrl(lv) { const M = window.MercIcons; if (!M || !M.data.mercdave_screen) return ''; this._fc = this._fc || {}; if (this._fc[lv]) return this._fc[lv];
      const cells = M.cell16('mercdave_screen').slice(), fc = M.cells(this.faceId(lv), this.faceColors[String(lv)]), w = M.w(this.faceId(lv)), h = M.h(this.faceId(lv));
      if (!fc.length) return ''; const ox = 2 + Math.floor((12 - w) / 2), oy = 1 + Math.floor((12 - h) / 2);
      fc.forEach((col, i) => { if (col && col !== 'transparent') cells[(oy + Math.floor(i / w)) * 16 + ox + (i % w)] = col; });
      return (this._fc[lv] = M.pxUrl(cells, 16)); },
    shownFace() { const r = this.card && (this.more ? this.rows[(this.rows[this.hint] || {}).next] : this.rows[this.hint]); return r ? this.faceOf(r) : 2; },
    setContext(k) { if (k) this.ctx = k; },
    notify() {}, // kept for the HUD's open-window calls
    // Called by the assistant view each scan with the visible help keys of the topmost scope.
    setScope(id, keys) { if (!this.ready) return;
      const unread = keys.filter(k => this.rows[k] && this.rows[k].type === 'help' && !this.read[k]).sort((a, b) => this.prio[a] - this.prio[b]);
      const marks = unread.slice(0, MAX), changed = id !== this.scope || unread.join() !== this.unread.join();
      this.scope = id; this.unread = unread; this.marks = marks;
      if (this.card && (id !== this._cardScope || (this.hint && !keys.includes(this.hint)))) { this.card = false; this.hint = null; changed || this.emit(); }
      if (!this.card && marks.length && !this.autoShown[id]) { this.autoShown[id] = true; this.show(marks[0]); return; }
      if (changed) this.emit(); },
    show(k) { this.hint = k; this.more = false; this.card = true; this._cardScope = this.scope; this.emit(); },
    toggle() { if (this.card) this.close(); else this.show(this.marks[0] || null); },
    close() { this.card = false; this.emit(); },
    ok() { if (this.hint) { this.read[this.hint] = 1; try { localStorage.setItem(LS, JSON.stringify(this.read)); } catch (e) {} }
      this.card = false; this.hint = null; this.emit(); },
    next() { const m = this.marks; if (m.length < 2) return; const i = m.indexOf(this.hint); this.show(m[(i + 1) % m.length]); },
    tellMore() { this.more = true; this.emit(); },
    resetHints() { this.read = {}; this.autoShown = {}; try { localStorage.removeItem(LS); } catch (e) {} this.emit(); },
  };
  window.MercdayAssistant = window.Mercdave = A;
  // Global scan driver, independent of any view's lifecycle: the latest-rendered view registers itself as A.scanner.
  // Driven by DOM changes + input (timers created at script load proved unreliable in the host), debounced to one scan per 80 ms.
  const runScan = () => { A._q = 0; const s = A.scanner; if (s && s.frameRef && s.frameRef.current && s.frameRef.current.isConnected) { try { s.scan(); } catch (e) { console.warn('[assistant] scan', e); } } };
  A.kick = () => { if (A._q) return; A._q = 1; setTimeout(runScan, 80); };
  const start = () => { new MutationObserver(m => { if (m.some(x => !(x.target.closest && x.target.closest('[data-asst-ui]')))) A.kick(); }).observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
    ['click', 'mouseup', 'wheel', 'resize', 'keyup'].forEach(ev => addEventListener(ev, () => A.kick(), true)); A.kick(); };
  if (document.body) start(); else addEventListener('DOMContentLoaded', start);
  A.load();
})();
