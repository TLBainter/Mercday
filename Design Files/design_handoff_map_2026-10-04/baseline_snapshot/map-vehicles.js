// Map vehicles (2026-10-07): steampunk train (engine · boxcar · flatcar · passenger · caboose), horse-drawn coach, airship. Same part format as map-elements.js
// (box / gable / pyr / lathe / card, textured, model units: K = 1.4 map px per unit in x / z, KY = 1.6 world per unit in y). Models are built along +x (nose = +x),
// centred on x = 50 (W = 100), z = 0; map-core rotates each group by vh.yaw (x–z) and vh.pitch (nose up) about its centre and draws every box face incl. the back.
// Palette: brown wood, black iron, gold trim. Glass + lamp texels have light maps (glow at night).
// MercVehicles.make(create) → { textures(), car(kind, wf), team(spec, frame), coach(wf), airship(pf), puff(size, shade), stack, COATS }
// MercVehicles.sim(data) → { step(dt), groups(rect, kit, hs) } — movement rules (see bottom). Godot: Vehicles.gd + PathFollow3D per vehicle.
(function (root) {
  const n = (x, y) => { let h = (x * 374761393 + y * 668265263) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
  const hex = h => { const v = parseInt(h.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };
  const dk = (h, f) => '#' + hex(h).map(v => Math.max(0, Math.min(255, Math.round(v * f))).toString(16).padStart(2, '0')).join('');
  const K = 1.4, KY = 1.6, HL = K / KY;
  const WD = ['#3e2614', '#56341c', '#6e4526', '#875832', '#a06a3c'], IR = ['#141216', '#201e22', '#2e2b30', '#403c44', '#55505a'], GD = ['#6e5014', '#a07a22', '#cf9f38', '#ecc65a', '#fae39a'];
  const GL = '#262a36', GLH = '#4c5468', LAMP = '#fff4c0', LAMPR = '#ff7a4a', AMB = '#ffcf70', CU = ['#6e3a1e', '#8a4a26', '#a65e32', '#c0763e', '#d89058'], WHITE = '#f2eee6';
  const glass = c => c === GL.toLowerCase() || c === GLH.toLowerCase(), lampLit = c => c === LAMP.toLowerCase() || c === LAMPR.toLowerCase() || c === AMB.toLowerCase();
  const COATS = [
    { id: 'bay', base: '#7a4626', hi: '#8e5530', mane: '#1e1612', leg: '#1e1612', pat: 'solid' },
    { id: 'chestnut', base: '#a05a2c', hi: '#b46a36', mane: '#7a3e1e', leg: '#a05a2c', pat: 'solid' },
    { id: 'black', base: '#2a2422', hi: '#3a3230', mane: '#141010', leg: '#2a2422', pat: 'solid' },
    { id: 'dapple', base: '#8e8a84', hi: '#d2cec6', mane: '#4e4a46', leg: '#5e5a54', pat: 'dapple' },
    { id: 'palomino', base: '#d0a04c', hi: '#e0b862', mane: '#f2e8c8', leg: '#d0a04c', pat: 'solid' },
    { id: 'pinto', base: '#6e4428', hi: WHITE, mane: '#2a1e16', leg: WHITE, pat: 'pinto' },
    { id: 'appaloosa', base: '#8a6a4a', hi: WHITE, mane: '#3a2a1e', leg: '#8a6a4a', pat: 'appy' },
    { id: 'buckskin', base: '#c8985a', hi: '#d8aa6c', mane: '#1e1612', leg: '#1e1612', pat: 'solid' },
    { id: 'grey', base: '#d0ccc4', hi: '#ecebe6', mane: '#8a8680', leg: '#bcb8b0', pat: 'solid' }];
  function make(create) {
    const memo = new Map(), all = [];
    // mod(id, w, h, fn, lit, tile): pixel texture; lit(col, x, y) → texel glows (builds c.light). tile = repeat 1 texel per model unit.
    const mod = (id, w, h, fn, lit, tile) => { if (memo.has(id)) return memo.get(id); const c = create(w, h), g = c.getContext('2d'), im = g.createImageData(w, h), d = im.data, L = lit ? new Uint8Array(w * h) : null;
      const px = (x, y, col) => { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= w || y >= h || !col) return; const [r, gg, b] = hex(col), i = (y * w + x) * 4; d[i] = r; d[i + 1] = gg; d[i + 2] = b; d[i + 3] = 255; if (L) L[y * w + x] = lit(col.toLowerCase(), x, y) ? 1 : 0; };
      fn(px, w, h); g.putImageData(im, 0, 0); c.id = id; if (tile) c.tile = true;
      if (L && L.some(v => v)) { const lc = create(w, h), lg = lc.getContext('2d'), ld = lg.createImageData(w, h); for (let i = 0; i < w * h; i++) if (L[i]) ld.data.fill(255, i * 4, i * 4 + 4); lg.putImageData(ld, 0, 0); c.light = lc; }
      memo.set(id, c); all.push(c); return c; };
    const each = (w, h, f) => px => { for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) px(x, y, f(x, y)); };
    // ── textures
    const wood = () => mod('vh_wood', 4, 4, each(4, 4, (x, y) => y === 3 ? WD[1] : n(x + 11, y * 5) > 0.78 ? WD[4] : y & 1 ? WD[2] : WD[3]), null, true);
    const woodV = () => mod('vh_woodv', 4, 4, each(4, 4, (x, y) => x === 3 ? WD[1] : n(x * 7, y + 3) > 0.8 ? WD[4] : x & 1 ? WD[2] : WD[3]), null, true);
    const iron = () => mod('vh_iron', 4, 4, each(4, 4, (x, y) => (x === 1 && y === 1) || (x === 3 && y === 3) ? IR[4] : x === 3 || y === 3 ? IR[1] : n(x, y + 9) > 0.7 ? IR[3] : IR[2]), null, true);
    const gold = () => mod('vh_gold', 2, 2, each(2, 2, (x, y) => x + y === 0 ? GD[4] : x + y === 1 ? GD[3] : GD[2]), null, true);
    const roof = () => mod('vh_roof', 4, 4, each(4, 4, (x, y) => x === 0 ? IR[0] : y === 0 ? IR[2] : IR[1]), null, true);
    const deckT = () => mod('vh_deck', 4, 4, each(4, 4, (x, y) => y === 3 ? WD[2] : n(x + 3, y * 9) > 0.75 ? WD[4] : WD[3]), null, true);
    const boiler = () => mod('vh_boiler', 12, 16, each(12, 16, (x, y) => y === 0 ? GD[3] : y === 15 ? IR[0] : y === 1 || y === 8 || y === 14 ? GD[2] : (y === 2 || y === 9) && x % 3 === 0 ? GD[1] : n(x, y) > 0.86 ? IR[2] : IR[1]));
    const stack = () => mod('vh_stack', 8, 6, each(8, 6, (x, y) => y === 0 ? GD[3] : y === 1 ? GD[2] : y === 4 ? GD[1] : n(x, y + 4) > 0.8 ? IR[2] : IR[1]));
    const brass = () => mod('vh_brass', 8, 4, each(8, 4, (x, y) => [GD[4], GD[3], GD[2], GD[1]][y]));
    const cabSide = () => mod('vh_cabside', 6, 6, each(6, 6, (x, y) => y === 0 ? GD[2] : y === 5 ? IR[1] : y === 4 ? GD[1] : y <= 2 && x >= 1 && x <= 4 ? (x === 1 && y === 1 ? GLH : GL) : x & 1 ? WD[2] : WD[3]), glass);
    const lamp = () => mod('vh_lamp', 3, 3, each(3, 3, (x, y) => x === 1 && y === 1 ? LAMP : GD[2]), lampLit);
    const lampR = () => mod('vh_lampr', 3, 3, each(3, 3, (x, y) => x === 1 && y === 1 ? LAMPR : GD[2]), lampLit);
    const wheel = f => mod('vh_wheel' + f, 6, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 6; x++) { const dx = x - 2.5, dy = y - 2.5, r = Math.hypot(dx, dy); if (r > 3.1) continue;
      const spoke = f ? Math.abs(Math.abs(dx) - Math.abs(dy)) < 0.6 : (x === 2 || x === 3 || y === 2 || y === 3); px(x, y, r > 2.2 ? IR[3] : r < 0.8 ? GD[3] : spoke ? IR[2] : IR[0]); } });
    const boxSide = () => mod('vh_boxside', 12, 5, each(12, 5, (x, y) => y === 0 ? GD[2] : y === 4 ? GD[1] : x >= 4 && x <= 7 ? (x === 4 || x === 7 ? WD[0] : x === 6 && y === 2 ? GD[3] : WD[1]) : (x === 1 && y === 1) || (x === 2 && y === 2) || (x === 1 && y === 3) || (x === 10 && y === 1) || (x === 9 && y === 2) || (x === 10 && y === 3) ? WD[1] : x % 3 === 2 ? WD[2] : WD[3]));
    const passSide = () => mod('vh_passside', 14, 6, each(14, 6, (x, y) => y === 0 ? GD[3] : y === 4 ? GD[1] : y === 5 ? WD[1] : x === 0 || x === 13 ? WD[1] : (y === 2 || y === 3) && [1, 2, 4, 5, 8, 9, 11, 12].includes(x) ? (y === 2 && [1, 4, 8, 11].includes(x) ? GLH : GL) : y === 1 ? WD[3] : WD[2]), glass);
    const passEnd = () => mod('vh_passend', 4, 6, each(4, 6, (x, y) => y === 0 ? GD[3] : y === 5 ? WD[1] : (x === 1 || x === 2) && y >= 1 && y <= 4 ? (y <= 2 ? GL : WD[1]) : y === 4 ? GD[1] : WD[3]), glass);
    const cbSide = () => mod('vh_cbside', 10, 5, each(10, 5, (x, y) => y === 0 ? GD[2] : y === 3 ? GD[1] : y === 4 ? WD[1] : (y === 1 || y === 2) && (x === 2 || x === 3 || x === 6 || x === 7) ? (y === 1 && (x === 2 || x === 6) ? GLH : GL) : x & 1 ? WD[2] : WD[3]), glass);
    const cupola = () => mod('vh_cupola', 4, 3, each(4, 3, (x, y) => y === 0 ? GD[2] : y === 2 ? WD[1] : x === 1 || x === 2 ? GL : WD[2]), glass);
    const crate = () => mod('vh_crate', 4, 4, each(4, 4, (x, y) => x === 0 || y === 0 || x === 3 || y === 3 || x === y ? WD[1] : WD[3]));
    const barrel = () => mod('vh_barrel', 8, 6, each(8, 6, (x, y) => y === 1 || y === 4 ? IR[2] : y === 0 || y === 5 ? WD[1] : x & 1 ? WD[2] : WD[3]));
    const tarp = () => mod('vh_tarp', 4, 4, each(4, 4, (x, y) => (x + y) % 4 === 0 ? '#86754f' : n(x, y + 2) > 0.7 ? '#ab9a72' : '#9c8a64'), null, true);
    const coachS = () => mod('vh_coach', 8, 5, each(8, 5, (x, y) => y === 0 ? GD[3] : y === 4 ? WD[2] : (x === 3 || x === 4) ? (y === 1 ? (x === 3 ? GLH : GL) : IR[2]) : (x === 5 && y === 2) || ((x === 1 || x === 6) && y === 2) ? GD[2] : (x === 2 || x === 5) && y === 1 ? IR[0] : IR[1]), glass);
    const coachE = () => mod('vh_coachend', 4, 5, each(4, 5, (x, y) => y === 0 ? GD[3] : y === 4 ? WD[2] : y === 1 && (x === 1 || x === 2) ? GL : IR[1]), glass);
    const skin = () => mod('vh_skin', 2, 2, each(2, 2, (x, y) => y ? '#c08e68' : '#d8a880'));
    const coat = () => mod('vh_coat', 2, 2, each(2, 2, (x, y) => (x + y) & 1 ? '#22222e' : '#2e2e3c'));
    const lantern = () => mod('vh_lantern', 3, 4, each(3, 4, (x, y) => y === 0 ? GD[3] : y === 3 ? GD[1] : x === 1 ? LAMP : GD[2]), lampLit);
    const smoke = () => mod('vh_smoke', 4, 4, each(4, 4, (x, y) => n(x * 3, y * 5 + 1) > 0.7 ? '#ffffff' : n(x + 7, y) > 0.75 ? '#c8c8c8' : '#e4e4e4'));
    // horse coats: body 8×4 (pattern) · head 3×2 (± blaze) · leg 1×4 (± sock, hoof row) · mane 2×2
    const hBody = c => mod('vh_hb_' + c.id, 8, 4, each(8, 4, (x, y) => { const sh = y === 3 ? dk(c.base, 0.85) : c.base;
      if (c.pat === 'dapple') return n(x * 3, y * 5) > 0.55 ? c.hi : sh; if (c.pat === 'pinto') return (x >= 1 && x <= 3 && y >= 1) || (x >= 5 && x <= 6 && y <= 2) ? c.hi : sh;
      if (c.pat === 'appy') return x >= 4 ? (n(x * 5, y * 3) > 0.7 ? dk(c.base, 0.6) : c.hi) : sh; return y === 0 || n(x, y + 3) > 0.85 ? c.hi : sh; }));
    const hHead = (c, b) => mod('vh_hh' + (b ? 'b_' : '_') + c.id, 3, 2, each(3, 2, (x, y) => b && x === 1 ? WHITE : x === 2 && y === 1 ? dk(c.base, 0.7) : c.base));
    const hLeg = (c, s) => mod('vh_hl' + (s ? 's_' : '_') + c.id, 1, 4, each(1, 4, (x, y) => y === 3 ? '#2a2018' : s && y >= 1 ? WHITE : c.leg));
    const hMane = c => mod('vh_hm_' + c.id, 2, 2, each(2, 2, (x, y) => (x + y) & 1 ? dk(c.mane, 0.8) : c.mane), null, true);
    // airship
    const env = () => mod('vh_env', 24, 32, each(24, 32, (x, y) => { if (y <= 1) return GD[3]; if (y === 6 || y === 18 || y === 29) return x % 4 === 0 ? IR[4] : IR[1]; if (y === 5 || y === 7 || y === 17 || y === 19 || y === 28 || y === 30) return x % 4 === 2 ? GD[2] : CU[0];
      if (x === 0 || x === 12) return CU[0]; const py = (y - 2) % 4, px0 = (x + (((y - 2) >> 2) & 1) * 2) % 4; if (py === 0 || px0 === 0) return (py === 0 && px0 === 0) ? GD[1] : CU[1]; return n(x, y) > 0.82 ? CU[4] : n(x + 5, y) > 0.5 ? CU[3] : CU[2]; }));
    const cone = () => mod('vh_cone', 8, 8, each(8, 8, (x, y) => y === 0 ? GD[3] : x % 4 === 0 ? GD[2] : n(x, y) > 0.8 ? IR[3] : IR[1]));
    const fin = () => mod('vh_fin', 8, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 8; x++) { const rib = x % 3 === 0; if (y === 5 && !rib) continue; if (y === 4 && x % 3 === 2) continue; px(x, y, y === 0 ? GD[1] : rib ? GD[2] : n(x, y) > 0.7 ? CU[2] : CU[1]); } });
    const hull = () => mod('vh_hull', 18, 4, each(18, 4, (x, y) => y === 0 ? GD[3] : y === 1 ? WD[1] : y === 2 ? (x % 4 === 2 ? AMB : x % 4 === 1 || x % 4 === 3 ? GD[1] : WD[2]) : x % 6 === 0 ? GD[2] : WD[1]), lampLit);
    const hull2 = () => mod('vh_hull2', 4, 4, each(4, 4, (x, y) => y === 3 ? WD[0] : n(x, y * 3) > 0.8 ? WD[2] : WD[1]), null, true);
    const cabin = () => mod('vh_cabin', 8, 4, each(8, 4, (x, y) => y === 0 ? GD[2] : y === 3 ? (x === 2 || x === 5 ? GD[2] : WD[1]) : x === 0 || x === 7 ? WD[1] : (x + y) & 1 ? AMB : GD[1]), lampLit);
    const rail = () => mod('vh_rail', 4, 2, px => { for (let x = 0; x < 4; x++) px(x, 0, GD[2]); px(0, 1, GD[1]); }, null, true);
    const prop = f => mod('vh_prop' + f, 7, 7, px => { for (let y = 0; y < 7; y++) for (let x = 0; x < 7; x++) { const dx = x - 3, dy = y - 3, on = f ? Math.abs(dx) === Math.abs(dy) : dx === 0 || dy === 0; if (!on) continue; px(x, y, dx === 0 && dy === 0 ? IR[3] : Math.max(Math.abs(dx), Math.abs(dy)) === 3 ? GD[2] : WD[3]); } });
    const chain = () => mod('vh_chain', 1, 2, each(1, 2, (x, y) => y ? IR[1] : IR[4]), null, true);
    const gear = () => mod('vh_gear', 6, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 6; x++) { const r = Math.hypot(x - 2.5, y - 2.5); if (r > 3.1 || r < 1.2) continue; if (r > 2.5 && (x + y) % 2) continue; px(x, y, r > 2.5 ? GD[3] : GD[2]); } });
    const ball = () => mod('vh_ball', 8, 4, each(8, 4, (x, y) => x % 3 === 1 && y % 2 === 1 ? IR[0] : y === 0 ? GD[3] : GD[2]));
    const sail = () => mod('vh_sail', 6, 6, each(6, 6, (x, y) => x === 0 || y === 0 || y === 5 ? '#c8b894' : (x === 2 || x === 4) && y > 1 && y < 4 ? GD[2] : (x === 3 && (y === 2 || y === 3)) ? GD[3] : y % 2 ? '#e2d6b8' : '#ece2c8'));
    const pennant = () => mod('vh_pennant', 4, 2, each(4, 2, (x, y) => x === 0 ? GD[2] : (x + y) & 1 ? IR[1] : IR[2]));
    const dirt = () => mod('vh_dirt', 4, 4, each(4, 4, (x, y) => n(x * 5, y * 3 + 7) > 0.78 ? '#5a4632' : n(x + 9, y * 7) > 0.6 ? '#7a6044' : '#6c543a'));
    const spot = () => mod('vh_spot', 4, 4, each(4, 4, (x, y) => x === 0 || y === 0 || x === 3 || y === 3 ? GD[2] : AMB), lampLit);
    const ALL = () => { [wood, woodV, iron, gold, roof, deckT, boiler, stack, brass, cabSide, lamp, lampR, boxSide, passSide, passEnd, cbSide, cupola, crate, barrel, tarp, coachS, coachE, skin, coat, lantern, smoke, env, cone, fin, hull, hull2, cabin, rail, chain, gear, ball, spot, sail, pennant, dirt].forEach(f => f());
      wheel(0); wheel(1); prop(0); prop(1); for (const c of COATS) { hBody(c); hHead(c, 0); hHead(c, 1); hLeg(c, 0); hLeg(c, 1); hMane(c); } return all; };
    // ── part helpers (model units; x centred on 0, shifted to 50 by fin())
    const A = t => ({ top: t, front: t, back: t, left: t, right: t });
    const B = (x, z, y, w, d, h, tex, tint, extra) => Object.assign({ kind: 'box', x, z, y, w, d, h, tex: tex.width ? A(tex) : tex, tint }, extra || {});
    const SB = (x, z, y, w, d, h, side, ends, top) => B(x, z, y, w, d, h, { top: top || ends, front: side, back: side, left: ends, right: ends });
    const LV = (x, z, y, w, h, prof, tex, tint) => ({ kind: 'lathe', x, z, y, w, d: w, h, prof, tex: { side: tex }, tint });
    const LH = (x0, z, y, len, dia, prof, tex, tint) => ({ kind: 'lathe', x: x0, z, y, w: dia, d: dia, h: len * HL, prof, tex: { side: tex }, tint, tilt: -Math.PI / 2, piv: [x0, y, z] });
    const PH = (x0, z, y, hgt, d, len, tex) => ({ kind: 'pyr', x: x0, z, y, w: hgt / HL, d, h: len * HL, tex: { s: tex, n: tex, l: tex, r: tex }, tilt: -Math.PI / 2, piv: [x0, y, z] }); // pyramid pointing +x (bow)
    const fin_ = (parts) => { for (const p of parts) { p.x += 50; if (p.piv) p.piv = [p.piv[0] + 50, p.piv[1], p.piv[2]]; } parts.W = 100; return parts; };
    const DOME = [[0, 1], [0.35, 0.94], [0.65, 0.75], [0.85, 0.48], [1, 0]], CYL = [[0, 1], [1, 1]];
    const MC = new Map(), M = (k, f) => { if (!MC.has(k)) MC.set(k, f()); return MC.get(k); };
    // ── train. D = car width (track gauge ±2.4 px). Lengths (model units) in LEN; wf = wheel frame 0/1 (spokes + / ×, rods up / down).
    const D = 3.8, LEN = { engine: 13, boxcar: 11, flatcar: 11, passenger: 13, caboose: 10 };
    const wheels = (x, dia, wf, dd) => [-1, 1].map(s => B(x, s * ((dd || D) / 2 + 0.15), 0, dia, 0.3, dia * HL, { top: iron(), front: wheel(wf), back: wheel(wf), left: iron(), right: iron() }));
    const bogie = (x, wf) => [B(x, 0, 0.3, 3, D - 0.4, 0.7, iron()), ...wheels(x - 0.9, 1.3, wf), ...wheels(x + 0.9, 1.3, wf)];
    const coupler = x => B(x, 0, 0.95, 0.9, 0.6, 0.5, iron());
    const KINDS = {
      engine: wf => [B(0, 0, 1.0, 13, D - 0.4, 0.8, iron()), B(0.8, 0, 1.8, 9.4, D + 0.6, 0.2, { top: wood(), front: gold(), back: gold(), left: gold(), right: gold() }),
        ...wheels(-3.6, 2.3, wf), ...wheels(-1.0, 2.3, wf), ...wheels(1.6, 2.3, wf), ...wheels(4.6, 1.3, wf), ...wheels(-5.7, 1.3, wf),
        ...[-1, 1].map(s => B(-1.0, s * (D / 2 + 0.35), wf ? 1.25 : 0.75, 5.6, 0.15, 0.25, gold())), ...[-1, 1].map(s => B(3.5, s * (D / 2 + 0.05), 1.1, 1.8, 0.5, 0.9, brass())),
        LH(-3.4, 0, 3.4, 8.6, 3.4, [[0, 1], [0.96, 1], [1, 0]], boiler()), LV(4.0, 0, 4.7, 1.5, 2.6, [[0, 0.55], [0.5, 0.45], [0.75, 0.85], [0.9, 1], [1, 0.95]], stack()),
        LV(0.8, 0, 4.7, 1.6, 1.1, DOME, brass()), LV(-1.4, 0, 4.75, 1.2, 0.8, DOME, brass()), B(-2.6, 0, 4.8, 0.3, 0.3, 0.8, gold()),
        B(5.0, 0, 4.9, 0.9, 0.9, 0.8, { top: gold(), front: gold(), back: gold(), left: gold(), right: lamp() }),
        B(6.3, 0, 0.2, 0.8, D - 0.4, 0.9, gold()), B(6.9, 0, 0.2, 0.6, D - 1.2, 0.5, iron()),
        SB(-5, 0, 1.8, 3.2, D, 3.6, cabSide(), cabSide()), B(-5, 0, 5.3, 3.9, D + 0.6, 0.12, gold()), B(-5, 0, 5.42, 3.8, D + 0.5, 0.35, roof()), coupler(-6.9)],
      boxcar: wf => [B(0, 0, 1.0, 11, D - 0.4, 0.5, iron()), ...bogie(-3.6, wf), ...bogie(3.6, wf), SB(0, 0, 1.5, 11, D, 3.4, boxSide(), woodV()),
        B(0, 0, 4.9, 11.4, D + 0.4, 0.35, roof()), B(0, 0, 5.25, 10.6, 0.8, 0.12, wood()), ...[-1, 1].flatMap(s => [-1, 1].map(q => B(s * 5.45, q * D / 2, 1.5, 0.2, 0.2, 3.4, gold()))), coupler(-5.8), coupler(5.8)],
      flatcar: wf => [B(0, 0, 1.0, 11, D - 0.4, 0.5, iron()), ...bogie(-3.6, wf), ...bogie(3.6, wf), B(0, 0, 1.5, 11, D, 0.45, { top: deckT(), front: gold(), back: gold(), left: wood(), right: wood() }),
        ...[-5.2, -1.7, 1.7, 5.2].flatMap(x => [-1, 1].map(q => B(x, q * (D / 2 - 0.1), 1.95, 0.25, 0.25, 1.0, gold()))),
        B(-3.2, 0, 1.95, 2.6, 2.6, 2.3, crate()), B(-3.0, 0.2, 4.25, 1.7, 1.7, 1.5, crate()), LV(0.1, -0.85, 1.95, 1.5, 1.9, [[0, 0.85], [0.5, 1], [1, 0.85]], barrel()), LV(0.1, 0.85, 1.95, 1.5, 1.9, [[0, 0.85], [0.5, 1], [1, 0.85]], barrel()),
        LV(1.8, 0, 1.95, 1.5, 1.9, [[0, 0.85], [0.5, 1], [1, 0.85]], barrel()), B(3.9, 0, 1.95, 2.4, 3.0, 1.6, tarp()), coupler(-5.8), coupler(5.8)],
      passenger: wf => [B(0, 0, 1.0, 13, D - 0.4, 0.5, iron()), ...bogie(-4.4, wf), ...bogie(4.4, wf), SB(0, 0, 1.5, 12, D, 3.3, passSide(), passEnd()),
        ...[-1, 1].flatMap(s => [B(s * 6.25, 0, 1.5, 0.5, D - 0.6, 0.25, wood()), ...[-1, 1].map(q => B(s * 6.4, q * (D / 2 - 0.5), 1.75, 0.2, 0.15, 0.8, gold()))]),
        B(0, 0, 4.75, 12.2, D + 0.15, 0.15, gold()), { kind: 'gable', x: 0, z: 0, y: 4.8, w: 12.8, d: D + 0.5, h: 1.0, tex: { s: roof(), n: roof(), l: wood(), r: wood() } }, coupler(-6.9), coupler(6.9)],
      caboose: wf => [B(0, 0, 1.0, 10, D - 0.4, 0.5, iron()), ...bogie(-3.2, wf), ...bogie(3.2, wf), SB(0, 0, 1.5, 9, D, 3.0, cbSide(), passEnd()),
        B(0, 0, 4.4, 9.7, D + 0.6, 0.12, gold()), B(0, 0, 4.5, 9.6, D + 0.5, 0.35, roof()), SB(0.6, 0, 4.85, 3.2, D - 0.8, 1.5, cupola(), cupola()), B(0.6, 0, 6.35, 3.6, D - 0.4, 0.3, roof()),
        LV(-2.6, 0.8, 4.85, 0.5, 1.3, CYL, stack()), ...[-1, 1].flatMap(s => [B(s * 4.75, 0, 1.5, 0.5, D - 0.6, 0.25, wood()), ...[-1, 1].map(q => B(s * 4.9, q * (D / 2 - 0.5), 1.75, 0.2, 0.15, 0.8, gold()))]),
        ...[-1, 1].map(q => B(-4.75, q * 1.3, 3.6, 0.4, 0.4, 0.5, { top: gold(), front: gold(), back: gold(), right: gold(), left: lampR() })), coupler(-5.4), coupler(5.4)] };
    const car = (kind, wf) => M('car|' + kind + wf, () => fin_(KINDS[kind](wf)));
    // ── horse team (2 horses side by side, z ±0.85). frame 0 / 1 = trot (diagonal leg pairs swap, body bobs), 2 = standing.
    const horse = (c, sock, blaze, z, fr) => { const dy = fr === 1 ? 0.1 : 0, bt = hBody(c), hd = hHead(c, 0), hb = hHead(c, blaze), mn = hMane(c);
      const legs = [[1, -1], [1, 1], [-1, -1], [-1, 1]].map(([fx, sz], i) => { const pairA = (fx === 1) === (sz === -1), a = fr === 2 ? 0 : (pairA === (fr === 0) ? 0.38 : -0.32), x = fx * 1.05, zz = z + sz * 0.25;
        return B(x, zz, 0, 0.35, 0.3, 1.6, hLeg(c, sock === 2 || (sock === 1 && fx === 1)), null, { tilt: a, piv: [x, 1.6, zz] }); });
      return [...legs, B(0, z, 1.55 + dy, 3.0, 0.95, 1.15, bt), B(1.55, z, 2.3 + dy, 0.6, 0.6, 1.4, bt, null, { tilt: -0.55, piv: [1.3, 2.3 + dy, z] }),
        B(1.2, z, 2.6 + dy, 0.22, 0.26, 1.3, mn, null, { tilt: -0.55, piv: [1.3, 2.3 + dy, z] }),
        B(2.45, z, 3.0 + dy, 1.1, 0.5, 0.55, { top: hb, front: hd, back: hd, left: hd, right: hb }, null, { tilt: -0.45, piv: [2.0, 3.3 + dy, z] }),
        B(2.05, z, 3.7 + dy, 0.15, 0.36, 0.3, mn), B(-1.62, z, 1.5 + dy, 0.28, 0.3, 1.2, mn, null, { tilt: fr === 1 ? -0.42 : -0.28, piv: [-1.5, 2.7 + dy, z] }),
        B(1.15, z, 2.15 + dy, 0.35, 1.05, 0.95, iron()), B(0.2, z, 1.5 + dy, 0.3, 1.02, 1.25, iron()), B(0.1, z, 2.7 + dy, 0.8, 0.9, 0.12, gold())]; };
    const team = (s, fr) => M('team|' + [s.a, s.b, s.sa, s.sb, s.ba, s.bb, fr].join(','), () => fin_([...horse(COATS[s.a], s.sa, s.ba, -0.85, fr), ...horse(COATS[s.b], s.sb, s.bb, 0.85, fr === 2 ? 2 : 1 - fr),
      B(-0.6, 0, 1.6, 4.2, 0.2, 0.18, wood()), B(-1.9, 0, 1.6, 0.3, 2.4, 0.2, wood())]));
    // ── coach (black lacquer + gold, wood undercarriage, coachman). Front = +x (toward the team).
    const Dc = 3.0;
    const coach = wf => M('coach|' + wf, () => fin_([...wheels(-2.2, 2.6, wf, Dc + 0.2), ...wheels(2.0, 2.0, wf, Dc + 0.2), B(0, 0, 0.9, 6, 1.0, 0.35, iron()), B(-2.2, 0, 1.1, 0.6, Dc + 0.3, 0.4, iron()), B(2.0, 0, 1.1, 0.6, Dc + 0.3, 0.4, iron()),
      B(-0.4, 0, 1.05, 3.8, Dc - 0.4, 0.4, iron()), SB(-0.4, 0, 1.4, 4.6, Dc, 3.0, coachS(), coachE()), B(-0.4, 0, 4.4, 5.0, Dc + 0.3, 0.35, roof()),
      ...[-1, 1].map(q => B(-0.4, q * (Dc / 2 + 0.05), 4.75, 4.6, 0.12, 0.35, rail())), B(-1.0, 0, 4.75, 1.6, 1.6, 0.8, crate()),
      B(2.5, 0, 2.1, 1.4, Dc - 0.4, 0.9, wood()), B(3.3, 0, 1.6, 0.5, Dc - 0.4, 0.15, wood()), B(2.55, 0, 3.0, 0.7, 0.8, 1.0, coat()), B(2.6, 0, 4.0, 0.5, 0.5, 0.5, skin()),
      B(2.6, 0, 4.45, 0.85, 0.85, 0.08, roof()), B(2.6, 0, 4.5, 0.6, 0.6, 0.45, roof()), ...[-1, 1].map(q => B(1.9, q * (Dc / 2 + 0.1), 3.4, 0.4, 0.4, 0.6, lantern())),
      B(4.6, 0, 1.4, 2.6, 0.25, 0.2, wood())]));
    // ── airship: copper envelope (iron bands, gold seams) + brass nose collar, iron cone, gear + spike; bat-wing fins; side engine arms;
    // wooden ship hull hung on chains (portholes, stern cabin with lattice windows, bow lantern, figurehead), rear propeller. pf = propeller frame.
    const ENV = [[0, 0.12], [0.05, 0.5], [0.14, 0.78], [0.28, 0.95], [0.45, 1], [0.62, 0.98], [0.78, 0.88], [0.9, 0.68], [1, 0.42]];
    const finT = () => ({ top: gold(), front: fin(), back: fin(), left: gold(), right: gold() });
    const airship = pf => M('air|' + pf, () => { const Y = 22, U = Y - 17; // envelope axis height; hull hangs ~10 units below the envelope so it shows south of it from the 55° camera
      return fin_([B(0, 0, 0, 11, 1.6, 0.8, iron()), B(0, 0, 0.8, 15, 3.6, 1.2, hull2()), SB(0, 0, 2.0, 18, 5, 2.4, hull(), hull2(), deckT()),
      PH(9, 0, 3.2, 2.4, 5, 3.5, hull()), PH(7.5, 0, 1.4, 1.2, 3.6, 3.0, hull2()), PH(11.6, 0, 2.6, 0.8, 0.8, 1.3, gold()), B(13.4, 0, 4.0, 2.2, 0.22, 0.22, wood()),
      ...[-1, 1].map(q => B(0, q * 2.42, 4.4, 17.6, 0.15, 0.8, rail())), B(8.9, 0, 4.4, 0.15, 4.8, 0.8, rail()),
      SB(-6.6, 0, 4.4, 4.8, 4.6, 2.6, cabin(), cabin()), B(-6.6, 0, 6.9, 5.5, 5.3, 0.12, gold()), B(-6.6, 0, 7.0, 5.4, 5.2, 0.35, roof()),
      B(-3.95, 0, 5.4, 0.5, 1.4, 1.2, { top: gold(), front: gold(), back: gold(), left: gold(), right: spot() }), B(8.4, 0, 4.4, 0.5, 0.5, 0.9, lantern()),
      B(2.4, 0, 4.4, 0.35, 0.35, 7.2, wood()), B(1.0, 0, 5.4, 3.2, 0.12, 5.4, { top: sail(), front: sail(), back: sail(), left: sail(), right: sail() }), B(2.4, 0, 11.6, 0.6, 0.6, 0.3, gold()),
      B(-8.6, 0, 7.35, 0.2, 0.2, 3.2, iron()), B(-9.8, 0, 9.6, 2.2, 0.1, 0.9, { top: pennant(), front: pennant(), back: pennant(), left: pennant(), right: pennant() }),
      B(-9.6, 0, 2.4, 1.2, 0.8, 0.8, iron()), B(-10.3, 0, 1.0, 0.15, 3.2, 3.0, A(prop(pf))),
      ...[-1, 1].flatMap(q => [-5.5, 5.5].map(x => B(x, q * 1.8, 4.4, 0.18, 0.18, Y - 4.4 - 4.4, chain()))),
      LH(-16, 0, Y, 31, 11, ENV, env()), LH(-16.7, 0, Y, 0.8, 1.6, CYL, brass()), LH(15, 0, Y, 1.6, 5.0, CYL, brass()), LH(16.6, 0, Y, 4.2, 4.2, [[0, 1], [0.3, 0.8], [1, 0.06]], cone()),
      B(22.2, 0, Y - 0.15, 2.6, 0.25, 0.3, gold()), B(21.4, 0, Y - 1, 0.25, 2.2, 1.9, { top: gold(), front: gold(), back: gold(), left: gear(), right: gear() }),
      LV(-1, 0, Y + 4.3, 2.6, 2.2, [[0, 0.6], [0.2, 0.95], [0.5, 1], [0.8, 0.8], [1, 0.3]], ball()),
      B(-13, 0, Y + 3, 5, 0.3, 4.4, finT()), B(-13, 0, Y - 7.6, 4.4, 0.3, 3.2, finT()), ...[-1, 1].map(q => B(-13, q * 5.5, Y - 0.1, 5, 3.6, 0.25, { top: fin(), front: gold(), back: gold(), left: gold(), right: gold() })),
      ...[-1, 1].flatMap(q => [B(3, q * 7.3, Y - 2, 1.0, 4.0, 0.5, iron()), LH(1.4, q * 9.6, Y - 1.7, 2.8, 1.3, [[0, 0.6], [0.5, 1], [1, 0.7]], brass()), B(1.2, q * 9.6, Y - 3.1, 0.15, 2.6, 2.4, A(prop(pf)))])]); });
    const puff = (si, ci) => M('puff|' + si + '|' + ci, () => { const s = si / 4, g = Math.round(150 + ci * 14).toString(16).padStart(2, '0'); return fin_([B(0, 0, -s * HL / 2, s, s, s * HL, smoke(), '#' + g + g + g)]); });
    return { textures: ALL, get dirtTex() { return dirt(); }, car, team, coach, airship, puff, LEN, COATS, stack: [4.0, 7.3], D };
  }
  // ── simulation. data = { rail: [{ id, from, to, pts: [[x, z, y]] }], trails: [[[x, z, y]]], cities: [[x, z, name]], ground(x, z), hAt(x, z), avoid(x, z), seed }
  // Train: engine + 3–6 random middle cars (≥ 1 passenger, order shuffled) + caboose. Follows the rail graph; at a "… Station" node it stops (4–7 s), at a junction it
  //   rolls through onto a random other edge; at a dead end it stops, then the consist runs back the way it came (caboose end leads → model flips, engine at the front).
  //   Speed ≤ 24 px/s, accel 6 px/s², brakes on a √ curve into stations. Smoke: a puff every 0.09 s moving (0.35 s standing), rises + drifts, grows, then shrinks (2.6 s).
  // Coach: team + coach follow trade-route lines (t.tradeLines). At a line end it continues onto any other line passing within 6 px (random, either direction ≥ 15 px);
  //   (bridge decks count as lines, joined within 14 px). Line end at a town (settlement within 6 px) → 25 % (100 % if no other line) the coach enters: hidden 6–14 s,
