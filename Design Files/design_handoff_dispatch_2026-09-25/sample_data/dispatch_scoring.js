// Match-rating, success-odds and Optimize logic from Dispatch Window (port to DispatchLogic.gd).
// Depends on: this.contract {id, diff, reward, dist, hours, mercMin, mercMax}, this.traditions, this.roleList, this.modes, this.bank, this.availableIds.
  // Shared vocabulary: 'Knowledge 1..12', 'Tool 1..12', tradition names. Contract 1 recommendations use the same formulas as Contract Viewer.
  rng(seed) { let a = seed * 2654435761 >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  pickN(r, pool, n) { const p = [...pool], out = []; while (out.length < n && p.length) out.push(p.splice(Math.floor(r() * p.length), 1)[0]); return out; }
  mercTraits(id) {
    if (!this._mt) this._mt = {};
    if (!this._mt[id]) { const r = this.rng(id + 101), K = Array.from({ length: 12 }, (_, i) => 'Knowledge ' + (i + 1)), T = Array.from({ length: 12 }, (_, i) => 'Tool ' + (i + 1));
      this._mt[id] = { know: this.pickN(r, K, 4), tools: this.pickN(r, T, 3), trad: this.traditions[id][0] }; }
    return this._mt[id];
  }
  contractRecs() {
    const i = this.contract.id ?? 0;
    const know = Array.from({ length: 8 }, (_, k) => ({ name: 'Knowledge ' + ((i + k * 3) % 12 + 1), b: ((i + 1) * (k + 5) * 7) % 40 }));
    const tools = Array.from({ length: 8 }, (_, k) => ({ name: 'Tool ' + ((i * 2 + k * 5) % 12 + 1), b: ((i + 3) * (k + 2) * 11) % 40 }));
    const trads = Array.from({ length: 10 }, (_, k) => ({ name: this.traditions[k][0], b: ((i + 2) * (k + 7) * 13) % 50 }));
    const rank = l => { const seen = new Set(); return [...l].sort((a, b) => b.b - a.b).map(x => x.name).filter(nm => !seen.has(nm) && seen.add(nm)); };
    return { know: rank(know), tools: rank(tools), trads: rank(trads) };
  }
  recsFor(role) {
    const cid = this.contract.id ?? 0; if (this._recsId !== cid) { this._recs = this.contractRecs(); this._recsId = cid; }
    const base = this._recs, r = role === 'General' || role === 'Leader' ? 0 : this.roleList.indexOf(role) + 1;
    const rot = (l, k) => { k = k % l.length; return l.slice(k).concat(l.slice(0, k)); };
    return { know: rot(base.know, r * 2), tools: rot(base.tools, r * 2), trads: rot(base.trads, r * 2) };
  }
  w(list, name) { const i = list.indexOf(name); return i < 0 ? 0 : (list.length - i) / list.length; }
  top2(ws) { const s = [...ws].sort((a, b) => b - a); return ((s[0] || 0) + (s[1] || 0)) / 2; }
  score(id, role, extra) {
    const t = this.mercTraits(id), rc = this.recsFor(role), ex = extra || { know: [], tools: [] };
    const know = [...new Set([...t.know, ...ex.know])], tools = [...new Set([...t.tools, ...ex.tools])];
    return 0.4 * this.top2(know.map(n => this.w(rc.know, n))) + 0.35 * this.top2(tools.map(n => this.w(rc.tools, n))) + 0.25 * this.w(rc.trads, t.trad);
  }
  toStars(v) { return Math.max(0.5, Math.min(5, Math.round(v * 5 * 2) / 2)); }
  fit(id, role, extra) { return this.toStars(this.score(id, role, extra)); }
  topTraits(id, role) {
    const t = this.mercTraits(id), rc = this.recsFor(role);
    return [...t.know.map(n => ({ name: n, kind: 'know', v: this.w(rc.know, n) })), ...t.tools.map(n => ({ name: n, kind: 'tool', v: this.w(rc.tools, n) }))].sort((a, b) => b.v - a.v).slice(0, 2);
  }
  traitsFor(id, role) { return this.topTraits(id, role).map(t => ({ name: t.name, v: this.toStars(t.v) })); }
  leaderShare() { const L = this.state.slots[0]; if (L == null) return { know: [], tools: [] }; const tt = this.topTraits(L, 'Leader'); return { know: tt.filter(t => t.kind === 'know').map(t => t.name), tools: tt.filter(t => t.kind === 'tool').map(t => t.name) }; }
  starCells(v, i, col) { const full = v >= i + 1, half = !full && v >= i + 0.5; return this.starMap.join('').split('').map((ch, j) => ch !== '#' ? 'transparent' : (full || (half && j % 9 <= 4)) ? col : '#1f3560'); }
  stars(v, col) { return [0, 1, 2, 3, 4].map(i => this.starCells(v, i, col)); }
  dur(h) { if (h === 0) return 'Instant'; h = Math.round(h); return Math.floor(h / 24) + ' Days, ' + (h % 24) + ' Hours'; }
  legCost(m, n) { const units = Math.floor(this.contract.dist / m.per); return units * m.rate * (m.perMerc ? n : 1); }
  legTime(m) { return m.speed ? this.contract.dist / m.speed * 24 : 0; }
  swordMap() { const g = Array.from({ length: 12 }, () => Array(12).fill('.'));
    for (let r = 0; r <= 6; r++) { g[r][11 - r] = 'b'; if (r > 0) g[r][12 - r] = 'b'; }
    [[5, 2], [6, 3], [7, 4], [8, 5], [9, 6], [10, 0], [11, 0], [11, 1]].forEach(([r, c]) => g[r][c] = 'b');
    [[8, 3], [9, 2], [10, 1]].forEach(([r, c]) => g[r][c] = 'g'); return g.flat(); }
  isDirty() { const s = this.state; return s.slots.some(x => x != null) || s.venture || s.ret || s.roles.some((r, i) => i > 0 && r !== 'Support'); }
  assign(slot, id) { this.setState(s => { const slots = s.slots.map(x => x === id ? null : x); slots[slot] = id; return { slots, picker: null, dragOver: null }; }); }
  odds() { return this.oddsFor(this.state.slots, this.state.roles); }
  oddsFor(slots, roles) {
    const c = this.contract;
    if (slots[0] == null) return 0;
    const tt = this.topTraits(slots[0], 'Leader'), share = { know: tt.filter(t => t.kind === 'know').map(t => t.name), tools: tt.filter(t => t.kind === 'tool').map(t => t.name) };
    const scores = slots.map((id, i) => id == null ? null : this.score(id, roles[i], i === 0 ? null : share)).filter(v => v != null);
    const avg = scores.reduce((a, b) => a + b, 0) / scores.length, highs = scores.filter(v => v >= 0.7).length;
    const v = avg * 80 + highs * 6 + (scores.length - c.mercMin) * 3 - 10 - (c.diff - 3) * 10;
    return Math.max(1, Math.min(99, Math.round(v)));
  }
  oddsColor(p) { return p >= 85 ? '#3fae5a' : p >= 70 ? '#6cc36a' : p >= 55 ? '#5aa6e8' : p >= 45 ? '#f2b33d' : p >= 25 ? '#f28c28' : '#e8583f'; }
  // TODO(game impl): brute force is fine for a handful of mercs; for large rosters, prune (e.g. top-N by general fit)
  // and restrict roles to those the contract actually offers. Optimize picks both mercs AND roles here.
  doOptimize() {
    const c = this.contract, ids = this.availableIds;
    let best = null;
    const consider = (slots, roles) => { const o = this.oddsFor(slots, roles), k = slots.filter(x => x != null).length;
      if (!best || o > best.o || (o === best.o && k < best.k)) best = { o, k, slots: [...slots], roles: [...roles] }; };
    const rec = (slots, roles, i, k) => {
      if (i === k) { const pad = [...slots]; while (pad.length < 5) pad.push(null); const rp = [...roles]; while (rp.length < 5) rp.push('Support'); consider(pad, rp); return; }
      for (const id of ids) { if (slots.includes(id)) continue;
        if (i === 0) rec([id], ['Leader'], 1, k);
        else for (const r of this.roleList) rec([...slots, id], [...roles, r], i + 1, k); }
    };
    for (let k = c.mercMin; k <= Math.min(c.mercMax, ids.length); k++) rec([], [], 0, k);
    const slots = best ? best.slots : [null, null, null, null, null], roles = best ? best.roles : ['Leader', 'Support', 'Support', 'Support', 'Support'];
    const n = Math.max(slots.filter(x => x != null).length, c.mercMin), cap = c.reward * 0.1;
    let travel = null;
    const byTime = [...this.modes].sort((a, b) => this.legTime(a) - this.legTime(b));
    const cost = m => this.legCost(m, n);
    for (const v of byTime) {
      const rets = [...this.modes].filter(r => cost(v) + cost(r) <= this.bank).sort((a, b) => cost(a) - cost(b) || this.legTime(a) - this.legTime(b));
      const r = rets.find(r => cost(v) + cost(r) <= cap);
      if (r) { travel = [v, r]; break; }
    }
    if (!travel) { let min = Infinity; for (const v of byTime) for (const r of this.modes) { const t = cost(v) + cost(r); if (t <= this.bank && t < min) { min = t; travel = [v, r]; } } }
    this.setState({ slots, roles, venture: travel ? travel[0].key : null, ret: travel ? travel[1].key : null, dialog: null, roleMenu: null });
  }
