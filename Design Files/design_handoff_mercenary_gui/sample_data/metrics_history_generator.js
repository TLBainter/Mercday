// Deterministic sample history generator used by Metrics Viewer (port to MetricsHistory.gd).
// world(M): M months of daily samples. series(): buckets daily samples into day/week/month/quarter.
// employment/levels/salaries arrays match sample_data.json mercs.
const employment = [14, 3, 27, 8, 19, 1, 11, 6, 22, 4], levels = [7, 12, 3, 9, 15, 5, 11, 2, 8, 4], salaries = [60, 150, 1200, 80, 300, 40, 90, 1500, 70, 120];
class MetricsHistory {
  constructor() { this.employment = employment; this.levels = levels; this.salaries = salaries; this._cmb = {}; }
  defs = {
    merc: [
      { k: 'salary', name: 'Salary', agg: 'last', fmt: 'money' }, { k: 'xp', name: 'Experience Gain', agg: 'sum', fmt: 'int' }, { k: 'level', name: 'Level', agg: 'last', fmt: 'int' },
      { k: 'wins', name: 'Successful Contracts', agg: 'sum', fmt: 'int' }, { k: 'losses', name: 'Failed Contracts', agg: 'sum', fmt: 'int' },
      { k: 'sRoll', name: 'Successes Rolled (Avg / Contract)', agg: 'evt', fmt: 'dec' }, { k: 'fRoll', name: 'Failures Rolled (Avg / Contract)', agg: 'evt', fmt: 'dec' },
      { k: 'kills', name: 'Enemies Defeated', agg: 'sum', fmt: 'int' }, { k: 'op', name: 'Guild Opinion', agg: 'avg', fmt: 'op' }],
    contract: [
      { k: 'count', name: 'Contract #', agg: 'sum', fmt: 'int', group: 'Totals' }, { k: 'wins', name: 'Successful Contracts', agg: 'sum', fmt: 'int', group: 'Totals' }, { k: 'losses', name: 'Failed Contracts', agg: 'sum', fmt: 'int', group: 'Totals' },
      { k: 'i1', name: 'Issuer Type 1', agg: 'sum', fmt: 'int', group: 'Contract # by Issuer Type' }, { k: 'i2', name: 'Issuer Type 2', agg: 'sum', fmt: 'int', group: 'Contract # by Issuer Type' }, { k: 'i3', name: 'Issuer Type 3', agg: 'sum', fmt: 'int', group: 'Contract # by Issuer Type' }, { k: 'i4', name: 'Issuer Type 4', agg: 'sum', fmt: 'int', group: 'Contract # by Issuer Type' },
      { k: 'diff', name: 'Average Difficulty', agg: 'evt', fmt: 'dec', group: 'Averages' }, { k: 'reward', name: 'Average Reward', agg: 'evt', fmt: 'money', group: 'Averages' }, { k: 'expense', name: 'Average Expense', agg: 'evt', fmt: 'money', group: 'Averages' }, { k: 'time', name: 'Average Time (incl. Travel)', agg: 'evt', fmt: 'days', group: 'Averages' }],
    guild: [
      { k: 'bank', name: 'Guild Bank Value', agg: 'last', fmt: 'money' }, { k: 'exp', name: 'Guild Expenses', agg: 'sum', fmt: 'money' }, { k: 'count', name: 'Mercenary #', agg: 'last', fmt: 'int' },
      { k: 'dead', name: 'Merc Casualties', agg: 'sum', fmt: 'int' }, { k: 'mop', name: 'Merc Guild Opinion', agg: 'avg', fmt: 'op' }, { k: 'cop', name: 'Client Guild Opinion', agg: 'avg', fmt: 'op' }],
  };
  defaultOn = { merc: { salary: 1, level: 1, wins: 1 }, contract: { count: 1, wins: 1, losses: 1 }, guild: { bank: 1, exp: 1 } };
  rng(seed) { let a = seed * 2654435761 >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  world(M) {
    if (this._w && this._wM === M) return this._w;
    const D = M * 30, r = this.rng(17 + M), Z = () => new Float64Array(D), E = () => ({ s: new Float64Array(D), n: new Float64Array(D) });
    const hire = this.employment.map(e => Math.max(0, D - e * 30));
    const ghosts = [[0, 200], [0, 410], [60, 700]].filter(g => g[1] < D);
    const G = { bank: Z(), exp: Z(), count: Z(), dead: Z(), mop: Z(), cop: Z() };
    const CT = [0, 1, 2].map(() => ({ count: Z(), i1: Z(), i2: Z(), i3: Z(), i4: Z(), diff: E(), wins: Z(), losses: Z(), reward: E(), expense: E(), time: E() }));
    const MD = this.levels.map(() => ({ salary: Z(), xp: Z(), level: Z(), wins: Z(), losses: Z(), sRoll: E(), fRoll: E(), kills: Z(), op: Z() }));
    MD.forEach((md, i) => { let o = (i * 4 + 10) % 11 - 5; for (let d = D - 1; d >= hire[i]; d--) { md.op[d] = o; if (r() < 0.035) o = Math.max(-5, Math.min(5, o + (r() < 0.5 ? -1 : 1))); } });
    MD.forEach((md, i) => { const S = this.salaries[i], T = D - hire[i], k = Math.floor(T / 180); for (let d = hire[i]; d < D; d++) md.salary[d] = Math.round(S * (1 - 0.12 * (k - Math.floor((d - hire[i]) / T * (k + 1))))); });
    const cash = Z(); let cop = 1;
    for (let d = 0; d < D; d++) {
      const real = []; hire.forEach((h, i) => { if (d >= h) real.push(i); });
      const gh = ghosts.filter(g => d >= g[0] && d < g[1]);
      ghosts.forEach(g => { if (g[1] === d) G.dead[d]++; });
      G.count[d] = real.length + gh.length;
      real.forEach(i => { MD[i].xp[d] += 2 + Math.floor(r() * 4); });
      const add = (e, v) => { e.s[d] += v; e.n[d]++; };
      if (G.count[d] && r() < Math.min(0.7, 0.2 + 0.05 * G.count[d])) {
        const diff = Math.max(0.5, Math.min(5, Math.round((0.5 + r() * 3 + d / D * 1.5) * 2) / 2));
        const reward = Math.round(diff * 150 * (0.6 + r() * 0.8)), expense = Math.round(reward * (0.06 + r() * 0.12)), ok = r() < 0.92 - diff * 0.08;
        const C = CT[Math.floor(r() * 3)]; C.count[d]++; C['i' + (1 + Math.floor(r() * 4))][d]++;
        add(C.diff, diff); add(C.reward, reward); add(C.expense, expense); add(C.time, (12 + diff * 20 * (0.5 + r())) / 24);
        C[ok ? 'wins' : 'losses'][d]++;
        cash[d] += (ok ? reward : 0) - expense; G.exp[d] += expense; cop += ok ? 0.35 : -0.8;
        const team = [...real].sort(() => r() - 0.5).slice(0, 1 + Math.floor(r() * Math.min(4, real.length)));
        team.forEach(i => { const md = MD[i]; md.xp[d] += Math.round(40 + diff * 30 * (ok ? 1 : 0.5)); md[ok ? 'wins' : 'losses'][d]++;
          add(md.sRoll, 2 + r() * 3 + (ok ? 2 : 0)); add(md.fRoll, 1 + r() * 2 + (ok ? 0 : 2)); md.kills[d] += Math.floor(r() * diff * 2.5); });
      }
      if (d % 30 === 29) { const pay = real.reduce((a, i) => a + MD[i].salary[d], 0) + gh.length * 60; cash[d] -= pay; G.exp[d] += pay; }
      cop = Math.max(-5, Math.min(5, cop * 0.99)); G.cop[d] = cop;
      G.mop[d] = real.length ? real.reduce((a, i) => a + MD[i].op[d], 0) / real.length : 0;
    }
    let b = 500, lo = Infinity; for (let d = 0; d < D; d++) { b += cash[d]; G.bank[d] = b; lo = Math.min(lo, b); }
    if (lo < 100) for (let d = 0; d < D; d++) G.bank[d] += 100 - lo;
    MD.forEach((md, i) => { const L = this.levels[i], T = D - hire[i], st = Math.max(1, L - Math.max(1, Math.floor(T / 90))); let tot = 0, cum = 0;
      for (let d = hire[i]; d < D; d++) tot += md.xp[d];
      for (let d = hire[i]; d < D; d++) { cum += md.xp[d]; md.level[d] = st + Math.floor((L - st) * cum / (tot || 1)); } });
    this._w = { D, hire, G, CT, MD }; this._cmb = {}; this._wM = M; return this._w;
  }
  combined(W, types) {
    const key = types.join(','); if (this._cmb[key]) return this._cmb[key];
    const out = {}; Object.keys(W.CT[0]).forEach(k => { const a0 = W.CT[0][k];
      if (a0.s) { const s = new Float64Array(W.D), n = new Float64Array(W.D); types.forEach(t => { const e = W.CT[t - 1][k]; for (let d = 0; d < W.D; d++) { s[d] += e.s[d]; n[d] += e.n[d]; } }); out[k] = { s, n }; }
      else { const a = new Float64Array(W.D); types.forEach(t => { const e = W.CT[t - 1][k]; for (let d = 0; d < W.D; d++) a[d] += e[d]; }); out[k] = a; } });
    return this._cmb[key] = out;
  }
  series(a, agg, start, len, size) {
    const n = Math.ceil(len / size), out = []; let prev = null;
    for (let b = 0; b < n; b++) { const x = start + b * size, z = Math.min(start + len, x + size); let s = 0, c = 0;
      if (agg === 'evt') { for (let d = x; d < z; d++) { s += a.s[d]; c += a.n[d]; } const v = c ? s / c : prev; out.push(v); if (v != null) prev = v; }
      else if (agg === 'last') out.push(a[z - 1]);
      else { for (let d = x; d < z; d++) s += a[d]; out.push(agg === 'sum' ? s : s / (z - x)); } }
    const first = out.find(v => v != null) ?? 0; return out.map(v => v == null ? first : v);
  }
}
