// PromotionsManager shared logic (PLACEHOLDER data). Used by Promotions (ad campaigns) and Hiring (Finance › Hiring).
// Components copy these methods/fields onto themselves (useCore) so filter defs, renderers and matching live in ONE place.
window.mercPromoSeed = (t) => { return { v: 6, next: 11,
      // 9 Job Ads (one concluded → hidden by default) + 1 Guild Ad. res = results not tied to a listed applicant. inf = Infinite (billed monthly).
      campaigns: [{ id: 1, name: 'Campaign 1', mode: 'job', type: 'flyers', start: t - 12, days: 30, sel: { tradition: [0, 5] }, res: 2 }, { id: 2, name: 'Campaign 2', mode: 'promo', type: 'wom', start: t - 3, days: 14, sel: { ctype: [1], loc: [0] }, res: 1, team: [2, 5], per: 25 },
        { id: 3, name: 'Campaign 3', mode: 'job', type: 'radio', start: t - 40, days: null, inf: true, sel: {}, res: 9 },
        { id: 4, name: 'Campaign 4', mode: 'job', type: 'flyers', start: t - 2, days: 5, sel: { tradition: [9] }, res: 0 },
        { id: 5, name: 'Campaign 5', mode: 'job', type: 'sponsor', start: t - 20, days: 30, sel: { target: 2, tradition: [2, 4] }, res: 5 },
        { id: 6, name: 'Campaign 6', mode: 'job', type: 'radio', start: t - 8, days: 10, sel: { tradition: [6] }, res: 1 },
        { id: 7, name: 'Campaign 7', mode: 'job', type: 'wom', start: t - 5, days: 7, sel: {}, res: 1, team: [1, 4], per: 25 },
        { id: 8, name: 'Campaign 8', mode: 'job', type: 'flyers', start: t - 45, days: 30, sel: { tradition: [3] }, res: 4 },
        { id: 9, name: 'Campaign 9', mode: 'job', type: 'sponsor', start: t - 70, days: null, inf: true, sel: { target: 7 }, res: 14 },
        { id: 10, name: 'Campaign 10', mode: 'job', type: 'radio', start: t - 1, days: 25, sel: { tradition: [1, 8] }, res: 0 }],
      applicants: Array.from({ length: 8 }, (_, i) => ({ id: 20 + i, trad: (i * 3 + 1) % 10, level: [4, 9, 2, 12, 6, 15, 3, 8][i], ask: [320, 540, 260, 780, 410, 960, 300, 600][i],
        uniq: [0, 2, 1, 3, 1, 4, 0, 2][i], rarity: [0, 1, 0, 2, 1, 3, 0, 1][i], fit: [2, 3.5, 1.5, 4, 3, 4.5, 2.5, 3][i], from: [1, 3, null, 5, 6, 9, null, 10][i] /* null = Walk-In */, unseen: i === 3 || i === 5 /* new applicant → notification dot (card, Finance › Hiring tab, My Finance) */,
        ancestry: i % 6, bloodline: (i + 2) % 6, age: 19 + i * 5, heritage: (i + 1) % 6, perks: [i % 8, (i + 3) % 8], drawbacks: [(i + 5) % 8], skills: [(i + 1) % 8, (i + 4) % 8], criminality: i % 4,
        stats: { speed: 3 + (i * 4) % 6, cognition: 2 + (i * 2) % 6, vigor: 1 + (i * 3) % 7, dexterity: 4 + i % 4, wile: 2 + (i * 5) % 6 }, tools: [(i + 2) % 6], knowledges: [i % 6] })) };  };
