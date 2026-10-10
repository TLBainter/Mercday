'use strict';
//node addons/pixel_model/tools/extract_models.js <handoff baseline_snapshot dir> <project root>
//Writes Scripts/Tests/Map/Fixtures/models.json (D1) and Art/Map/Source/map-scatter.json (D2); contract C2.
const fs = require('fs'), path = require('path'), vm = require('vm'), crypto = require('crypto');
const SNAP = process.argv[2], ROOT = process.argv[3];
if (!SNAP || !ROOT) { console.error('usage: node extract_models.js <baseline_snapshot> <project root>'); process.exit(1); }
const fail = msg => { console.error('FAIL ' + msg); process.exit(1); };
const SRC = ['map-elements.js', 'map-settlements.js', 'map-core.js'];
const raw = Object.fromEntries(SRC.map(f => [f, fs.readFileSync(path.join(SNAP, f))]));
const text = Object.fromEntries(SRC.map(f => [f, raw[f].toString('utf8')]));
const source = Object.fromEntries(SRC.map(f => { const t = text[f]; return [f, { lines: t.split('\n').length -
	(t.endsWith('\n') ? 1 : 0), sha256: crypto.createHash('sha256').update(raw[f]).digest('hex') }]; }));
const ME_T = text['map-elements.js'], MS_T = text['map-settlements.js'], MC_T = text['map-core.js'];

const once = (t, needle, what) => { const i = t.indexOf(needle);
	if (i < 0 || t.indexOf(needle, i + 1) >= 0) fail(what + ': expected exactly one match of ' + JSON.stringify(needle));
	return i; };
const patch = (t, from, to) => { once(t, from, 'patch'); return t.replace(from, () => to); };
const grabOnce = (t, re, what) => { const m = [...t.matchAll(new RegExp(re.source, 'g'))];
	if (m.length !== 1) fail(what + ': expected one match, got ' + m.length); return m[0]; };

const create = (w, h) => { const c = { width: w, height: h, pixels: null };
	c.getContext = () => ({ createImageData: (W, H) => ({ width: W, height: H, data: new Uint8ClampedArray(W * H * 4) }),
		putImageData: img => { c.pixels = img.data; }, drawImage: () => {} });
	return c; };
const MATH_TRAP = '(() => { const m = {}; for (const k of Object.getOwnPropertyNames(Math)) m[k] = Math[k];' +
	' m.random = () => { throw new Error("Math.random called"); }; globalThis.Math = m; })();';
const STUBS = 'globalThis.window = globalThis; globalThis.document = { createElement: () => __create(1, 1) };';
const context = stubs => { const c = vm.createContext({ __create: create }); vm.runInContext(MATH_TRAP, c);
	if (stubs) vm.runInContext(STUBS, c); return c; };

//6a: n exported from the IIFE scope; a second context replaces deOverlap by identity
const ME_N = patch(ME_T, 'root.MercElements = { make, LIGHT_COLORS };', 'root.MercElements = { make, LIGHT_COLORS, n };');
const ME_RAW = patch(ME_N, 'k.parts = deOverlap(k.parts)', 'k.parts = k.parts');
const load = meText => { const c = context(true);
	vm.runInContext(meText, c, { filename: 'map-elements.js' });
	vm.runInContext(MS_T, c, { filename: 'map-settlements.js' });
	return { c, ME: c.MercElements.make(create), EX: c.MercElements }; };
const A = load(ME_N), B = load(ME_RAW), ME = A.ME;
let trapOk = false;
try { vm.runInContext('Math.random()', A.c); } catch (e) { trapOk = /Math.random called/.test(e.message); }
if (!trapOk) fail('Math.random trap not installed');

const kind = v => Object.prototype.toString.call(v);
const hx = v => v.toString(16).padStart(2, '0');
const grid = (c, fn) => Array.from({ length: c.height }, (_, y) => Array.from({ length: c.width }, (_, x) =>
	fn(c.pixels, (y * c.width + x) * 4)));
const textures = {}, subs = {};
let nullFaces = 0;
const dumpMod = c => { if (textures[c.id]) return; textures[c.id] = { w: c.width, h: c.height, tile: !!c.tile,
	pixels: grid(c, (d, i) => d && d[i + 3] ? '#' + hx(d[i]) + hx(d[i + 1]) + hx(d[i + 2]) : null),
	light: c.light ? grid(c.light, (d, i) => d && d[i + 3] ? 1 : 0) : null }; };
