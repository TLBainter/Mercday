// Settlement generator: cities and capitals build themselves on location from building kits (MercElements.kit / .core) + rules below.
// MercSettlements.generate(site, grid, ME, K) → [element]. site = { id, kind: 'city'|'capital', style, x, y, nbrs: [[x, y, name]] } (image px).
// grid (½-res cells, shared by every site so settlements never overlap): RW, RH, dry (1 = land, not sea/lake/river/rail corridor),
//   nat (nation id), lvl (terrace level), occ (0 free · 1 building · 2 street), paint (street/plaza color code), code(style, 'street'|'plaza').
// Hard rules: every building footprint cell and every street cell is dry land of the site's own nation (never crosses a border, never enters
// water, rivers or the railroad corridor); a footprint spans ≤ 1 terrace level (then flattened); buildings keep a 1-cell gap from each other.
(function (root) {
  // Tier = settlement size. radius px; plaza (city) half-size cells; roads = main road count; lengths px; branchP = branch chance [alleys, 2nd level];
  // turn = chance per step of a 90° bend; buildings = target (main pass); infill = extra small buildings on streets that already have buildings.
  const TIERS = {
    // 2026-10-07 density pass: same footprint, more alleys (branchEvery ↓, branchP ↑), tighter lots (1-cell setback, no random gap), back-row lots (backP).
    city: { radius: 46, plaza: 3, roads: [2, 4], roadLen: [20, 44], branchEvery: [5, 9], branchLen: [8, 18], branchP: [0.8, 0.55], turn: 0.06, buildings: [34, 48], landmarks: 2, infill: 30, backP: 0.85 },
    capital: { radius: 92, core: true, roads: [4, 4], roadLen: [34, 70], branchEvery: [4, 7], branchLen: [10, 24], branchP: [0.85, 0.6], turn: 0.05, buildings: [80, 120], landmarks: 3, infill: 70, backP: 0.9 } };
  // Small kits used by the infill pass (squeezed into gaps along streets that already have buildings).
  const SMALL = ['hut', 'stall', 'dar'];
  // Region (style) rules: which kits a nation builds and how often; landmarks = first buildings placed on the main roads near the center.
  const STYLES = {
    buern: { kits: { hut: 3, stall: 1.5, dar: 4, riad: 3, l_house: 2, windcatcher: 1.5, stepped_kasbah: 1, tower_house: 1.5, domed: 1.5, merchant: 1.5, caravanserai: 1, hammam: 1, round_tower: 0.5, minaret: 0.6, cathedral: 0, shatyor: 0, kremlin_tower: 0.2 },
      landmarks: ['minaret', 'stepped_kasbah', 'merchant'] },
    vaernebo: { kits: { hut: 3, stall: 1.5, dar: 4, riad: 2.5, l_house: 2, windcatcher: 0.8, stepped_kasbah: 0.6, tower_house: 1, domed: 2.5, merchant: 1.5, caravanserai: 0.8, hammam: 2, round_tower: 0.6, minaret: 0.6, cathedral: 0.6, shatyor: 0.3, kremlin_tower: 0.4 },
      landmarks: ['domed', 'cathedral', 'minaret'] },
    rossade: { kits: { hut: 3, stall: 1.2, dar: 4, riad: 2.5, l_house: 2, windcatcher: 0.4, stepped_kasbah: 0.5, tower_house: 1.5, domed: 1.5, merchant: 1.5, caravanserai: 0.4, hammam: 0.8, round_tower: 1, minaret: 0.3, cathedral: 1, shatyor: 1, kremlin_tower: 1 },
      landmarks: ['cathedral', 'shatyor', 'kremlin_tower'] },
    // 2026-10-07 nation styles. small = this style's infill kits.
    kathaya: { kits: { kt_shack: 3, kt_adobe: 4, kt_falsefront: 3, kt_saloon: 1, kt_mission: 0.5, kt_watertower: 0.6, kt_hacienda: 1 }, small: ['kt_shack', 'kt_adobe'], landmarks: ['kt_mission', 'kt_saloon', 'kt_watertower'] },
    aldurstein: { kits: { al_stuga: 4, al_longhouse: 2, al_ottoman: 3, al_block: 1.5, al_warehouse: 1, al_stave: 0.3, al_mosque: 0.3 }, small: ['al_stuga'], landmarks: ['al_mosque', 'al_stave', 'al_block'] },
    zukei: { kits: { zk_minka: 3, zk_machiya: 4, zk_shop: 1.5, zk_temple: 0.4, zk_pagoda: 0.3, zk_yagura: 0.3 }, small: ['zk_minka'], gates: 'zk_torii', landmarks: ['zk_pagoda', 'zk_temple', 'zk_castle'] },
    suorr: { kits: { su_cottage: 3, su_terrace: 4, su_casa: 2.5, su_factory: 1.2, su_gasholder: 0.5, su_cathedral: 0.3, su_clocktower: 0.3 }, small: ['su_cottage'], landmarks: ['su_clocktower', 'su_factory', 'su_cathedral'] },
    miliim: { kits: { ml_rondavel: 5, ml_granary: 2, ml_compound: 2, ml_mudhouse: 3, ml_market: 1, ml_mosque: 0.3, ml_palace: 0.3 }, small: ['ml_rondavel', 'ml_granary'], landmarks: ['ml_mosque', 'ml_market', 'ml_palace'] },
    aerdis: { kits: { ae_cottage: 4, ae_longcottage: 2, ae_pub: 1.2, ae_terrace: 2, ae_chapel: 0.5, ae_roundtower: 0.3, ae_wizard: 0.3 }, small: ['ae_cottage'], landmarks: ['ae_roundtower', 'ae_pub', 'ae_wizard'] },
    copari: { kits: { co_shack: 4, co_tenement: 3, co_mansard: 2.5, co_victorian: 2, co_warehouse: 1.5, co_bauhaus: 0.6, co_colonial: 0.3 }, small: ['co_shack'], landmarks: ['co_colonial', 'co_warehouse', 'co_bauhaus'] } };
  // Nation → style. Every city / capital label in these nations becomes a settlement (map-core adds sites not already in map-elements.json). Cyfrolaef: no buildings.
  const NATION_STYLE = { 'Principality of Buern': 'buern', 'Principality of Vaernebo': 'vaernebo', 'Principality of Rossade': 'rossade', 'Kingdom of Kathaya': 'kathaya', 'Queendom of Aldurstein': 'aldurstein',
    'Isolationist Empire of Zukei': 'zukei', 'Free Cities of Suorr': 'suorr', 'Federation of Miliim': 'miliim', 'Kingdom of Aerdis': 'aerdis', 'Republic of Copari': 'copari' };
  // Building rules: zone weight (inner = within 45 % of the radius), street it may front ('main' = main roads + capital ring only), max per settlement.
  const RULES = {
    dar: { inner: 1, outer: 1.5, front: 'any' }, riad: { inner: 1.3, outer: 0.8, front: 'any' }, tower_house: { inner: 0.7, outer: 1, front: 'any' },
    domed: { inner: 1.2, outer: 0.6, front: 'any' }, hammam: { inner: 1, outer: 0.4, front: 'any', max: 3 }, merchant: { inner: 1.5, outer: 0.5, front: 'main' },
    caravanserai: { inner: 0.2, outer: 1.2, front: 'main', max: 2 }, minaret: { inner: 1, outer: 0.3, front: 'any', max: 2 }, kremlin_tower: { inner: 0.6, outer: 0.6, front: 'main', max: 2 },
    hut: { inner: 0.5, outer: 1.5, front: 'any' }, stall: { inner: 1.5, outer: 0.3, front: 'main' }, stepped_kasbah: { inner: 0.8, outer: 1, front: 'any', max: 3 }, l_house: { inner: 1, outer: 1, front: 'any' },
    round_tower: { inner: 0.6, outer: 0.6, front: 'any', max: 3 }, cathedral: { inner: 1.2, outer: 0.2, front: 'main', max: 1 }, shatyor: { inner: 0.8, outer: 0.3, front: 'any', max: 2 }, windcatcher: { inner: 1, outer: 0.8, front: 'any' } };
  const hash = s => { let h = 2166136261; for (const c of String(s)) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; };
  const rng = seed => { let a = seed; return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; };
Object.assign(RULES, { kt_shack: { inner: 0.5, outer: 1.5, front: 'any' }, kt_falsefront: { inner: 1.5, outer: 0.6, front: 'main' }, kt_saloon: { inner: 1.5, outer: 0.3, front: 'main', max: 2 }, kt_mission: { inner: 1, outer: 0.4, front: 'any', max: 1 },
    kt_watertower: { inner: 0.3, outer: 1, front: 'any', max: 2 }, kt_hacienda: { inner: 0.4, outer: 1.2, front: 'any', max: 3 },
    al_stuga: { inner: 0.6, outer: 1.5, front: 'any' }, al_longhouse: { inner: 0.4, outer: 1.4, front: 'any' }, al_block: { inner: 1.6, outer: 0.4, front: 'main', max: 4 }, al_stave: { inner: 1, outer: 0.5, front: 'any', max: 1 }, al_mosque: { inner: 1.4, outer: 0.2, front: 'any', max: 1 }, al_warehouse: { inner: 0.3, outer: 1.2, front: 'any', max: 3 },
    zk_minka: { inner: 0.4, outer: 1.6, front: 'any' }, zk_shop: { inner: 1.6, outer: 0.4, front: 'main' }, zk_temple: { inner: 1, outer: 0.6, front: 'any', max: 1 }, zk_pagoda: { inner: 1, outer: 0.5, front: 'any', max: 1 }, zk_castle: { inner: 1, outer: 0.2, front: 'any', max: 1 }, zk_torii: { inner: 1, outer: 1, front: 'any', max: 3 }, zk_yagura: { inner: 0.4, outer: 1, front: 'any', max: 2 },
    su_cottage: { inner: 0.5, outer: 1.5, front: 'any' }, su_factory: { inner: 0.2, outer: 1.5, front: 'any', max: 3 }, su_gasholder: { inner: 0.2, outer: 1.2, front: 'any', max: 2 }, su_cathedral: { inner: 1.4, outer: 0.2, front: 'main', max: 1 }, su_clocktower: { inner: 1.5, outer: 0.2, front: 'main', max: 1 },
    ml_rondavel: { inner: 0.6, outer: 1.5, front: 'any' }, ml_granary: { inner: 0.4, outer: 1.2, front: 'any' }, ml_compound: { inner: 0.6, outer: 1.3, front: 'any' }, ml_mosque: { inner: 1.4, outer: 0.2, front: 'any', max: 1 }, ml_palace: { inner: 1.4, outer: 0.2, front: 'any', max: 1 }, ml_market: { inner: 1.5, outer: 0.3, front: 'main', max: 3 },
    ae_cottage: { inner: 0.6, outer: 1.5, front: 'any' }, ae_pub: { inner: 1.4, outer: 0.5, front: 'main', max: 3 }, ae_terrace: { inner: 1.4, outer: 0.5, front: 'any' }, ae_chapel: { inner: 1, outer: 0.5, front: 'any', max: 2 }, ae_roundtower: { inner: 1, outer: 0.4, front: 'any', max: 1 }, ae_wizard: { inner: 0.8, outer: 0.6, front: 'any', max: 1 },
    co_shack: { inner: 0.3, outer: 1.8, front: 'any' }, co_tenement: { inner: 1.4, outer: 0.6, front: 'any' }, co_warehouse: { inner: 0.3, outer: 1.4, front: 'any', max: 3 }, co_bauhaus: { inner: 1.2, outer: 0.5, front: 'main', max: 2 }, co_colonial: { inner: 1.5, outer: 0.2, front: 'main', max: 1 } });
  const DEF_RULE = { inner: 1, outer: 1, front: 'any' }, RU = k => RULES[k] || DEF_RULE;
  // Ruined variant of any kit (SITE.ruin): parts above 45 % of the height drop out (45 %), the rest above 30 % are cut to 55–100 %, tint → dreary grey-mauve, slight lean.
  let ruinN = 0; const ruinTint = h => { const v = h && h[0] === '#' ? [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)) : [200, 196, 200], l = 0.3 * v[0] + 0.59 * v[1] + 0.11 * v[2], c = [106, 94, 102]; return '#' + v.map((q, i) => Math.round(Math.min(255, ((q * 0.4 + l * 0.25) + c[i] * 0.35) * 0.82)).toString(16).padStart(2, '0')).join(''); };
  const ruinify = (k, id) => { if (!k || !k.parts || /^cy_/.test(id) || id === 'station') return k; let sd = (hash(id) + (ruinN++) * 2654435761) >>> 0; const rr = () => { sd = (Math.imul(sd, 1664525) + 1013904223) >>> 0; return sd / 4294967296; };
    let top = 0; for (const p of k.parts) top = Math.max(top, (p.y || 0) + (p.h || 0)); const parts = [];
    for (const p of k.parts) { const y = p.y || 0; if (y > top * 0.45 && rr() < 0.45) continue; const q = { ...p, tint: ruinTint(p.tint), tilt: (p.tilt || 0) + (rr() - 0.5) * 0.08, piv: p.piv || [k.W / 2, 0, (k.D || 0) / 2] }; if (y > top * 0.3 && q.h) q.h *= 0.55 + rr() * 0.45; parts.push(q); }
    return Object.assign({ ...k, parts }, { W: k.W, D: k.D }); };
  const DIRS = [[0, 1], [1, 0], [0, -1], [-1, 0]]; // 0 S · 1 E · 2 N · 3 W (image z grows south)
  const ev = v => (Math.round(v) >> 1) << 1;
  // 2026-10-07: minimum size, train stations, docks.
  //  MIN_BUILD: a settlement is rebuilt with GROW × reach (radius, road lengths, branch chance) until it has ≥ MIN_BUILD buildings (best attempt kept).
  //  STN: a settlement gets the shared station building when a rail station lies within radius × grow × reach of its center, or when any of its cells
  //       (buildings / streets) is within edge px of the track centerline (= 5 px beyond the 8 px rail clearance). Station sits off px beside the track,
  //       city side first, then a street runs to the nearest street. Rail stations no settlement claims get a standalone station.
  //  DOCKS: settlements touching sea / lake (not rivers) of their own nation get docks: count = clamp(round(buildings / per), 1, max[kind]);
  //       capitals first place DOCKS.capital kits (if their style weight > 0); kit weights = kits + styles override; ≥ spacing px apart;
  //       land part = flat own-nation dry land, water part ≥ minWater wet; a street connects each to the nearest street (≤ 60 px).
  const MIN_BUILD = 9, GROW = [1, 1.5, 2.2], STN = { reach: 1.25, edge: 13, off: 5, force: 160 };
  // Per-site overrides: grow = radius multiplier, lv = max terrace span under a lot (default 1; plots flatten), station = always build a track-side station (nearest track within STN.force px).
  const SITE = { Hjalt: { grow: 2, station: true, lv: 2 }, Marrigwani: { grow: 2.4, at: [1246, 1322], station: true, stationName: 'Marida Station', lv: 2 }, Mjwaka: { station: false }, Ninhar: { station: false, at: [2583, 1221], grow: 1.2, lv: 2 },
    // 2026-10-07 coast expansions (docks = dock count override): new sea-level shores / isles were added to the height map around these towns.
    Makaliim: { grow: 1.9, lv: 1, docks: 6, at: [1672, 1170], stnCity: true, noKits: ['ml_palace'] }, Kilm: { grow: 1.0, lv: 2, docks: 5, at: [1162, 1030] }, Kaltam: { at: [3066, 729] }, "Sidara's Edge": { docks: 12, grow: 1.7, lv: 2, at: [2728, 1728] }, "Port Stramtor": { docks: 12, grow: 1.6, lv: 2, at: [3972, 1250] }, Durton: { at: [3401, 703] }, "Ora'Luli": { at: [3715, 885], grow: 2.4, lv: 2 }, Skolot: { grow: 1.6, lv: 2, docks: 4, at: [1665, 667], sub: { lv: 2, docks: 1, station: false } }, Zashnik: { grow: 2, lv: 2, docks: 4, at: [2084, 652] },
    Pannor: { grow: 1.4, docks: 4 }, Vergrur: { grow: 1.7, docks: 3, lv: 2, at: [3200, 856] }, Tanskjol: { grow: 1.6, docks: 3, lv: 2, at: [3304, 928] }, Austyg: { grow: 1.4, lv: 2, docks: 5 },
    // ruin: every kit is ruinified (upper parts knocked off / cut down, dreary tint); addKits / addSmall: extra kits mixed into the style.
    Capria: { ruin: true, addKits: { cy_b04: 0.6, cy_b09: 0.5, cy_b02: 0.4, cy_b24: 0.3, cy_b01: 0.3 }, addSmall: ['cy_s07', 'cy_s14'] }, Panvila: { grow: 1.5, lv: 2, docks: 5 }, Uldescan: { grow: 1.4, docks: 4 }, Cidmolha: { grow: 1.35, docks: 6, at: [2489, 1052] }, Cipex: { at: [2351, 1137], cut: [[2358, 1104], [2369, 1072], [2387, 1064], [2418, 1062], [2426, 1084], [2426, 1118], [2408, 1128], [2379, 1128], [2359, 1120]], sub: { grow: 0.8, station: false } }, Lageira: { station: true, stationAt: [2100, 985] }, 'Castelo Divirio': { station: true, stationAt: [2142, 1099], stationPlot: { x0: 2120, z0: 1094, side: 'E' } } /* 2026-10-08: station west of the Bayoubend branch just NW of Cypress Junction, facing the track (E), not north of the Fenwyn line */ }; // station: true = station at the track point nearest the town centre // station: false = never builds its own station
  //  Docks sit low: the shore cell may be at most maxRise terraces above the lowest land level (g.lvlMin); the dock plot is then flattened DOWN to
  //  the lowest land level (a low quay terrace cut into the coast). Open water only: ≥ open px of water straight out from the shore and water
  //  ±side px either side of the pier tip — rivers (and anything narrower) never get docks; lakes and the continental channel do.
  const DOCKS = { per: 10, max: { city: 2, capital: 3 }, spacing: 34, minWater: 0.7, maxRise: 2, open: 44, side: 12, kits: { dock: 3, harbor: 1, shipyard: 0 }, capital: ['harbor', 'shipyard'],
    styles: { suorr: { shipyard: 1.2 }, copari: { shipyard: 1.2 }, aldurstein: { shipyard: 0.5 }, aerdis: { shipyard: 0.3 }, kathaya: { harbor: 0.6 }, miliim: { harbor: 0.3, dock: 4 } } };
  function stationFit(g, K, ME, stn, cx, cz, nat, tol = 1, off = STN.off, only = null) {
    const { RW, RH } = g, OFF = off;
    const fits = (x0, z0, x1, z1) => { let lo = 1e9, hi = -1e9, n0 = nat;
      for (let z = Math.floor(z0 / 2); z <= Math.ceil(z1 / 2) - 1; z++) for (let x = Math.floor(x0 / 2); x <= Math.ceil(x1 / 2) - 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) return false; const j = z * RW + x;
        if (!g.dry0[j] || g.occ[j] === 1 || g.railHard[j]) return false; if (!n0) n0 = g.nat[j]; if (!n0 || g.nat[j] !== n0) return false; const l = g.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; }
      return hi - lo <= tol; };
    const pts = (g.trackPts || []).filter(p => Math.abs(p[0] - stn.x) < 60 && Math.abs(p[1] - stn.z) < 60).sort((a, b) => Math.hypot(a[0] - stn.x, a[1] - stn.z) - Math.hypot(b[0] - stn.x, b[1] - stn.z));
    for (let i = 0; i < pts.length; i += 2) { const [px, pz, ux, uz] = pts[i], hor = Math.abs(ux) >= Math.abs(uz), sides = hor ? (cz < pz ? ['S', 'N'] : ['N', 'S']) : (cx < px ? ['E', 'W'] : ['W', 'E']);
      for (const side of (only === 'city' ? [sides[0]] : only && hor ? [only] : sides)) { const kit = ME.kit('station', 'buern', null, { side }), fw = kit.W * K, fd = kit.D * K; let x0, z0;
        if (hor) { x0 = ev(px - fw / 2); z0 = side === 'S' ? ev(pz - OFF - fd) : ev(pz + OFF); } else { z0 = ev(pz - fd / 2); x0 = side === 'E' ? ev(px - OFF - fw) : ev(px + OFF); }
        if (!fits(x0, z0, x0 + fw, z0 + fd)) continue;
        return { kit, x0, z0, fw, fd, door: hor ? [x0 + fw / 2, side === 'S' ? z0 - 2 : z0 + fd + 2] : [side === 'E' ? x0 - 2 : x0 + fw + 2, z0 + fd / 2] }; } }
    return null; }
  const gEl = (id, kit, kid, x0, z0, K, settlement) => ({ id, type: 'gen', kit: kid, settlement, L: Object.assign(kit.parts, { W: kit.W }), x: x0 + kit.W * K / 2, y: z0 + kit.D * K, plot: { px: kit.W * K / 2, pb: kit.D * K } });
  // Standalone landmark (temple): nearest spot (ring search ≤ 90 px) where the kit's footprint is own-nation dry land, off rail, ≤ 2 terrace levels; plot flattens.
  function landmark(p, g, ME, K, kid, tag) { const kit = ME.kit(kid, 'buern', rng(hash(p.name))), fw = kit.W * K, fd = kit.D * K, { RW, RH } = g;
    const fits = (x0, z0) => { let lo = 1e9, hi = -1e9, n0 = -1; for (let z = Math.floor(z0 / 2) - 1; z <= Math.ceil((z0 + fd) / 2); z++) for (let x = Math.floor(x0 / 2) - 1; x <= Math.ceil((x0 + fw) / 2); x++) {
      if (x < 0 || z < 0 || x >= RW || z >= RH) return false; const j = z * RW + x; if (!g.dry[j] || g.occ[j] || g.railHard[j]) return false; if (n0 < 0) n0 = g.nat[j]; if (g.nat[j] !== n0) return false; const l = g.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; } return hi - lo <= 2; };
    for (let d = 0; d <= 90; d += 2) for (let dz = -d; dz <= d; dz += 2) for (let dx = -d; dx <= d; dx += 2) { if (Math.max(Math.abs(dx), Math.abs(dz)) !== d) continue; const x0 = ev(p.x + dx - fw / 2), z0 = ev(p.y + dz - fd / 2); if (!fits(x0, z0)) continue;
      for (let z = Math.floor(z0 / 2); z <= Math.ceil((z0 + fd) / 2) - 1; z++) for (let x = Math.floor(x0 / 2); x <= Math.ceil((x0 + fw) / 2) - 1; x++) g.occ[z * RW + x] = 1;
      return gEl(tag, kit, kid, x0, z0, K, null); }
    return null; }
  // Standalone station (rail station with no settlement around it).
  // Tries track-side spots (tolerance 0 → 3 levels, offset 5 → 13 px), then a ring search ≤ 50 px (off rail, ≤ 3 levels) so every named station gets a building.
  // STN_SIDE: per-station overrides — south: build on the south side of the track (cz probe below the track); dx: shift the track-point search (image px).
  const STN_SIDE = { 'Cypress Junction': { south: true, dx: -8, force: true } }; // force: south of the track at the nearest track point, plot flattened (no level tolerance)
  function station(s, g, ME, K) { let sp = null; const so = STN_SIDE[s.name], s2 = so ? { ...s, x: s.x + (so.dx || 0) } : s;
    for (const [tol, off] of (so && so.force ? [] : [[0, STN.off], [2, STN.off], [2, STN.off + 4], [3, STN.off + 8]])) { sp = stationFit(g, K, ME, s2, s2.x, so && so.south ? s.z + 60 : s.z - 1, 0, tol, off, so && so.south ? 'N' : null); if (sp) break; }
    if (!sp && !(so && so.force)) { const kit = ME.kit('station', 'buern', null, { side: 'S' }), fw = kit.W * K, fd = kit.D * K, { RW, RH } = g;
      const ok = (x0, z0) => { let lo = 1e9, hi = -1e9; for (let z = Math.floor(z0 / 2); z <= Math.ceil((z0 + fd) / 2) - 1; z++) for (let x = Math.floor(x0 / 2); x <= Math.ceil((x0 + fw) / 2) - 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) return false; const j = z * RW + x; if (!g.dry0[j] || g.occ[j] || g.railHard[j]) return false; const l = g.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; } return hi - lo <= 3; };
      for (let d = 4; d <= 50 && !sp; d += 2) for (let dz = -d; dz <= d && !sp; dz += 2) for (let dx = -d; dx <= d; dx += 2) { if (Math.max(Math.abs(dx), Math.abs(dz)) !== d) continue; const x0 = ev(s.x + dx - fw / 2), z0 = ev(s.z + dz - fd / 2); if (ok(x0, z0)) { sp = { kit, x0, z0, fw, fd }; break; } } }
    if (!sp && so && so.force && g.trackPts) { const kit = ME.kit('station', 'buern', null, { side: 'N' }), fw = kit.W * K, fd = kit.D * K, { RW, RH } = g;
      const clear = (x0, z0) => { for (let z = Math.floor(z0 / 2); z <= Math.ceil((z0 + fd) / 2) - 1; z++) for (let x = Math.floor(x0 / 2); x <= Math.ceil((x0 + fw) / 2) - 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) return false; const j = z * RW + x; if (!g.dry0[j] || g.occ[j] === 1 || g.railHard[j]) return false; } return true; };
      const tp = g.trackPts.filter(p => Math.hypot(p[0] - s2.x, p[1] - s.z) < 40 && Math.abs(p[2]) >= Math.abs(p[3])).sort((a, b) => Math.hypot(a[0] - s2.x, a[1] - s.z) - Math.hypot(b[0] - s2.x, b[1] - s.z));
      for (const [px, pz] of tp) { for (let off = STN.off; off <= STN.off + 10 && !sp; off += 2) { const x0 = ev(px - fw / 2), z0 = ev(pz + off); if (clear(x0, z0)) sp = { kit, x0, z0, fw, fd, forced: true }; } if (sp) break; } }
    if (!sp) return [];
    if (sp.forced) { const lv = []; for (let z = Math.floor(sp.z0 / 2); z <= Math.ceil((sp.z0 + sp.fd) / 2) - 1; z++) for (let x = Math.floor(sp.x0 / 2); x <= Math.ceil((sp.x0 + sp.fw) / 2) - 1; x++) lv.push(g.lvl[z * g.RW + x]); lv.sort((a, b) => b - a); sp.forcedLvl = lv[0]; }
    for (let z = Math.floor(sp.z0 / 2); z <= Math.ceil((sp.z0 + sp.fd) / 2) - 1; z++) for (let x = Math.floor(sp.x0 / 2); x <= Math.ceil((sp.x0 + sp.fw) / 2) - 1; x++) g.occ[z * g.RW + x] = 1;
    return [{ ...gEl('stn_' + s.name.replace(/\W+/g, '_'), sp.kit, 'station', sp.x0, sp.z0, K, null), stationName: s.name }]; }
  // Sub-sites (ISLE_SITES): extra layout centres of an existing town on its offshore isles (same name / style; own small layout; SITE[name].sub overrides).
  const ISLE_SITES = { Skolot: [[1702, 536], [1641, 560], [1586, 556]], Cipex: [[2322, 1118]] }; // Cipex: NW quarter around the Temple of the Drunkard
  const SO = s => s.sub ? ((SITE[s.name] || {}).sub || {}) : SITE[s.name];
  // SITE.cut = image-px polygon the town may not build in (cells blocked with occ 3 while it generates, then released).
  const inPoly = (P, x, z) => { let c = false; for (let i = 0, j = P.length - 1; i < P.length; j = i++) { const [xi, zi] = P[i], [xj, zj] = P[j]; if ((zi > z) !== (zj > z) && x < (xj - xi) * (z - zi) / (zj - zi) + xi) c = !c; } return c; };
  function generate(site, g, ME, K) { const __g0 = performance.now(), cut = !site.sub && (SITE[site.name] || {}).cut, mk = [];
    if (cut) { let x0 = 1e9, z0 = 1e9, x1 = -1e9, z1 = -1e9; for (const [x, z] of cut) { x0 = Math.min(x0, x); z0 = Math.min(z0, z); x1 = Math.max(x1, x); z1 = Math.max(z1, z); }
      for (let z = z0 >> 1; z <= z1 >> 1; z++) for (let x = x0 >> 1; x <= x1 >> 1; x++) { const j = z * g.RW + x; if (!g.occ[j] && inPoly(cut, x * 2 + 1, z * 2 + 1)) { g.occ[j] = 3; mk.push(j); } } }
    try { return generate0(site, g, ME, K); } finally { for (const j of mk) if (g.occ[j] === 3) g.occ[j] = 0; const PS = root.MercSettlements.perSite = root.MercSettlements.perSite || {}; PS[site.name] = Math.round(performance.now() - __g0); } }
  function generate0(site, g, ME, K) { if ((SO(site) || {}).at) site = { ...site, x: SO(site).at[0], y: SO(site).at[1] }; // SITE.at = layout centre override (image px)
    const T0 = TIERS[site.kind] || TIERS.city, B = Math.ceil(T0.radius * 1.6 * GROW[GROW.length - 1] + 90), RW = g.RW;
    const bx0 = Math.max(0, (site.x - B) >> 1), bx1 = Math.min(RW - 1, (site.x + B) >> 1), bz0 = Math.max(0, (site.y - B) >> 1), bz1 = Math.min(g.RH - 1, (site.y + B) >> 1), bw = bx1 - bx0 + 1;
    const snap = () => { const n = bw * (bz1 - bz0 + 1), o = new Uint8Array(n), p = new Uint8Array(n); for (let z = bz0, k = 0; z <= bz1; z++, k += bw) { const a = z * RW + bx0; o.set(g.occ.subarray(a, a + bw), k); p.set(g.paint.subarray(a, a + bw), k); } return [o, p]; };
    const restore = s => { for (let z = bz0, k = 0; z <= bz1; z++, k += bw) { const a = z * RW + bx0; g.occ.set(s[0].subarray(k, k + bw), a); g.paint.set(s[1].subarray(k, k + bw), a); } };
    const s0 = snap(), OV = SO(site) || {};
    const findStn = (out, grow) => { if (out.cx == null || OV.station === false) return null; const R0 = T0.radius * grow * STN.reach; let s = null, d = 1e9;
      // Named rail stations are never claimed: they stand alone at their own label (see station()).
      // SITE.stationName: the town claims that named station (built at its rail point, town streets connect to it; no standalone copy).
      if (OV.stationAt) return { x: OV.stationAt[0], z: OV.stationAt[1], name: null }; // explicit track point (image px)
      if (OV.stationName && g.stations) { const ns = g.stations.find(q => q.name === OV.stationName); if (ns) return { x: ns.x, z: ns.z, name: ns.name }; }
      if (OV.station && g.trackPts) { let bp = null, bd = STN.force; for (const p of g.trackPts) { const dd = Math.hypot(p[0] - out.cx, p[1] - out.cz); if (dd < bd) { bd = dd; bp = p; } } if (bp) return { x: bp[0], z: bp[1], name: null }; }
      if (!g.near13) return null; let hx = -1, hz = -1;
      for (let z = bz0, k = 0; z <= bz1 && hx < 0; z++, k += bw) for (let x = bx0; x <= bx1; x++) { const j = z * RW + x; if (g.occ[j] && g.near13[j] && g.occ[j] !== s0[0][k + x - bx0]) { hx = x * 2; hz = z * 2; break; } }
      if (hx < 0) return null; let bp = null, bd = 1e9; for (const p of g.trackPts) { const dd = Math.hypot(p[0] - out.cx, p[1] - out.cz); if (dd < bd && Math.hypot(p[0] - hx, p[1] - hz) < 60) { bd = dd; bp = p; } }
      return bp ? { x: bp[0], z: bp[1], name: null } : null; };
    let best = null, stn = null, last = null;
    for (let a = 0; a < GROW.length; a++) { if (a) restore(s0);
      const gk = GROW[a] * (OV.grow || 1); last = build(site, g, ME, K, gk, stn);
      if (!stn) { stn = findStn(last, gk); if (stn) { restore(s0); last = build(site, g, ME, K, gk, stn); } }
      if (!best || last.length > best.n) best = { n: last.length, a }; if (last.length >= MIN_BUILD) return last; }
    if (best.a === GROW.length - 1) return last; restore(s0); return build(site, g, ME, K, GROW[best.a] * (OV.grow || 1), stn); }
  function build(site, g, ME0, K, grow, stn) { let __pt = performance.now(); const PF = root.MercSettlements.prof = root.MercSettlements.prof || {}, MK = k => { const n = performance.now(); PF[k] = (PF[k] || 0) + n - __pt; __pt = n; }; PF.builds = (PF.builds || 0) + 1; const OVb = SO(site) || {}, ME = OVb.ruin ? { ...ME0, kit: (id, sty, rr, o) => ruinify(ME0.kit(id, sty, rr, o), id) } : ME0;
    const LV = (SO(site) || {}).lv || 1, T0 = TIERS[site.kind] || TIERS.city, r = rng((hash(site.id || site.name) + Math.round(grow * 7919)) >>> 0), st = (S1 => OVb.noKits ? { ...S1, kits: Object.fromEntries(Object.entries(S1.kits).filter(([k]) => !OVb.noKits.includes(k))), landmarks: (S1.landmarks || []).filter(k => !OVb.noKits.includes(k)) } : S1)((S0 => OVb.addKits ? { ...S0, kits: { ...S0.kits, ...OVb.addKits }, small: [...(S0.small || SMALL), ...(OVb.addSmall || [])] } : S0)(STYLES[site.style] || STYLES.buern)), /* noKits: kits this town never builds (e.g. Makaliim's palace → its citadel landmark) */ out = [], roads = [];
    const tier = grow === 1 ? T0 : { ...T0, radius: T0.radius * grow, roadLen: T0.roadLen.map(v => v * grow), branchLen: T0.branchLen.map(v => v * Math.sqrt(grow)), roads: [Math.min(4, T0.roads[0] + 1), 4],
      branchP: T0.branchP.map(p => Math.min(0.85, p + 0.15)), buildings: T0.buildings.map(v => Math.max(v, MIN_BUILD + 3)), infill: Math.round(T0.infill * grow) };
    const { RW, RH } = g, C = (x, z) => { const cx = x >> 1, cz = z >> 1; return cx < 0 || cz < 0 || cx >= RW || cz >= RH ? -1 : cz * RW + cx; };
    const R = (a, b) => a + r() * (b - a), RI = (a, b) => Math.floor(R(a, b + 1));
    let nat = 0; for (let d = 0; d <= 12 && !nat; d += 2) for (let dz = -d; dz <= d && !nat; dz += 2) for (let dx = -d; dx <= d; dx += 2) { const j = C(site.x + dx, site.y + dz); if (j >= 0 && g.nat[j]) { nat = g.nat[j]; break; } }
    if (!nat) return out;
    const land = j => j >= 0 && g.dry[j] && g.nat[j] === nat;
    const cellsOf = (x0, z0, x1, z1, m, f) => { const a = Math.floor(x0 / 2) - m, b = Math.ceil(x1 / 2) - 1 + m, c = Math.floor(z0 / 2) - m, d = Math.ceil(z1 / 2) - 1 + m;
      for (let cz = c; cz <= d; cz++) for (let cx = a; cx <= b; cx++) f(cx < 0 || cz < 0 || cx >= RW || cz >= RH ? -1 : cz * RW + cx, cx >= a + m && cx <= b - m && cz >= c + m && cz <= d - m); };
    let why = ''; const rectOk = (x0, z0, x1, z1, maxLv, m = 1) => { let ok = true, lo = 1e9, hi = -1e9; why = ''; cellsOf(x0, z0, x1, z1, m, (j, inner) => { if (!ok) return;
        if (inner) { if (!land(j)) { ok = false; why = j < 0 ? 'edge' : !g.dry[j] ? 'wet/rail' : 'nation'; return; } if (g.occ[j]) { ok = false; why = g.occ[j] === 2 ? 'street' : 'occupied'; return; } const l = g.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; } else if (j >= 0 && g.occ[j] === 1) { ok = false; why = 'margin'; } });
      if (ok && hi - lo > maxLv) { why = 'levels'; return false; } return ok; };
    const stats = {}; // gap-fill rejection reasons (MercSettlements.stats[name])
    const mark = (x0, z0, x1, z1, v, paint) => cellsOf(x0, z0, x1, z1, 0, j => { if (j < 0) return; if (v != null) g.occ[j] = v; if (paint) g.paint[j] = paint; });
    const STREET = g.code(site.style, 'street'), PLAZA = g.code(site.style, 'plaza');
    const add = (kit, id, x0, z0) => { const fw = kit.W * K, fd = kit.D * K; mark(x0, z0, x0 + fw, z0 + fd, 1);
      out.push({ id: site.id + '_' + out.length, type: 'gen', kit: id, settlement: site.id, L: Object.assign(kit.parts, { W: kit.W }), x: x0 + fw / 2, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); };
    let cur = null; const roadCell = (x, z) => { const j = C(x, z); if (land(j) && g.occ[j] !== 1) { if (cur && g.occ[j] !== 2) cur.cells.push([j, cur.pts.length]); g.occ[j] = 2; g.paint[j] = STREET; return true; } return false; };
    let ox = ev(site.x), oz = ev(site.y);
    // Neighbor repulsion (site.nbrs = [[x, y, name]] image px; other settlements + labelled points within 3 × radius).
    //  A = away vector = Σ unit(site − n) · radius / dist(site, n); |A| capped at 1 (strength).
    //  away(dx, dz) = cos(angle between (dx, dz) and A) · strength, −1..1.
    //  Per-direction reach: rLim = radius · (1 + 0.6 · away) → up to 1.6× away from neighbors, down to 0.4× toward them.
    //  Fair share: a street / building cell must be ≥ GAP px closer to its own center than to any neighbor (weighted Voronoi with a buffer).
    //  Main roads: lengths × (1 + 0.5 · away(dir)); cities pick their 2–4 road directions by away(dir) + noise; bends turn toward the away side 75 % of the time.
    const GAP = 16, NB = (site.nbrs || []).filter(p => (grow < 2 || p[3]) && Math.hypot(p[0] - site.x, p[1] - site.y) < tier.radius * 3); // last growth step ignores plain POI pins
    let ax = 0, az = 0; for (const [nx, nz] of NB) { const dx = site.x - nx, dz = site.y - nz, dd = Math.hypot(dx, dz) || 1; ax += dx / dd * tier.radius / dd; az += dz / dd * tier.radius / dd; }
    const am = Math.hypot(ax, az), AX = am ? ax / am : 0, AZ = am ? az / am : 0, AS = Math.min(1, am);
    const away = (dx, dz) => { const dd = Math.hypot(dx, dz); return dd ? (dx * AX + dz * AZ) / dd * AS : 0; };
    const rLim = (x, z) => tier.radius * (1 + 0.6 * away(x - ox, z - oz));
    const fair = (x, z, gap = GAP) => { const d0 = Math.hypot(x - ox, z - oz); for (const [nx, nz] of NB) if (Math.hypot(x - nx, z - nz) - d0 < gap) return false; return true; };
    const fairRect = (x0, z0, x1, z1, gap) => fair(x0, z0, gap) && fair(x1, z0, gap) && fair(x0, z1, gap) && fair(x1, z1, gap);
    const trace = (x, z, d, len, main, parent, pIdx) => { const pts = [], rd = { pts, main, w: main ? 4 : 2, cells: [], used: -1, need: -1, parent, pIdx }; cur = rd; let [dx, dz] = DIRS[d], lt = 0, pl = null; x = ev(x); z = ev(z);
      for (let s = 0; s < len / 2; s++) { const j = C(x, z); if (!land(j) || g.occ[j] === 1 || Math.hypot(x - ox, z - oz) > rLim(x, z) || !fair(x, z)) break;
        const lv = g.lvl[j]; if (pl != null && Math.abs(lv - pl) > 1) break; pl = lv;
        roadCell(x, z); if (main) roadCell(x + (dx === 0 ? 2 : 0), z + (dz === 0 ? 2 : 0)); pts.push([x, z, d]); x += dx * 2; z += dz * 2;
        if (s - lt > 4 && r() < tier.turn) { const L1 = (d + 1) % 4, L3 = (d + 3) % 4, b1 = away(...DIRS[L1]) >= away(...DIRS[L3]); d = (r() < 0.75) === b1 ? L1 : L3; [dx, dz] = DIRS[d]; lt = s; } }
      cur = null; if (pts.length > 2) roads.push(rd); else for (const [j] of rd.cells) { g.occ[j] = 0; g.paint[j] = 0; } };
    const spiral = (fn, max, step) => { for (let d = 0; d <= max; d += step) for (let dz = -d; dz <= d; dz += step) for (let dx = -d; dx <= d; dx += step) { if (Math.max(Math.abs(dx), Math.abs(dz)) !== d) continue; if (fn(ev(site.x + dx), ev(site.y + dz))) return true; } return false; };
    let starts = [];
    MK('neighbors');
    // Capital: walled core (one flattened pad) + ring road + 4 main roads (gate south, west, east, north).
    const core = tier.core && ME.core && spiral((x, z) => { const k = ME.core(site.style, r), fw = k.W * K, fd = k.D * K, x0 = ev(x - fw / 2), z0 = ev(z - fd / 2);
      if (!rectOk(x0 - 6, z0 - 6, x0 + fw + 6, z0 + fd + 6, 3)) return false;
      mark(x0 + 2 * K, z0 + 2 * K, x0 + fw - 2 * K, z0 + fd - 2 * K, null, PLAZA); add(k, 'walled_core', x0, z0); ox = x; oz = z;
      const X0 = ev(x0 - 4), Z0 = ev(z0 - 4), X1 = ev(x0 + fw + 2), Z1 = ev(z0 + fd + 2), side = (pts) => roads.push({ pts, main: true, w: 2, ring: true, cells: [], used: -1, need: -1 });
      const top = [], bot = [], lef = [], rig = []; for (let xx = X0; xx <= X1; xx += 2) { if (roadCell(xx, Z0)) top.push([xx, Z0, 1]); if (roadCell(xx, Z1)) bot.push([xx, Z1, 1]); }
      for (let zz = Z0; zz <= Z1; zz += 2) { if (roadCell(X0, zz)) lef.push([X0, zz, 0]); if (roadCell(X1, zz)) rig.push([X1, zz, 0]); } [bot, lef, rig, top].forEach(side);
      starts = [[x0 + k.gate * K - 2, Z1 + 2, 0], [X0 - 2, z, 3], [X1 + 2, z, 1], [x, Z0 - 2, 2]]; return true; }, 60, 4);
    if (!core) { const pl = (tier.plaza || 3) * 2;
      if (!spiral((x, z) => { if (!rectOk(x - pl, z - pl, x + pl + 2, z + pl + 2, 1)) return false; mark(x - pl, z - pl, x + pl + 2, z + pl + 2, 2, PLAZA); ox = x; oz = z; return true; }, Math.round(40 * grow), 2)) return out;
      starts = [[ox, oz + pl + 2, 0], [ox + pl + 2, oz, 1], [ox, oz - pl - 2, 2], [ox - pl - 2, oz, 3]];
      starts = starts.map(st => [st, away(...DIRS[st[2]]) + r() * 0.8]).sort((a, b) => b[1] - a[1]).map(a => a[0]).slice(0, RI(...tier.roads)); }
    // Train station first (main roads route around it); its street is added after the alleys.
    let stEl = null; if (stn) { const sc = (SO(site) || {}).stnCity, SPx = (SO(site) || {}).stationPlot, sp = SPx ? (() => { const kit = ME.kit('station', 'buern', null, { side: SPx.side }), fw = kit.W * K, fd = kit.D * K; const x0 = ev(SPx.x0), z0 = ev(SPx.z0), hor = SPx.side === 'N' || SPx.side === 'S'; return { kit, x0, z0, fw, fd, door: hor ? [x0 + fw / 2, SPx.side === 'S' ? z0 - 2 : z0 + fd + 2] : [SPx.side === 'E' ? x0 - 2 : x0 + fw + 2, z0 + fd / 2] }; })() /* SITE.stationPlot: exact plot (x0, z0 = NW corner, image px) + side the platform faces */ : sc ? (stationFit(g, K, ME, stn, ox, oz, nat, 1, STN.off, 'city') || stationFit(g, K, ME, stn, ox, oz, nat, 3, STN.off, 'city') || stationFit(g, K, ME, stn, ox, oz, nat, 4, STN.off + 4, 'city')) : (stationFit(g, K, ME, stn, ox, oz, nat) || stationFit(g, K, ME, stn, ox, oz, nat, 3)); /* SITE.stnCity: town side of the track only, tight to it */ if (sp) { add(sp.kit, 'station', sp.x0, sp.z0); out[out.length - 1].stationName = stn.name; stEl = sp; } }
    // Street from (sx, sz) to the nearest existing street (BFS over own dry land, ≤ maxPx); added as a kept main road so lots can front it.
    const connect = (sx, sz, maxPx) => { const s = C(ev(sx), ev(sz)); if (s < 0 || !land(s) || g.occ[s]) return false; const prev = new Map([[s, [-1, 0]]]), q = [s], lim = (maxPx / 2) | 0; let hit = -1;
      for (let h = 0; h < q.length && hit < 0; h++) { const j = q[h], dpt = prev.get(j)[1]; if (dpt >= lim) continue;
        for (const n of [j + RW, j + 1, j - RW, j - 1]) { if (n < 0 || n >= RW * RH || prev.has(n) || !land(n) || g.occ[n] === 1) continue; prev.set(n, [j, dpt + 1]); if (g.occ[n] === 2) { hit = n; break; } q.push(n); } }
      if (hit < 0) return false; const path = []; for (let k = prev.get(hit)[0]; k >= 0; k = prev.get(k)[0]) path.push(k); path.reverse();
      const pts = path.map((k, i) => { const nx = i + 1 < path.length ? path[i + 1] : hit, dd = nx - k, d = dd === RW ? 0 : dd === 1 ? 1 : dd === -RW ? 2 : 3; g.occ[k] = 2; g.paint[k] = STREET; return [(k % RW) * 2, ((k / RW) | 0) * 2, d]; });
      if (pts.length) roads.push({ pts, main: true, w: 2, ring: true, cells: [], used: -1, need: -1 }); return true; };
    for (const [x, z, d] of starts) trace(x, z, d, R(...tier.roadLen) * (1 + 0.5 * away(...DIRS[d])), true);
    MK('core+stn');
    // Alleys: perpendicular branches off main roads, then a sparser second level off the alleys.
    const branch = (list, p, lenK) => { for (const rd of list) { let next = RI(...tier.branchEvery) / 2; for (let i = 0; i < rd.pts.length; i++) { if (i < next) continue; next = i + RI(...tier.branchEvery) / 2;
        const [x, z, d] = rd.pts[i]; for (const sd of [1, 3]) if (r() < p) { const nd = (d + sd) % 4, [ddx, ddz] = DIRS[nd], off = nd <= 1 ? rd.w : 2; trace(x + ddx * off, z + ddz * off, nd, R(...tier.branchLen) * lenK, false, rd, i); } } } };
    const mains = roads.slice(); branch(mains, tier.branchP[0], 1); branch(roads.slice(mains.length), tier.branchP[1], 0.6);
    if (stEl) connect(stEl.door[0], stEl.door[1], 160);
    MK('alleys');
    // Lots: walk every street, both sides; landmarks first, then weighted picks by zone + street type + style.
    const target = RI(...tier.buildings), count = {}; let placed = 0, lm = 0, lmTry = 0, back = 0;
    const choose = (zone, main) => { const ks = Object.keys(st.kits).filter(k => { const ru = RU(k); return ru && (ru.front !== 'main' || main) && !(ru.max && (count[k] || 0) >= ru.max); });
      let tot = 0; const acc = ks.map(k => (tot += st.kits[k] * RU(k)[zone], tot)), v = r() * tot; return ks[acc.findIndex(a => a >= v)]; };
    const pickSmall = main => { const ks = (st.small || SMALL).filter(k => (st.kits[k] || 0) > 0 && (RU(k).front !== 'main' || main)); let tot = 0; const acc = ks.map(k => (tot += st.kits[k], tot)), v = r() * tot; return ks[acc.findIndex(a => a >= v)]; };
    // lots(rd, small, fill): fill = gap pass — no count cap, whole street, tries a weighted kit then two small ones at 5 positions, ≤ LV + 1 terrace levels.
    const lots = (rd, small, fill, relax) => { const nextI = [0, 0], cap = fill ? 1e9 : small ? target + tier.infill : target, lim = rd.pts.length;
      for (let i = 0; i < lim && placed < cap; i++) { const [x, z, d] = rd.pts[i], zone = Math.hypot(x - ox, z - oz) / tier.radius < 0.45 ? 'inner' : 'outer';
        for (let s = 0; s < 2 && placed < cap; s++) { if (i < nextI[s]) continue; const isLm = !small && !fill && rd.main && lm < tier.landmarks && lmTry < 12;
          const ids = fill ? [choose(zone, rd.main), pickSmall(rd.main), pickSmall(rd.main)] : [small ? pickSmall(rd.main) : isLm ? st.landmarks[lm] : choose(zone, rd.main)]; if (isLm) lmTry++;
          for (const id of ids) { if (!id) continue; const kit = ME.kit(id, site.style, r), fw = kit.W * K, fd = kit.D * K; let x0, z0, ok = false;
            // Gap fill also slides the lot ±2 / ±4 px along the street and allows one more terrace level (plot is flattened later).
            // Relaxed passes (Flykst diagnosis 2026-10-07: most gap-fill lots failed on 'street' / 'margin' / 'fair'): flush setback (sb 0) allowed, buildings may touch
            // (no 1-cell margin), neighbour buffer GAP / 4.
            outer: for (const sb of relax ? [1, 0] : [1]) for (const sh of fill ? [0, 2, -2, 4, -4] : [0]) { if (d === 0 || d === 2) { x0 = s ? x + rd.w + sb : x - sb - fw; z0 = (d === 0 ? z : z - fd) + sh; } else { z0 = s ? z + rd.w + sb : z - sb - fd; x0 = (d === 1 ? x : x - fw) + sh; }
              if (!fairRect(x0, z0, x0 + fw, z0 + fd, relax ? GAP / 4 : GAP)) { if (fill) stats.fair = (stats.fair || 0) + 1; continue; } if (rectOk(x0, z0, x0 + fw, z0 + fd, fill ? LV + 1 : LV, relax ? 0 : 1)) { ok = true; break outer; } if (fill) stats[why] = (stats[why] || 0) + 1; }
            if (fill) stats.tries = (stats.tries || 0) + 1, ok && (stats.placed = (stats.placed || 0) + 1);
            if (!ok) continue;
            add(kit, id, x0, z0); placed++; rd.used = Math.max(rd.used, i); count[id] = (count[id] || 0) + 1; if (isLm) { lm++; lmTry = 0; }
            nextI[s] = i + Math.ceil(((d === 0 || d === 2 ? fd : fw) + 1) / 2);
            // Back row: a small building directly behind (away from the street), 1-cell gap.
            if (r() < (tier.backP || 0)) { const bid = pickSmall(false); if (bid) { const bk = ME.kit(bid, site.style, r), bw = bk.W * K, bd = bk.D * K; let bx, bz;
              if (d === 0 || d === 2) { bx = s ? x0 + fw + 2 : x0 - 2 - bw; bz = z0; } else { bz = s ? z0 + fd + 2 : z0 - 2 - bd; bx = x0; }
              if (fairRect(bx, bz, bx + bw, bz + bd) && rectOk(bx, bz, bx + bw, bz + bd, LV)) { add(bk, bid, bx, bz); back++; count[bid] = (count[bid] || 0) + 1; } } }
            break; } } } };
    MK('lots');
    // Docks (see DOCKS): coast candidates = own dry land cells with sea / lake in a cardinal direction, inside reach, nearest the center first.
    { const cand = [], RR = tier.radius * 1.15, c0x = Math.max(1, (ox - RR) >> 1), c1x = Math.min(RW - 2, (ox + RR) >> 1), c0z = Math.max(1, (oz - RR) >> 1), c1z = Math.min(RH - 2, (oz + RR) >> 1);
      if (g.wet) for (let cz = c0z; cz <= c1z; cz++) for (let cx = c0x; cx <= c1x; cx++) { const j = cz * RW + cx; if (!land(j) || g.occ[j] === 1) continue; const x = cx * 2 + 1, z = cz * 2 + 1, dd = Math.hypot(x - ox, z - oz);
        if (dd > rLim(x, z) * 1.15 || !fair(x, z) || g.lvl[j] > (g.lvlMin || 0) + DOCKS.maxRise) continue;
        DIRS.forEach(([dx, dz], d) => { const o = dz * RW + dx; if (!g.wet[j + o]) return; let k = 0, n = j; while (k < 40) { n += o; if (n < 0 || n >= RW * RH || !g.wet[n]) break; k++; } if (k * 2 < DOCKS.open) return;
          const tip = j + o * Math.round(DOCKS.open / 4), sd = Math.round(DOCKS.side / 2), lat = dx ? RW : 1; if (!g.wet[tip + lat * sd] || !g.wet[tip - lat * sd]) return;
          cand.push([cx, cz, d, dd + (g.lvl[j] - (g.lvlMin || 0)) * 40]); }); }
      if (cand.length) { cand.sort((a, b) => a[3] - b[3]); const ds = { ...DOCKS.kits, ...(DOCKS.styles[site.style] || {}) }, ovD = (SO(site) || {}).docks, want = ovD || Math.min(DOCKS.max[site.kind] || 2, Math.max(1, Math.round(target / DOCKS.per)));
        const list = site.kind === 'capital' ? DOCKS.capital.filter(k => (ds[k] || 0) > 0) : [];
        while (list.length < want) { const ks = Object.keys(ds).filter(k => ds[k] > 0); let tot = 0; const acc = ks.map(k => (tot += ds[k], tot)), v = r() * tot; list.push(ks[acc.findIndex(a => a >= v)]); }
        // Land part: no buildings / streets inside (none in a 1-cell margin), ≥ 75 % own dry land (the rest may be sea / lake), land spans ≤ 2 terrace levels.
        const shoreOk = (x0, z0, x1, z1) => { let n = 0, l = 0, lo = 1e9, hi = -1e9, bad = false; cellsOf(x0, z0, x1, z1, 1, (j, inner) => { if (bad) return; if (j < 0) { bad = inner; return; }
            if (!inner) { if (g.occ[j] === 1) bad = true; return; } n++; if (g.occ[j]) { bad = true; return; } if (land(j)) { l++; const v = g.lvl[j]; if (v < lo) lo = v; if (v > hi) hi = v; } else if (!g.wet[j]) bad = true; });
          return !bad && n && l / n >= 0.75 && hi - lo <= 1 && hi <= (g.lvlMin || 0) + 2; }; // whole land part already low (≤ 1 terrace above the lowest land) → no notch cut into cliffs
        const done = [], wetOk = (x0, z0, x1, z1) => { let n = 0, w = 0, bad = false; cellsOf(x0, z0, x1, z1, 0, j => { n++; if (j < 0) return; if (g.wet[j]) w++; if (g.occ[j] === 1) bad = true; }); return !bad && n && w / n >= DOCKS.minWater; };
        for (const id of list.slice(0, Math.max(want, list.length))) for (let ci = 0; ci < cand.length && ci < 1500; ci++) { const [cx, cz, d] = cand[ci], dir = 'SENW'[d];
          if (done.some(p => Math.hypot(p[0] - cx * 2, p[1] - cz * 2) < DOCKS.spacing)) continue;
          const kit = ME.kit(id, site.style, r, { dir, style: site.style }), fw = kit.W * K, fd = kit.D * K, DL = kit.Dl * K, LP = kit.Lp * K; let x0, z0, L, Wr, door;
          if (dir === 'S') { const zs = (cz + 1) * 2; x0 = ev(cx * 2 + 1 - fw / 2); z0 = zs - DL; L = [x0, z0, x0 + fw, zs]; Wr = [x0, zs, x0 + fw, zs + LP]; door = [x0 + fw / 2, z0 - 2]; }
          else if (dir === 'N') { const zs = cz * 2; x0 = ev(cx * 2 + 1 - fw / 2); z0 = zs - LP; L = [x0, zs, x0 + fw, zs + DL]; Wr = [x0, z0, x0 + fw, zs]; door = [x0 + fw / 2, zs + DL + 2]; }
          else if (dir === 'E') { const xs = (cx + 1) * 2; z0 = ev(cz * 2 + 1 - fd / 2); x0 = xs - DL; L = [x0, z0, xs, z0 + fd]; Wr = [xs, z0, xs + LP, z0 + fd]; door = [x0 - 2, z0 + fd / 2]; }
          else { const xs = cx * 2; z0 = ev(cz * 2 + 1 - fd / 2); x0 = xs - LP; L = [xs, z0, xs + DL, z0 + fd]; Wr = [x0, z0, xs, z0 + fd]; door = [xs + DL + 2, z0 + fd / 2]; }
          if (!fairRect(...L) || !shoreOk(...L) || !wetOk(...Wr)) continue;
          add(kit, id, x0, z0); out[out.length - 1].dock = dir; out[out.length - 1].low = true; done.push([cx * 2, cz * 2]); connect(door[0], door[1], 60); break; } } }
    roads.forEach(rd => lots(rd, false));
    MK('docks');
    // Infill: small kits (hut 3×3, stall, dar) only along streets that already front a building.
    roads.filter(rd => rd.used >= 0).forEach(rd => lots(rd, true));
    MK('infill');
    // Gap fill (2026-10-07f): every street along its whole length (built or not) gets lots wherever room remains, 3 passes; tries a weighted kit then 2 small ones,
    // each at 5 positions along the street → no empty frontage. Streets that still front nothing are pruned below.
    for (let k = 0; k < 3; k++) roads.forEach(rd => lots(rd, false, true, k > 0));
    MK('gapfill');
    // Prune streets: each keeps up to 1 step past its last fronting building (or to its furthest kept branch); streets with neither are removed.
    // Children are processed before parents so a kept alley keeps its parent connected. Ring roads (capital) always stay.
    for (let k = roads.length - 1; k >= 0; k--) { const rd = roads[k]; rd.keep = rd.ring ? 1e9 : Math.max(rd.used >= 0 ? rd.used + 1 : -1, rd.need);
      if (rd.keep >= 0 && rd.parent) rd.parent.need = Math.max(rd.parent.need, rd.pIdx); }
    for (const rd of roads) for (const [j, i] of rd.cells) if (i > rd.keep && g.occ[j] === 2) { g.occ[j] = 0; g.paint[j] = 0; }
    for (const rd of roads) for (const [j, i] of rd.cells) if (i <= rd.keep) { g.occ[j] = 2; g.paint[j] = STREET; }
    MK('prune');
    // Pack fill (2026-10-07i). Diagnosis (Rausa / Flykst / Mjwaka / Makaliini): lots are only tried at one fixed setback facing one street, and in the dense
    // alley grid almost every lot rect overlaps the NEXT street (rejects: street ≈ 147k, occupied ≈ 41k vs ≈ 40 placed per town), so block interiors, corners
    // and the land between parallel alleys stay empty even though ~45 % of the free cells are ≤ 2 cells from a street and flat.
    // Fix: after pruning, scan every free own-land cell within reach (2 px lattice, 2 passes); try the style's kits largest → smallest with the cell as any of
    // the 4 corners; accept when the footprint is free land (1-cell gap to other buildings, streets may touch, ≤ LV + 1 levels), fair (GAP / 4) and ≤ 2 cells from a kept street.
    if ((SO(site) || {}).pack !== false) { const ids = [...new Set([...Object.keys(st.kits).filter(k => (st.kits[k] || 0) > 0 && RU(k)), ...(st.small || SMALL).filter(k => (st.kits[k] || 0) > 0)])];
      const KD = ids.map(id => { const k = ME.kit(id, site.style, r); return { id, w: k.W * K, d: k.D * K, max: RU(k).max }; }).sort((p, q) => q.w * q.d - p.w * p.d);
      let NS = 2; const nearSt = (x0, z0, x1, z1) => { let hit = false; cellsOf(x0, z0, x1, z1, NS, (j, inner) => { if (!hit && !inner && j >= 0 && g.occ[j] === 2) hit = true; }); return hit; };
      const RR = tier.radius * 1.6; let packed = 0; const CORN = [[0, 0], [1, 0], [0, 1], [1, 1]], minW = Math.min(...KD.map(k => k.w)), minD = Math.min(...KD.map(k => k.d));
      // Street distance (perf 2026-10-07): Chebyshev cell distance to the nearest kept street over the scan window; a cell farther than the reach
      // (NS + largest kit side + 1) can't host a lot that is ≤ NS cells from a street → skipped before any rect test.
      const wx0 = Math.max(0, (ev(ox - RR) >> 1) - 2), wz0 = Math.max(0, (ev(oz - RR) >> 1) - 2), wx1 = Math.min(RW - 1, ((ox + RR) >> 1) + 2), wz1 = Math.min(g.RH - 1, ((oz + RR) >> 1) + 2), WW = wx1 - wx0 + 1, WH = wz1 - wz0 + 1;
      const SD = new Uint8Array(WW * WH).fill(255), sq = new Int32Array(WW * WH); let sh = 0, stl = 0;
      for (let zz = 0; zz < WH; zz++) for (let xx = 0; xx < WW; xx++) if (g.occ[(wz0 + zz) * RW + wx0 + xx] === 2) { SD[zz * WW + xx] = 0; sq[stl++] = zz * WW + xx; }
      while (sh < stl) { const k = sq[sh++], xx = k % WW, zz = (k / WW) | 0, d = SD[k] + 1; if (d > 60) continue; for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const nx = xx + dx, nz = zz + dz; if (nx < 0 || nz < 0 || nx >= WW || nz >= WH) continue; const n = nz * WW + nx; if (SD[n] > d) { SD[n] = d; sq[stl++] = n; } } }
      const maxSide = Math.ceil(Math.max(...KD.map(k => Math.max(k.w, k.d))) / 2) + 1;
      for (let pass = 0; pass < 3; pass++) { NS = pass < 2 ? 2 : 5; const reach = NS + maxSide + 1; for (let z = ev(oz - RR); z <= oz + RR; z += 2) for (let x = ev(ox - RR); x <= ox + RR; x += 2) { const cx = (x >> 1) - wx0, cz = (z >> 1) - wz0; if (cx < 0 || cz < 0 || cx >= WW || cz >= WH || SD[cz * WW + cx] > reach) continue; if (Math.hypot(x - ox, z - oz) > rLim(x, z) * 1.1) continue; const j = C(x, z); if (!land(j) || g.occ[j]) continue;
        // Prune (perf 2026-10-07): every kit rect anchored at a corner contains the min-W × min-D rect at that corner, and every reject reason is monotone
        // (land / occupied / margin / levels), so a corner whose min rect fails is skipped for all kits; a cell with no passing corner is skipped outright.
        const okC = CORN.map(([ax, az]) => { const x0 = ev(x - ax * (minW - 2)), z0 = ev(z - az * (minD - 2)); return rectOk(x0, z0, x0 + minW, z0 + minD, LV + 1, 1); }); if (!okC.some(Boolean)) continue;
        let done = false; for (const kd of KD) { if (kd.max && (count[kd.id] || 0) >= kd.max) continue;
          for (let ci = 0; ci < 4; ci++) { if (!okC[ci]) continue; const [ax, az] = CORN[ci], x0 = ev(x - ax * (kd.w - 2)), z0 = ev(z - az * (kd.d - 2)), x1 = x0 + kd.w, z1 = z0 + kd.d;
            if (!rectOk(x0, z0, x1, z1, LV + 1, 1) || !nearSt(x0, z0, x1, z1) || !fairRect(x0, z0, x1, z1, GAP / 4)) continue;
            const kit = ME.kit(kd.id, site.style, r); if (kit.W * K !== kd.w || kit.D * K !== kd.d) { if (!rectOk(x0, z0, x0 + kit.W * K, z0 + kit.D * K, LV + 1, 1)) continue; }
            add(kit, kd.id, x0, z0); count[kd.id] = (count[kd.id] || 0) + 1; packed++; done = true; break; } if (done) break; } }
      } stats.packed = packed; }
    MK('pack');
    // Gates (style.gates, e.g. Zukei torii): spanning kept main roads — one near the plaza end, one at the town edge — never off-road.
    if (st.gates) for (const rd of roads.filter(q => q.main && !q.ring && q.keep >= 3).slice(0, 3)) for (const i of [2, Math.min(rd.pts.length - 1, rd.keep)]) {
      const [x, z, d] = rd.pts[i], ns = d === 0 || d === 2, kit = ME.kit(st.gates, site.style, r, { along: ns ? 'x' : 'z' }), fw = kit.W * K, fd = kit.D * K;
      const x0 = ns ? x + 2 - fw / 2 : x + 1 - fw / 2, z0 = ns ? z + 1 - fd / 2 : z + 2 - fd / 2;
      if (out.some(e => e.kit === st.gates && Math.hypot(e.x - (x0 + fw / 2), e.y - (z0 + fd)) < 14)) continue;
      out.push({ id: site.id + '_' + out.length, type: 'gen', kit: st.gates, settlement: site.id, L: Object.assign(kit.parts, { W: kit.W }), x: x0 + fw / 2, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); }
    MK('gates'); out.cx = ox; out.cz = oz; (root.MercSettlements.stats = root.MercSettlements.stats || {})[site.name] = { ...stats, roads: roads.length, streetPts: roads.reduce((a, r) => a + r.pts.length, 0), buildings: out.length, LV }; return out;
  }
  root.MercSettlements = { SITE, ISLE_SITES, landmark, generate, station, TIERS, STYLES, RULES, SMALL, NATION_STYLE, MIN_BUILD, GROW, STN, DOCKS };
})(typeof window !== 'undefined' ? window : globalThis);