//   then comes back out the way it came. Other dead ends → waits 2–5 s, turns around. Rail crossings: waits while a train is within 16 px. ≤ 9 px/s. Horses: 2-frame trot every 1.7 px travelled, standing pose when stopped. Wheels: 2-frame spokes.
  // Airship: city → city (straight line, path + ±60 px clear of Cyfrolaef / the crater), heading turns ≤ 0.45 rad/s, ≤ 18 px/s, hovers 6–12 s per city;
  //   altitude = max ground under / 60 / 120 px ahead + 46, eased; gentle bob. Dithered ground shadow under it.
  function sim(data) {
    let seed = data.seed || 7; const rnd = () => { seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
    const pick = a => a[Math.floor(rnd() * a.length) % a.length];
    const mkSeg = (pts, a, b, e) => { const cum = new Float32Array(pts.length); for (let i = 1; i < pts.length; i++) cum[i] = cum[i - 1] + Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]); return { pts, cum, len: cum[pts.length - 1], a, b, e }; };
    const revSeg = s => mkSeg(s.pts.slice().reverse(), s.b, s.a, s.e);
    const at = (v, s) => { let k = v.segs.length - 1, o = v.h - s; while (o < 0 && k > 0) { k--; o += v.segs[k].len; } const sg = v.segs[k]; o = Math.max(0, Math.min(sg.len, o));
      let lo = 0, hi = sg.pts.length - 1; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (sg.cum[m] <= o) lo = m; else hi = m; } const f = Math.min(1, (o - sg.cum[lo]) / ((sg.cum[hi] - sg.cum[lo]) || 1)), P = sg.pts[lo], Q = sg.pts[hi];
      return [P[0] + (Q[0] - P[0]) * f, P[1] + (Q[1] - P[1]) * f, P[2] + (Q[2] - P[2]) * f]; };
    const pose = (v, s, half) => { const f = at(v, s - half), b = at(v, s + half), dx = f[0] - b[0], dz = f[1] - b[1], dy = f[2] - b[2], L = Math.hypot(dx, dz) || 1e-6; return { x: (f[0] + b[0]) / 2, z: (f[1] + b[1]) / 2, y: (f[2] + b[2]) / 2, yaw: Math.atan2(dz, dx), pitch: Math.atan2(dy, L) }; };
    const trim = (v, keep) => { while (v.segs.length > 1) { let behind = v.h; for (let k = v.segs.length - 2; k >= 1; k--) behind += v.segs[k].len; if (behind >= keep) v.segs.shift(); else break; } };
    const reverse = (v, L) => { let k = v.segs.length - 1, o = v.h - L; while (o < 0 && k > 0) { k--; o += v.segs[k].len; } o = Math.max(0, o); v.segs = v.segs.slice(k).reverse().map(revSeg); v.h = v.segs[v.segs.length - 1].len - o; };
    const segAt = (v, s) => { let k = v.segs.length - 1, o = v.h - s; while (o < 0 && k > 0) { k--; o += v.segs[k].len; } return [k, Math.max(0, Math.min(v.segs[k].len, o))]; };
    const ang2 = (u, v) => Math.abs(Math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1]));
    const GK = (x, z) => ((Math.round(x) >> 3) * 4096 + (Math.round(z) >> 3)), near8 = (G, x, z, f) => { for (let dz = -16; dz <= 16; dz += 8) for (let dx = -16; dx <= 16; dx += 8) { const L = G.get(GK(x + dx, z + dz)); if (L && f(L)) return true; } return false; };
    // ── trains. Block signalling: every rail edge is a block. A train holds the edges it covers + the one it has reserved; it reserves the next edge
    // ≤ 90 px before a node (only if no other train holds it) and stops CLR px short of the node while the next edge is taken or another train is on the
    // node. Waiting 6–12 s (head-on standoff) → it runs back the way it came. Stations: stop CLR px short, dwell 4–7 s. Dead end: stop, dwell, run back.
    // Level crossings: a train stops 12 px short of a crossing while a coach is on it (coaches only start across when no train is near — see coaches).
    const E = data.rail || [], adj = new Map(), nodeP = new Map(); E.forEach((e, i) => { for (const nd of [e.from, e.to]) { if (!adj.has(nd)) adj.set(nd, []); adj.get(nd).push(i); } nodeP.set(e.from, e.pts[0]); nodeP.set(e.to, e.pts[e.pts.length - 1]); });
    const LEN = { engine: 13, boxcar: 11, flatcar: 11, passenger: 13, caboose: 10 }, GAP = 1.2, Kp = 1.4, CLR = 22;
    // Station stops (2026-10-08): every station building within 16 px of an edge = a stop at its nearest track point (distance along the edge, both directions).
    const STS = data.stations || []; const edgeStops = E.map(e => { const sg = mkSeg(e.pts), out = []; for (const [sx, sz, nm] of STS) { let bd = 16, bk = -1; e.pts.forEach((p, k) => { const d = Math.hypot(p[0] - sx, p[1] - sz); if (d < bd) { bd = d; bk = k; } }); if (bk >= 0) out.push({ d: sg.cum[bk], name: nm }); } return out; });
    const edgeSeg = (i, from) => { const e = E[i], fw = from === e.from, sg = fw ? mkSeg(e.pts, e.from, e.to, i) : mkSeg(e.pts.slice().reverse(), e.to, e.from, i); sg.stops = edgeStops[i].map(s => ({ d: fw ? s.d : sg.len - s.d, name: s.name })).sort((p, q) => p.d - q.d); return sg; };
    const trains = []; const used = new Set();
    const CNT = data.counts || {}; for (let k = 0; k < Math.min(CNT.trains ?? 3, E.length); k++) { const mid = ['passenger'], nm = 2 + Math.floor(rnd() * 4); for (let i = 0; i < nm; i++) mid.push(pick(['boxcar', 'flatcar', 'passenger', 'boxcar', 'flatcar']));
      for (let i = mid.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [mid[i], mid[j]] = [mid[j], mid[i]]; }
      const cars = ['engine', ...mid, 'caboose'].map(kind => ({ kind })); let acc = 0; for (const c of cars) { c.s = (acc + LEN[c.kind] / 2) * Kp; c.half = LEN[c.kind] / 2 * Kp * 0.8; acc += LEN[c.kind] + GAP; } const L = acc * Kp;
      const cand = E.map((e, i) => i).filter(i => !used.has(i) && ![E[i].from, E[i].to].some(nd => [...used].some(u => E[u].from === nd || E[u].to === nd)) && mkSeg(E[i].pts).len > L + 2 * CLR + 10); if (!cand.length) break; const ei = pick(cand); used.add(ei);
      const sg = edgeSeg(ei, rnd() < 0.5 ? E[ei].from : E[ei].to); const fp = cars.find(c => c.kind === 'passenger'); trains.push({ id: k, cars, L, sp: fp ? fp.s : null, stopAt: null, stopName: null, lastStop: null, lastStopD: -1e9, segs: [sg], h: L + CLR + rnd() * (sg.len - L - 2 * CLR), v: 0, dwell: 0, dist: 0, puffs: [], pt: 0, vmax: 20 + rnd() * 4, next: null, served: false, wait: 0, turn: false, patience: 6 + rnd() * 6 }); }
    const holds = (tr, ei) => tr.next === ei || tr.segs.some(q => q.e === ei);
    const freeEdge = (ei, self) => trains.every(o => o === self || !holds(o, ei));
    const nodeBusy = (nd, self) => { const P = nodeP.get(nd); if (!P) return false; for (const o of trains) { if (o === self) continue; for (let s2 = 0; s2 <= o.L; s2 += 4) { const q = at(o, s2); if (Math.hypot(q[0] - P[0], q[1] - P[1]) < CLR - 4) return true; } } return false; };
    let coaches = [];
    const coachOn = (x, z, r) => coaches.some(c => !c.hidden && c.body && c.body.some(p => Math.hypot(p[0] - x, p[1] - z) < r));
    // Stops: a train with a passenger car stops at every station it passes so its FIRST passenger car is centred on the station's track point (head target =
    // station distance + that car's offset; the target may lie on the reserved next edge — until it is reserved the block rule holds the train short of the node,
    // then it pulls up to the mark). Dwell 4–7 s. Dead end (no other edge): stop 3 px short, dwell, run back. A station is not re-served until the train has moved L + 40 px.
    const findStop = (tr, sg, rem) => { if (tr.sp == null) return; let best = null; const cand = [...(sg.stops || []).map(s => ({ ...s, ahead: s.d - tr.h })), ...(tr.next != null && tr.nseg ? tr.nseg.stops.map(s => ({ ...s, ahead: s.d + rem })) : [])];
      for (const s of cand) { const tgt = s.ahead + tr.sp; if (tgt < 0.5 || (s.name === tr.lastStop && tr.dist - tr.lastStopD < tr.L + 40)) continue; if (!best || tgt < best.tgt) best = { tgt, name: s.name }; } if (best) { tr.stopAt = tr.dist + best.tgt; tr.stopName = best.name; } };
    const stepTrain = (tr, dt) => { const sg = tr.segs[tr.segs.length - 1], end = sg.b, rem = sg.len - tr.h, opts = (adj.get(end) || []).filter(i => i !== sg.e), station = !opts.length;
      if (tr.dwell > 0) { tr.v = 0; tr.dwell -= dt; if (tr.dwell <= 0) { if (tr.turn) { reverse(tr, tr.L); tr.turn = false; tr.served = false; tr.next = null; tr.nseg = null; tr.stopAt = null; } else tr.served = true; } }
      else { tr.turn = !opts.length; if (tr.next == null && opts.length && rem < 90) { const fr = opts.filter(i => freeEdge(i, tr)); if (fr.length) tr.next = pick(fr); }
        if (tr.next != null && !tr.nseg) tr.nseg = edgeSeg(tr.next, end); if (tr.stopAt == null) findStop(tr, sg, rem);
        let stop = Infinity; if (station && !tr.served) stop = rem - 3; if (tr.stopAt != null) stop = Math.min(stop, tr.stopAt - tr.dist); if (opts.length && rem < 90 && (tr.next == null || nodeBusy(end, tr))) stop = Math.min(stop, rem - CLR);
        if (!sg.xc) sg.xc = xings(sg); for (const q of sg.xc) { const d = q[0] - tr.h; if (d > 0 && d < 70 && (coachOn(q[1], q[2], 12) || xReserved(q[1], q[2]))) { stop = Math.min(stop, d - 12); tr.yieldC = true; } } // occupied or reserved crossing ahead → stop 12 px short
        tr.yieldC = false; for (let d = 4; d <= 64 && d <= rem; d += 4) { const p = at(tr, -d); if (coachOn(p[0], p[1], 5)) { stop = Math.min(stop, d - 10); tr.yieldC = true; break; } } // anything on the track ahead → stop short
        const vt = stop === Infinity ? tr.vmax : Math.min(tr.vmax, Math.sqrt(2 * 5 * Math.max(0, stop))); tr.v = Math.min(vt, tr.v + 6 * dt); let mv = tr.v * dt; if (stop !== Infinity) mv = Math.min(mv, Math.max(0, stop)); tr.h += mv; tr.dist += mv;
        if (stop !== Infinity && stop - mv < 0.3) { tr.v = 0; if (tr.stopAt != null && tr.stopAt - tr.dist < 0.3) { tr.dwell = 4 + rnd() * 3; tr.lastStop = tr.stopName; tr.lastStopD = tr.dist; tr.stopAt = null; tr.served = false; } else if (station && !tr.served && stop >= rem - 3.5) tr.dwell = 4 + rnd() * 3; else { tr.wait += dt; if (tr.wait > tr.patience && tr.next == null) { reverse(tr, tr.L); tr.nseg = null; tr.stopAt = null; tr.wait = 0; tr.served = false; tr.patience = 6 + rnd() * 6; } } } else tr.wait = 0;
        if (tr.h >= sg.len - 1e-6 && tr.next != null) { const over = Math.max(0, tr.h - sg.len); tr.segs.push(tr.nseg || edgeSeg(tr.next, end)); tr.h = over; tr.next = null; tr.nseg = null; tr.served = false; trim(tr, tr.L + 10); } }
      const eng = pose(tr, tr.cars[0].s, tr.cars[0].half), c = Math.cos(eng.yaw), s = Math.sin(eng.yaw); tr.pt += dt;
      const rate = tr.v > 1 ? 0.09 : 0.35; while (tr.pt >= rate) { tr.pt -= rate; tr.puffs.push({ x: eng.x + c * 4.0 * Kp, z: eng.z + s * 4.0 * Kp, y: eng.y + 7.3 * 1.6, vx: -c * tr.v * 0.3 + (rnd() - 0.5) * 2 + 2, vz: -s * tr.v * 0.3 + (rnd() - 0.5) * 2 - 1, vy: 6 + rnd() * 3, age: 0, life: 2.2 + rnd() * 0.8, rot: rnd() * 6.283 }); }
      for (const p of tr.puffs) { p.age += dt; p.x += p.vx * dt; p.z += p.vz * dt; p.y += p.vy * dt; p.vy *= Math.pow(0.6, dt); p.vx *= Math.pow(0.7, dt); p.vz *= Math.pow(0.7, dt); }
      tr.puffs = tr.puffs.filter(p => p.age < p.life); };
    // ── coaches. Lines = trade-route centre lines (t.tradeLines) + bridge decks. Right-hand traffic: each coach drives LANE px right of the centre line
    // (tapering to 0 over TAPER px onto a bridge; bridges are one coach at a time — the next waits TAPER px short). Every line end is a node; its options =
    // other lines passing within 6 px (14 px at bridges) whose heading turns < TURN° from the arriving heading. An end that is no town and whose options all
    // lead to such ends is dead; coaches never take an option toward a dead end and never spawn heading into one → no U-turns on the road.
    // Town end: 25 % (100 % if no option) the coach enters — hidden 6–14 s — then leaves on any live line touching the town end (temporary; Godot builds town traffic).
    // Spacing: a coach queues 9 px behind one ahead in its lane (slows ≤ 20 px), never passing. Junctions / bridges: zone locks (see 'Conflict zones').
    // Level crossings: waits ≥ 12 px short while a train is within 16 px of the crossing or within 110 px ahead of an engine on that track.
    // Junction split (2026-10-08): coaches can only change road at line ENDS, so a T-junction (one line's end on another's middle) or a crossroads (two middles
    // within 3 px) was one-way / impassable → the road graph fell apart into small islands (the contract caravan shuttled Drekahorn ↔ Sudein ↔ Durton).
    // Every trail is split at each point where another trail's or bridge's end touches it (≤ 6 px) and where another trail's middle crosses it (≤ 3 px, one split per
    // crossing cluster); both pieces share the junction point and must keep ≥ 16 points. Junction zones / lane rules then see a plain end-to-end meeting.
    const trl0 = (data.trails || []).filter(l => l.length >= 12), trl = (() => { const SP = trl0.map(() => new Set()), G0 = new Map(), K0 = (x, z) => (Math.round(x) >> 3) * 4096 + (Math.round(z) >> 3);
      trl0.forEach((l, li) => l.forEach((p, k) => { const key = K0(p[0], p[1]); if (!G0.has(key)) G0.set(key, []); G0.get(key).push(li, k); }));
      const nearest = (P, skip, r) => { const best = new Map(); for (let dz = -8; dz <= 8; dz += 8) for (let dx = -8; dx <= 8; dx += 8) { const L = G0.get(K0(P[0] + dx, P[1] + dz)); if (!L) continue; for (let q = 0; q < L.length; q += 2) { const li = L[q], k = L[q + 1]; if (li === skip) continue; const p = trl0[li][k], d = Math.hypot(p[0] - P[0], p[1] - P[1]); if (d > r) continue; const b = best.get(li); if (!b || d < b[1]) best.set(li, [k, d]); } } return best; };
      const ok = (li, k) => k >= 16 && trl0[li].length - 1 - k >= 16;
      const endsAll = [...trl0.map((l, li) => [[l[0], li], [l[l.length - 1], li]]).flat(), ...(data.bridges || []).filter(l => l.length >= 2).map(l => [[l[0], -1], [l[l.length - 1], -1]]).flat()];
      for (const [P, li0] of endsAll) for (const [li, [k]] of nearest(P, li0, 6)) if (ok(li, k)) SP[li].add(k);
      trl0.forEach((l, li) => { let run = null; for (let k = 16; k < l.length - 16; k++) { const hit = [...nearest(l[k], li, 3).keys()].some(lj => { const [k2] = nearest(l[k], li, 3).get(lj); return ok(lj, k2); }); if (hit) { if (!run) run = [k, k]; else run[1] = k; } else if (run) { SP[li].add((run[0] + run[1]) >> 1); run = null; } } });
      const out = []; trl0.forEach((l, li) => { const ks = [...SP[li]].sort((a, b) => a - b), cut = []; let last = 0; for (const k of ks) if (k - last >= 16 && l.length - 1 - k >= 16) { cut.push(k); last = k; } let s = 0; for (const k of cut) { out.push(l.slice(s, k + 1)); s = k; } out.push(l.slice(s)); }); return out; })();
    const NT = trl.length, BRL = data.bridges || [], lines = trl.concat(BRL), grid = new Map();
    const dg = new Map(); BRL.forEach((l, bid) => l.forEach(p => { const key = GK(p[0], p[1]); if (!dg.has(key)) dg.set(key, []); dg.get(key).push(bid, p); }));
    const onDeck = (x, z) => { let r = -1; near8(dg, x, z, L => { for (let q = 0; q < L.length; q += 2) { const p = L[q + 1]; if (Math.hypot(p[0] - x, p[1] - z) < 3.4) { r = L[q]; return true; } } return false; }); return r; };
    // bridge zones along a seg (trail lines cross bridge decks too): [{ d0, d1, bid }]
    const zonesOf = sg => sg.zones || (sg.zones = (() => { const out = []; let cur = null; for (let i = 0; i < sg.pts.length; i++) { const b2 = onDeck(sg.pts[i][0], sg.pts[i][1]); if (b2 >= 0) { if (cur && cur.bid === b2) cur.d1 = sg.cum[i]; else { cur = { d0: sg.cum[i], d1: sg.cum[i], bid: b2 }; out.push(cur); } } else cur = null; } return out; })());
    lines.forEach((l, li) => l.forEach((p, k) => { const key = GK(p[0], p[1]); if (!grid.has(key)) grid.set(key, []); grid.get(key).push(li, k); }));
    const PULL = 6, LC = 11.6 * Kp, LANE = 2.6, TAPER = 12, TURN = 105 * Math.PI / 180 /* junction turns up to 105° (a T-junction is ~90°; the trail geometry itself stays < 55°); U-turns never */;
    const lineSeg = (li, k0, dir) => { const l = lines[li], pts = dir > 0 ? l.slice(k0) : l.slice(0, k0 + 1).reverse(), sg = mkSeg(pts, null, null, li); sg.side = dir > 0 ? 1 : 0; return sg; };
    const hdg = (l, k, dir, n) => { const p = l[k], q = l[Math.max(0, Math.min(l.length - 1, k + dir * n))]; return [q[0] - p[0], q[1] - p[1]]; };
    const nearPts = (P, li, rad) => { const best = new Map(); near8(grid, P[0], P[1], L => { for (let q = 0; q < L.length; q += 2) { const lj = L[q], k = L[q + 1]; if (lj === li) continue; const p = lines[lj][k], d = Math.hypot(p[0] - P[0], p[1] - P[1]); if (d > rad(lj)) continue; const b2 = best.get(lj); if (!b2 || d < b2[1]) best.set(lj, [k, d]); } return false; }); return best; };
    // Conflict zones (2026-10-08). Junction zones = 4 px cells within 5 px of two different trail lines, 8-connected → one id each. Bridge zones = the deck ('b' + id).
    // seg.zl = [{ zid, a, b, line, dir }] intervals along a seg (junction ± 3 px, bridge ± TAPER so the waiting coach is fully in its lane).
    const JZ = new Map(), JK = (x, z) => (Math.round(x) >> 2) * 8192 + (Math.round(z) >> 2); { const mark = new Set();
      for (let li = 0; li < NT; li++) for (const p of lines[li]) { if (onDeck(p[0], p[1]) >= 0) continue; if (near8(grid, p[0], p[1], L => { for (let q = 0; q < L.length; q += 2) { const lj = L[q]; if (lj === li || lj >= NT) continue; const r = lines[lj][L[q + 1]]; if (Math.abs(r[0] - p[0]) < 5 && Math.abs(r[1] - p[1]) < 5 && Math.hypot(r[0] - p[0], r[1] - p[1]) < 5) return true; } return false; })) mark.add(JK(p[0], p[1])); }
      let nz = 0; for (const k of mark) { if (JZ.has(k)) continue; const id = 'j' + nz++, st = [k]; JZ.set(k, id); while (st.length) { const c0 = st.pop(), cx = Math.floor(c0 / 8192), cz = c0 % 8192; for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const k2 = (cx + dx) * 8192 + (cz + dz); if (mark.has(k2) && !JZ.has(k2)) { JZ.set(k2, id); st.push(k2); } } } } }
    const zoneAtP = (x, z) => { const b2 = onDeck(x, z); return b2 >= 0 ? 'b' + b2 : JZ.get(JK(x, z)) || null; };
    const zlOf = sg => sg.zl || (sg.zl = (() => { const out = []; let cur = null; for (let i = 0; i < sg.pts.length; i++) { const zid = zoneAtP(sg.pts[i][0], sg.pts[i][1]); if (zid && cur && cur.zid === zid) { cur.b = sg.cum[i]; cur.i1 = i; } else if (zid) { cur = { zid, a: sg.cum[i], b: sg.cum[i], i0: i, i1: i, line: sg.e }; out.push(cur); } else cur = null; }
      for (const q of out) { const br = q.zid[0] === 'b', m = br ? TAPER : 3, P = sg.pts[q.i0], Q = sg.pts[q.i1]; q.a -= m; q.b += m; q.dir = [Q[0] - P[0], Q[1] - P[1]]; } return out; })());
    const holders = new Map(); // zid → Map(coach → { line, dir })
    // junction: compatible only when both pass straight through on the same single line (opposite lanes / following); bridge: same direction only.
    const compat = (zid, mine, other) => zid[0] === 'b' ? mine.dir[0] * other.dir[0] + mine.dir[1] * other.dir[1] > 0 : mine.lines.size === 1 && other.lines.size === 1 && [...mine.lines][0] === [...other.lines][0];
    const claim = (c, S, base) => { const M = new Map(); for (const z of S) { const m = M.get(z.zid) || { lines: new Set(), dir: z.dir, end: -1e9 }; m.lines.add(z.line); m.end = Math.max(m.end, z.b); M.set(z.zid, m); } return M; };
    const ends = lines.map((l, li) => [0, 1].map(side => { const n = l.length, k = side ? n - 1 : 0, P = l[k], hin = hdg(l, k, side ? -1 : 1, 8), arr = [-hin[0], -hin[1]], opts = [];
      for (const [lj, [k2]] of nearPts(P, li, lj => (lj >= NT || li >= NT ? 14 : 6))) { const n2 = lines[lj].length, mn = lj >= NT || li >= NT ? 3 : 15;
        for (const dir of [1, -1]) { if (dir > 0 ? n2 - 1 - k2 < mn : k2 < mn) continue; const out = hdg(lines[lj], k2, dir, 8), a2 = ang2(arr, out); if (a2 > TURN) continue; opts.push({ lj, k: k2, dir, side: dir > 0 ? 1 : 0, w: Math.cos(a2) + 0.2 }); } }
      return { P, opts, town: !!(data.inTown && data.inTown(P[0], P[1])), dead: false }; }));
    for (let ch = true; ch;) { ch = false; for (const E2 of ends) for (const en of E2) { if (en.dead || en.town) continue; if (en.opts.every(o => ends[o.lj][o.side].dead)) { en.dead = true; ch = true; } } }
    const liveOpts = en => en.opts.filter(o => !ends[o.lj][o.side].dead);
    const exitOpts = en => { const out = []; for (const [lj, [k2]] of nearPts(en.P, -1, () => 8)) { const n2 = lines[lj].length; for (const dir of [1, -1]) { if ((dir > 0 ? n2 - 1 - k2 : k2) < 15 || ends[lj][dir > 0 ? 1 : 0].dead || ends[lj][dir > 0 ? 1 : 0] === en) continue; out.push({ lj, k: k2, dir }); } } return out; };
    // level crossings (trail × track): per trail seg (distance along it) and per rail seg (distance along the edge)
    const rg = new Map(); E.forEach(e => e.pts.forEach(p => { const key = GK(p[0], p[1]); if (!rg.has(key)) rg.set(key, []); rg.get(key).push(p); }));
    const railNear = (x, z, r) => near8(rg, x, z, L => L.some(p => Math.hypot(p[0] - x, p[1] - z) < r));
    const crossOf = sg => { const out = []; let inC = false, cur = null; for (let i = 0; i < sg.pts.length; i++) { const on = railNear(sg.pts[i][0], sg.pts[i][1], 7); if (on && !inC) { if (cur && sg.cum[i] - cur.d1 < LC + 8) { /* gap too short to wait in → same band */ } else { cur = { d: sg.cum[i], d1: sg.cum[i], x: sg.pts[i][0], z: sg.pts[i][1], pts: [] }; out.push(cur); } } if (on) { cur.d1 = sg.cum[i]; if (!cur.pts.length || sg.cum[i] - cur.pts[cur.pts.length - 1][2] > 6) cur.pts.push([sg.pts[i][0], sg.pts[i][1], sg.cum[i]]); } inC = on; } return out; }; // rail bands (road within 7 px of a track); bands closer than LC + 8 px merge (a road hugging the track is one band) // rail bands: d (start) … d1 (end) within 7 px of a track
    const trailNear = (x, z, r) => near8(grid, x, z, L => { for (let q = 0; q < L.length; q += 2) { if (L[q] >= NT) continue; const p = lines[L[q]][L[q + 1]]; if (Math.hypot(p[0] - x, p[1] - z) < r) return true; } return false; });
    function xings(sg) { const out = []; let inC = false; for (let i = 0; i < sg.pts.length; i++) { const on = trailNear(sg.pts[i][0], sg.pts[i][1], 6); if (on && !inC) out.push([sg.cum[i], sg.pts[i][0], sg.pts[i][1]]); inC = on; } return out; }
    // trainNear: any car within 16 px of the crossing, or a MOVING train whose next 110 px reach it. A stopped train (station dwell / block wait) doesn't hold coaches
    // back: a coach that starts across reserves the crossing (c.xres) and trains never move onto a reserved crossing (see stepTrain).
    const trainNear = (x, z, pts) => { const P = pts && pts.length ? pts : [[x, z]]; for (const tr of trains) { if (tr.yieldC) continue; /* holding for a coach on the track: it won't move until that clears */ const s0 = tr.v > 0.5 ? -110 : 0; for (let s2 = s0; s2 <= tr.L; s2 += 6) { const p = at(tr, s2); if (P.some(q => Math.hypot(p[0] - q[0], p[1] - q[1]) < 16)) return true; } } return false; };
    const xReserved = (x, z) => coaches.some(c => c.xres && c.xres.some(q => (q.pts || [[q.x, q.z]]).some(p => Math.hypot(p[0] - x, p[1] - z) < 12)));
    const reserveX = (c, q, distAhead) => { (c.xres || (c.xres = [])).push({ x: q.x, z: q.z, pts: q.pts, until: c.dist + distAhead + LC + 4 }); };
    // spawn: on trail lines only, heading toward a live end
    { const tot = trl.reduce((q, l) => q + l.length, 0), N = Math.min(CNT.coaches ?? 60, Math.round(tot / 450));
      for (let i = 0, tries = 0; coaches.length < N && NT && tries < N * 20; tries++) { let r = rnd() * tot, li = 0; while (li < NT - 1 && r > lines[li].length) { r -= lines[li].length; li++; }
        const dir = rnd() < 0.5 ? 1 : -1, sg = lineSeg(li, dir > 0 ? 0 : lines[li].length - 1, dir); if (sg.len < LC + 8 || ends[li][sg.side].dead) continue; const h = LC + rnd() * (sg.len - LC - 4); if (crossOf(sg).some(q2 => q2.d > h - LC - 6 && q2.d < h + 6) || zlOf(sg).some(z => z.b > h - LC - 4 && z.a < h + 30)) continue;
        const a = Math.floor(rnd() * 9); let b = Math.floor(rnd() * 9); if (b === a) b = (a + 1 + Math.floor(rnd() * 8)) % 9;
        const c = { id: coaches.length, segs: [sg], h, v: 0, vmax: 6.5 + rnd() * 2.5, dwell: 0, dist: rnd() * 10, spec: { a, b, sa: Math.floor(rnd() * 3), sb: Math.floor(rnd() * 3), ba: rnd() < 0.5 ? 1 : 0, bb: rnd() < 0.5 ? 1 : 0 }, prev: -1, plan: null, locks: new Map(), nseg: null };
        const P0 = at(c, LC / 2); if (coaches.some(o => o.body && o.body.some(p => Math.hypot(p[0] - P0[0], p[1] - P0[1]) < 14))) continue; coachBody(c); coaches.push(c); } }
    function laneAt(c, s) { const [k, o] = segAt(c, s), sg = c.segs[k]; let d = 1e9; const zd = (z, off) => { const a2 = z.d0 + off, b2 = z.d1 + off; return o < a2 ? a2 - o : o > b2 ? o - b2 : 0; };
      for (const z of zonesOf(sg)) d = Math.min(d, zd(z, 0)); if (k > 0) { const pv = c.segs[k - 1]; for (const z of zonesOf(pv)) d = Math.min(d, zd(z, -pv.len)); } if (k < c.segs.length - 1) for (const z of zonesOf(c.segs[k + 1])) d = Math.min(d, zd(z, sg.len));
      if (k === c.segs.length - 1 && c.plan && c.plan.opt && c.plan.opt.lj >= NT) d = Math.min(d, Math.max(0, sg.len - o)); return LANE * Math.max(0, Math.min(1, d / TAPER)) + (c.pull || 0) * PULL * (c.pside || 1); }
    function lanePose(c, s, half) { const p = pose(c, s, half), nx = -Math.sin(p.yaw), nz = Math.cos(p.yaw), g0 = data.ground(p.x, p.z), TT = (data.terrace || 8) * 0.5; let l = laneAt(c, s); /* ledge guard: never hang the lane off a terrace edge beside the road — halve, then centre */ for (let k = 0; k < 3 && l !== 0; k++) { if (Math.abs(data.ground(p.x + nx * (l + Math.sign(l) * 1.5), p.z + nz * (l + Math.sign(l) * 1.5)) - g0) <= TT) break; l = k < 1 ? l / 2 : 0; } p.x += nx * l; p.z += nz * l; return p; }
    function coachBody(c) { const hp = lanePose(c, 1, 1), cp = lanePose(c, 8.2 * Kp, 2.4 * Kp), rp = lanePose(c, LC - 1, 1); const tp = lanePose(c, 2.4 * Kp, 2 * Kp); c.body = [[hp.x, hp.z], [tp.x, tp.z], [cp.x, cp.z], [rp.x, rp.z]]; c.hu = [Math.cos(tp.yaw), Math.sin(tp.yaw)]; }
    // Destinations (2026-10-08, contract caravans): every coach heads for a goal town end (c.goal). Road graph = line ends; an option at an end leads to the far
    // end of the line it joins, cost = px along it. distTo(goal) = reverse Dijkstra (cached per goal). At each end the coach takes the option that minimises
    // remaining distance; at the goal it enters the town (hidden 6–14 s), then picks a new goal town ≥ 300 px of road away. ETA = (rest of seg + D[end]) / vmax.
    const nodeId = (li, side) => li * 2 + side, lineLen = li => { const l = lines[li]; let s = 0; for (let q = 1; q < l.length; q++) s += Math.hypot(l[q][0] - l[q - 1][0], l[q][1] - l[q - 1][1]); return s; }, LL = lines.map((_, li) => lineLen(li));
    const optCost = o => { const l = lines[o.lj], kEnd = o.dir > 0 ? l.length - 1 : 0; return LL[o.lj] * Math.abs(kEnd - o.k) / Math.max(1, l.length - 1); };
    // Towns are transit nodes (2026-10-08): a coach that enters a town at one road end may leave by ANY road of that town (exitOptsTown). The road graph gets an
    // edge town-end → every exit start of the same town (cost 40 px ≈ crossing the streets). Without these, only roads meeting end-to-end connected (median 2 towns reachable).
    ends.forEach((E2, li) => E2.forEach(en => { if (en.town && li < NT && data.townAt) en.name = data.townAt(en.P[0], en.P[1]); }));
    const TBN = new Map(); ends.forEach((E2, li) => E2.forEach(en => { if (en.town && en.name) { if (!TBN.has(en.name)) TBN.set(en.name, []); TBN.get(en.name).push(en); } }));
    const exitOptsTown = en => { const L = en.name && TBN.get(en.name) || [en], seen = new Set(), out = []; for (const e2 of L) for (const o of exitOpts(e2)) { const k = o.lj + ':' + o.dir; if (!seen.has(k) && optCost(o) >= LC + 6) { seen.add(k); out.push(o); } } return out; }; // exits shorter than a rig are skipped (the coach couldn't fit on them → endless 3 s retries)
    const REV = new Map(), addE = (from, to, w) => { if (!REV.has(to)) REV.set(to, []); REV.get(to).push([from, w]); };
    ends.forEach((E2, li) => E2.forEach((en, side) => { for (const o of liveOpts(en)) addE(nodeId(li, side), nodeId(o.lj, o.side), optCost(o)); if (en.town && en.name) for (const o of exitOptsTown(en)) addE(nodeId(li, side), nodeId(o.lj, o.dir > 0 ? 1 : 0), optCost(o) + 40); }));
    const FWD = new Map(); for (const [to, L] of REV) for (const [from, w] of L) { if (!FWD.has(from)) FWD.set(from, []); FWD.get(from).push([to, w]); }
    // fromDist(n): forward Dijkstra (cached) → every end reachable from n with its road distance. Goals are only ever picked from these (the turn filter makes the
    // road graph directed; a random goal could be unreachable and the coach would bounce back into the town it just left).
    const FC = new Map(), fromDist = n0 => { if (FC.has(n0)) return FC.get(n0); const D = new Map([[n0, 0]]), Q = [[0, n0]]; while (Q.length) { Q.sort((a, b) => a[0] - b[0]); const [d, n] = Q.shift(); if (d > D.get(n)) continue; for (const [p, w] of (FWD.get(n) || [])) { const nd = d + w; if (!(D.get(p) <= nd)) { D.set(p, nd); Q.push([nd, p]); } } } FC.set(n0, D); return D; };
    const goalFrom = (c, n0, avoidName) => { const D = fromDist(n0), cand = townEnds.filter(g => { const d = D.get(g), nm = ends[g >> 1][g & 1].name; return d != null && nm !== avoidName && nm !== c.goalName && d >= 300 && d <= 1800; /* trip 300–1800 px of road (≈ 1–4 min real time at coach speed) */ }), any = townEnds.filter(g => D.get(g) != null && ends[g >> 1][g & 1].name !== avoidName);
      const pickL = cand.length ? cand : any; if (!pickL.length) return false; c.goal = pick(pickL); c.goalName = ends[c.goal >> 1][c.goal & 1].name; return true; };
    const DC = new Map(), distTo = g => { if (DC.has(g)) return DC.get(g); const D = new Map([[g, 0]]), Q = [[0, g]]; while (Q.length) { Q.sort((a, b) => a[0] - b[0]); const [d, n] = Q.shift(); if (d > D.get(n)) continue; for (const [p, w] of (REV.get(n) || [])) { const nd = d + w; if (!(D.get(p) <= nd)) { D.set(p, nd); Q.push([nd, p]); } } } DC.set(g, D); return D; };
    const townEnds = []; ends.forEach((E2, li) => E2.forEach((en, side) => { if (en.town && li < NT) { en.name = data.townAt ? data.townAt(en.P[0], en.P[1]) : null; if (en.name) townEnds.push(nodeId(li, side)); } }));
    const pickGoal = (c, from) => { const D0 = from != null ? null : null; const cand = townEnds.filter(g => { if (c.goalName && ends[g >> 1][g & 1].name === c.goalName) return false; const D = distTo(g); return from == null || (D.get(from) > 300 && D.get(from) < 4000); }); c.goal = cand.length ? pick(cand) : (townEnds.length ? pick(townEnds) : null); c.goalName = c.goal != null ? ends[c.goal >> 1][c.goal & 1].name : null; };
    for (const c of coaches) { const sg = c.segs[c.segs.length - 1]; if (!goalFrom(c, nodeId(sg.e, sg.side), null)) pickGoal(c, null); }
    const planFor = c => { const sg = c.segs[c.segs.length - 1], en = ends[sg.e][sg.side], lo = liveOpts(en), here = nodeId(sg.e, sg.side);
      if (c.goal != null && (here === c.goal || (en.town && en.name && en.name === c.goalName))) return { town: en, arrived: true }; // any road into the goal town counts
      if (c.goal != null) { const D = distTo(c.goal); let best = null, bd = Infinity; for (const o of lo) { const d = optCost(o) + (D.get(nodeId(o.lj, o.side)) ?? Infinity) + (o.lj === c.prev ? 40 : 0); if (d < bd) { bd = d; best = o; } } let td = Infinity; if (en.town && en.name) for (const o of exitOptsTown(en)) td = Math.min(td, optCost(o) + 40 + (D.get(nodeId(o.lj, o.dir > 0 ? 1 : 0)) ?? Infinity)); if (td < bd) return { town: en }; /* shortest way runs through this town → transit */ if (best && bd < Infinity) return { opt: best, go: false }; if (en.town) return { town: en }; }
      if (en.town && (!lo.length || rnd() < 0.25)) return { town: en }; if (!lo.length) return { town: en }; // (fallback: no live option — hide like a town)
      let r = rnd() * lo.reduce((q, o) => q + o.w * (o.lj === c.prev ? 0.3 : 1), 0), o = lo[0]; for (const q of lo) { r -= q.w * (q.lj === c.prev ? 0.3 : 1); if (r <= 0) { o = q; break; } } return { opt: o, go: false }; };
    // connSeg: continue from the end point E straight onto the new line at its first point ≥ 1.5 px ahead of E (no backward hop at the junction).
    const connSeg = (sg, o) => { const E = sg.pts[sg.pts.length - 1], Q = sg.pts[Math.max(0, sg.pts.length - 9)], u = [E[0] - Q[0], E[1] - Q[1]], ul = Math.hypot(u[0], u[1]) || 1, L = lines[o.lj]; let k = o.k;
      for (let n = 0; n < 14; n++) { const p = L[k]; if (((p[0] - E[0]) * u[0] + (p[1] - E[1]) * u[1]) / ul >= 1.5) break; const k2 = k + o.dir; if (k2 < 0 || k2 >= L.length) break; k = k2; }
      const s2 = lineSeg(o.lj, k, o.dir), s3 = mkSeg([E, ...s2.pts], null, null, o.lj); s3.side = s2.side; return s3; };
    // exitClear: no same-direction coach body within 2.8 px of my lane line between a and b px ahead of my head (current seg, then c.nseg).
    const routeAt = (c, d, rem) => { const sg = c.segs[c.segs.length - 1]; if (d <= rem || !c.nseg) { const q = { segs: [sg], h: c.h + Math.min(d, rem) }; return [at(q, 0), at(q, 1)]; } const q = { segs: [c.nseg], h: Math.min(c.nseg.len, d - rem) }; return [at(q, 0), at(q, 1)]; };
    const exitClear = (c, a, b, rem) => { for (let d = Math.max(0, a); d <= b; d += 2) { const [P, Q] = routeAt(c, d, rem), yaw = Math.atan2(P[1] - Q[1], P[0] - Q[0]), x = P[0] - Math.sin(yaw) * LANE, z = P[1] + Math.cos(yaw) * LANE;
        for (const o of coaches) { if (o === c || o.hidden || o.parked || !o.body || o.hu[0] * Math.cos(yaw) + o.hu[1] * Math.sin(yaw) < 0.3) continue; if (o.body.some(p => Math.abs(p[0] - x) < 3 && Math.abs(p[1] - z) < 3)) return false; } } return true; };
    const queueAhead = (c, dist) => { const H = c.body[0], u = c.hu; return coaches.some(o => { if (o === c || o.hidden || !o.body || u[0] * o.hu[0] + u[1] * o.hu[1] < 0.5) return false; return o.body.some(R => { const dx = R[0] - H[0], dz = R[1] - H[1], al = dx * u[0] + dz * u[1]; return al > 0 && al < dist && Math.abs(dx * u[1] - dz * u[0]) < 3 && o.v < 2; }); }); };
    // Night camp (2026-10-08): at night every coach on the road finds a spot clear of junction / bridge zones, rail bands and other coaches (≥ 14 px), brakes,
    // pulls over PULL px off its lane (right side; left if the right is water) over 1.5 s and lights a campfire beside the team. Coaches in towns stay there.
    // Parked coaches drop their zone locks and are ignored by traffic rules. Day: the fire goes out, the coach eases back into its lane and carries on.
    // Camp layout (pull 0 → 1): rear point stays on the lane (+ PULL px off it × pull), the coach swings θc = 0.45 rad and the team θt = 1.0 rad toward the camp side,
    // so the rig curves round the fire, noses away from the road. Fire = 5 px out from the coach–team joint, 2 px back. Returns poses + fire point.
    const TOP = (x, z) => (data.top || data.ground)(x, z);
    const campLayout = (c, pull, side) => { const r = lanePose(c, LC - 1, 1), ref = lanePose(c, 8.2 * Kp, 2.4 * Kp), psi = ref.yaw, s = side || c.pside || 1, h = [Math.cos(psi), Math.sin(psi)], n = [-h[1] * s, h[0] * s];
      const a1 = psi + s * 0.45 * pull, a2 = psi + s * 1.0 * pull, d1 = [Math.cos(a1), Math.sin(a1)], d2 = [Math.cos(a2), Math.sin(a2)];
      const cc = [r.x + d1[0] * 4.76, r.z + d1[1] * 4.76], J = [r.x + d1[0] * 8.6, r.z + d1[1] * 8.6], tc = [J[0] + d2[0] * 4.3, J[1] + d2[1] * 4.3], F = [J[0] + n[0] * 5 - h[0] * 2, J[1] + n[1] * 5 - h[1] * 2];
      return { coach: { x: cc[0], z: cc[1], yaw: a1 }, team: { x: tc[0], z: tc[1], yaw: a2 }, fire: F, rear: [r.x, r.z], n }; };
    // Safe camp spot (checked before braking, at the point the coach will stop): no junction / bridge zone and no seg end within the stopping stretch; rig + fire
    // ≥ 10 px from any track; fire on dry land outside towns, within one terrace of the road; ≥ 24 px from other camps and ≥ 14 px from other coaches. Side: right, else left.
    const wetAt = (x, z) => data.ground(x, z) <= data.ground(-10, -10) + 0.01;
    const campOK = (c, side, ahead) => { const sh = (P) => [P[0] + c.hu[0] * ahead, P[1] + c.hu[1] * ahead], L = campLayout(c, 1, side), F = sh(L.fire), pts = [sh([L.coach.x, L.coach.z]), sh([L.team.x, L.team.z]), sh(L.rear), F];
      if (pts.some(p => railNear(p[0], p[1], 10)) || c.body.some(p => railNear(p[0], p[1], 10))) return false; if (wetAt(F[0], F[1]) || pts.some(p => wetAt(p[0], p[1]))) return false;
      if (data.inTown && (data.inTown(F[0], F[1]) || data.inTown(pts[1][0], pts[1][1]))) return false; const T0 = TOP(L.rear[0], L.rear[1]); if (pts.some(p => Math.abs(TOP(p[0], p[1]) - T0) > 0.8 * (data.terrace || 1))) return false;
      for (const o of coaches) { if (o === c || o.hidden || !o.body) continue; if (o.camp && Math.hypot(o.camp[0] - F[0], o.camp[1] - F[1]) < 24) return false; if (o.body.some(p => pts.some(q => Math.hypot(p[0] - q[0], p[1] - q[1]) < 14))) return false; } return true; };
    const canPark = (c, rem) => { const brake = c.v * c.v / 8 + 1, sg = c.segs[c.segs.length - 1];
      for (const z of zlOf(sg)) if (z.a - c.h < brake + 6 && z.b - c.h > -LC - 6) return 0; if (rem < brake + 6) return 0;
      for (const q of sg.cross) if (q.d - c.h < brake + 14 && q.d1 - c.h > -LC - 10) return 0;
      for (const s of [1, -1]) if (campOK(c, s, brake)) return s; return 0; };
    const parkStep = (c, dt) => { if (night) { if (c.parked) { c.pull = Math.min(1, (c.pull || 0) + dt / 1.5); c.v = 0; campBody(c); return true; } return false; }
      if (c.parked) { c.camp = null; c.pull = Math.max(0, (c.pull || 0) - dt / 1.5); c.v = 0; if (c.pull <= 0) { c.parked = false; c.pull = 0; coachBody(c); } else campBody(c); return true; } return false; };
    const campBody = c => { const L = campLayout(c, c.pull || 0); c.body = [[L.team.x + Math.cos(L.team.yaw) * 2, L.team.z + Math.sin(L.team.yaw) * 2], [L.team.x, L.team.z], [L.coach.x, L.coach.z], L.rear]; c.camp = night && c.pull >= 0.8 ? L.fire : null; };
    const stepCoach = (c, dt) => {
      if (c.hidden && night) return; if (parkStep(c, dt)) return;
      if (c.hidden) { c.dwell -= dt; if (c.dwell > 0) return; const ex = exitOptsTown(c.town); if (!ex.length) { c.dwell = 5; return; } // exits: only lines whose far end leads somewhere else (reachable goal, not straight back into this town); else pick a goal reachable from an exit
        const farName = o => { const en2 = ends[o.lj][o.dir > 0 ? 1 : 0]; return en2.name || null; }, reach = (D2, o) => (D2.get(nodeId(o.lj, o.dir > 0 ? 1 : 0)) ?? Infinity) + optCost(o);
        if (c.transit && c.goal != null && !c.goalPicked) { const DT = distTo(c.goal), best = ex.filter(o => reach(DT, o) < Infinity).sort((p, q) => reach(DT, p) - reach(DT, q))[0]; if (best) { c.exitPick = best; c.goalPicked = true; } } // passing through: keep the destination, leave by the road toward it
        if (!c.goalPicked) { c.exitPick = null; const exs = ex.slice().sort(() => rnd() - 0.5); for (const o of exs) if (goalFrom(c, nodeId(o.lj, o.dir > 0 ? 1 : 0), c.stayName)) { c.exitPick = o; break; } c.goalPicked = true; } // goal + the exit it was found from are chosen together
        const D = c.goal != null ? distTo(c.goal) : null, o = c.exitPick && ex.some(q => q.lj === c.exitPick.lj && q.dir === c.exitPick.dir) ? c.exitPick : D ? ex.filter(o2 => reach(D, o2) < Infinity).concat(ex).slice().sort((a, b) => ((D.get(nodeId(a.lj, a.dir > 0 ? 1 : 0)) ?? 1e9) + optCost(a)) - ((D.get(nodeId(b.lj, b.dir > 0 ? 1 : 0)) ?? 1e9) + optCost(b)))[0] : pick(ex), sg = lineSeg(o.lj, o.k, o.dir); if (sg.len < LC + 4) { c.dwell = 1; c.goalPicked = false; c.exitPick = null; return; }
        if (crossOf(sg).some(q2 => q2.d < LC + 20 && trainNear(q2.x, q2.z))) { c.dwell = 2; return; } // don't step out onto a level crossing with a train coming
        const q = { segs: [sg], h: LC }, QB = [at(q, 0), at(q, LC / 2), at(q, LC)]; if (coaches.some(o2 => o2 !== c && !o2.hidden && o2.body && o2.body.some(p => QB.some(P0 => Math.hypot(p[0] - P0[0], p[1] - P0[1]) < 9)))) { c.dwell = 2; return; }
        if (zlOf(sg).some(z => z.a < LC + 30)) { const M = claim(c, zlOf(sg).filter(z => z.a < LC + 30)); if ([...M].some(([zid, mine]) => { const H2 = holders.get(zid); return H2 && [...H2].some(([o, m]) => o !== c && !compat(zid, mine, m)); })) { c.dwell = 1.5; return; } for (const [zid, mine] of M) { if (!holders.has(zid)) holders.set(zid, new Map()); holders.get(zid).set(c, mine); c.locks.set(zid, c.dist + mine.end - LC + LC + 2); } }
        c.segs = [sg]; c.h = LC; c.hidden = false; c.plan = null; c.nseg = null; c.prev = -1; c.v = 0; c.goalPicked = false; c.stayName = null; coachBody(c); return; }
      const sg = c.segs[c.segs.length - 1], rem = sg.len - c.h; if (!sg.cross) sg.cross = crossOf(sg); const ensurePlan = () => { if (!c.plan) { c.plan = planFor(c); if (c.plan.opt) c.nseg = connSeg(sg, c.plan.opt); } }; if (rem < 60) ensurePlan();
      let stop = Infinity, vt = c.vmax; c.why = null;
      if (c.xres) c.xres = c.xres.filter(q => c.dist < q.until); const mine = cr => c.xres && c.xres.some(q => Math.hypot(q.x - cr.x, q.z - cr.z) < 2);
      for (const cr of sg.cross) { const d = cr.d - c.h; if (d > 0 && d < 24 && !mine(cr)) { const tn = trainNear(cr.x, cr.z, cr.pts); if (tn || queueAhead(c, d + LC + 8)) { stop = Math.min(stop, d - 12); c.why = tn ? 'train' : 'xroom'; } else if (d < 14) reserveX(c, cr, cr.d1 - c.h); } } // level crossing: no train near and room on the far side
      // zone locks: before the head reaches a zone (≤ 30 px), take it together with every zone that follows within LC + 12 px of its exit, and only if the
      // LC + 12 px after the last one are clear (room for the whole rig + the 9 px following gap) → a coach never stops inside a junction / on a bridge, so waits can't form a cycle.
      for (const [zid, until] of c.locks) if (c.dist >= until) { c.locks.delete(zid); const H2 = holders.get(zid); if (H2) H2.delete(c); }
      const ahead = () => { const out = []; for (const z of zlOf(sg)) out.push({ ...z, a: z.a - c.h, b: z.b - c.h }); if (c.nseg) for (const z of zlOf(c.nseg)) out.push({ ...z, a: z.a + rem, b: z.b + rem }); return out.filter(z => z.b > -LC); };
      let Z = ahead().filter(z => !c.locks.has(z.zid) && z.a < 30);
      if (Z.length) { let S = [Z[0]], last = Z[0].b; for (let pass = 0; pass < 2; pass++) { if (last + LC + 12 > rem) ensurePlan(); const all = ahead(); for (const z of all) if (!c.locks.has(z.zid) && z.a <= last + LC + 12 && !S.some(q => q.zid === z.zid && q.a === z.a)) { S.push(z); last = Math.max(last, z.b); } }
        const lead = Z[0].a < 2 || exitClear(c, 1, Z[0].a + 2, rem); // a coach queued behind another never claims ahead of it (the leader goes first)
        const XB = [...sg.cross.map(q => ({ d: q.d - c.h, d1: q.d1 - c.h, x: q.x, z: q.z, pts: q.pts })), ...(c.nseg ? (c.nseg.cross || (c.nseg.cross = crossOf(c.nseg))).map(q => ({ d: q.d + rem, d1: q.d1 + rem, x: q.x, z: q.z, pts: q.pts })) : [])];
        // waiting spot: Z[0].a − 1, pulled back to 12 px before any rail band the waiting body would touch (a coach never waits on / beside a track)
        let wAt = Z[0].a - 1; for (const q of XB) if (q.d1 > wAt - LC - 4 && q.d < wAt + 2 && q.d > 0) wAt = Math.min(wAt, q.d - 12);
        const xing = XB.some(q => q.d1 > wAt && q.d < last + LC + 12 && !mine(q) && trainNear(q.x, q.z, q.pts)); // a crossing I already reserved is mine: the train is holding for me // no claim while a train is near a level crossing on the way through // no claim while a train is near a level crossing inside it
        const room = lead && !xing && ((c.plan && c.plan.town && last + LC + 12 > rem) || exitClear(c, last, last + LC + 12, rem));
        const M = claim(c, S), ok = room && [...M].every(([zid, mine]) => { const H2 = holders.get(zid); if (!H2) return true; for (const [o, m] of H2) if (o !== c && !compat(zid, mine, m)) return false; return true; });
        if (ok || Z[0].a < -1) { for (const q of XB) if (q.d1 > wAt && q.d < last + LC + 12) reserveX(c, q, q.d1); for (const [zid, mine] of M) { if (!holders.has(zid)) holders.set(zid, new Map()); holders.get(zid).set(c, mine); c.locks.set(zid, c.dist + mine.end + LC + 2); } c.wait = 0; }
        else { stop = Math.min(stop, Math.max(0, wAt)); c.wait = (c.wait || 0) + dt; c.why = !lead ? 'queue' : xing ? 'train' : room ? 'zone' : 'exit'; c.whyZ = Z[0].zid; } }
      // following: same-direction coach ahead in my lane → queue 9 px behind (slow ≤ 20 px)
      const H = c.body[0], u = c.hu;
      const mySg = c.segs[c.segs.length - 1]; for (const o of coaches) { if (o === c || o.hidden || o.parked || !o.body) continue; if (u[0] * o.hu[0] + u[1] * o.hu[1] <= 0.5) continue; const oSg = o.segs[o.segs.length - 1]; if (oSg.e === mySg.e && oSg.side !== mySg.side) continue; /* same road, opposite direction: other lane (a hook can make headings agree briefly) */ if ((H[0] - o.body[0][0]) * o.hu[0] + (H[1] - o.body[0][1]) * o.hu[1] > 0) continue; /* I'm ahead of its head: it follows me, not the reverse */
        for (const R2 of o.body.slice(1)) { const dx = R2[0] - H[0], dz = R2[1] - H[1], along = dx * u[0] + dz * u[1], lat = Math.abs(dx * u[1] - dz * u[0]); if (along > -1 && along < 20 && lat < 2.8) { if (along < 9) { stop = Math.min(stop, 0); c.why = c.why || 'follow'; c.whyO = o.id; } else vt = Math.min(vt, o.v + 0.5); } } }
      c.noPark = Math.max(0, (c.noPark || 0) - dt); if (night && !c.parking && !c.noPark) { const s = canPark(c, rem); if (s) c.parking = s; } // commit to a checked spot, then brake (4 px/s²) straight into it
      if (!night) c.parking = 0;
      if (c.parking) { c.v = Math.max(0, c.v - 4 * dt); vt = Math.min(vt, c.v); if (c.v < 0.3) { if (!campOK(c, c.parking, 0)) { c.parking = 0; c.noPark = 3; } /* spot turned out bad → drive on 3 s before looking again */ else { c.parked = true; c.pside = c.parking; c.parking = 0; c.pull = 0; c.v = 0; for (const zid of c.locks.keys()) { const H2 = holders.get(zid); if (H2) H2.delete(c); } c.locks.clear(); c.xres = null; campBody(c); return; } } }
      const v2 = stop === Infinity ? vt : Math.min(vt, Math.sqrt(2 * 4 * Math.max(0, stop))); c.v = Math.min(v2, c.v + 3 * dt); let mv = c.v * dt; if (stop !== Infinity) mv = Math.min(mv, Math.max(0, stop)); if (stop !== Infinity && stop - mv < 0.2) c.v = 0;
      c.h += mv; c.dist += mv; c.stopT = mv > 0.01 ? 0 : (c.stopT || 0) + dt;
      if (c.h >= sg.len) { const over = c.h - sg.len; ensurePlan(); const pl = c.plan; c.plan = null;
        if (pl.town) { c.hidden = true; c.town = pl.town; c.dwell = pl.arrived ? 6 + rnd() * 8 : 1.5 + rnd() * 2; c.transit = !pl.arrived; /* passing through a town on the way: 1.5–3.5 s; destination: 6–14 s */ c.stayName = pl.town.name || (data.townAt ? data.townAt(pl.town.P[0], pl.town.P[1]) : null); c.v = 0; for (const zid of c.locks.keys()) { const H2 = holders.get(zid); if (H2) H2.delete(c); } c.locks.clear(); c.nseg = null; return; }
        c.prev = sg.e; c.segs.push(c.nseg || connSeg(sg, pl.opt)); c.nseg = null; c.h = over; trim(c, LC + 6); }
      coachBody(c); };
    // airships
    const cities = data.cities || [], ships = [];
    const clear = (x0, z0, x1, z1) => { const L = Math.hypot(x1 - x0, z1 - z0), nx = -(z1 - z0) / (L || 1), nz = (x1 - x0) / (L || 1); for (let s = 0; s <= L; s += 15) { const x = x0 + (x1 - x0) * s / L, z = z0 + (z1 - z0) * s / L; for (const o of [-60, 0, 60]) if (data.avoid(x + nx * o, z + nz * o)) return false; } return true; };
    const altAt = (x, z, hd) => { let m = 0; for (const d of [0, 60, 120]) m = Math.max(m, data.hAt(x + Math.cos(hd) * d, z + Math.sin(hd) * d)); return m + 46; };
    const target = a => { for (const [lo, hi] of [[300, 1400], [150, 2600]]) { const c = cities.filter(c => c !== a.at && c !== a.last && (d => d >= lo && d <= hi)(Math.hypot(c[0] - a.x, c[1] - a.z)) && clear(a.x, a.z, c[0], c[1])); if (c.length) { a.last = a.at; a.at = pick(c); return; } } a.dwell = 10; };
    for (let k = 0; k < Math.min(CNT.ships ?? 2, cities.length); k++) { const c = pick(cities), a = { x: c[0], z: c[1], hd: rnd() * 6.283, v: 0, dwell: 2 + rnd() * 6, at: c, last: null, ph: rnd() * 6.283 }; a.y = altAt(a.x, a.z, a.hd); ships.push(a); }
    const stepShip = (a, dt) => { if (a.dwell > 0) { a.dwell -= dt; a.v = Math.max(0, a.v - 6 * dt); if (a.dwell <= 0) target(a); }
      else { const tx = a.at[0], tz = a.at[1], d = Math.hypot(tx - a.x, tz - a.z), want = Math.atan2(tz - a.z, tx - a.x); let df = want - a.hd; while (df > Math.PI) df -= 6.283; while (df < -Math.PI) df += 6.283;
        a.hd += Math.max(-0.45 * dt, Math.min(0.45 * dt, df)); const vt = 18 * Math.min(1, d / 90) * (Math.abs(df) > 1 ? 0.4 : 1); a.v += Math.max(-6 * dt, Math.min(4 * dt, vt - a.v)); if (d < 8) a.dwell = 6 + rnd() * 6; }
      a.x += Math.cos(a.hd) * a.v * dt; a.z += Math.sin(a.hd) * a.v * dt; a.y += (altAt(a.x, a.z, a.hd) - a.y) * Math.min(1, dt * 0.6); };
    let time = 0, night = false, campList = []; const CAMP_R = 7, setNight = b => { night = !!b; };
    const step = dt => { while (dt > 0) { const h = Math.min(0.1, dt); dt -= h; time += h; for (const tr of trains) stepTrain(tr, h); for (const c of coaches) stepCoach(c, h); for (const a of ships) stepShip(a, h); } };
    const inR = (R, x, z) => x >= R[0] && x <= R[2] && z >= R[1] && z <= R[3];
    const grp = (x, z, y, hs, L, yaw, pitch, extra) => Object.assign({ e: { x, y: z, gy: y / hs, kit: 'vh', type: 'vh', nf: true }, L, vh: { yaw, pitch: pitch || 0 } }, extra || {});
    // Smoke (2026-10-08): fire sources (opt.fires = [[key, [x, y, z]]] from map-core: bridge torches, braziers, any fire part) + campfires. Only when opt.smoke
    // (zoom ≥ 101 %) and the source is inside opt.view: a small grey cube every 0.4–0.6 s, rises 3–4.5 px/s with drift, grows 0.3 → 1 unit then fades out (life 2–3 s).
    const SMK = new Map(); let smT = 0;
    const smokeStep = (srcs, on, V, dt) => { const live = new Set(); if (on) for (const [key, P] of srcs) { if (P[0] < V[0] || P[0] > V[2] || P[2] < V[1] || P[2] > V[3] + 20) continue; live.add(key); let S = SMK.get(key); if (!S) { S = { t: rnd() * 0.5, ps: [] }; SMK.set(key, S); }
        S.t -= dt; if (S.t <= 0) { S.t = 0.4 + rnd() * 0.2; S.ps.push({ x: P[0] + (rnd() - 0.5) * 0.6, y: P[1], z: P[2] + (rnd() - 0.5) * 0.6, vx: 0.6 + (rnd() - 0.5) * 0.8, vz: -0.3 + (rnd() - 0.5) * 0.6, vy: 3 + rnd() * 1.5, age: 0, life: 2 + rnd(), rot: rnd() * 6.283 }); }
        for (const p of S.ps) { p.age += dt; p.x += p.vx * dt; p.z += p.vz * dt; p.y += p.vy * dt; p.vy *= Math.pow(0.75, dt); } S.ps = S.ps.filter(p => p.age < p.life); }
      for (const k of SMK.keys()) if (!live.has(k)) SMK.delete(k); };
    const groups = (R, kit, hs, opt) => { const out = []; opt = opt || {}; const dtS = Math.min(0.5, time - smT); smT = time;
      // Camps: fire + cleared dirt patch (2 px blocks within CAMP_R px of the fire, dithered rim, skipping the trail tread within 4 px of the road line; on each block's top).
      const camps = []; campList = []; if (night && kit.campfire) for (const c of coaches) { if (!c.parked || c.hidden || !c.camp) continue; const [x, z] = c.camp; campList.push([x, z, CAMP_R]);
        camps.push(['c' + c.id, [x, TOP(x, z) + 6, z]]); if (!inR(R, x, z)) continue; const sg = c.segs[c.segs.length - 1], road = sg.pts.filter(p => Math.abs(p[0] - x) < 16 && Math.abs(p[1] - z) < 16), cells = [];
        for (let cz = Math.floor((z - CAMP_R) / 2) * 2; cz < z + CAMP_R; cz += 2) for (let cx = Math.floor((x - CAMP_R) / 2) * 2; cx < x + CAMP_R; cx += 2) { const d = Math.hypot(cx + 1 - x, cz + 1 - z); if (d > CAMP_R || (d > CAMP_R - 1.6 && ((cx + cz) >> 1) & 1)) continue; if (road.some(p => Math.hypot(p[0] - cx - 1, p[1] - cz - 1) < 4)) continue; if (wetAt(cx + 1, cz + 1)) continue;
          cells.push([cx, cz, cx + 2, cz + 2, TOP(cx + 1, cz + 1) + 0.06, 0, 0, 0, 1, 1, 0, 1, 1]); }
        out.push(grp(x, z, TOP(x, z), hs, kit.campfire, 0, 0, { sh: { cells, tex: kit.dirtTex } })); }
      smokeStep([...(opt.fires || []), ...camps], !!opt.smoke && !!opt.view, opt.view || R, dtS);
      for (const S of SMK.values()) for (const p of S.ps) { const k = p.age / p.life, sz = (0.3 + 0.7 * Math.min(1, k * 1.6)) * (k > 0.7 ? (1 - k) / 0.3 : 1); if (sz < 0.12) continue; out.push(grp(p.x, p.z, p.y, hs, kit.puff(Math.max(1, Math.round(sz * 4)), Math.min(7, 2 + Math.floor(k * 6))), p.rot, 0)); }
      for (const tr of trains) { const wf = Math.floor(tr.dist / 2) & 1; for (const c of tr.cars) { const p = pose(tr, c.s, c.half); if (inR(R, p.x, p.z)) out.push(grp(p.x, p.z, p.y, hs, kit.car(c.kind, wf), p.yaw, p.pitch)); }
        for (const p of tr.puffs) { if (!inR(R, p.x, p.z)) continue; const k = p.age / p.life, s = (0.9 + 2.4 * k) * (k > 0.75 ? (1 - k) / 0.25 : 1); if (s < 0.15) continue; out.push(grp(p.x, p.z, p.y, hs, kit.puff(Math.max(1, Math.round(s * 4)), Math.min(7, Math.floor(k * 8))), p.rot, 0)); } }
      for (const c of coaches) { if (c.hidden) continue; if (c.parked) { const L = campLayout(c, c.pull || 0); if (!inR(R, L.coach.x, L.coach.z)) continue; const off = (c.pull || 0) > 0.5, Y = (x, z) => off ? TOP(x, z) : data.ground(x, z);
          out.push(grp(L.team.x, L.team.z, Y(L.team.x, L.team.z), hs, kit.team(c.spec, 2), L.team.yaw, 0), grp(L.coach.x, L.coach.z, Y(L.coach.x, L.coach.z), hs, kit.coach(0), L.coach.yaw, 0)); continue; }
        const ph = lanePose(c, 2.4 * Kp, 2 * Kp); if (!inR(R, ph.x, ph.z)) continue; const fr = c.v < 0.3 ? 2 : Math.floor(c.dist / 1.7) & 1, wf = Math.floor(c.dist / 1.2) & 1, pc = lanePose(c, 8.2 * Kp, 2.4 * Kp);
        out.push(grp(ph.x, ph.z, ph.y, hs, kit.team(c.spec, fr), ph.yaw, ph.pitch), grp(pc.x, pc.z, pc.y, hs, kit.coach(wf), pc.yaw, pc.pitch)); }
      const Ra = [R[0] - 40, R[1] - 40, R[2] + 40, R[3] + 160];
      for (const a of ships) { if (!inR(Ra, a.x, a.z)) continue; const cw = Math.cos(a.hd), sw = Math.sin(a.hd), SL = 36, SW = 13, Rb = SL / 2 + 2, cells = [];
        // shadow: the 16 × 6 dithered ellipse stretched to SL × SW px and turned with the heading; one quad per 2 px terrain block on that block's top (drapes over terraces / peaks).
        const loc = (x, z) => { const dx = x - a.x, dz = z - a.z, lx = dx * cw + dz * sw, lz = -dx * sw + dz * cw; return [Math.max(0, Math.min(1, 0.5 + lx / SL)), Math.max(0, Math.min(1, 0.5 + lz / SW))]; };
        for (let cz = Math.floor((a.z - Rb) / 2) * 2; cz < a.z + Rb; cz += 2) for (let cx = Math.floor((a.x - Rb) / 2) * 2; cx < a.x + Rb; cx += 2) { const dx = cx + 1 - a.x, dz = cz + 1 - a.z, lx = dx * cw + dz * sw, lz = -dx * sw + dz * cw;
          if (Math.abs(lx) > SL / 2 + 1 || Math.abs(lz) > SW / 2 + 1) continue; const A0 = loc(cx, cz), A1 = loc(cx, cz + 2), B0 = loc(cx + 2, cz), B1 = loc(cx + 2, cz + 2);
          cells.push([cx, cz, cx + 2, cz + 2, (data.top || data.ground)(cx + 1, cz + 1) + 0.12, ...A0, ...A1, ...B0, ...B1]); }
        out.push(grp(a.x, a.z, a.y + Math.sin(time * 0.9 + a.ph) * 0.8, hs, kit.airship(Math.floor(time * 12) & 1), a.hd, 0, { sh: { cells } })); }
      return out; };
    const info = () => { const out = [];
      coaches.forEach((c, i) => { const sg = c.segs[c.segs.length - 1], rem = Math.max(0, sg.len - c.h), D = c.goal != null ? distTo(c.goal) : null, d = c.hidden ? 0 : rem + (D ? (D.get(nodeId(sg.e, sg.side)) ?? 0) : 0), P = c.hidden ? c.town.P : c.body[1];
        out.push({ key: 'coach' + i, kind: 'coach', x: P[0], z: P[1], y: (data.top || data.ground)(P[0], P[1]) + 4, hidden: !!c.hidden, parked: !!c.parked, dest: c.hidden && !c.transit ? (c.stayName || 'town') : (c.goalName || '—'), at: c.hidden && !c.transit ? c.stayName : null, eta: c.hidden ? Math.max(0, c.dwell) : d / Math.max(1, c.vmax), dist: d }); });
      trains.forEach((tr, i) => { const sg = tr.segs[tr.segs.length - 1], p = pose(tr, tr.cars[0].s, tr.cars[0].half), rem = Math.max(0, sg.len - tr.h), d = tr.stopAt != null ? Math.max(0, tr.stopAt - tr.dist) : rem; let nm = tr.stopName; if (!nm) { const st = (sg.stops || []).find(s => s.d > tr.h); nm = st ? st.name : sg.b; }
        out.push({ key: 'train' + i, kind: 'train', x: p.x, z: p.z, y: p.y + 6, hidden: false, dest: tr.dwell > 0 ? (tr.lastStop || nm) : nm, at: tr.dwell > 0 ? tr.lastStop : null, eta: tr.dwell > 0 ? tr.dwell : d / Math.max(1, tr.vmax * 0.85), dist: d }); });
      ships.forEach((a, i) => { const d = Math.hypot(a.at[0] - a.x, a.at[1] - a.z); out.push({ key: 'ship' + i, kind: 'ship', x: a.x, z: a.z, y: a.y + 22, hidden: false, dest: a.at[2], at: a.dwell > 0 ? a.at[2] : null, eta: a.dwell > 0 ? a.dwell : d / 16, dist: d }); }); return out; };
    return { step, groups, setNight, info, _dbg: () => ({ distTo, fromDist, nodeId, liveOpts, optCost }), get camps() { return campList; }, trains, get coaches() { return coaches; }, ships, ends, holders, zoneCount: () => new Set(JZ.values()).size, get time() { return time; } };
  }
  root.MercVehicles = { make, sim, COATS };
})(typeof window !== 'undefined' ? window : globalThis);