const texOut = t => { if (!t) { nullFaces++; return null; }
	if (t.s) { dumpMod(t.s); subs[t.id] = { parent: t.s.id, r: t.r }; return { id: t.id, parent: t.s.id, r: t.r }; }
	dumpMod(t); return { id: t.id }; };
const partOut = p => { const q = {}; for (const [k, v] of Object.entries(p))
	q[k] = k === 'tex' && v ? Object.fromEntries(Object.entries(v).map(([f, t]) => [f, texOut(t)])) : v; return q; };
const modelOut = k => ({ W: k.W, D: k.D, parts: k.parts.map(partOut) });

//stage 3 ids: ED 2 sources plus the 41 ruin ids
const pad2 = i => String(i).padStart(2, '0');
const RUIN_B = Array.from({ length: 26 }, (_, i) => 'cy_b' + pad2(i + 1));
const RUIN_S = Array.from({ length: 15 }, (_, i) => 'cy_s' + pad2(i + 1));
const ids = new Set(), addK = list => (list || []).forEach(([k]) => ids.add(k));
Object.values(ME.FOLIAGE).forEach(c => addK(c.k));
ME.FOLIAGE_ZONES.forEach(z => { addK(z.k); addK(z.fill && z.fill.k); });
const WS = ME.WATER_SCATTER;
[WS.k, WS.kIcy, WS.kViolet, WS.river.kits, ME.ICE_MOUNTAIN.kits].forEach(addK);
//JK 0: w_lily (MC:991) and the five defined but unreferenced kits complete the 95
['w_lily', 'f_haystack', 'f_sheaf', 'p_dune', 'p_dune2', 'p_wheat'].forEach(i => ids.add(i));
const edIds = [...ids].filter(i => !/^cy_[bs]\d\d$/.test(i)).length;
[...RUIN_B, ...RUIN_S].forEach(i => ids.add(i));
const stage3 = [...ids].sort();

//3: base models with the palette proxy and r counter
const PAL0 = ME.PALS.buern, palRead = new Set();
ME.PALS.buern = new Proxy(PAL0, { get: (o, k) => { palRead.add(String(k)); return o[k]; } });
const models = {}, rawKits = {}, variants = {}, errors = {};
const msg = e => String((e && e.message) || e);
for (const id of stage3) { palRead.clear(); let rc = 0; const r = () => { rc++; return 0.4; };
	try { const k = ME.kit(id, 'buern', r); rawKits[id] = k;
		models[id] = { ...modelOut(k), rCalls: rc, palKeys: [...palRead] }; } catch (e) { errors[id] = msg(e); } }
ME.PALS.buern = PAL0;
//4: tree variants
const TREES = [...ME.TREES];
let nVariants = 0;
for (const id of TREES) { variants[id] = {};
	for (let v = 0; v < 5; v++) {
		try { variants[id][v] = modelOut(ME.kit(id, 'buern', () => 0.4, { v })); nVariants++; }
		catch (e) { errors[id + '#' + v] = msg(e); } } }
const atlases = {};
for (const name of [...ME.atlas.names, 'styles']) { try { atlases[name] = ME.atlas(name).rects; } catch (e) { atlases[name] = null; } }

//6a: raw ruin parts and n samples
const ruins_raw = {};
for (const id of RUIN_B) {
	try { ruins_raw[id] = B.ME.kit(id, 'buern', () => 0.4).parts.map(partOut); } catch (e) { errors['raw:' + id] = msg(e); } }
const nf = A.EX.n, n_samples = [];
for (let x = 0; x < 16; x++) for (let y = 0; y < 16; y++) n_samples.push([x, y, nf(x, y)]);
n_samples.push([3, 101, nf(3, 101)], [12, 11, nf(12, 11)]);

