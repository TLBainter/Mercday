// Mail + Calendar add-on core. Godot: MailCenter + CalendarService autoloads. Shared by Inbox, Calendar and Game HUD.
// Data: emails.tsv (every email and how each choice chains to the next), senders.tsv (sender registry; clients mirror ClientRegistry).
// Store: window.__mailCal (separate from GameState / window.__mercStore, which it reads for money, opinion, loans, active contracts, clock).
(function () {
  if (window.MailCal) return;
  const K = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const W = '#ffffff', G = '#8a97ad', O = '#f28c28', R = '#e8583f';
  // PLACEHOLDER add-on icons (icon_sheet/addon_mail-calendar-mercdave_ICONS.png, row 0, 16 px cells; mercdave_screen = blank monitor for the face overlay). Registered into MercIcons so cell16 / tint / tabOn work.
  const ICONS = {
    mail: [0, { a: W, b: G, c: O }, ['................', '................', '................', 'aaaaaaaaaaaaaaaa', 'baaaaaaaaaaaaaab', 'abbaaaaaaaaaabba', 'aaabbaaaaaabbaaa', 'aaaaabbccbbaaaaa', 'aaaaaaccccaaaaaa', 'aaaaaaaccaaaaaaa', 'aaaaaaaaaaaaaaaa', 'aaaaaaaaaaaaaaaa', 'bbbbbbbbbbbbbbbb', '................', '................', '................']],
    mail_open: [1, { a: W, b: G, c: '#4a5a80' }, ['................', '...aaaaaaaaaa...', '...abbbbbbbba...', '...aaaaaaaaaa...', '...abbbbbbbaa...', '...aaaaaaaaaa...', 'c..abbbbbbbba..c', 'cc.aaaaaaaaaa.cc', 'cccccccccccccccc', 'aaaaaaaaaaaaaaaa', 'aaaaaaabbaaaaaaa', 'aaaaabbaabbaaaaa', 'aaabbaaaaaabbaaa', 'abbaaaaaaaaaabba', 'bbbbbbbbbbbbbbbb', '................']],
    calendar: [2, { a: W, b: G, c: O, d: R }, ['...b.......b....', '...b.......b....', '.ddbdddddddbdd..', '.ddddddddddddd..', '.ddddddddddddd..', '.aaaaaaaaaaaaa..', '.abbabbabbabba..', '.abbabbabbabba..', '.aaaaaaaaaaaaa..', '.abbabbaccabba..', '.abbabbaccabba..', '.aaaaaaaaaaaaa..', '.abbabbabbaaaa..', '.abbabbabbaaaa..', '.aaaaaaaaaaaaa..', '................']],
    request: [3, { a: W, c: O }, ['................', '..aaaaaaaaaaaa..', '.aaaaaaaaaaaaaa.', 'aaaaaaccccaaaaaa', 'aaaaaccaaccaaaaa', 'aaaaaaaaaccaaaaa', 'aaaaaaaaccaaaaaa', 'aaaaaaaccaaaaaaa', 'aaaaaaaaaaaaaaaa', 'aaaaaaaccaaaaaaa', '.aaaaaaaaaaaaaa.', '..aaaaaaaaaaaa..', '...aaa..........', '...aa...........', '...a............', '................']],
    bill: [4, { a: W, b: G, c: O }, ['................', '..aaaaaaaaaaaa..', '..abbbbbbbaaaa..', '..aaaaaaaaaaaa..', '..abbbbbaaaaaa..', '..aaaaaaaaaaaa..', '..abbbbbbbbaaa..', '..aaaaaaaaaaaa..', '..abbbbaaaaaaa..', '..aaaaaaaaaaaa..', '..aaaaaaaaaaaa..', '..aaaaaaccccaa..', '..aaaaaaccccaa..', '..aaaaaaaaaaaa..', '..a.aa.aa.aa.a..', '................']],
    news: [5, { a: W, b: G, c: O }, ['................', '.aaaaaaaaaaaaaa.', '.abbbbbbbbbbbba.', '.abbbbbbbbbbbba.', '.aaaaaaaaaaaaaa.', '.acccccaabbbbba.', '.acccccaaaaaaaa.', '.acccccabbbbbba.', '.acccccaaaaaaaa.', '.aaaaaaabbbbbba.', '.aaaaaaaaaaaaaa.', '.abbbbbbbbbbbba.', '.aaaaaaaaaaaaaa.', '.abbbbbbbbaaaaa.', '.aaaaaaaaaaaaaa.', '................']],
    mercdave_screen: [6, { a: '#8a97ad', b: '#c9d6ea', d: '#0e1628' }, ['.bbbbbbbbbbbbbb.', 'bddddddddddddddb', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', 'adddddddddddddda', '.aaaaaaaaaaaaaa.', '......aaaa......', '....aaaaaaaa....']],
  };
  function entry(col, pal, rows) {
    let x0 = 16, y0 = 16, x1 = -1, y1 = -1;
    rows.forEach((r, y) => r.split('').forEach((c, x) => { if (c !== '.') { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }));
    const order = []; let px = '';
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const c = rows[y][x]; if (c === '.') { px += '.'; continue; } let i = order.indexOf(c); if (i < 0) { order.push(c); i = order.length - 1; } px += K[i]; }
    return [col, 0, x0, y0, x1 - x0 + 1, y1 - y0 + 1, 0, order.map(c => pal[c]).join(','), px];
  }
  function reg() { const M = window.MercIcons; if (!M) return false; Object.entries(ICONS).forEach(([id, [col, pal, rows]]) => { if (!M.data[id]) M.data[id] = entry(col, pal, rows); }); return true; }

  const TODAY = 1296; // Day 7, Month 8, Year 4 (matches Finance Viewer)
  const parseTSV = txt => { const lines = txt.replace(/\r/g, '').split('\n').filter(l => l.trim()); const head = lines[0].split('\t');
    return lines.slice(1).map(l => { const c = l.split('\t'), o = {}; head.forEach((h, i) => { o[h] = (c[i] || '').trim(); }); return o; }); };
  const hm = s => { const [h, m] = (s || '0:0').split(':').map(Number); return (h || 0) * 60 + (m || 0); };
  const date = d => 'Day ' + (((d % 30) + 30) % 30 + 1) + ', Month ' + (Math.floor((((d % 360) + 360) % 360) / 30) + 1) + ', Year ' + (Math.floor(d / 360) + 1);
  const when = t => { const d = Math.floor(t / 1440), mi = t % 1440, hh = Math.floor(mi / 60), mm = mi % 60; return date(d) + ' · ' + (hh % 12 || 12) + ':' + String(mm).padStart(2, '0') + ' ' + (hh < 12 ? 'AM' : 'PM'); };
  const rng = seed => { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; };

  // Sample roster bits (MercRegistry in-engine). Balance = vacation days remaining (BenefitsManager).
  const MERC = { level: [7, 12, 3, 9, 15, 5, 11, 2, 8, 4], vacLeft: [6, 9, 2, 7, 1, 10, 5, 8, 3, 9], seed: ['Available', 'Available', 'Available', 'Available', 'Available', 'Available', 'Available', 'Available', 'Available', 'Resting'] };
  const TRAD = [['Brave', '#5aa6e8'], ['Chymist', '#6cc36a'], ['Divine', '#f2d33d'], ['Hellion', '#a36ce8'], ['Honorable', '#f28c28'], ['Mage', '#a8385a'], ['Mystech', '#3fc9c0'], ['Performer', '#f07ab8'], ['Sorcerer', '#e8583f'], ['Warrior', '#a0a8b8']]; // matches Contract Viewer
  const COMPANIES = Array.from({ length: 9 }, (_, k) => 'Company ' + (k + 1) + ' Name');
  // Bazaar mirror (BazaarManager). Same PLACEHOLDER catalog + sample orders as Bazaar.dc.html; Bazaar runs on day 540, so its days are shifted onto this clock.
  const BZ_TODAY = 540, BZ_RAR = [['Ordinary', '#a0a8b8'], ['Common', '#f3ead7'], ['Uncommon', '#6cc36a'], ['Rare', '#5aa6e8'], ['Very Rare', '#a36ce8']], BZ_MULT = [1, 2.5, 6, 15, 40];
  const BZ_DEPTS = [['weapons', 'Weapons', 40, [['Swords', 'Sword'], ['Axes', 'Axe'], ['Bows', 'Bow'], ['Daggers', 'Dagger'], ['Staves', 'Staff'], ['Firearms', 'Firearm']]], ['armor', 'Armor', 50, [['Light Armor', 'Light Armor'], ['Medium Armor', 'Medium Armor'], ['Heavy Armor', 'Heavy Armor'], ['Shields', 'Shield']]], ['headwear', 'Headwear', 25, [['Helmets', 'Helmet'], ['Hoods', 'Hood'], ['Hats', 'Hat'], ['Circlets', 'Circlet']]], ['containers', 'Containers', 20, [['Backpacks', 'Backpack'], ['Pouches', 'Pouch'], ['Quivers', 'Quiver'], ['Chests', 'Chest']]], ['tools', 'Tools', 30, [['Kits', 'Kit'], ['Instruments', 'Instrument'], ['Navigation', 'Compass']]], ['consumables', 'Consumables', 8, [['Potions', 'Potion'], ['Rations', 'Ration'], ['Scrolls', 'Scroll'], ['Bombs', 'Bomb']]], ['trinkets', 'Trinkets', 35, [['Rings', 'Ring'], ['Amulets', 'Amulet'], ['Charms', 'Charm']]]];
  let BZ_CAT = null;
  const bzItem = id => { if (!BZ_CAT) { let a = 77 * 2654435761 >>> 0; const r = () => { a = (a + 0x6D2B79F5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; let n = 1; BZ_CAT = {};
    BZ_DEPTS.forEach(([dk, dl, base, subs]) => subs.forEach(([sl, sing]) => { for (let k = 0; k < 5; k++) { const roll = r(), ri = roll < 0.3 ? 0 : roll < 0.55 ? 1 : roll < 0.75 ? 2 : roll < 0.9 ? 3 : 4; BZ_CAT[n] = { id: n, name: sing + ' ' + (k + 1), sub: sl, dept: dl, ri, price: Math.max(1, Math.round(base * BZ_MULT[ri] * (0.7 + r() * 0.6))) }; n++; r(); } })); }
    return BZ_CAT[id]; };
  const bzSample = () => [[1045, 534, [[101, 1]]], [1044, 526, [[55, 1], [70, 3], [88, 1]]], [1043, 505, [[12, 1]]], [1042, 488, [[3, 1], [40, 2]]], [1041, 462, [[118, 2]]]].map(([id, placed, lines]) => ({ id, placed, days: 20, lines, total: lines.reduce((a, [i, q]) => a + bzItem(i).price * q, 0) }));
  const SAMPLE_ACTIVE = { 2: { name: 'Contract 3 Name', hours: 150, team: [{ id: 6, role: 'Leader' }, { id: 2, role: 'Guide' }] }, 5: { name: 'Contract 6 Name', hours: 80, team: [{ id: 1, role: 'Leader' }, { id: 7, role: 'Driver' }] } }; // = GameState.active seed (standalone previews)
  const SAMPLE_LOANS = [{ lender: 'Lender 1', principal: 2000, rate: 0.08, months: 12, paid: 4 }, { lender: 'Lender 2', principal: 800, rate: 0.12, months: 6, paid: 1 }];

  const S = window.__mailCal = {
    subs: new Set(), ready: false, error: null, rows: {}, senders: {}, mail: [], rel: {}, paid: {}, pending: {},
    vacs: [ // approved history + upcoming (PLACEHOLDER); requests from emails are added as 'pending'
      { id: 'h1', merc: 4, start: 1293, days: 6, state: 'approved' }, { id: 'h2', merc: 0, start: 1268, days: 4, state: 'approved' }, { id: 'h3', merc: 2, start: 1254, days: 7, state: 'approved' },
      { id: 'h4', merc: 5, start: 1279, days: 3, state: 'approved' }, { id: 'h5', merc: 9, start: 1309, days: 5, state: 'approved' }, { id: 'h6', merc: 6, start: 1325, days: 4, state: 'approved' },
      { id: 'h7', merc: 3, start: 1240, days: 5, state: 'approved' }, { id: 'h8', merc: 8, start: 1222, days: 3, state: 'approved' }],
    emit() { this.subs.forEach(f => f()); },
    game() { return window.__mercStore || null; },
    now() { const g = this.game(); return g && g.now ? g.now : TODAY * 1440 + 600; },
    today() { return Math.floor(this.now() / 1440); },
    date, when,
    // ---------- loading ----------
    load(base) { if (this._loading) return this._loading; const b = base || './';
      return (this._loading = Promise.all([fetch(b + 'emails.tsv').then(r => r.text()), fetch(b + 'senders.tsv').then(r => r.text())]).then(([e, s]) => {
        parseTSV(e).forEach(r => { this.rows[r.id] = r; }); parseTSV(s).forEach(r => { this.senders[r.id] = r; });
        Object.values(this.rows).filter(r => r.start_day).sort((a, b) => (+a.start_day * 1440 + hm(a.start_time)) - (+b.start_day * 1440 + hm(b.start_time)))
          .forEach(r => this.deliver(r.id, null, +r.start_day * 1440 + hm(r.start_time), r.read === '1', true));
        this.ready = true; this.emit(); }).catch(err => { this.error = String(err); this.emit(); })); },
    // ---------- mail ----------
    // Deliver a row into the mailbox. Follow-ups inherit the thread root and the root's vacation request.
    deliver(id, parent, t, read, quiet) { const r = this.rows[id]; if (!r || this.mail.some(m => m.id === id)) return;
      const p = parent ? this.mail.find(m => m.id === parent) : null;
      const m = { id, t: t ?? this.now(), read: !!read, choice: null, parent: parent || null, root: p ? p.root : id, vac: p ? p.vac : null };
      if (r.vac && !m.vac) { const [merc, start, days] = r.vac.split(':').map(Number); const v = { id: 'v' + id, merc, start, days, state: 'pending', mail: id }; this.vacs.push(v); m.vac = v.id; }
      if (r.read === '1' && quiet) { const o = this.opts(r); if (o.length === 1) m.choice = 0; }
      this.mail.push(m); if (!quiet) this.emit(); },
    row(m) { return this.rows[m.id] || {}; },
    sender(id) { return this.senders[id] || { id, kind: 'Unknown', name: id, sub: '', location: '', client: '0' }; },
    opts(r) { return [1, 2, 3].map(i => r['opt' + i] ? { label: r['opt' + i], next: r['next' + i] || '', fx: (r['fx' + i] || '').split(';').map(s => s.trim()).filter(Boolean) } : null).filter(Boolean); },
    // Net notes change of an option (money:N and pay). Shown on the button.
    cost(r, o) { return o.fx.reduce((a, f) => { const [k, v] = f.split(':'); return k === 'money' ? a + (+v) : k === 'pay' ? a - (+r.amount || 0) : a; }, 0); },
    vacOf(m) { return m && m.vac ? this.vacs.find(v => v.id === m.vac) : null; },
    merc(i) { const g = this.game(), onRun = Object.values((g && g.active) || SAMPLE_ACTIVE).find(x => x.team.some(t => t.id === i)), t = this.today();
      const away = this.vacs.find(v => v.merc === i && v.state === 'approved' && t >= v.start && t < v.start + v.days);
      return { id: i, name: 'FirstName' + (i + 1) + ' LastName' + (i + 1), trad: TRAD[i][0], tradColor: TRAD[i][1], level: MERC.level[i], vacLeft: MERC.vacLeft[i], status: onRun ? 'On a Contract' : away ? 'On Vacation' : MERC.seed[i], opinion: ((i * 4 + 10) % 11 - 5) + ((g && g.guildAdj && g.guildAdj[i]) || 0) }; },
    bill(r) { if (!r.amount) return null; const key = r.bill_id || r.id, pay = [1, 2, 3].some(i => (r['fx' + i] || '').split(';').includes('pay'));
      return { key, amount: +r.amount, due: r.date ? +r.date : null, status: this.paid[key] ? 'Paid' : !r.date ? 'Paid' : pay ? 'Unpaid' : 'Auto-pay' }; },
    fill(s, m) { const r = this.row(m), v = this.vacOf(m), mc = v ? this.merc(v.merc) : null, b = this.bill(r) || {};
      return (s || '').replace(/\\n/g, '\n').replace(/\{merc\}/g, mc ? mc.name : '').replace(/\{vac_days\}/g, v ? v.days : '').replace(/\{vac_start\}/g, v ? date(v.start) : '')
        .replace(/\{vac_end\}/g, v ? date(v.start + v.days - 1) : '').replace(/\{amount\}/g, b.amount != null ? b.amount.toLocaleString('en-US') : '').replace(/\{date\}/g, r.date ? date(+r.date) : '').replace(/\{sender\}/g, this.sender(r.sender).name); },
    thread(m) { const out = []; let p = m.parent && this.mail.find(x => x.id === m.parent); while (p) { out.unshift(p); p = p.parent && this.mail.find(x => x.id === p.parent); } return out; },
    markRead(id) { const m = this.mail.find(x => x.id === id); if (m && !m.read) { m.read = true; this.emit(); } },
    unread(folder) { return this.mail.filter(m => !m.read && (!folder || this.row(m).folder === folder)).length; },
    // Apply option k of email id: effects, record the reply, schedule the follow-up (next row) after delay_h game hours (prototype: 1.6 s).
    choose(id, k) { const m = this.mail.find(x => x.id === id), r = this.rows[id]; if (!m || m.choice != null) return; const o = this.opts(r)[k]; if (!o) return;
      m.choice = k; m.choiceT = this.now(); m.read = true; let del = false; const g = this.game(), v = this.vacOf(m);
      o.fx.forEach(f => { const [key, a1, a2] = f.split(':');
        if (key === 'money' && g) { g.money += +a1; g.emit(); }
        if (key === 'pay') { const b = this.bill(r); if (b) { this.paid[b.key] = true; if (g) { g.money -= b.amount; g.emit(); } } }
        if (key === 'vac' && v) { if (a1 === 'approve') v.state = 'approved'; if (a1 === 'deny') v.state = 'denied'; if (a1 === 'shift') { v.start += +a2; v.state = 'approved'; } }
        if (key === 'opinion' && g && g.adjOpinion) g.adjOpinion(+a1, +a2);
        if (key === 'rel') this.rel[a1] = (this.rel[a1] || 0) + (+a2);
        if (key === 'delete') del = true; });
      if (del) this.mail = this.mail.filter(x => x.id !== id);
      if (o.next) { this.pending[id] = o.next; setTimeout(() => { delete this.pending[id]; this.deliver(o.next, del ? null : id, this.now()); }, 1600); }
      this.emit(); },
    // ---------- calendar ----------
    types: {
      vacation: { label: 'Vacations', icon: 'sun_rising', color: '#5aa6e8' },
      dividend: { label: 'Dividends', icon: 'coin', color: '#f2b33d' },
      earnings: { label: 'Earnings', icon: 'chart_arrow', tint: '#9cc6ef', color: '#9cc6ef' },
      loan: { label: 'Loans', icon: 'money_bag', color: '#e6d3a2' },
      bill: { label: 'Bills Due', icon: 'bill', color: '#e8583f' },
      contract: { label: 'Contracts', icon: 'contracts', color: '#f28c28' },
      delivery: { label: 'Deliveries', icon: 'parcel', color: '#e6d3a2' },
    },
    isDivDay: d => ((d % 90) + 90) % 90 === 45, // matches Finance Viewer
    earningsCo: d => { const q = ((d % 90) + 90) % 90 - 40; return q >= 0 && q % 3 === 0 && q / 3 < 9 ? q / 3 : -1; }, // company k reports on quarter day 40 + 3k
    // All events on day d (except vacations, which are spans: see vacSpans).
    events(d) { const out = [], t = this.today(), past = d < t, g = this.game();
      if (this.isDivDay(d)) out.push({ type: 'dividend', title: 'Quarterly Dividends', sub: past ? 'Paid by all 9 companies' : 'All 9 companies pay shareholders' });
      const k = this.earningsCo(d); if (k >= 0) { const beat = rng(k * 31 + Math.floor(d / 90) * 7)() < 0.6; out.push({ type: 'earnings', title: COMPANIES[k] + ' Earnings', sub: past ? (beat ? 'Beat estimates' : 'Missed estimates') : d === t ? 'Reporting today' : 'Report expected' }); }
      if (((d % 30) + 30) % 30 === 0) { const m0 = Math.floor(t / 30) * 30; ((g && g.loans) || SAMPLE_LOANS).forEach(l => { const n = (d - m0) / 30, idx = l.paid - 1 + n; if (idx < 0 || idx >= l.months) return;
        out.push({ type: 'loan', title: 'Loan Payment · ' + l.lender, sub: Math.ceil(l.principal * (1 + l.rate) / l.months).toLocaleString('en-US') + ' notes · ' + (d <= m0 ? 'Paid' : 'Payment ' + (idx + 1) + ' of ' + l.months) }); }); }
      const bills = {}; this.mail.forEach(m => { const r = this.row(m), b = this.bill(r); if (b && b.due != null) bills[b.key] = { b, r, first: (bills[b.key] && bills[b.key].first) || r }; });
      Object.values(bills).forEach(({ b, first }) => { if (b.due === d) out.push({ type: 'bill', title: first.subject.replace(/\{date\}/g, ''), sub: b.amount.toLocaleString('en-US') + ' notes · ' + b.status, status: b.status, mail: first.id }); });
      // Returning mercs: one event per active contract on its estimated return day; crew = [{ merc, role }] for the hover tooltip.
      Object.values((g && g.active) || SAMPLE_ACTIVE).forEach(run => { if (t + Math.ceil(run.hours / 24) === d) { const n = run.team.length; out.push({ type: 'contract', title: n + (n === 1 ? ' merc returns' : ' mercs return'), sub: run.name + ' · estimated', contract: run.name, crew: run.team.map(x => ({ ...this.merc(x.id), role: x.role })) }); } });
      this.orders().forEach(o => { if (o.arrive === d) { const n = o.lines.reduce((a, l) => a + l[1], 0); out.push({ type: 'delivery', title: 'Order #' + o.id + (o.arrive <= t ? ' delivered' : ' expected'), sub: n + (n === 1 ? ' item' : ' items') + ' · ' + o.total.toLocaleString('en-US') + ' notes', order: o.id }); } });
      return out; },
    // Bazaar orders on this clock: placed / arrive shifted from Bazaar's day 540 base. lines → [{ name, qty, rarity, color, sub }].
    orders() { const g = this.game(), src = (g && g.bazaar && g.bazaar.orders) || this._bz || (this._bz = bzSample()), sh = TODAY - BZ_TODAY;
      return src.map(o => ({ id: o.id, placed: o.placed + sh, days: o.days, arrive: o.placed + o.days + sh, total: o.total, lines: o.lines,
        items: o.lines.map(([i, q]) => { const it = bzItem(i) || { name: 'Item ' + i, ri: 0, sub: '', dept: '' }; return { name: it.name, qty: q, rarity: BZ_RAR[it.ri][0], color: BZ_RAR[it.ri][1], sub: it.sub }; }) })); },
    vacSpans(d0, d1) { return this.vacs.filter(v => v.state !== 'denied' && v.start <= d1 && v.start + v.days - 1 >= d0); },
    // UI hooks registered by Game HUD (openCalendar(day) / openMail(id)); absent in standalone previews.
    openCalendar: null, openMail: null,
    icons: ICONS,
  };
  window.MailCal = S;
  // merc-icons.js can re-run (nested DC helmets) and replace window.MercIcons with a fresh table: re-register on every assignment.
  let cur = window.MercIcons;
  try { Object.defineProperty(window, 'MercIcons', { configurable: true, get() { return cur; }, set(v) { cur = v; reg(); } }); } catch (e) {}
  reg();
  S.ensureIcons = () => { const M = window.MercIcons; if (M && !M.data.mail) reg(); };
  S.load();
})();