window.MercPromoBase = class {
  // PromotionsWindow.tscn — Ad Campaigns (Job Postings | Guild Promo) + Hiring. PromotionsManager autoload owns campaigns + applicants.
  store() { const w = window.__mercStore; if (w) return w; if (!this.local) { const self = this; this.local = { money: 5000, emit() { self.forceUpdate(); } }; } return this.local; }
  commit() { const st = this.store(); if (st.emit) st.emit(); this.forceUpdate(); }
  ents() { const st = this.store(), p = this.props;
    if (st.entitlements) return st.entitlements();
    const all = !!p.demoAll;
    return { oddJobs: all ? 3 : 0, ancestry: all, bloodline: all, age: all, hiringDiscrim: all, heritage: all, perks: all, drawbacks: all, skills: all, criminality: all, physical: true, cognition: all, vigor: all, dexterity: all, wile: all, tools: all, knowledges: all, guildOpinion: all, clientOpinion: all, maxMercs: 20, adDirect: all, adRadio: all, adSponsor: all, promotions: true, jobPostings: true, maxPromoDays: all ? Infinity : 5, adBoost: all ? 25 : 0, guildPromo: all, gpMinDifficulty: all, gpMaxDifficulty: all, gpContractType: all }; }
  pr() { const st = this.store(); if (!st.promo || st.promo.v !== 6) st.promo = window.mercPromoSeed(this.today()); return st.promo; }
  today() { const st = this.store(); return (st.legal && st.legal.today) || 540; }
  traditions = [['Brave', '#5aa6e8'], ['Chymist', '#6cc36a'], ['Divine', '#f2d33d'], ['Hellion', '#a36ce8'], ['Honorable', '#f28c28'], ['Mage', '#a8385a'], ['Mystech', '#3fc9c0'], ['Performer', '#f07ab8'], ['Sorcerer', '#e8583f'], ['Warrior', '#a0a8b8']];
  rarities = ['Common', 'Uncommon', 'Rare', 'Very Rare'];
  groups = ['Value', 'Identity', 'Physical', 'Mental'];
  // Campaign types. quality = how likely it is to attract top mercs/contracts (1–5). eff = base effectiveness % (null = varies with the crew; Marketing Agency multiplies it). PLACEHOLDER prices. Word of Mouth is paid as an Odd Job instead.
  types = [
    { k: 'wom', name: 'Word of Mouth', sub: 'Odd Job · pay your mercs', quality: 1, eff: null, perDay: 0, ent: e => (e.oddJobs || 0) > 0, upgrade: 'Odd Jobs', upgradeId: 'oddjobs', tiers: 3 },
    { k: 'flyers', name: 'Flyers', sub: '5 notes / day', quality: 2, eff: 2, perDay: 5, ent: e => !!e.promotions, upgrade: 'Promotions', upgradeId: 'promotions', tier: 1, tiers: 1 },
    { k: 'direct', name: 'Direct Sale', sub: '40 notes / day · Guild Promo only', quality: 3, eff: 9, perDay: 40, promoOnly: true, target: 'Company', ent: e => !!e.adDirect, upgrade: 'Promo Methods', upgradeId: 'promomethods', tier: 1, tiers: 3 },
    { k: 'radio', name: 'Radio', sub: '80 notes / day', quality: 4, eff: 12, perDay: 80, noLoc: [0, 4, 7] /* Buern, Rossade, Vaernebo: no radio coverage */, ent: e => !!e.adRadio, upgrade: 'Promo Methods', upgradeId: 'promomethods', tier: 2, tiers: 3 },
    { k: 'sponsor', name: 'Sponsorship', sub: '250 notes / day · one sponsor', quality: 5, eff: 15, perDay: 250, oneLoc: true /* Sponsorship: one location per promotion */, target: 'Sponsor', ent: e => !!e.adSponsor, upgrade: 'Promo Methods', upgradeId: 'promomethods', tier: 3, tiers: 3 }];
  effOf(t, E) { if (t.eff == null) return 'Varies'; const v = t.eff * (1 + (E.adBoost || 0) / 100); return (Math.round(v * 10) / 10) + '%'; }
  locNames = ['Buern', 'Aerdis', 'Aldurstein', 'Zukei', 'Rossade', 'Copari', 'Miliim', 'Vaernebo', 'Cyfrolaef'];
  // Keep a selection valid for a campaign type: drop locations the type can't reach; Sponsorship keeps one.
  fitSel(sel, type) { const t = this.types.find(x => x.k === type) || {}; let loc = Array.isArray(sel.loc) ? sel.loc : [];
    if (t.noLoc) loc = loc.filter(i => !t.noLoc.includes(i)); if (t.oneLoc) loc = loc.slice(0, 1); return { ...sel, loc }; }
  icons = { wom: 'wom', flyers: 'flyers', direct: 'direct_sale', radio: 'radio', sponsor: 'sponsorship' }; // atlas ids (merc-icons.js)
  tabIcons = { ads: 'job_ads', guild: 'guild_ads', hiring: 'add_person' };
  get eyeCells() { return window.MercIcons ? window.MercIcons.cells('eye') : []; }
  pal(map) { if (typeof map === 'string') return window.MercIcons ? window.MercIcons.cell16(map) : []; return map.join('').split('').map(ch => ch === 'w' ? '#f3ead7' : ch === 'o' ? '#f28c28' : ch === 'b' ? '#5a7fb8' : 'transparent'); }
  starMap = window.MercIcons ? window.MercIcons.mask('star9') : ['....#....', '...###...', '...###...', '#########', '.#######.', '..#####..', '..#####..', '.###.###.', '.##...##.'];
  diffColors = { 0.5: '#29e029', 1: '#50e029', 1.5: '#77e029', 2: '#a6e33b', 2.5: '#cae33b', 3: '#e3d83b', 3.5: '#e3b43b', 4: '#e08629', 4.5: '#e05f29', 5: '#e03829' }; // same as Contract Viewer
  rateColors = { 0.5: '#e03829', 1: '#e05f29', 1.5: '#e08629', 2: '#e3b43b', 2.5: '#e3d83b', 3: '#cae33b', 3.5: '#a6e33b', 4: '#77e029', 4.5: '#50e029', 5: '#29e029' };
  stars(v) { const col = this.rateColors[v] || '#f28c28'; return [0, 1, 2, 3, 4].map(i => { const full = v >= i + 1, half = !full && v >= i + 0.5; return window.MercIcons.diffStar(full ? 1 : half ? 0.5 : 0, col); }); }
  swordMap() { const g = Array.from({ length: 12 }, () => Array(12).fill('.'));
    for (let r = 0; r <= 6; r++) { g[r][11 - r] = 'b'; if (r > 0) g[r][12 - r] = 'b'; }
    [[5, 2], [6, 3], [7, 4], [8, 5], [9, 6], [10, 0], [11, 0], [11, 1]].forEach(([r, c]) => g[r][c] = 'b');
    [[8, 3], [9, 2], [10, 1]].forEach(([r, c]) => g[r][c] = 'g'); return g.flat(); }
  n(v) { return Math.round(v).toLocaleString('en-US'); }
  mname(id) { return 'FirstName' + (id + 1) + ' LastName' + (id + 1); }
  names(pfx, n) { return Array.from({ length: n }, (_, i) => pfx + ' ' + (i + 1)); }
  // Merc trait filters: one def per trait the merc overview can show, grouped. lock: entitlement + unlocking upgrade; hire: also needs Discrimination IV (Hiring Discrimination).
  mercDefs(hiring) { const P = this.pr(), D = k => ({ ent: k, upgrade: 'Discrimination', upgradeId: 'discrim', tier: 4, tiers: 4, hire: true }), B = t => ({ upgrade: 'Background Check', upgradeId: 'background', tier: t, tiers: 5 });
    const jobC = P.campaigns.filter(c => c.mode === 'job'), T = (u, id) => ({ upgrade: u, upgradeId: id, tier: 1, tiers: 1 });
    return [
      { k: 'salary', g: 'Value', label: 'Salary Request', kind: 'slider2', min: 0, max: 2000, step: 50, span: '1 / -1', fmt: v => this.n(v) + ' / mo' },
      ...(hiring ? [{ k: 'from', g: 'Value', label: 'Applied Via', kind: 'chips', opts: [...jobC.map(c => c.name), 'Walk-In'], vals: [...jobC.map(c => c.id), null], span: '1 / -1' }] : []),
      { k: 'tradition', g: 'Identity', label: 'Tradition', kind: 'trad', span: '1 / -1' },
      { k: 'ancestry', g: 'Identity', label: 'Ancestry', kind: 'chips', opts: this.names('Ancestry', 6), lock: D('ancestry') },
      { k: 'bloodline', g: 'Identity', label: 'Bloodline', kind: 'chips', opts: this.names('Bloodline', 6), lock: D('bloodline') },
      { k: 'heritage', g: 'Identity', label: 'Heritage', kind: 'chips', opts: this.names('Heritage', 6), lock: { ent: 'heritage', ...B(1) } },
      { k: 'criminality', g: 'Identity', label: 'Criminality', kind: 'chips', opts: this.names('Criminality', 4), lock: { ent: 'criminality', ...T('Criminal Background Check', 'criminal') } },
      { k: 'age', g: 'Physical', label: 'Age', kind: 'range', min: 16, max: 90, step: 1, lock: D('age') },
      { k: 'vigor', g: 'Physical', label: 'Min Vigor', kind: 'min', stat: true, min: 0, max: 10, lock: { ent: 'vigor', ...T('Brawn Test', 'brawn') } },
      { k: 'speed', g: 'Physical', label: 'Min Speed', kind: 'min', stat: true, min: 0, max: 10, lock: { ent: 'physical', upgrade: 'Mercday Pro', upgradeId: 'pro', tier: 1, tiers: 1 } },
      { k: 'dexterity', g: 'Physical', label: 'Min Dexterity', kind: 'min', stat: true, min: 0, max: 10, lock: { ent: 'dexterity', ...T('Readiness Test', 'readiness') } },
      { k: 'cognition', g: 'Mental', label: 'Min Cognition', kind: 'min', stat: true, min: 0, max: 10, lock: { ent: 'cognition', ...T('Aptitude Test', 'aptitude') } },
      { k: 'wile', g: 'Mental', label: 'Min Wile', kind: 'min', stat: true, min: 0, max: 10, lock: { ent: 'wile', ...T('Personality Test', 'personality') } },
      { k: 'knowledges', g: 'Mental', label: 'Knowledges', kind: 'chips', opts: this.names('Knowledge', 6), lock: { ent: 'knowledges', ...T('Education Exam', 'education') } },
      { k: 'tools', g: 'Mental', label: 'Tools', kind: 'chips', opts: this.names('Tool', 6), lock: { ent: 'tools', ...T('Skill Test', 'skilltest') } }]; }
  // Contract filters (Guild Promo): modules with history. Level and reward are never targetable; locations need an Operations Permit.
  // PLACEHOLDER history + relationships (ContractHistory / ClientManager in Godot).
  contractDefs(type) { const L = this.store().legal || (window.mercLegalSeed ? window.mercLegalSeed() : { permits: {} }), perm = L.permits || {}, t = this.types.find(x => x.k === type) || {};
    // Contract Type + Locations sit side by side in fixed-height scroll boxes sized so the builder itself never scrolls.
    const boxH = Math.max(150, 350 - (t.target ? 78 : 0) - (type === 'wom' ? 160 : 0)) + 'px';
    const hist = (i, s) => [(i * 7 + s) % 12 + 1, (i * 5 + s) % 9, (i * 3 + s) % 4], GP = (ent, tier) => ({ ent, upgrade: 'Guild Promo', upgradeId: 'guildpromo', tier, tiers: 4 });
    return [
      ...(t.target ? [{ k: 'target', label: t.target === 'Sponsor' ? 'Sponsor (Company or Event) · pick 1' : 'Advertise To', kind: t.target === 'Sponsor' ? 'one' : 'chips' /* Direct Sale: any number of companies */, opts: t.target === 'Sponsor' ? [...this.names('Company', 6), ...this.names('Event', 3)] : this.names('Company', 6), span: '1 / -1' }] : []),
      { k: 'diff', label: 'Difficulty', kind: 'stars2', span: '1 / -1', rowLocks: { Min: GP('gpMinDifficulty', 2), Max: GP('gpMaxDifficulty', 3) } },
      { k: 'ctype', label: 'Contract Type', kind: 'mods', boxH, lock: GP('gpContractType', 4), mods: this.names('Type', 6).map((nm, i) => ({ name: nm, img: 'Contract Image', hist: hist(i, 2) })) },
      { k: 'loc', label: 'Locations · sets roughly how far contracts are' + (t.oneLoc ? ' · pick 1' : ''), short: 'Locations', kind: 'mods', single: !!t.oneLoc, boxH, mods: this.locNames.map((nm, i) => { const noPerm = !(perm[i] && perm[i].ops), noRadio = !!(t.noLoc && t.noLoc.includes(i));
        return { name: nm, img: 'Location Image', hist: hist(i, 5), rel: [2, 1, 3, -1, 0, -3, 1, 0, 2][i], off: noPerm || noRadio, offNote: noRadio ? 'No radio coverage' : 'No Operations Permit', offWhere: noRadio ? 'Radio can\'t reach ' + nm : 'Legal › Permits' }; }) }]; }
  lockOf(def, E) { const l = def.lock; if (!l) return null; return !!E[l.ent] && (!l.hire || !!E.hiringDiscrim) ? null : l; }
  sliderRef(k) { this.srefs = this.srefs || {}; return this.srefs[k] || (this.srefs[k] = ({ current: null })); }
  // One renderer for every filter section (builder + Hiring list).
  sec(def, sel, set, E) {
    const lk = this.lockOf(def, E), v = sel[def.k];
    const base = { label: def.label, labelColor: lk ? '#5e7699' : '#9cc6ef', span: def.span || 'auto', locked: !!lk, isChips: false, isNum: false, isCrew: false, isSlider: false, isStars: false, isMods: false, chips: [], nums: [], mods: [], starRows: [], sl: {} };
    if (lk) return { ...base, feature: def.label.replace(/^(Min |Avoid )/, ''), upgrade: lk.upgrade, upgradeId: lk.upgradeId, tier: lk.tier, tiers: lk.tiers };
    const arr = Array.isArray(v) ? v : [];
    const chip = (label, val, extra = {}) => { const on = def.kind === 'one' ? v === val : arr.includes(val);
      return { label, title: '', on, fg: on ? '#0a0f1c' : '#9cc6ef', bg: on ? (def.avoid ? '#e8583f' : '#f28c28') : '#15223d', ring: on ? 'transparent' : '#1f3560', opacity: 1, cursor: 'pointer', dot: false, dotColor: '',
        onClick: () => set(def.k, def.kind === 'one' ? (on ? undefined : val) : on ? arr.filter(x => x !== val) : [...arr, val]), ...extra }; };
    if (def.kind === 'trad') return { ...base, isChips: true, chips: this.traditions.map(([nm, col], i) => chip(nm, i, { dot: true, dotColor: col })) };
    if (def.kind === 'chips' || def.kind === 'one') return { ...base, isChips: true, chips: def.opts.map((o, i) => chip(o, def.vals ? def.vals[i] : i)) };
    if (def.kind === 'mods') { const E2 = E;
      return { ...base, isMods: true, boxH: def.boxH || '260px', mods: def.mods.map((m, i) => { const on = arr.includes(i), off = !!m.off;
        return { name: m.name, imgLabel: m.img, on, ring: on ? '#f28c28' : '#1f3560', ringW: on ? '3px' : '2px', opacity: off ? 0.4 : 1, filter: off ? 'grayscale(1)' : 'none' /* no Operations Permit: grayed, not clickable */, cursor: off ? 'not-allowed' : 'pointer', title: off ? m.offNote + ' (' + m.offWhere + ')' : '',
          chkBg: on ? '#f28c28' : '#0a0f1c', chkRing: on ? '#ffb266' : '#3b6fb6', chkMark: on ? '✓' : '' /* checkbox, top-right of every card */,
          hasRel: m.rel != null, relOpen: !!E2.clientOpinion, relLocked: !E2.clientOpinion, rel: (m.rel > 0 ? '+' : '') + m.rel, relColor: m.rel > 0 ? '#6cc36a' : m.rel < 0 ? '#e8583f' : '#f2b33d',
          stats: [['Received', m.hist[0], '#f3ead7'], ['Completed', m.hist[1], '#6cc36a'], ['Failed', m.hist[2], '#e8583f']].map(([label, value, color]) => ({ label, value: String(value), color, title: label + ' from this ' + (m.rel != null ? 'location' : 'contract type') })),
          hasNote: off, note: m.offNote, onClick: () => { if (!off) set(def.k, on ? arr.filter(x => x !== i) : def.single ? [i] /* one only: replaces */ : [...arr, i]); } }; }) }; }
    if (def.kind === 'stars2') { const [lo, hi] = Array.isArray(v) ? v : [0.5, 5], lbl = x => x + (x === 1 ? ' star' : ' stars');
      // Half-star steps: left half of a star = n − 0.5, right half = n. Colors = contract difficulty colors (Contract Viewer diffColors), by value.
      // Hover previews the value on the star pixels only (brighter), no box highlight.
      const hv = this.state.starHover;
      // rowLocks: a row (Min / Max) can be locked on its own → Feature Lock in place of its stars; its value stays at the default.
      const row = (label, cur, pick) => { const rl = def.rowLocks && def.rowLocks[label], rlk = rl && !E[rl.ent] ? rl : null;
        if (rlk) return { label, locked: true, open: false, feature: label + ' Difficulty', upgrade: rlk.upgrade, upgradeId: rlk.upgradeId, tier: rlk.tier, tiers: rlk.tiers, stars: [] };
        const pv = hv && hv.k === def.k && hv.row === label ? hv.v : null, show = pv ?? cur, col = this.diffColors[show];
        return { label, locked: false, open: true, feature: '', upgrade: '', upgradeId: '', tier: 1, tiers: 1, stars: [1, 2, 3, 4, 5].map(n => ({ halfTitle: label + ' ' + lbl(n - 0.5), fullTitle: label + ' ' + lbl(n), onHalf: () => pick(n - 0.5), onFull: () => pick(n),
          enterHalf: () => this.setState({ starHover: { k: def.k, row: label, v: n - 0.5 } }), enterFull: () => this.setState({ starHover: { k: def.k, row: label, v: n } }), leave: () => this.setState({ starHover: null }),
          cells: window.MercIcons.diffStar(n <= show ? 1 : n - 0.5 === show ? 0.5 : 0, col, pv != null ? '#2b4f8a' : '#1f3560') })) }; };
      return { ...base, isStars: true, starRows: [row('Min', lo, x => set(def.k, [x, Math.max(x, hi)])), row('Max', hi, x => set(def.k, [Math.min(lo, x), x]))] }; }
    if (def.kind === 'slider2') { const [lo, hi] = Array.isArray(v) ? v : [def.min, def.max], ref = this.sliderRef(def.k), span = def.max - def.min, pct = x => ((x - def.min) / span * 100) + '%';
      const at = e => { const r = ref.current.getBoundingClientRect(), f = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)); return def.min + Math.round(f * span / def.step) * def.step; };
      const apply = (e, which) => { const x = at(e), cur = Array.isArray(sel[def.k]) ? sel[def.k] : [def.min, def.max]; set(def.k, which === 'lo' ? [Math.min(x, cur[1]), cur[1]] : [cur[0], Math.max(x, cur[0])]); };
      return { ...base, isSlider: true, sl: { ref, loPct: pct(lo), hiPct: pct(hi), span: ((hi - lo) / span * 100) + '%', loLabel: def.fmt(lo), hiLabel: def.fmt(hi),
        down: e => { if (!ref.current) return; const x = at(e), which = Math.abs(x - lo) <= Math.abs(x - hi) && !(x > hi) ? 'lo' : 'hi'; this.drag = { k: def.k, which }; e.currentTarget.setPointerCapture(e.pointerId); apply(e, which); },
        move: e => { if (this.drag && this.drag.k === def.k) apply(e, this.drag.which); }, up: () => { this.drag = null; } } }; }
    const num = (value, onChange, sep) => ({ value, min: def.min, max: def.max, step: def.step || 1, onChange, sep });
    if (def.kind === 'range') { const [lo, hi] = Array.isArray(v) ? v : [def.min, def.max];
      return { ...base, isNum: true, nums: [num(lo, x => set(def.k, [Math.min(x, hi), hi]), false), num(hi, x => set(def.k, [lo, Math.max(x, lo)]), true)] }; }
    return { ...base, isNum: true, nums: [num(v ?? def.min, x => set(def.k, x), false)] }; }
  active(def, v) { if (v == null) return false; if (def.kind === 'slider2') return v[0] > def.min || v[1] < def.max; if (def.kind === 'stars2') return v[0] > 0.5 || v[1] < 5; if (def.kind === 'range') return v[0] > def.min || v[1] < def.max; if (def.kind === 'min') return v > def.min; return Array.isArray(v) ? v.length > 0 : true; }
  grouped(ctx, defs, sel, set, E) { const og = this.state.openG[ctx] || {};
    return this.groups.map(g => { const ds = defs.filter(d => d.g === g), open = !!og[g], cnt = ds.filter(d => !this.lockOf(d, E) && this.active(d, sel[d.k])).length;
      return { label: g, hasHead: true, open, caret: open ? '▼' : '▶', headBg: open ? '#1f3560' : '#15223d', hasCount: cnt > 0, count: String(cnt), secs: open ? ds.map(d => this.sec(d, sel, set, E)) : [],
        toggle: () => this.setState(p => ({ openG: { ...p.openG, [ctx]: { ...(p.openG[ctx] || {}), [g]: !open } } })) }; }).filter(g => defs.some(d => d.g === g.label)); }
  summary(c) { const defs = c.mode === 'job' ? this.mercDefs(false) : this.contractDefs(c.type), out = [];
    defs.forEach(d => { const v = c.sel[d.k]; if (!this.active(d, v)) return;
      const val = d.kind === 'trad' ? v.map(i => this.traditions[i][0]).join(', ') : d.kind === 'one' ? d.opts[v] : d.kind === 'mods' ? v.map(i => d.mods[i].name).join(', ') : d.kind === 'stars2' ? v[0] + '–' + v[1] + ' stars' : d.kind === 'slider2' ? d.fmt(v[0]) + ' – ' + d.fmt(v[1]) : d.kind === 'range' ? v[0] + '–' + v[1] : d.kind === 'min' ? v + '+' : v.map(i => d.opts[i]).join(', ');
      out.push({ label: d.short || d.label, value: val }); });
    return out.length ? out.slice(0, 4) : [{ label: 'Targeting', value: 'Anyone' }]; }
  matches(a, f, E) {
    for (const d of this.mercDefs(true)) { if (this.lockOf(d, E)) continue; const v = f[d.k]; if (!this.active(d, v)) continue;
      const x = d.k === 'tradition' ? a.trad : d.stat ? a.stats[d.k] : d.k === 'salary' ? a.ask : a[d.k];
      if ((d.kind === 'range' || d.kind === 'slider2') && (x < v[0] || x > v[1])) return false;
      if (d.kind === 'min' && x < v) return false;
      if ((d.kind === 'chips' || d.kind === 'trad')) { const xs = Array.isArray(x) ? x : [x]; if (d.avoid ? v.some(i => xs.includes(i)) : !v.some(i => xs.includes(i))) return false; } }
    return true; }
  employed() { const st = this.store(), P = this.pr(); return 12 - Object.keys(st.fired || {}).length + (P.hired || 0); }
  flash(text, color) { clearTimeout(this.nt); this.setState({ notice: { text, color } }); this.nt = setTimeout(() => this.setState({ notice: null }), 3200); }
  componentWillUnmount() { clearTimeout(this.nt); (this.timers || []).forEach(clearTimeout); }
  crewCands(seed) { return Array.from({ length: 12 }, (_, i) => ({ id: i, name: this.mname(i), fit: Math.max(0.5, Math.min(5, ((i * 37 + seed) % 10) / 2 + 0.5)) })); }
  defPay() { const st = this.store(); return st.oddJobDefault ?? 25; }
};
window.mercPromoUnseen = (st) => !!(st && st.promo && st.promo.applicants && st.promo.applicants.some(a => a.unseen));