//6: MC slice for GS and GV; SCAT and FLAT_KIT literals from MC text; BUSH literal from ME text
const gsA = once(MC_T, 'const GS = {', 'GS start');
const GV_END = 'V[kd].push(P); } }); return V; })();';
const gsB = once(MC_T, GV_END, 'GV end') + GV_END.length;
const GSV = vm.runInContext(MC_T.slice(gsA, gsB) + '\n({ GS, GV });', context(false), { filename: 'map-core.js#GS' });
const lit = (src, re, what) => vm.runInContext(grabOnce(src, re, what)[1], context(false));
const SCAT = lit(MC_T, /const SCAT = (\/.*?\/[a-z]*), SCAT_S/, 'SCAT');
const FLAT_KIT = lit(MC_T, /FLAT_KIT = (\/.*?\/[a-z]*), prop/, 'FLAT_KIT');
const BUSH = [...lit(ME_T, /const BUSH = (new Set\(\[[^\]]*\]\));/, 'BUSH')];
const cyRow = ME.FOLIAGE_ZONES.find(z => z.id === 'cyfrolaef_ruins');
if (!cyRow) fail('FOLIAGE_ZONES row cyfrolaef_ruins missing');
const CYF = cyRow.k, cyfTot = CYF.reduce((a, q) => a + q[1], 0);

//6b: geometry oracle from the MC part emitter
const pickGeo = () => { const out = [], has = (id, f) => rawKits[id] && rawKits[id].parts.some(f);
	for (const f of [p => p.kind === 'box', p => p.kind === 'gable' || p.kind === 'pyr', p => !!(p.tilt || p.pitch)]) {
		const id = stage3.find(i => !out.includes(i) && has(i, f)); if (id) out.push(id); }
	return out; };
let geometry = null, geometry_error = null;
try {
	const gA = once(MC_T, 'const LT = {', 'emitter start'), gB = once(MC_T, 'const cull = o.cullScatter', 'emitter end');
	const EL = grabOnce(MC_T, /const EL = (\{[^}]*\})/, 'EL')[1];
	const src = '(() => { const t = {}, hs = 1, WATER_H = 0, LW = null, E = { SCENE_W: 66 }, window = {}, EL = ' + EL + ';\n' +
		'const natAt = () => [0, 0], C3 = () => [1, 1, 1], UV = { get: s => s === "shadow" ? [0, 1, 1] : [0, s.width, s.height] };\n' +
		'let quad = null;\n' + MC_T.slice(gA, gB) + '\nreturn (q, gs) => { quad = q; emitGroups(gs); }; })()';
	const run = vm.runInContext(src, context(false), { filename: 'map-core.js#emit' });
	geometry = {};
	for (const id of pickGeo()) { const k = rawKits[id], rec = [];
		const g = { e: { x: 0, y: 0, gy: -0.03, nf: true, kit: '' }, L: Object.assign(k.parts.slice(), { W: k.W }), noLit: false };
		run((pts, col, uv) => { for (let i = 0; i < 4; i++) rec.push([pts[i][0], pts[i][1], pts[i][2], uv[i][0], uv[i][1], col[0]]); }, [g]);
		geometry[id] = rec; }
} catch (e) { geometry = null; geometry_error = msg(e); }

//7: sequences, generators re-declared from the PR 6 snippet
const M = 4294967296;
const mul = seed => { let a = seed; return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a);
	t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / M; }; };
const srng = seed => { let s = seed >>> 0 || 1; return () => { s = Math.imul(s ^ (s >>> 15), 2246822507) + 0x9e3779b9 >>> 0;
	s ^= s >>> 13; return (s >>> 0) / M; }; };
const hstr = str => { let h = 2166136261; for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619); return h >>> 0; };
const hash = s => { let h = 2166136261; for (const c of String(s)) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; };
const hh = (x, z) => { let h = Math.imul(x | 0, 73856093) ^ Math.imul(z | 0, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177);
	return ((h ^ (h >>> 16)) >>> 0) / M; };
const vn = (x, z) => { const xi = Math.floor(x), zi = Math.floor(z), fx = x - xi, fz = z - zi, a = hh(xi, zi), b = hh(xi + 1, zi),
	c = hh(xi, zi + 1), d = hh(xi + 1, zi + 1); return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz; };
const seq = (g, k) => Array.from({ length: k }, () => Math.round(g() * M));
const S20 = ['', 'a', 'f_oak', 'f_pine', 'f_birch', 'f_palm', 'f_shadepine', 'f_wisteria_w', 'p_rocks', 'w_pebbles',
	'r_rock1', 'cy_b01', 'Makaliim', "Nathair's Prairie", "Erakha's Hollow", 'Tiir Wood', 'Yrspholahs',
	'Belameir Icefield', 'Kale Vidneku Citadel', 'station'];
const sequences = { srng: {}, mulberry32: {}, hstr: {}, fnv1a: {}, hh: [], vn: [] };
for (const s of [1, 7, 12345, 0, ...[0, 1, 2, 3, 4].map(v => v * 7919 + hstr('f_oak'))]) sequences.srng[s] = seq(srng(s), 1000);
for (const s of [1, 7, 12345, 0, 4294967295]) sequences.mulberry32[s] = seq(mul(s), 1000);
for (const s of [...S20, ...stage3]) { sequences.hstr[s] = hstr(s); sequences.fnv1a[s] = hash(s); }
for (const salt of [1, 7, 12345]) for (let i = 0; i < 1000; i++)
	sequences.hh.push([i + salt, i * 7 - 500, Math.round(hh(i + salt, i * 7 - 500) * M)]);
for (const [x, z] of [[0, 0], [-1, -1], [5695, 2959], [-2147483648, 2147483647], [17085, 14805]])
	sequences.hh.push([x, z, Math.round(hh(x, z) * M)]);
for (let i = 0; i < 200; i++) sequences.vn.push([i * 3.37, i * 1.91, vn(i * 3.37, i * 1.91)]);
const nSeq = Object.values(sequences).reduce((a, v) => a + (Array.isArray(v) ? v.length : Object.keys(v).length), 0);

//8: JSON with indent 1; RegExp as {re, flags}, Set as array; ASCII escapes
let nonFinite = 0;
const replacer = (k, v) => { const t = kind(v);
	if (t === '[object RegExp]') return { re: v.source, flags: v.flags };
	if (t === '[object Set]') return [...v];
	if (typeof v === 'number' && !isFinite(v)) nonFinite++;
	return v; };
const toJson = o => JSON.stringify(o, replacer, 1).replace(/[^\x00-\x7f]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0')) + '\n';
const modelsOut = { version: 1, source, call: { style: 'buern', r: 0.4 },
	stage3_ids: stage3, palettes: { PALS: ME.PALS, LIGHT_COLORS: A.EX.LIGHT_COLORS }, textures, subs, atlases,
	models, variants, errors, ruins_raw, n_samples, gv: GSV.GV, sequences };
if (geometry) modelsOut.geometry = geometry; else modelsOut.geometry_error = geometry_error;
const scatterOut = { FOLIAGE: ME.FOLIAGE, FOLIAGE_ZONES: ME.FOLIAGE_ZONES, WATER_SCATTER: ME.WATER_SCATTER,
	ICE_MOUNTAIN: ME.ICE_MOUNTAIN, TREES, BUSH, SCAT, FLAT_KIT, GS: GSV.GS, GV: GSV.GV, CYF,
	spread_ids: { re: '^cy_b', flags: '' } };
const mj = toJson(modelsOut), sj = toJson(scatterOut);
const write = (rel, s) => { const p = path.join(ROOT, rel); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, s); };
write('Scripts/Tests/Map/Fixtures/models.json', mj);
write('Art/Map/Source/map-scatter.json', sj);
const nErr = Object.keys(errors).length, nModels = Object.keys(models).length;
console.error('info ed_ids ' + edIds + ' stage3 ' + stage3.length + ' trees ' + TREES.length + ' textures ' +
	Object.keys(textures).length + ' subs ' + Object.keys(subs).length + ' null_faces ' + nullFaces + ' zones ' +
	ME.FOLIAGE_ZONES.length + ' cyf_tot ' + cyfTot + ' n_samples ' + n_samples.length + ' ruins_raw ' +
	Object.keys(ruins_raw).length + ' geometry ' + (geometry ? Object.keys(geometry).map(i => i + ':' + geometry[i].length).join(',') :
	'error: ' + geometry_error) + ' nonfinite ' + nonFinite);
for (const [k, v] of Object.entries(errors)) console.error('error ' + k + ': ' + v);
console.log('models ' + nModels + ' variants ' + nVariants + ' sequences ' + nSeq + ' errors ' + nErr);
if (ME.FOLIAGE_ZONES.length !== 56) fail('FOLIAGE_ZONES.length ' + ME.FOLIAGE_ZONES.length + ' != 56');
if (nModels < 136) fail('only ' + nModels + ' models built');
if (nonFinite) fail(nonFinite + ' non-finite numbers');
if (nErr) fail(nErr + ' errors');
