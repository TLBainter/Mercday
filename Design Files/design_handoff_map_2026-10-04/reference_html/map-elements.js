// Map elements: semi-3D pixel-art symbols. Each model = textured parts (boxes, gable roofs, pyramids, flat decals, flag cards); every face except the
// back (north) wall is drawn, so the model reads fully as the camera passes over it. Shared by Map View (browser) and the atlas exporter.
// MercElements.make(create) → { model(type) → [part], bridge() → { end, mid }, ubridge() → { end, mid } (stone arch), rail(), atlas('buildings' | 'terrain' | 'paths') → { canvas, rects, rows }, SCENE_W }.
// Face tex = module canvas (has .id) or sub-rect { id, s: module, r: [x, y, w, h] }; always stretched to the whole face.
// Optional part.tint (hex) multiplies grayscale textures (roof_tile, flag_cloth); part.tintFaces limits it to those faces (default all). create(w, h) must return a canvas of that size.
// Scene space (sprite px): x 0..SCENE_W (west → east), z = depth (0 = front/south edge, larger = further north), y = up from ground.
// Parts (x, z = center; w = x size, d = z size, h = height; y = base):
//   box   { tex: { top (w×d), front (w×h), left (d×h), right (d×h) } }
//   gable { ridge along x; tex: { s (w×slope), n (w×slope), l (d×h), r (d×h) } }   (gable triangles: texture squeezed into the triangle)
//   pyr   { tex: { s, n, l, r } (base×h, squeezed to the apex) }
//   decal { flat on the ground; tex: { top (w×d) } }
//   card  { vertical, faces south; tex: { front (w×h) } }
// Textures with .tile = true repeat across the face at 1 texel per model unit (bottom-left anchored) instead of stretching.
//   lathe { round solid: prof = [[t 0..1 up, r 0..1 of w/2], …], 12 segments; tex: { side } wraps once around, v top → bottom (onion domes, drums) }
(function (root) {
  const n = (x, y) => { let h = (x * 374761393 + y * 668265263) | 0; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
  const hex = h => { const v = parseInt(h.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };
  function make(create) {
    const spr = (w, h, fn) => { w = Math.max(1, Math.round(w)); h = Math.max(1, Math.round(h)); const c = create(w, h), g = c.getContext('2d'), id = g.createImageData(w, h), d = id.data;
      const px = (x, y, col) => { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= w || y >= h || !col) return; const [r, gg, b] = hex(col), i = (y * w + x) * 4; d[i] = r; d[i + 1] = gg; d[i + 2] = b; d[i + 3] = 255; };
      fn(px, w, h); g.putImageData(id, 0, 0); return c; };
    const memo = new Map(), M = (key, f) => { if (!memo.has(key)) memo.set(key, f()); return memo.get(key); };
    // ── textures: small fixed-size modules, shared by every part and STRETCHED onto each face (1 module per material).
    // A face may use a sub-rect of a module: { id, s: module, r: [x, y, w, h] } (e.g. house side = left 7 cols of the house front).
    // Light maps (2026-10-07): LIGHT[textureId](hex, x, y) → texel glows at night. mod() records every written texel and builds c.light (same size, white = glow, transparent = dark).
    // Textures without a rule get no light map (= fully dark). Night colour per nation: LIGHT_COLORS. Parts can also glow via lit_white (dark thin window / door slabs, see map-core litSwap).
    const blu = c => parseInt(c.slice(5, 7), 16) > parseInt(c.slice(1, 3), 16) + 25, lum = c => (parseInt(c.slice(1, 3), 16) * 0.3 + parseInt(c.slice(3, 5), 16) * 0.59 + parseInt(c.slice(5, 7), 16) * 0.11) / 255;
    const LIGHT = { pise_wall: c => c === '#5c5c5c' || c === '#333333', house_wall: c => c === '#ffe7a0' || c === '#d9a640', wall_window: c => c === '#5c5c5c' || c === '#2c2c2c', strip_window: (c, x, y) => y === 1 || y === 2,
      shoji_wall: c => c === '#f2efe6' || c === '#d6d0bf', clock_face: c => c === '#f2efe6', mashrabiya: c => c === '#3a2818', window_glow: () => true, lit_white: () => true, minaret_sebka: c => lum(c) < 0.3, stone_wall: c => blu(c) };
    const mod = (id, w, h, fn) => M(id, () => { const rule = LIGHT[id], lit = rule ? new Map() : null;
      const c = spr(w, h, rule ? (px, W2, H2) => fn((x, y, col) => { px(x, y, col); if (col) lit.set((x | 0) + ',' + (y | 0), !!rule(String(col).toLowerCase(), x | 0, y | 0)); }, W2, H2) : fn); c.id = id;
      if (lit) { const L = create(c.width, c.height), lg = L.getContext('2d'), d = lg.createImageData(c.width, c.height); for (const [k, v] of lit) { if (!v) continue; const [x, y] = k.split(',').map(Number); if (x < 0 || y < 0 || x >= c.width || y >= c.height) continue; const i = (y * c.width + x) * 4; d.data[i] = d.data[i + 1] = d.data[i + 2] = d.data[i + 3] = 255; } lg.putImageData(d, 0, 0); c.light = L; }
      return c; }), sub = (id, s, r) => M(id, () => ({ id, s, r }));
    const PL = ['#f1e6c8', '#e2d4b0'], TIM = '#6e5438', TIM2 = '#5a3d24';
    const plaster = (px, w, h) => { for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) px(x, y, x === 0 || x === w - 1 || y === 0 ? TIM : y === h - 1 ? '#c9b48a' : n(x + w, y) > 0.85 ? PL[1] : PL[0]); };
    const win = (px, x, y) => { for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) px(x + i, y + j, j === 0 || i === 1 ? TIM : j === 1 ? '#ffe7a0' : '#d9a640'); };
    const wall = () => mod('house_wall', 16, 10, px => { plaster(px, 16, 10); for (let y = 5; y < 9; y++) { px(7, y, TIM2); px(8, y, '#6e4a2c'); } px(8, 7, '#f2d33d'); win(px, 2, 2); win(px, 11, 2); });
    const wallSide = () => sub('house_wall_side', wall(), [0, 0, 7, 10]);
    const gableTri = () => mod('house_gable', 10, 7, px => { for (let y = 0; y < 7; y++) for (let x = 0; x < 10; x++) px(x, y, y === 6 ? TIM : x === 5 ? TIM : n(x, y + 9) > 0.85 ? PL[1] : PL[0]); });
    // Tintable (grayscale) textures: the part's tint multiplies the texture in-engine (white = tint color).
    const roofTile = () => mod('roof_tile', 12, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 12; x++) px(x, y, y === 5 ? '#737373' : y === 0 ? '#ffffff' : ((y + (x >> 1)) % 3 === 0 ? '#c4c4c4' : '#ffffff')); });
    const TINT = { red: '#c9452f', blue: '#3f6fb0', flag: '#e04040' };
    const stone = () => mod('stone_wall', 8, 18, px => { for (let y = 0; y < 18; y++) for (let x = 0; x < 8; x++) { const b2 = ((y >> 1) + ((x + ((y >> 1) % 2) * 2) >> 2)) % 2; px(x, y, x === 0 ? '#8a827a' : x === 7 ? '#6d665f' : b2 ? '#a29b95' : '#948c84'); }
      for (const wy of [4, 10]) { px(3, wy, '#2b3f5c'); px(4, wy, '#2b3f5c'); px(3, wy + 1, '#2b3f5c'); px(4, wy + 1, '#7fb3e0'); } });
    const stonePlain = () => sub('stone_wall_plain', stone(), [0, 13, 8, 5]);
    const stoneTop = () => mod('stone_top', 8, 8, px => { for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) px(x, y, x === 0 || y === 0 || x === 7 || y === 7 ? '#6d665f' : n(x, y) > 0.6 ? '#a29b95' : '#8a827a'); });
    const LEAF = ['#2a5e28', '#3f7f34', '#5a9a40', '#7cb850'];
    const leafTop = () => mod('leaf_top', 8, 8, px => { for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { const r = n(x * 3 + 1, y * 5 + 8); px(x, y, r > 0.7 ? LEAF[3] : r > 0.25 ? LEAF[2] : LEAF[1]); } });
    const leafSide = () => mod('leaf_side', 8, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 8; x++) { const r = n(x * 3 + 2, y * 5 + 8); px(x, y, y === 5 ? LEAF[0] : y === 0 && r > 0.4 ? LEAF[2] : r > 0.82 ? LEAF[2] : r < 0.18 ? LEAF[0] : LEAF[1]); } });
    const bark = () => mod('bark', 2, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 2; x++) px(x, y, x === 0 ? '#5a3d24' : '#6e5438'); });
    const dirt = () => mod('dirt_road', 6, 12, px => { for (let y = 0; y < 12; y++) for (let x = 0; x < 6; x++) { if ((x === 0 || x === 5) && n(x, y) > 0.5) continue; px(x, y, n(x + 5, y) > 0.8 ? '#a8865a' : n(x, y + 3) < 0.15 ? '#7d5f3c' : '#957450'); } });
    const fenceTex = () => mod('fence', 12, 4, px => { for (let x = 0; x < 12; x++) { px(x, 1, '#a07850'); px(x, 3, '#86603e'); } for (let x = 1; x < 12; x += 4) for (let y = 0; y < 4; y++) px(x, y, y === 0 ? '#c49a6c' : '#6e4a2c'); });
    const flag = () => mod('flag_cloth', 3, 3, px => { for (let y = 0; y < 3; y++) for (let x = 0; x < 3; x++) px(x, y, y === 2 ? '#c8c8c8' : x === 2 && y === 1 ? '#e6e6e6' : '#ffffff'); });
    // 1-px flat colors: 0 house top · 1 chimney cap · 2 fence rail top · 3 fence post end
    const SWC = ['#c9b48a', '#4a443e', '#c49a6c', '#6e4a2c'], swatches = () => mod('swatches', 4, 1, px => SWC.forEach((c, i) => px(i, 0, c)));
    const sw = i => sub(['swatch_house_top', 'swatch_chimney_cap', 'swatch_fence_top', 'swatch_fence_end'][i], swatches(), [i, 0, 1, 1]);
    // ── parts
    const box = (x, z, y, w, d, h, tex) => ({ kind: 'box', x, z, y, w, d, h, tex });
    const house = (x, z, w, d, wh, rh, red, chimney) => { const R = roofTile(), out = [
      box(x, z, 0, w, d, wh, { top: sw(0), front: wall(), left: wallSide(), right: wallSide() }),
      { kind: 'gable', x, z, y: wh, w: w + 2, d: d + 2, h: rh, tint: red ? TINT.red : TINT.blue, tintFaces: ['s', 'n'], tex: { s: R, n: R, l: gableTri(), r: gableTri() } }];
      if (chimney) out.push(box(x + w / 2 - 4, z + d / 4, wh + rh * 0.4, 2, 2, rh * 0.75, { top: sw(1), front: stonePlain(), left: stonePlain(), right: stonePlain() }));
      return out; };
    const tree = (x, z, s = 1) => { const cw = Math.round(9 * s), ch = Math.round(7 * s), tw = Math.round(6 * s), th = Math.round(4 * s), tr = Math.round(5 * s), L = { top: leafTop(), front: leafSide(), left: leafSide(), right: leafSide() }; return [
      box(x, z, 0, 2, 2, tr, { top: bark(), front: bark(), left: bark(), right: bark() }), box(x, z, tr, cw, cw, ch, L), box(x - 0.5, z + 0.5, tr + ch, tw, tw, th, L)]; };
    const bush = (x, z, w, d = 5, h = 4) => [box(x, z, 0, w, d, h, { top: leafTop(), front: leafSide(), left: leafSide(), right: leafSide() })];
    const fence = (x, z, w) => [box(x, z, 0, w, 1, 4, { top: sw(2), front: fenceTex(), left: sw(3), right: sw(3) })];
    const bellTower = (x, z) => [box(x, z, 0, 8, 8, 18, { top: stoneTop(), front: stone(), left: stone(), right: stonePlain() }),
      { kind: 'pyr', x, z, y: 18, w: 10, d: 10, h: 9, tint: TINT.red, tex: { s: roofTile(), n: roofTile(), l: roofTile(), r: roofTile() } },
      box(x, z, 25, 1, 1, 7, { top: bark(), front: bark(), left: bark(), right: bark() }),
      { kind: 'card', x: x + 2, z, y: 29, w: 3, h: 3, tint: TINT.flag, tex: { front: flag() } }];
    const MODELS = {
      village: () => [ // 66 px scene. back: trees + bell tower + 2 houses · center: bush, dirt road · front: 2 houses, fences, bushes
        { kind: 'decal', x: 33, z: 7, w: 6, d: 18, tex: { top: dirt() } },
        ...tree(5, 22), ...tree(61, 21, 0.9), ...bellTower(33, 20),
        ...house(18, 15, 20, 10, 11, 7, 0, 1), ...house(48, 15, 18, 10, 10, 7, 1),
        ...bush(33, 9, 8),
        ...house(13, 4, 16, 9, 9, 6, 1, 1), ...house(53, 4, 17, 9, 9, 6, 0),
        ...fence(15, -2.5, 22), ...fence(51, -2.5, 22), ...bush(3, -2, 6), ...bush(63, -2, 6)] };

    // ── BUERN / ROSSADE / VAERNEBO ("buern" family): Moroccan kasbah + riad blended with Russian kremlin. Half-scale kit: 1 texel = 1 model unit.
    // Textures flagged tile repeat across a face (bottom-left anchored) instead of stretching, so every building keeps the same pixel density.
    // Walls, merlons, domes, minaret panels, awnings, small roof tiles are grayscale → tinted per nation (PALS). Doors, zellige, lattice, brick, finials keep their colors.
    // No foliage. Kits: KIT[id](palette, rng) → { W, D, parts } in local units (x 0..W, z 0..D, z 0 = front/south). core() = capital walled core.
    const PALS = {
      buern: { wall: '#e8a684', dome: '#3f9a62', roof: '#3f9a62', tent: '#2f7a4a', awn: '#c9452f', stripe: '#c9452f', street: ['#b48660', '#a87b56'], plaza: ['#d4b48e', '#c8a882'] },
      vaernebo: { wall: '#ead29c', dome: '#e8b440', roof: '#2f8a5a', tent: '#2f6a4a', awn: '#3f6fb0', stripe: '#3f9a62', street: ['#b09670', '#a48a66'], plaza: ['#d8c49a', '#ccb88e'] },
      rossade: { wall: '#d8c4a4', dome: '#4a7ac8', roof: '#4a7ac8', tent: '#2f6a4a', awn: '#c9452f', stripe: '#e8b440', street: ['#9a8e80', '#8e8274'], plaza: ['#bdb2a4', '#b2a698'] } };
    const BASEP = { dome: '#3f9a62', roof: '#3f9a62', tent: '#2f7a4a', awn: '#c9452f', stripe: '#c9452f' };
    Object.assign(PALS, {
      kathaya: { ...BASEP, wall: '#e2b88a', wood: '#b07a4a', roof: '#b0583a', tin: '#a8aeb2', boards: ['#c8a070', '#a87850', '#d8c8a8', '#8a6040'], street: ['#c9a06a', '#bd9460'], plaza: ['#dcc094', '#d0b488'] },
      aldurstein: { ...BASEP, wall: '#ece6da', falu: '#8a3a2a', wood: '#6a4a32', roof: '#3e4a3c', turf: '#5a7040', stone: '#ece6da', lead: '#7a92a8', tile: '#b0503a', block: '#e4ded2', street: ['#8a8680', '#7e7a74'], plaza: ['#b4aea4', '#a8a298'] },
      zukei: { ...BASEP, wall: '#efece4', roof: '#3c4452', thatch: '#9a8a5c', plaster: '#efece4', red: '#b0302a', stone: '#a8a49a', gray: '#c8c4bc', street: ['#a89a84', '#9c8e78'], plaza: ['#cfc6b4', '#c4baa8'] },
      suorr: { ...BASEP, wall: '#ece2cc', slate: '#4a4e58', stucco: '#ece2cc', terra: '#b85a38', soot: '#3a3634', iron: '#5a5e64', street: ['#5e5a56', '#54504c'], plaza: ['#8a8278', '#7e766c'] },
      miliim: { ...BASEP, wall: '#b8744a', mud: '#b8744a', thatch: '#c8a050', ochre: '#d0905a', lime: '#ece0c4', wood: '#4a3220', street: ['#b0703e', '#a46636'], plaza: ['#c8885a', '#bc7c4e'] },
      aerdis: { ...BASEP, wall: '#a8a69c', white: '#f0ece0', thatch: '#c8a860', stone: '#a8a69c', slate: '#46505c', magic: '#5a6ad0', fronts: ['#2f7a4a', '#b03a32', '#3a5a9a', '#e0b040', '#7a3a7a'], street: ['#8a8a7e', '#7e7e72'], plaza: ['#aeae9e', '#a2a292'] },
      copari: { ...BASEP, wall: '#d8ccb4', plaster: '#d8ccb4', slate: '#4a5058', rust: '#8a5a3a', iron: '#6a6e72', bau: '#f0f0ec', terra: '#a85a3a', pastels: ['#a8c0b0', '#d8b0a0', '#c8c0e0', '#e0d0a0'], street: ['#6a6460', '#605a56'], plaza: ['#948c84', '#888078'] } });
    const G = { w: '#f2efe6', g: '#2f8a5a', b: '#2b4f9a', y: '#e0b040', wd: '#8a5530', wd2: '#5e3a22', st: '#d9a640' };
    const tmod = (id, w, h, fn) => { const c = mod(id, w, h, fn); c.tile = true; return c; };
    const pise = () => tmod('pise_wall', 8, 5, px => { for (let y = 0; y < 5; y++) for (let x = 0; x < 8; x++) px(x, y, y === 0 ? '#dedede' : y === 4 ? (n(x, 9) > 0.6 ? '#c2c2c2' : '#cccccc') : n(x * 3, y * 7) > 0.86 ? '#e4e4e4' : '#f2f2f2');
      for (const wx of [1, 5]) { px(wx, 1, '#5c5c5c'); px(wx, 2, '#333333'); } });
    const pisePlain = () => sub('pise_plain', pise(), [3, 3, 1, 1]);
    const crenel = () => tmod('merlon_step', 4, 2, px => { px(1, 0, '#ffffff'); px(0, 1, '#f2f2f2'); px(1, 1, '#f2f2f2'); px(2, 1, '#cfcfcf'); });
    const brickCrenel = () => tmod('merlon_swallowtail', 4, 2, px => { px(0, 0, '#b0442e'); px(2, 0, '#8a3020'); px(0, 1, '#b0442e'); px(1, 1, '#b0442e'); px(2, 1, '#8a3020'); });
    const doorS = () => mod('door_horseshoe', 3, 4, px => { px(1, 0, G.wd2); for (let y = 1; y < 4; y++) { px(0, y, G.wd); px(1, y, G.wd2); px(2, y, G.wd); } px(2, 2, G.st); });
    const gate = () => mod('gate_horseshoe', 5, 6, px => { for (let x = 1; x < 4; x++) px(x, 0, G.g); for (let y = 1; y < 6; y++) { const z = y & 1 ? G.g : G.w; px(0, y, z); px(4, y, z); for (let x = 1; x < 4; x++) px(x, y, y === 1 || x === 2 ? G.wd2 : G.wd); } px(1, 3, G.st); px(3, 3, G.st); });
    const zellige = () => tmod('zellige_band', 4, 1, px => [G.g, G.w, G.b, G.y].forEach((c, x) => px(x, 0, c)));
    const lattice = () => tmod('mashrabiya', 2, 2, px => { px(0, 0, '#a0703e'); px(1, 1, '#a0703e'); px(1, 0, '#3a2818'); px(0, 1, '#3a2818'); });
    const awning = () => tmod('awning_stripe', 2, 1, px => { px(0, 0, '#ffffff'); px(1, 0, '#9c9c9c'); });
    const roofS = () => tmod('roof_tile_s', 4, 2, px => { for (let x = 0; x < 4; x++) { px(x, 0, x === 3 ? '#d4d4d4' : '#f0f0f0'); px(x, 1, '#8e8e8e'); } });
    const domeRib = () => mod('dome_rib', 12, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 12; x++) px(x, y, y === 5 ? '#bcbcbc' : x % 3 === 0 ? '#b0b0b0' : x % 3 === 1 ? '#ffffff' : y === 0 ? '#d8d8d8' : '#ececec'); });
    const domeStripe = () => mod('dome_stripe', 12, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 12; x++) px(x, y, (x + y) % 4 < 2 ? '#ffffff' : '#8e8e8e'); });
    const doorT = () => mod('door_small', 1, 2, px => { px(0, 0, G.wd2); px(0, 1, G.wd); });
    const finial = () => mod('finial_gold', 1, 3, px => { px(0, 0, '#f2d33d'); px(0, 1, '#c99a2e'); px(0, 2, '#f2d33d'); });
    const sebka = () => tmod('minaret_sebka', 3, 12, px => { for (let y = 0; y < 12; y++) for (let x = 0; x < 3; x++) { let c = x === 0 ? '#d6d6d6' : x === 2 ? '#c2c2c2' : '#ececec';
        if (y < 2) c = (x + y) % 2 ? '#8e8e8e' : '#b8b8b8'; else if (y >= 3 && y <= 7 && ((x === 1) === (y % 2 === 1))) c = '#a4a4a4'; else if ((y === 9 || y === 10) && x === 1) c = '#2e2e2e'; else if (y === 11) c = '#cfcfcf'; px(x, y, c); } });
    const brick = () => tmod('brick_red', 4, 8, px => { for (let y = 0; y < 8; y++) for (let x = 0; x < 4; x++) { const joint = (x + ((y >> 1) % 2) * 2) % 4 === 0;
        px(x, y, y === 0 ? '#e8e2d0' : y % 2 === 0 || joint ? '#8a3020' : n(x, y) > 0.8 ? '#c4553a' : '#b0442e'); } for (const [x, y] of [[1, 3], [2, 3], [1, 4], [2, 4]]) px(x, y, '#2e2422'); });
    const ONION = [[0, 0.78], [0.2, 0.98], [0.42, 0.92], [0.62, 0.62], [0.8, 0.28], [1, 0]], CYL = [[0, 1], [1, 1]];
    const lathe = (x, z, y, w, h, prof, tex, tint) => ({ kind: 'lathe', x, z, y, w, d: w, h, prof, tint, tex: { side: tex } });
    const pbox = (x, z, y, w, d, h, T, tex) => ({ ...box(x, z, y, w, d, h, { top: pisePlain(), front: tex || pise(), left: tex || pise(), right: tex || pise() }), tint: T.wall });
    const bbox = (x, z, y, w, d, h) => box(x, z, y, w, d, h, { top: sw(1), front: brick(), left: brick(), right: brick() });
    const cbox = (x, z, y, w, d, T) => ({ ...box(x, z, y, w, d, 2, { top: pisePlain(), front: crenel(), left: crenel(), right: crenel() }), tint: T.wall });
    const par = (x, z, y, w, d, T, bk) => { const c = bk ? brickCrenel() : crenel(), tx = { top: bk ? sw(1) : pisePlain(), front: c, left: c, right: c }, P = (bx, bz, bw, bd) => ({ ...box(bx, bz, y, bw, bd, 2, tx), tint: bk ? null : T.wall });
      return [P(x, z - d / 2 + 0.5, w, 1), P(x, z + d / 2 - 0.5, w, 1), P(x - w / 2 + 0.5, z, 1, d - 2), P(x + w / 2 - 0.5, z, 1, d - 2)]; };
    const card = (x, zf, y, w, h, tex, tint) => ({ kind: 'card', x, z: zf - 0.12, y, w, h, tint, tex: { front: tex } });
    const door = (x, zf) => card(x, zf, 0, 3, 4, doorS()), band = (x, zf, y, w) => card(x, zf, y, w, 1, zellige());
    const fin = (x, z, y) => ({ kind: 'card', x, z, y, w: 1, h: 3, tex: { front: finial() } });
    const roof = (x, z, y, w, d, h, tint) => ({ kind: 'pyr', x, z, y, w, d, h, tint, tex: { s: roofS(), n: roofS(), l: roofS(), r: roofS() } });
    const shift = (parts, dx, dz) => parts.map(p => ({ ...p, x: p.x + dx, z: p.z + dz }));
    // ── Nation styles (2026-10-07): Kathaya (mid-colonial + old west), Aldurstein (nordic + turkish, semi-modern), Zukei (japanese, medieval → modern),
    // Suorr (heavy industrial, london / spain), Miliim (african), Aerdis (fantasy irish, a bit modern), Copari (cheap industrial, french colonial / victorian, 1920s german).
    // Grayscale tile textures (tinted per part): clapboard, wall_window, corrugated, thatch, stone_tile, strip_window. Colored: half_timber, shoji_wall, door_plain, sign_board, clock_face, window_glow.
    const clap = () => tmod('clapboard', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, y === 3 ? '#a2a2a2' : y === 0 ? '#ffffff' : n(x, y + 40) > 0.85 ? '#d6d6d6' : '#e8e8e8'); });
    // Fire (2026-10-07): 4-frame strip (4 × 5×8 px), frame 0 = fireF0 sub-rect; the shader steps frames (6 fps, per-object phase). Parts with fire: 1 use it on every face.
    const fireStrip = () => { const s = mod('fire_anim', 20, 8, px => { for (let f = 0; f < 4; f++) { const sway = [0, 0.8, 0, -0.8][f], tip = [1, 0, 2, 1][f];
      for (let y = tip; y < 8; y++) { const t = y / 7, w = t < 0.25 ? 0.6 : t < 0.5 ? 1.2 : t < 0.85 ? 2 : 1.6, cx = 2 + sway * (1 - t);
        for (let x = 0; x < 5; x++) { const dx = Math.abs(x - cx); if (dx > w) continue; px(f * 5 + x, y, y === 7 ? (dx < 1 ? '#ffc43a' : '#c83a10') : dx <= w - 1.2 && t > 0.45 ? '#fff2a8' : dx <= w - 0.6 ? '#ffc43a' : t < 0.4 ? '#ff8a1e' : '#e8501a'); } }
      if (f === 1) px(5 + 3, 0, '#ffd23a'); if (f === 3) px(15 + 1, 0, '#ff8a1e'); } }); s.fw = 5; return s; };
    const coals = () => mod('coals', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const v = n(x * 7 + 3, y * 5 + 11); px(x, y, v > 0.86 ? '#ffb23a' : v > 0.7 ? '#e0501a' : v > 0.45 ? '#3a2e2a' : v > 0.2 ? '#2a2220' : '#4a3a32'); } }); // charcoal + embers (brazier beds, campfires)
    const fireF0 = () => sub('fire_f0', fireStrip(), [0, 0, 5, 8]), litW = () => mod('lit_white', 1, 1, px => px(0, 0, '#f2f2f2'));
    const winW = () => tmod('wall_window', 4, 5, px => { for (let y = 0; y < 5; y++) for (let x = 0; x < 4; x++) px(x, y, x >= 1 && x <= 2 && y >= 1 && y <= 2 ? (x === 1 && y === 1 ? '#5c5c5c' : '#2c2c2c') : y === 4 ? '#d2d2d2' : '#f4f4f4'); });
    const corr = () => tmod('corrugated', 2, 4, px => { for (let y = 0; y < 4; y++) { px(0, y, '#ffffff'); px(1, y, n(1, y + 60) > 0.7 ? '#8a8a8a' : '#a6a6a6'); } });
    const thatch = () => tmod('thatch', 4, 3, px => { for (let y = 0; y < 3; y++) for (let x = 0; x < 4; x++) px(x, y, y === 2 ? '#9c9c9c' : n(x * 5 + 7, y * 3) > 0.62 ? '#c4c4c4' : '#ededed'); });
    const stoneT = () => tmod('stone_tile', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, y === 1 || y === 3 || x === (y < 2 ? 0 : 2) ? '#9e9e9e' : n(x + 70, y) > 0.6 ? '#d0d0d0' : '#e6e6e6'); });
    const strip = () => tmod('strip_window', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, y === 1 ? '#2c2c2c' : y === 2 ? '#4c4c4c' : y === 3 ? '#d6d6d6' : '#f6f6f6'); });
    const timber = () => tmod('half_timber', 6, 6, px => { for (let y = 0; y < 6; y++) for (let x = 0; x < 6; x++) px(x, y, x === 0 || y === 0 || y === 5 || x === y || x === 5 - y ? '#4a3220' : '#efe6d0'); });
    const shoji = () => tmod('shoji_wall', 4, 5, px => { for (let y = 0; y < 5; y++) for (let x = 0; x < 4; x++) px(x, y, x === 0 || y === 0 ? '#3a2a1e' : y >= 3 ? (x === 2 ? '#4a3424' : '#5e4230') : x === 2 ? '#d6d0bf' : '#f2efe6'); });
    const doorP = () => mod('door_plain', 2, 3, px => { for (let y = 0; y < 3; y++) { px(0, y, '#6e4a2c'); px(1, y, y === 0 ? '#4a3220' : '#8a5e38'); } px(1, 2, '#e0b040'); });
    const sign = () => mod('sign_board', 4, 2, px => { for (let y = 0; y < 2; y++) for (let x = 0; x < 4; x++) px(x, y, y === 0 && (x === 1 || x === 2) ? '#f0dca0' : '#7a4e2c'); });
    const clock = () => mod('clock_face', 2, 2, px => { px(0, 0, '#f2efe6'); px(1, 0, '#f2efe6'); px(0, 1, '#f2efe6'); px(1, 1, '#2c2c2c'); });
    const winGlow = () => mod('window_glow', 1, 1, px => px(0, 0, '#ffe07a'));
    const deck = () => tmod('deck_plank', 3, 2, px => { for (let x = 0; x < 3; x++) { px(x, 0, x === 2 ? '#a8a8a8' : '#efefef'); px(x, 1, x === 2 ? '#8e8e8e' : '#cfcfcf'); } });
    const DOME = [[0, 1], [0.35, 0.94], [0.65, 0.75], [0.85, 0.48], [1, 0]], CONE = [[0, 1], [1, 0.04]];
    const tb = (x, z, y, w, d, h, side, tint, top) => ({ ...box(x, z, y, w, d, h, { top: top || pisePlain(), front: side, left: side, right: side }), tint });
    const gb = (x, z, y, w, d, h, tex, tint) => ({ kind: 'gable', x, z, y, w, d, h, tint, tex: { s: tex, n: tex, l: tex, r: tex } });
    const py = (x, z, y, w, d, h, tex, tint) => ({ kind: 'pyr', x, z, y, w, d, h, tint, tex: { s: tex, n: tex, l: tex, r: tex } });
    const plainW = () => tmod('plain_white', 1, 1, px => px(0, 0, '#f2f2f2')), lt = t => (t && t.r ? plainW() : t); // lathes can't take sub-rects
    const cyl = (x, z, y, w, h, tex, tint) => lathe(x, z, y, w, h, CYL, lt(tex), tint), cone = (x, z, y, w, h, tex, tint) => lathe(x, z, y, w, h, CONE, lt(tex), tint);
    const pick = (r, a) => a[Math.floor(r() * a.length) % a.length];
    const chim = (x, z, y, h) => box(x, z, y, 0.8, 0.8, h, { top: sw(1), front: stonePlain(), left: stonePlain(), right: stonePlain() });
    const KIT = {
      dar: (T, r) => { const h = r() < 0.4 ? 5 : 4; return { W: 5, D: 5, parts: [pbox(2.5, 2.5, 0, 5, 5, h, T), ...par(2.5, 2.5, h, 5, 5, T), door(2.5, 0)] }; },
      riad: (T, r) => { const dx = r() < 0.5 ? 2.5 : 5.5, ox = 8 - dx; return { W: 8, D: 6, parts: [pbox(4, 3, 0, 8, 6, 5, T), ...par(4, 3, 5, 8, 6, T), band(4, 0, 4, 8), door(dx, 0), card(ox, 0, 2, 2, 2, lattice()),
        pbox(ox, 3.5, 5, 3, 2, 2, T), card(ox, 2.5, 6, 4, 1, awning(), T.awn)] }; },
      tower_house: T => ({ W: 7, D: 7, parts: [pbox(3.5, 3.5, 0, 6, 6, 9, T), ...par(3.5, 3.5, 9, 6, 6, T), door(3.5, 0.5),
        ...[[1, 1], [6, 1], [1, 6], [6, 6]].flatMap(([x, z]) => [pbox(x, z, 0, 2, 2, 11, T), cbox(x, z, 11, 2, 2, T)])] }),
      domed: T => ({ W: 6, D: 6, parts: [pbox(3, 3, 0, 6, 6, 4, T), ...par(3, 3, 4, 6, 6, T), door(3, 0), lathe(3, 3, 4, 3, 2, CYL, pise(), T.wall), lathe(3, 3, 6, 4, 4, ONION, domeRib(), T.dome), fin(3, 3, 9.6)] }),
      hammam: T => ({ W: 8, D: 6, parts: [pbox(4, 3, 0, 8, 6, 4, T), ...par(4, 3, 4, 8, 6, T), door(4, 0), ...[2, 4, 6].flatMap(x => [lathe(x, 3, 4, 2, 1, CYL, pise(), T.wall), lathe(x, 3, 5, 2, 2, ONION, domeRib(), T.dome)])] }),
      merchant: T => ({ W: 10, D: 6, parts: [pbox(5, 3, 0, 9, 5, 5, T), roof(5, 3, 5, 10, 6, 3, T.roof), card(5, 0.5, 4, 9, 1, awning(), T.awn), door(2.5, 0.5), door(7.5, 0.5)] }),
      caravanserai: T => ({ W: 10, D: 8, parts: [pbox(1.5, 1, 0, 3, 2, 4, T), pbox(8.5, 1, 0, 3, 2, 4, T), pbox(5, 7, 0, 10, 2, 4, T), pbox(1, 4, 0, 2, 4, 4, T), pbox(9, 4, 0, 2, 4, 4, T),
        pbox(5, 1.5, 0, 4, 3, 6, T), ...par(5, 1.5, 6, 4, 3, T), door(5, 0), band(5, 0, 5, 4), ...[[1.5, 0.5, 3, 1], [8.5, 0.5, 3, 1], [5, 7.5, 10, 1], [0.5, 4, 1, 4], [9.5, 4, 1, 4]].map(([x, z, w, d]) => cbox(x, z, 4, w, d, T))] }),
      minaret: T => ({ W: 3, D: 3, parts: [{ ...box(1.5, 1.5, 0, 3, 3, 12, { top: pisePlain(), front: sebka(), left: sebka(), right: sebka() }), tint: T.wall }, pbox(1.5, 1.5, 12, 2, 2, 2, T),
        lathe(1.5, 1.5, 14, 3, 3, ONION, domeRib(), T.dome), fin(1.5, 1.5, 16.6)] }),
      // small fillers (≈ 4×4 map px)
      hut: T => ({ W: 3, D: 3, parts: [pbox(1.5, 1.5, 0, 3, 3, 3, T), ...par(1.5, 1.5, 3, 3, 3, T), card(1.5, 0, 0, 1, 2, doorT())] }),
      stall: T => ({ W: 5, D: 4, parts: [pbox(2.5, 2, 0, 4, 3, 2, T), box(0.75, 0.75, 2, 0.5, 0.5, 1, { top: sw(3), front: sw(3), left: sw(3), right: sw(3) }), box(4.25, 0.75, 2, 0.5, 0.5, 1, { top: sw(3), front: sw(3), left: sw(3), right: sw(3) }),
        { ...box(2.5, 2, 3, 5, 4, 1, { top: awning(), front: awning(), left: awning(), right: awning() }), tint: T.awn }] }),
      // uniquely shaped
      stepped_kasbah: T => ({ W: 8, D: 8, parts: [pbox(4, 4, 0, 8, 8, 4, T), ...par(4, 4, 4, 8, 8, T), door(4, 0), band(4, 0, 3, 8), pbox(4.5, 4.5, 4, 5, 5, 3, T), ...par(4.5, 4.5, 7, 5, 5, T),
        card(4.5, 2, 4.5, 2, 2, lattice()), pbox(5, 5, 7, 3, 3, 3, T), ...par(5, 5, 10, 3, 3, T)] }),
      l_house: T => ({ W: 9, D: 8, parts: [pbox(4.5, 2, 0, 9, 4, 4, T), ...par(4.5, 2, 4, 9, 4, T), door(6.5, 0), card(2.5, 0, 1, 2, 2, lattice()), band(4.5, 0, 3, 9),
        pbox(2.5, 6, 0, 5, 4, 6, T), ...par(2.5, 6, 6, 5, 4, T), lathe(2.5, 6, 6, 2, 1, CYL, pise(), T.wall), lathe(2.5, 6, 7, 3, 3, ONION, domeRib(), T.dome), fin(2.5, 6, 9.6)] }),
      round_tower: T => ({ W: 5, D: 5, parts: [lathe(2.5, 2.5, 0, 4, 10, CYL, pise(), T.wall), lathe(2.5, 2.5, 10, 5, 1, CYL, pise(), T.wall), lathe(2.5, 2.5, 11, 4, 4, ONION, domeRib(), T.dome),
        fin(2.5, 2.5, 14.6), card(2.5, 0.5, 0, 3, 4, doorS()), band(2.5, 0.5, 8, 2)] }),
      cathedral: T => ({ W: 8, D: 8, parts: [pbox(4, 4, 0, 8, 8, 6, T), card(4, 0, 0, 5, 6, gate()), band(4, 0, 5, 8), lathe(4, 4, 6, 3, 3, CYL, pise(), T.wall), lathe(4, 4, 9, 4, 4, ONION, domeRib(), T.dome), fin(4, 4, 12.6),
        ...[[1.75, 1.75], [6.25, 1.75], [1.75, 6.25], [6.25, 6.25]].flatMap(([x, z]) => [lathe(x, z, 6, 1.5, 2, CYL, pise(), T.wall), lathe(x, z, 8, 2, 2, ONION, domeStripe(), T.stripe)])] }),
      shatyor: T => ({ W: 4, D: 4, parts: [bbox(2, 2, 0, 4, 4, 7), ...par(2, 2, 7, 4, 4, T, true), lathe(2, 2, 7, 3, 2, CYL, brick()), lathe(2, 2, 9, 3, 6, [[0, 1], [1, 0.08]], roofS(), T.tent), lathe(2, 2, 14.6, 1.5, 1.5, ONION, domeRib(), T.dome), fin(2, 2, 15.8)] }),
      windcatcher: T => ({ W: 6, D: 6, parts: [pbox(3, 3, 0, 6, 6, 5, T), ...par(3, 3, 5, 6, 6, T), door(2, 0), pbox(4.5, 4.5, 5, 2, 2, 6, T), card(4.5, 3.5, 8, 2, 2, lattice()), cbox(4.5, 4.5, 11, 2, 2, T)] }),
      kremlin_tower: T => ({ W: 4, D: 4, parts: [bbox(2, 2, 0, 4, 4, 8), ...par(2, 2, 8, 4, 4, T, true), roof(2, 2, 8, 3, 3, 5, T.tent), lathe(2, 2, 12.5, 2, 2, ONION, domeStripe(), T.dome), fin(2, 2, 14.3)] }) };
    const dp = (x, zf) => card(x, zf, 0, 2, 3, doorP()), post = (x, z, y, h, tint) => tb(x, z, y, 0.6, 0.6, h, clap(), tint);
    Object.assign(KIT, {
      // Kathaya — adobe + clapboard, false fronts, porches, mission church, water tower
      kt_shack: T => ({ W: 3, D: 3, parts: [tb(1.5, 1.5, 0, 3, 3, 3, clap(), T.wood), tb(1.5, 1.5, 3, 3.4, 3.4, 0.5, corr(), T.tin, corr()), dp(1.5, 0)] }),
      kt_adobe: (T, r) => { const h = r() < 0.5 ? 4 : 3; return { W: 5, D: 4, parts: [pbox(2.5, 2, 0, 5, 4, h, T), ...par(2.5, 2, h, 5, 4, T), dp(2.5, 0), ...[1, 2, 3, 4].map(x => card(x, 0, h - 1, 0.5, 0.5, sw(3)))] }; },
      kt_falsefront: (T, r) => { const c = pick(r, T.boards); return { W: 6, D: 6, parts: [tb(3, 3.75, 0, 6, 4.5, 5, clap(), c), gb(3, 4, 5, 6.4, 4, 2, roofS(), T.tin), card(3, 1.5, 5, 6, 3, clap(), c), card(3, 1.45, 5.6, 4, 2, sign()),
        tb(3, 0.75, 3.4, 6, 1.5, 0.4, clap(), T.wood, clap()), post(0.4, 0.3, 0, 3.4, T.wood), post(5.6, 0.3, 0, 3.4, T.wood), dp(3, 1.5)] }; },
      kt_saloon: (T, r) => ({ W: 8, D: 6, parts: [tb(4, 3.75, 0, 8, 4.5, 7, clap(), pick(r, T.boards)), gb(4, 4, 7, 8.4, 4, 2, roofS(), T.tin), card(4, 1.5, 7, 8, 2, clap(), T.wood), card(4, 1.45, 7.3, 5, 2, sign()),
        tb(4, 0.75, 3.4, 8, 1.5, 0.4, clap(), T.wood, clap()), card(4, 0.17, 3.8, 8, 1, fenceTex()), ...[0.4, 4, 7.6].map(x => post(x, 0.3, 0, 3.4, T.wood)), dp(4, 1.5)] }),
      kt_mission: T => ({ W: 8, D: 10, parts: [pbox(4.5, 6, 0, 6, 8, 6, T), gb(4.5, 6, 6, 6.4, 8.4, 2.5, roofS(), T.roof), card(4.5, 2, 6, 6, 3, pise(), T.wall), card(4.5, 1.95, 7.6, 1.2, 1.2, sw(1)), door(4.5, 2),
        pbox(1, 3, 0, 2, 2, 10, T), py(1, 3, 10, 2.4, 2.4, 2, roofS(), T.roof)] }),
      kt_watertower: T => ({ W: 4, D: 4, parts: [...[[0.8, 0.8], [3.2, 0.8], [0.8, 3.2], [3.2, 3.2]].map(([x, z]) => post(x, z, 0, 6, T.wood)), cyl(2, 2, 6, 4, 3, clap(), T.wood), cone(2, 2, 9, 4.4, 1.5, roofS(), T.tin)] }),
      kt_hacienda: T => ({ W: 9, D: 8, parts: [pbox(4.5, 6.5, 0, 9, 3, 4, T), gb(4.5, 6.5, 4, 9.4, 3.4, 1.5, roofS(), T.roof), pbox(1.25, 3, 0, 2.5, 4, 3.5, T), pbox(7.75, 3, 0, 2.5, 4, 3.5, T),
        gb(1.25, 3, 3.5, 2.9, 4.4, 1.2, roofS(), T.roof), gb(7.75, 3, 3.5, 2.9, 4.4, 1.2, roofS(), T.roof), dp(4.5, 5), pbox(4.5, 0.4, 0, 4, 0.8, 1.5, T)] }),
      // Aldurstein — falu-red cabins, turf longhouses, stave church, ottoman bay houses, lead-domed mosque, rendered blocks
      al_stuga: (T, r) => ({ W: 3, D: 4, parts: [tb(1.5, 2, 0, 3, 4, 3, clap(), pick(r, [T.falu, T.falu, '#d8b040', '#e8e4dc'])), gb(1.5, 2, 3, 3.6, 4.4, 2, roofS(), T.roof), dp(1.5, 0)] }),
      al_longhouse: T => ({ W: 9, D: 5, parts: [tb(4.5, 2.5, 0, 9, 4, 3, clap(), T.wood), gb(4.5, 2.5, 3, 9.6, 5, 3.5, thatch(), T.turf), dp(4.5, 0.5)] }),
      al_stave: T => ({ W: 6, D: 6, parts: [tb(3, 3, 0, 5, 5, 4, clap(), T.wood), py(3, 3, 4, 6.4, 6.4, 2.5, roofS(), T.roof), tb(3, 3, 5.5, 3, 3, 2.5, clap(), T.wood), py(3, 3, 8, 4, 4, 2, roofS(), T.roof),
        tb(3, 3, 9, 1.6, 1.6, 2, clap(), T.wood), cone(3, 3, 11, 2, 5, roofS(), T.roof), dp(3, 0.5)] }),
      al_ottoman: T => ({ W: 6, D: 5, parts: [tb(3, 2.75, 0, 5, 4.5, 3, winW(), T.stone), tb(3, 2.5, 3, 6, 5, 3, timber()), py(3, 2.5, 6, 6.6, 5.6, 2, roofS(), T.tile), dp(3, 0.5)] }),
      al_mosque: T => ({ W: 10, D: 9, parts: [tb(5, 5, 0, 8, 8, 5, winW(), T.stone), cyl(5, 5, 5, 4, 1, winW(), T.stone), lathe(5, 5, 6, 6, 3.5, DOME, roofS(), T.lead), fin(5, 5, 9.4),
        ...[2.5, 7.5].map(x => lathe(x, 2, 5, 2.5, 1.5, DOME, roofS(), T.lead)), ...[0.75, 9.25].flatMap(x => [cyl(x, 1, 0, 1.4, 14, winW(), T.stone), cyl(x, 1, 10, 2, 0.6, pisePlain(), T.stone), cone(x, 1, 14, 1.4, 4, roofS(), T.lead)]), door(5, 1)] }),
      al_block: (T, r) => { const h = 6 + Math.floor(r() * 3); return { W: 6, D: 5, parts: [tb(3, 2.5, 0, 6, 5, h, winW(), pick(r, [T.block, '#d8c8a0', '#a8c0c8'])), tb(3, 2.5, h, 6, 5, 0.6, pisePlain(), '#8a8a8a'), dp(3, 0)] }; },
      al_warehouse: T => ({ W: 8, D: 5, parts: [tb(4, 2.5, 0, 8, 5, 4, clap(), T.falu), gb(4, 2.5, 4, 8.4, 5.4, 2, roofS(), T.roof), card(4, 0, 0, 3, 3, clap(), T.wood)] }),
      // Zukei — thatched minka, two-storey machiya, temple, five-tier pagoda, castle keep + yagura turrets, torii, modern shops
      zk_minka: T => ({ W: 4, D: 4, parts: [tb(2, 2, 0, 4, 4, 2.5, shoji()), gb(2, 2, 2.5, 4.6, 4.6, 3, thatch(), T.thatch), dp(2, 0)] }),
      zk_machiya: T => ({ W: 5, D: 6, parts: [tb(2.5, 3, 0, 5, 6, 3, shoji()), gb(2.5, 3, 3, 5.6, 6.6, 1, roofS(), T.roof), tb(2.5, 3.6, 3, 5, 4.6, 2.5, shoji()), gb(2.5, 3.6, 5.5, 5.6, 5.2, 1.8, roofS(), T.roof), dp(2.5, 0)] }),
      zk_temple: T => ({ W: 9, D: 9, parts: [tb(4.5, 4.5, 0, 9, 9, 1, stoneT(), T.stone, stoneT()), tb(4.5, 4.5, 1, 6, 6, 4, shoji()), py(4.5, 4.5, 5, 10, 10, 2, roofS(), T.roof), tb(4.5, 4.5, 6, 4, 4, 1.5, shoji()),
        gb(4.5, 4.5, 7.5, 6, 5, 3, roofS(), T.roof), ...[1.6, 7.4].map(x => tb(x, 1.6, 1, 0.6, 0.6, 4, pisePlain(), T.red))] }),
      zk_pagoda: T => { const o = [tb(2.5, 2.5, 0, 5, 5, 0.6, stoneT(), T.stone, stoneT())]; let y = 0.6; for (let i = 0; i < 5; i++) { const w = 3.4 - i * 0.4; o.push(tb(2.5, 2.5, y, w, w, 1.6, shoji()), py(2.5, 2.5, y + 1.6, w + 2, w + 2, 0.9, roofS(), T.roof)); y += 2.1; }
        o.push(cyl(2.5, 2.5, y - 0.3, 0.4, 3, pisePlain(), '#c9a040')); return { W: 5, D: 5, parts: o }; },
      zk_castle: T => ({ W: 9, D: 8, parts: [tb(4.5, 4, 0, 9, 8, 3, stoneT(), T.stone, stoneT()), tb(4.5, 4, 3, 7, 6, 3, winW(), T.plaster), py(4.5, 4, 6, 8.4, 7.4, 1.6, roofS(), T.roof), tb(4.5, 4, 6.8, 5, 4, 2.5, winW(), T.plaster),
        gb(4.5, 4, 9.3, 6, 5, 1.6, roofS(), T.roof), tb(4.5, 4, 10.2, 3, 2.6, 2, winW(), T.plaster), py(4.5, 4, 12.2, 4.4, 4, 2, roofS(), T.roof), card(4.5, 0, 0, 2, 2.5, doorP())] }),
      zk_yagura: T => ({ W: 3, D: 3, parts: [tb(1.5, 1.5, 0, 3, 3, 2.5, stoneT(), T.stone, stoneT()), tb(1.5, 1.5, 2.5, 2.4, 2.4, 2.4, winW(), T.plaster), py(1.5, 1.5, 4.9, 3.4, 3.4, 1.6, roofS(), T.roof)] }),
      // torii spans a road: opt.along = 'x' (crossbar along x, road runs N–S) or 'z' (road runs E–W). Posts sit just outside a 4 px main road.
      zk_torii: (T, r, opt) => { const X = !opt || opt.along !== 'z', B = (a, b, y, w, d, h, c) => X ? tb(a, b, y, w, d, h, pisePlain(), c) : tb(b, a, y, d, w, h, pisePlain(), c);
        return { W: X ? 5 : 1, D: X ? 1 : 5, parts: [B(0.4, 0.5, 0, 0.6, 0.6, 5, T.red), B(4.6, 0.5, 0, 0.6, 0.6, 5, T.red), B(2.5, 0.5, 5, 6, 0.7, 0.6, '#2a2a2a'), B(2.5, 0.5, 4, 4.6, 0.5, 0.4, T.red)] }; },
      zk_shop: (T, r) => { const h = 4 + Math.floor(r() * 3); return { W: 4, D: 5, parts: [tb(2, 2.5, 0, 4, 5, h, strip(), pick(r, [T.gray, T.plaster, '#b8c0c4'])), tb(2, 2.5, h, 4, 5, 0.5, pisePlain(), '#7a7a7a'), card(2, 0, h - 1.5, 2, 1, sign(), T.red), dp(2, 0)] }; },
      // Suorr — brick terraces with chimneys, sawtooth factories + smokestacks, gasholders, whitewashed casas, spanish cathedral, clock tower
      su_cottage: T => ({ W: 3, D: 4, parts: [bbox(1.5, 2, 0, 3, 4, 3), gb(1.5, 2, 3, 3.4, 4.4, 1.6, roofS(), T.slate), dp(1.5, 0)] }),
      su_terrace: () => ({ W: 10, D: 4, parts: [bbox(5, 2, 0, 10, 4, 5), gb(5, 2, 5, 10.4, 4.4, 2, roofS(), '#4a4e58'), ...[1.7, 5, 8.3].flatMap(x => [chim(x, 2.2, 5.8, 2.2), dp(x, 0)])] }),
      su_factory: T => ({ W: 10, D: 8, parts: [bbox(5, 4, 0, 10, 8, 5), ...[1.35, 4, 6.65].map(z => gb(5, z, 5, 10, 2.7, 1.8, corr(), T.iron)), cyl(8.5, 6.5, 0, 1.6, 15, brick()), cyl(8.5, 6.5, 15, 1.8, 0.6, pisePlain(), T.soot), card(3, 0, 0, 3, 3, corr(), T.iron)] }),
      su_gasholder: T => ({ W: 6, D: 6, parts: [cyl(3, 3, 0, 6, 5, corr(), T.iron), lathe(3, 3, 5, 6, 0.8, DOME, corr(), T.iron), ...[[0.4, 0.4], [5.6, 0.4], [0.4, 5.6], [5.6, 5.6]].map(([x, z]) => tb(x, z, 0, 0.4, 0.4, 6.5, pisePlain(), T.soot))] }),
      su_casa: (T, r) => { const h = r() < 0.4 ? 6 : 4; return { W: 5, D: 5, parts: [tb(2.5, 2.5, 0, 5, 5, h, winW(), T.stucco), py(2.5, 2.5, h, 5.6, 5.6, 1.6, roofS(), T.terra), card(2.5, 0, h - 2.2, 3, 0.6, fenceTex()), dp(2.5, 0)] }; },
      su_cathedral: T => ({ W: 9, D: 10, parts: [tb(5, 6, 0, 7, 8, 7, winW(), T.stucco), gb(5, 6, 7, 7.4, 8.4, 3, roofS(), T.terra), tb(5, 6.5, 0, 9, 2.4, 6, winW(), T.stucco), gb(5, 6.5, 6, 9.4, 2.8, 1.6, roofS(), T.terra),
        tb(2, 2, 0, 3, 3, 14, winW(), T.stucco), py(2, 2, 14, 3.4, 3.4, 1, roofS(), T.terra), lathe(2, 2, 15, 2.4, 2.4, DOME, roofS(), T.terra), fin(2, 2, 17.2), door(6, 2)] }),
      su_clocktower: T => ({ W: 4, D: 4, parts: [bbox(2, 2, 0, 3, 3, 13), box(2, 2, 13, 3.6, 3.6, 1, { top: sw(1), front: stonePlain(), left: stonePlain(), right: stonePlain() }), card(2, 0.5, 10.5, 2, 2, clock()), py(2, 2, 14, 3.6, 3.6, 5, roofS(), T.slate), fin(2, 2, 18.6)] }),
      su_bastion: T => ({ W: 4, D: 4, parts: [cyl(2, 2, 0, 4, 7, brick()), cyl(2, 2, 7, 4.4, 1, pisePlain(), T.slate)] }),
      // Miliim — thatched rondavels, granaries, walled compounds, sahelian mud houses + mosque with torons, tiered palace, market
      ml_rondavel: (T, r) => ({ W: 3, D: 3, parts: [cyl(1.5, 1.5, 0, 3, 2.5, pise(), pick(r, [T.mud, T.ochre, T.lime])), cone(1.5, 1.5, 2.5, 3.8, 2.8, thatch(), T.thatch)] }),
      ml_granary: T => ({ W: 2, D: 2, parts: [cyl(1, 1, 0, 1, 0.8, pisePlain(), T.wood), cyl(1, 1, 0.8, 2, 2, pise(), T.mud), cone(1, 1, 2.8, 2.6, 2, thatch(), T.thatch)] }),
      ml_compound: (T, r) => ({ W: 8, D: 7, parts: [pbox(2, 0.4, 0, 4, 0.8, 2, T), pbox(7, 0.4, 0, 2, 0.8, 2, T), pbox(4, 6.6, 0, 8, 0.8, 2, T), pbox(0.4, 3.5, 0, 0.8, 5.4, 2, T), pbox(7.6, 3.5, 0, 0.8, 5.4, 2, T),
        ...shift(KIT.ml_rondavel(T, r).parts, 1, 3), ...shift(KIT.ml_rondavel(T, r).parts, 4, 3.2), ...shift(KIT.ml_granary(T, r).parts, 5, 0.9)] }),
      ml_mudhouse: (T, r) => { const h = r() < 0.5 ? 4 : 5; return { W: 5, D: 5, parts: [pbox(2.5, 2.5, 0, 5, 5, h, T), ...par(2.5, 2.5, h, 5, 5, T), ...[0.4, 4.6].map(x => cone(x, 0.4, h, 0.8, 1.8, pisePlain(), T.wall)),
        ...[1.5, 2.5, 3.5].map(x => card(x, 0, h - 1.5, 0.4, 0.4, sw(3))), dp(2.5, 0)] }; },
      ml_mosque: T => ({ W: 10, D: 9, parts: [pbox(5, 5, 0, 10, 8, 5, T), ...par(5, 5, 5, 10, 8, T), ...[1.5, 5, 8.5].flatMap(x => { const h = x === 5 ? 11 : 9; return [pbox(x, 1.5, 0, 2.2, 2.2, h, T), cone(x, 1.5, h, 2.2, 2, pisePlain(), T.wall), ...[3, 5, 7].map(y => card(x, 0.4, y, 2.6, 0.3, sw(3)))]; }), card(5, 0.4, 0, 2, 3, doorP())] }),
      ml_palace: T => ({ W: 9, D: 8, parts: [pbox(4.5, 4, 0, 9, 8, 4, T), ...par(4.5, 4, 4, 9, 8, T), pbox(4.5, 4.5, 4, 6, 5, 3, T), ...par(4.5, 4.5, 7, 6, 5, T), ...[[0.5, 0.5], [8.5, 0.5], [0.5, 7.5], [8.5, 7.5]].map(([x, z]) => cone(x, z, 4, 1.2, 2.4, pisePlain(), T.wall)), card(4.5, 0, 0, 3, 4, doorS())] }),
      ml_market: T => ({ W: 6, D: 5, parts: [...[[0.4, 0.4], [5.6, 0.4], [0.4, 4.6], [5.6, 4.6]].map(([x, z]) => tb(x, z, 0, 0.4, 0.4, 2.6, pisePlain(), T.wood)), tb(3, 2.5, 2.6, 6.4, 5.4, 0.6, thatch(), T.thatch, thatch()), tb(3, 2.5, 0, 4, 2, 1, pise(), T.ochre)] }),
      // Decorative mud-brick bridge (Makaliim citadel): deck at opt.h units over a cut, opt.len units long (N–S), 3 round arches on piers, parapets + torons.
      ml_bridge: (T, r, opt) => { const o = opt || {}, L = o.len || 14, H = o.h || 12, M = '#b8794a', Md = '#9a6038', P = []; // runs along x (W = L) so the arches face the camera
        P.push(tb(L / 2, 2, H - 1.4, L, 4, 1.4, pisePlain(), M), tb(L / 2, 0.25, H, L, 0.5, 1.1, pisePlain(), Md), tb(L / 2, 3.75, H, L, 0.5, 1.1, pisePlain(), Md));
        const n = 3; for (let k = 0; k <= n; k++) { const x = k * L / n; P.push(tb(Math.min(L - 0.6, Math.max(0.6, x)), 2, 0, 1.2, 3.6, H - 1.4, pisePlain(), Md)); }
        for (let k = 0; k < n; k++) { const x0 = k * L / n + 0.6, x1 = (k + 1) * L / n - 0.6, m = (x0 + x1) / 2, s = (x1 - x0) / 2; for (let q = -2; q <= 2; q++) { const xx = m + q * s / 2.5, hh = (H - 1.4) * (0.55 + 0.45 * (Math.abs(q) / 2) ** 2); P.push(tb(xx, 2, hh, s / 2.5 + 0.05, 4, H - 1.4 - hh, pisePlain(), M)); } }
        for (let x = 1; x < L; x += 2.2) P.push(tb(x, 0.25, H + 1.1, 0.5, 0.5, 0.5, pisePlain(), Md), tb(x, 3.75, H + 1.1, 0.5, 0.5, 0.5, pisePlain(), Md));
        return { W: L, D: 4, parts: P }; },
      // Makaliim citadel (raised castle grounds, MOUNDS): sahelian mud-brick enceinte with toron stakes, 4 tapered corner towers, gate on the south (bridge side),
      // palace in the middle (ml_palace × 1.15, fixed palette), courtyard paving.
      ml_citadel: () => { const T = { wall: '#c48a5a', wood: '#6a4a2e', roof: '#8a5a34', red: '#b85030' }, M = '#c48a5a', Md = '#a8703f', o = [tb(10, 10, 0, 20, 20, 0.5, pisePlain(), '#b88a5e')];
        for (const [x, z, w, d] of [[10, 0.9, 17, 1.4], [10, 19.1, 17, 1.4], [0.9, 10, 1.4, 17], [19.1, 10, 1.4, 17]]) { o.push(tb(x, z, 0.5, w, d, 5, pisePlain(), M)); const n = Math.round(Math.max(w, d) / 2.4); for (let k = 0; k < n; k++) { const f = (k + 0.5) / n - 0.5, px = x + (w > d ? f * w : 0), pz = z + (w > d ? 0 : f * d); o.push(tb(px, pz, 5.5, 0.9, 0.9, 1, pisePlain(), Md), tb(px + (w > d ? 0 : 0.8), pz + (w > d ? 0.8 : 0), 3.2, 0.25, 0.25, 0.25, pisePlain(), T.wood)); } }
        for (const [x, z] of [[1.4, 1.4], [18.6, 1.4], [1.4, 18.6], [18.6, 18.6]]) o.push(lathe(x, z, 0.5, 3.6, 8, [[0, 1], [1, 0.62]], pisePlain(), M), cone(x, z, 8.5, 2.4, 1.6, pisePlain(), Md));
        o.push(tb(10, 0.9, 0.5, 4, 2.2, 7, pisePlain(), Md), card(10, -0.25, 0.5, 2.4, 3.6, gate()));
        const P = KIT.ml_palace(T, () => 0.5); for (const p of P.parts) o.push({ ...p, x: (p.x - P.W / 2) * 1.15 + 10, z: (p.z - P.D / 2) * 1.15 + 11, y: (p.y || 0) * 1.15 + 0.5, w: p.w * 1.15, d: p.d * 1.15, h: (p.h || 0) * 1.15 });
        return F(20, 20, o); },
      ml_tower: T => ({ W: 3, D: 3, parts: [pbox(1.5, 1.5, 0, 2.6, 2.6, 7, T), cone(1.5, 1.5, 7, 2.6, 2.4, pisePlain(), T.wall), ...[3, 5].map(y => card(1.5, 0.2, y, 3, 0.3, sw(3)))] }),
      // Aerdis — whitewashed thatch cottages, colorful pub + terrace fronts, slate chapel, round tower, wizard spire, castle keep
      ae_cottage: T => ({ W: 4, D: 3, parts: [tb(2, 1.5, 0, 4, 3, 2.5, winW(), T.white), gb(2, 1.5, 2.5, 4.4, 3.6, 2.4, thatch(), T.thatch), chim(3.4, 1.5, 3, 2.6), dp(1.5, 0)] }),
      ae_longcottage: T => ({ W: 8, D: 4, parts: [tb(4, 2, 0, 8, 3.4, 2.8, winW(), T.white), gb(4, 2, 2.8, 8.4, 4, 2.6, thatch(), T.thatch), chim(0.8, 2, 3.4, 2.6), chim(7.2, 2, 3.4, 2.6), dp(3, 0.3)] }),
      ae_roundtower: T => ({ W: 3, D: 3, parts: [cyl(1.5, 1.5, 0, 2.8, 15, stoneT(), T.stone), cone(1.5, 1.5, 15, 3, 3.6, roofS(), T.stone), card(1.5, 0.2, 5, 0.6, 1.2, sw(1))] }),
      ae_chapel: T => ({ W: 6, D: 8, parts: [tb(3, 4.5, 0, 5, 7, 4, stoneT(), T.stone, stoneT()), gb(3, 4.5, 4, 5.4, 7.4, 3.6, roofS(), T.slate), tb(3, 1.2, 0, 2.4, 2.4, 9, stoneT(), T.stone, stoneT()), py(3, 1.2, 9, 2.8, 2.8, 2, roofS(), T.slate),
        card(3, 0, 0, 1.4, 2.4, doorP()), card(3, 1.32, 11, 0.4, 2, pisePlain(), T.stone), card(3, 1.3, 11.9, 1.4, 0.4, pisePlain(), T.stone)] }),
      ae_wizard: T => ({ W: 4, D: 4, parts: [cyl(2, 2, 0, 3.4, 10, stoneT(), T.stone), cyl(2, 2, 10, 4.2, 1.6, stoneT(), T.stone), cone(2, 2, 11.6, 4.4, 7, roofS(), T.magic), fin(2, 2, 18.4), card(2, 0.3, 0, 1.2, 2.2, doorP()),
        card(2, 0.25, 6, 0.8, 1, winGlow()), card(2, 0.25, 8.4, 0.8, 1, winGlow())] }),
      ae_pub: (T, r) => ({ W: 7, D: 5, parts: [tb(3.5, 2.5, 0, 7, 5, 4.5, winW(), T.white), card(3.5, 0, 0, 7, 3, winW(), pick(r, T.fronts)), card(3.5, -0.02, 2.6, 5, 0.8, sign()), gb(3.5, 2.5, 4.5, 7.4, 5.4, 2.2, roofS(), T.slate), dp(3.5, 0)] }),
      ae_terrace: (T, r) => ({ W: 9, D: 4, parts: [...[1.5, 4.5, 7.5].flatMap(x => [tb(x, 2, 0, 3, 4, 5, winW(), pick(r, T.fronts.concat([T.white]))), dp(x, 0)]), gb(4.5, 2, 5, 9.4, 4.4, 2, roofS(), T.slate)] }),
      ae_keep: T => ({ W: 8, D: 7, parts: [tb(4, 3.5, 0, 7, 6, 8, stoneT(), T.stone, stoneT()), ...par(4, 3.5, 8, 7, 6, T), ...[[0.9, 0.9], [7.1, 0.9], [0.9, 6.1], [7.1, 6.1]].flatMap(([x, z]) => [cyl(x, z, 0, 1.8, 10, stoneT(), T.stone), cone(x, z, 10, 2.2, 3, roofS(), T.slate)]), card(4, 0.5, 0, 2, 3, doorS())] }),
      // Copari — corrugated shacks + warehouses, brick tenements, mansard houses, victorian turret houses, 1920s strip-window blocks, colonial gov. house
      co_shack: (T, r) => ({ W: 3, D: 3, parts: [tb(1.5, 1.5, 0, 3, 3, 2.6, corr(), pick(r, [T.rust, T.iron, '#7a7060'])), tb(1.5, 1.5, 2.6, 3.4, 3.4, 0.4, corr(), T.rust, corr()), dp(1.5, 0)] }),
      co_tenement: (T, r) => { const h = 7 + Math.floor(r() * 3); return { W: 6, D: 5, parts: [bbox(3, 2.5, 0, 6, 5, h), ...par(3, 2.5, h, 6, 5, T, true), dp(3, 0)] }; },
      co_mansard: T => ({ W: 6, D: 5, parts: [tb(3, 2.5, 0, 6, 5, 5, winW(), T.plaster), py(3, 2.5, 5, 6.4, 5.4, 3, roofS(), T.slate), ...[1.8, 4.2].map(x => card(x, 0.3, 5.4, 1, 1.2, winW(), T.plaster)), dp(3, 0)] }),
      co_victorian: (T, r) => { const c = pick(r, T.pastels); return { W: 5, D: 5, parts: [tb(2.5, 2.5, 0, 5, 5, 6, clap(), c), gb(2.5, 2.5, 6, 5.4, 5.4, 3, roofS(), T.slate), cyl(0.9, 0.9, 0, 1.8, 8, clap(), c), cone(0.9, 0.9, 8, 2.2, 3, roofS(), T.slate), dp(3, 0)] }; },
      co_warehouse: T => ({ W: 10, D: 6, parts: [tb(5, 3, 0, 10, 6, 5, corr(), T.rust), gb(5, 3, 5, 10.4, 6.4, 1.4, corr(), T.iron), cyl(9, 5, 0, 1.2, 11, brick()), card(3.5, 0, 0, 3, 3.5, corr(), T.iron), card(7, 0, 3, 3, 1, sign())] }),
      co_bauhaus: T => ({ W: 7, D: 5, parts: [tb(3, 2.5, 0, 6, 5, 6, strip(), T.bau), tb(6.25, 2, 0, 1.5, 4, 8, strip(), T.bau), tb(3, 2.5, 6, 6.2, 5.2, 0.4, pisePlain(), '#bcbcbc'), card(2, 0, 0, 2, 2.6, doorP())] }),
      co_colonial: T => ({ W: 8, D: 7, parts: [tb(4, 4, 0, 8, 6, 6, winW(), T.plaster), py(4, 4, 6, 8.6, 6.6, 2.4, roofS(), T.terra), tb(4, 0.6, 2.8, 8, 1.2, 0.4, clap(), T.plaster), ...[0.4, 2.8, 5.2, 7.6].map(x => post(x, 0.3, 0, 2.8, T.plaster)), door(4, 1), card(4, 1, 4.5, 1.4, 1, flag(), TINT.flag)] }) });
    // ── Train station (2026-10-07): one shared design, no nation palette. opt.side = where the track runs (S / N → long side along x, E / W → along z).
    // Platform slab + canopy on posts on the track side, brick station house, clock tower, sign.
    const STN = { roof: '#4a4e58', canopy: '#46505c', plat: '#b8b0a4', post: '#3a3e44' };
    KIT.station = (T, r, opt) => { const side = (opt && opt.side) || 'S';
      if (side === 'S' || side === 'N') { const S = side === 'S', zp = S ? 1 : 5, zh = S ? 4 : 2;
        return { W: 12, D: 6, parts: [tb(6, zp, 0, 12, 2, 0.6, stoneT(), STN.plat, stoneT()), tb(6, zp, 3.2, 12.4, 2.2, 0.3, corr(), STN.canopy, corr()), ...[0.8, 4, 8, 11.2].map(x => tb(x, zp + (S ? -0.6 : 0.6), 0.6, 0.4, 0.4, 2.6, pisePlain(), STN.post)),
          bbox(6, zh, 0, 10, 4, 4), gb(6, zh, 4, 10.4, 4.4, 2, roofS(), STN.roof), bbox(6, zh, 4, 2.4, 2.4, 4.2), py(6, zh, 8.2, 3, 3, 2.2, roofS(), STN.roof), card(6, zh - 1.2, 6.2, 1.4, 1.4, clock()),
          card(3.5, zh - 2, 3.2, 3, 1, sign()), dp(2, zh - 2), dp(10, zh - 2)] }; }
      const E = side === 'E', xp = E ? 5 : 1, xh = E ? 2 : 4;
      return { W: 6, D: 12, parts: [tb(xp, 6, 0, 2, 12, 0.6, stoneT(), STN.plat, stoneT()), tb(xp, 6, 3.2, 2.2, 12.4, 0.3, corr(), STN.canopy, corr()), ...[0.8, 4, 8, 11.2].map(z => tb(xp + (E ? 0.6 : -0.6), z, 0.6, 0.4, 0.4, 2.6, pisePlain(), STN.post)),
        bbox(xh, 6, 0, 4, 10, 4), py(xh, 3.5, 4, 4.4, 5.2, 2, roofS(), STN.roof), py(xh, 8.5, 4, 4.4, 5.2, 2, roofS(), STN.roof), bbox(xh, 6, 4, 2.4, 2.4, 4.2), py(xh, 6, 8.2, 3, 3, 2.2, roofS(), STN.roof),
        card(xh, 4.8, 6.2, 1.4, 1.4, clock()), dp(xh, 1), card(xh, 1, 3.2, 3, 1, sign())] }; };
    // ── Docks (2026-10-07): dock / harbor / shipyard per nation suite. Built in a shore frame (u along the shore, v from the land back edge out over the water;
    // land 0..Dl, water Dl..Dl+Lp), then turned so the water side faces opt.dir (S / N / E / W). wl parts sit on the water surface; toDeck parts (piles,
    // quay walls) are stretched in-engine from the water up to the deck / land level.
    const DSUITE = {
      buern: { wall: pise, wt: 'wall', roof: 'flat', quay: pise, qt: 'wall', hull: '#6e4a2c', sail: '#f2ead8', tower: 'light', lt: 'wall' },
      vaernebo: { wall: pise, wt: 'wall', roof: 'dome', quay: pise, qt: 'wall', hull: '#5e4030', sail: '#f2ead8', tower: 'light', lt: 'wall' },
      rossade: { wall: pise, wt: 'wall', roof: 'pyr', rt: 'roof', quay: stoneT, qt: '#b8b0a4', hull: '#4a3a30', sail: '#e8e0d0', tower: 'light', lt: '#e8e2d6' },
      kathaya: { wall: clap, wt: 'wood', roof: 'gable', rt: 'tin', quay: clap, qt: 'wood', hull: '#8a5a3a', sail: '#f2ede0', tower: 'crane', ct: 'wood' },
      aldurstein: { wall: clap, wt: 'falu', roof: 'gable', rt: 'roof', quay: stoneT, qt: 'stone', hull: '#3a3e44', sail: '#f2f0ea', tower: 'crane', ct: '#c9a040' },
      zukei: { wall: shoji, wt: null, roof: 'gable', rt: 'roof', quay: stoneT, qt: 'stone', hull: '#6a4a30', sail: '#d8c8a0', tower: 'light', lt: 'plaster' },
      suorr: { wall: brick, wt: null, roof: 'gable', rt: 'slate', quay: stoneT, qt: '#9a948c', hull: '#2e3238', sail: null, funnel: '#b03a32', tower: 'crane', ct: 'iron' },
      miliim: { wall: pise, wt: 'mud', roof: 'thatch', quay: pise, qt: 'mud', hull: '#5a3a22', sail: '#e8dcc0', tower: null },
      aerdis: { wall: winW, wt: 'white', roof: 'gable', rt: 'slate', quay: stoneT, qt: 'stone', hull: '#2f5a3a', sail: '#f2f0e8', tower: 'light', lt: 'white' },
      copari: { wall: corr, wt: 'rust', roof: 'gable', rt: 'iron', quay: brick, qt: null, hull: '#3a3632', sail: null, funnel: '#2a2a2a', tower: 'crane', ct: 'rust' } };
    const ubx = (u, v, y, wu, wv, h, tx, tint, top, x) => ({ kind: 'box', u, v, y, wu, wv, h, tint, ...x, tex: { top: top || tx, front: tx, left: tx, right: tx } });
    const uroof = (kind, u, v, y, wu, wv, h, tx, tint) => ({ kind, u, v, y, wu, wv, h, tint, tex: { s: tx, n: tx, l: tx, r: tx } });
    const ulathe = (u, v, y, w, h, prof, tx, tint) => ({ kind: 'lathe', u, v, y, wu: w, wv: w, h, prof, tint, tex: { side: lt(tx) } });
    const orient = (Wu, Dv, dir, P, extra) => { const ns = dir === 'S' || dir === 'N';
      const parts = P.map(p => { const { u, v, wu, wv, ...q } = p; let x, z, w, d;
        if (dir === 'N') { x = u; z = v; w = wu; d = wv; } else if (dir === 'S') { x = u; z = Dv - v; w = wu; d = wv; } else if (dir === 'E') { x = v; z = Wu - u; w = wv; d = wu; } else { x = Dv - v; z = Wu - u; w = wv; d = wu; }
        return { ...q, x, z, w, d }; });
      return { W: ns ? Wu : Dv, D: ns ? Dv : Wu, parts, ...extra }; };
    const dTint = (T, k) => !k ? null : k[0] === '#' ? k : T[k] || null;
    const shed = (u, v, wu, wv, h, S, T) => { const wt = dTint(T, S.wt), o = [ubx(u, v, 0, wu, wv, h, S.wall(), wt, pisePlain())];
      if (S.roof === 'gable') o.push(uroof('gable', u, v, h, wu + 0.4, wv + 0.4, 1.8, roofS(), dTint(T, S.rt)));
      else if (S.roof === 'pyr') o.push(uroof('pyr', u, v, h, wu + 0.4, wv + 0.4, 1.8, roofS(), dTint(T, S.rt)));
      else if (S.roof === 'thatch') o.push(uroof('gable', u, v, h, wu + 0.6, wv + 0.6, 2.2, thatch(), T.thatch));
      else { o.push(ubx(u, v, h, wu, wv, 0.5, pisePlain(), wt)); if (S.roof === 'dome') o.push(ulathe(u, v, h + 0.5, Math.min(wu, wv) * 0.6, 1.6, DOME, roofS(), T.dome)); }
      return o; };
    const boat = (u, v, len, S, along) => { const L = along === 'u', bw = 1.8, o = [ubx(u, v, 0, L ? len : bw, L ? bw : len, 1, deck(), S.hull, null, { wl: true }), ubx(u, v, 1, L ? len - 0.6 : bw - 0.6, L ? bw - 0.6 : len - 0.6, 0.15, deck(), '#c8a878', null, { wl: true })];
      if (S.funnel) o.push(ubx(u, v, 1, L ? len * 0.35 : 1.2, L ? 1.2 : len * 0.35, 1, winW(), '#e8e4dc', null, { wl: true }), ulathe(u, v, 0, 0.8, 3, CYL, plainW(), S.funnel), { ...ulathe(u, v, 2, 0.8, 1.2, CYL, plainW(), S.funnel), wl: true });
      else { o.push(ubx(u, v, 1, 0.25, 0.25, len * 0.9 + 1, plainW(), '#5a3d24', null, { wl: true }));
        if (S.sail) o.push(ubx(u, v, 2.2, L ? len * 0.6 : 0.15, L ? 0.15 : len * 0.6, len * 0.6, plainW(), S.sail, null, { wl: true })); }
      return o.map(p => p.kind === 'lathe' ? { ...p, wl: true, y: p.y + 1 } : p); };
    const piles = (u, v0, v1, gap) => { const o = []; for (let v = v0; v <= v1; v += 2) for (const du of [-gap, gap]) o.push(ubx(u + du, v, -0.2, 0.35, 0.35, 0, plainW(), '#4a3226', null, { wl: true, toDeck: true })); return o; };
    const tower = (u, v, S, T) => { if (S.tower === 'light') { const c = dTint(T, S.lt) || '#f0ece0'; return [ulathe(u, v, 0, 1.8, 6, CYL, plainW(), c), ulathe(u, v, 3, 1.9, 0.6, CYL, plainW(), '#b03a32'), ulathe(u, v, 6, 1.4, 1, CYL, winGlow()), ulathe(u, v, 7, 1.8, 1.2, CONE, roofS(), '#3a3e44')]; }
      if (S.tower === 'crane') { const c = dTint(T, S.ct) || '#8a6a3a'; return [ubx(u, v, 0, 1.4, 1.4, 6, plainW(), c), ubx(u, v - 1.5, 6, 0.6, 5, 0.6, plainW(), c), ubx(u, v + 1.4, 5.4, 1, 1, 1, plainW(), '#3a3e44'), ubx(u, v - 3.6, 3, 0.15, 0.15, 3, plainW(), '#2a2a2a')]; }
      return []; };
    Object.assign(KIT, {
      dock: (T, r, opt) => { const S = DSUITE[opt.style] || DSUITE.buern, Wu = 10, Dl = 5, Lp = 9, D = Dl + Lp, pu = 7;
        const P = [...shed(3, 2.5, 5, 4, 3, S, T), ubx(pu, Dl + Lp / 2 - 0.5, -0.5, 2.2, Lp + 1, 0.5, deck(), '#9a7048'), ...piles(pu, Dl + 1, D - 1, 0.9), ...boat(4.4, Dl + 5.5, 5, S, 'v')];
        if (r() < 0.6) P.push(...boat(9.2, Dl + 6.5, 3.4, S, 'v'));
        return orient(Wu, D, opt.dir || 'S', P, { Dl, Lp }); },
      harbor: (T, r, opt) => { const S = DSUITE[opt.style] || DSUITE.buern, Wu = 14, Dl = 7, Lp = 6, D = Dl + Lp, qt = dTint(T, S.qt), q = S.quay();
        const P = [...shed(5, 3.2, 9, 5, 4, S, T), ubx(7, Dl + 1, -0.3, 14, 2, 0, q, qt, null, { wl: true, toDeck: true }), ubx(12.2, Dl + 2 + (Lp - 2) / 2, -0.3, 2, Lp - 2, 0, q, qt, null, { wl: true, toDeck: true }),
          ...[2, 6, 10].map(u => ubx(u, Dl + 1.6, 0, 0.4, 0.4, 0.6, plainW(), '#2a2a2a')), ...boat(6, Dl + 3.6, 8, S, 'u'), ...tower(12.2, D - 1.4, S, T)];
        return orient(Wu, D, opt.dir || 'S', P, { Dl, Lp }); },
      shipyard: (T, r, opt) => { const S = DSUITE[opt.style] || DSUITE.buern, Wu = 12, Dl = 6, Lp = 8, D = Dl + Lp, gt = dTint(T, S.ct) || '#6a6e72';
        const P = [...shed(3, 3, 5, 5, 4, S, T), ubx(8.5, Dl + Lp / 2 - 1, -0.3, 4, Lp + 2, 0, deck(), '#7a6a58', null, { wl: true, toDeck: true }), ubx(8.5, Dl + 3, 0, 2.4, 7, 1.6, deck(), S.hull)];
        for (let v = Dl; v <= Dl + 6; v += 1.5) P.push(ubx(8.5, v, 1.6, 2.8, 0.3, 1.4, plainW(), '#8a6240'));
        for (const v of [Dl - 0.5, Dl + 6.5]) P.push(ubx(6.2, v, 0, 0.5, 0.5, 6, plainW(), gt), ubx(10.8, v, 0, 0.5, 0.5, 6, plainW(), gt), ubx(8.5, v, 6, 5.2, 0.5, 0.5, plainW(), gt));
        P.push(ubx(6.2, Dl + 3, 6, 0.5, 7.5, 0.5, plainW(), gt), ubx(10.8, Dl + 3, 6, 0.5, 7.5, 0.5, plainW(), gt), ubx(8.5, Dl + 2, 5.5, 1.2, 1.2, 0.8, plainW(), '#3a3e44'));
        return orient(Wu, D, opt.dir || 'S', P, { Dl, Lp }); } });
    // Capital cores for the new styles: same 40×32 walled layout as core() — style walls, corner towers, gatehouse, keep at the back, 2 side landmarks, small houses in the front courts.
    const CORES = {
      kathaya: { wall: clap, wt: 'wood', tower: 'kt_watertower', keep: 'kt_mission', side: 'kt_hacienda', fill: ['kt_adobe', 'kt_shack', 'kt_adobe'] },
      aldurstein: { wall: winW, wt: 'stone', tower: 'al_stave', keep: 'al_mosque', side: 'al_ottoman', fill: ['al_stuga', 'al_ottoman', 'al_stuga'] },
      zukei: { wall: stoneT, wt: 'stone', wh: 3, tower: 'zk_yagura', keep: 'zk_castle', side: 'zk_temple', fill: ['zk_machiya', 'zk_minka'] },
      suorr: { wall: brick, tower: 'su_bastion', keep: 'su_cathedral', side: 'su_clocktower', fill: ['su_cottage', 'su_casa', 'su_terrace'] },
      miliim: { wall: pise, wt: 'mud', tower: 'ml_tower', keep: 'ml_palace', side: 'ml_mosque', fill: ['ml_rondavel', 'ml_mudhouse', 'ml_rondavel'] },
      aerdis: { wall: stoneT, wt: 'stone', tower: 'ae_roundtower', keep: 'ae_keep', side: 'ae_chapel', fill: ['ae_cottage', 'ae_pub'] },
      copari: { wall: brick, tower: 'su_bastion', keep: 'co_colonial', side: 'co_bauhaus', fill: ['co_mansard', 'co_victorian', 'co_shack'] } };
    const coreGen = (T, r, S, st) => { const o = [], wt = S.wall(), wh = S.wh || 4, tint = S.wt ? T[S.wt] : null, W2 = (x, z, w, d, h) => o.push(tb(x, z, 0, w, d, h || wh, wt, tint, wt));
      W2(20, 29, 36, 2); W2(3, 16, 2, 24); W2(37, 16, 2, 24); W2(8.5, 3, 13, 2); W2(31.5, 3, 13, 2); W2(20, 3, 10, 4, wh + 2); o.push(card(20, 1, 0, 4, 4, doorS()));
      const put = (id, cx, cz) => { const k = KIT[id](T, r); o.push(...shift(k.parts, cx - k.W / 2, cz - k.D / 2)); };
      for (const [x, z] of [[2, 2], [38, 2], [2, 30], [38, 30]]) put(S.tower, x, z);
      if (PALACE[st]) putK(o, PALACE[st](T, r), 20, 22.5); else put(S.keep, 20, 22); put(S.side, 7, 22); put(S.side, 33, 22);
      for (const [zx0, zx1] of [[5, 14], [26, 35]]) { let x = zx0, z = 6, rowD = 0;
        for (let k = 0; k < 8; k++) { const kt = KIT[pick(r, S.fill)](T, r); if (x + kt.W > zx1) { x = zx0; z += rowD + 1; rowD = 0; } if (z + kt.D > 16) break; o.push(...shift(kt.parts, x, z)); x += kt.W + 1; rowD = Math.max(rowD, kt.D); } }
      return { W: 40, D: 32, parts: o, gate: 20 }; };
    // Capital walled core 40×32: kasbah walls (2 thick, 5 tall, outer merlons), kremlin towers on the 4 corners, gatehouse front-center,
    // palace at the back (big onion + 2 side domes), 2 minarets, small houses packed into the two front courts. gate = x of the gate (units).
    const core = (T, r, st) => { const o = [], wall = (x, z, w, d, px, pz, pw, pd) => o.push(pbox(x, z, 0, w, d, 5, T), cbox(px, pz, 5, pw, pd, T));
      wall(20, 29, 36, 2, 20, 29.5, 36, 1); wall(3, 16, 2, 24, 2.5, 16, 1, 24); wall(37, 16, 2, 24, 37.5, 16, 1, 24); wall(8.5, 3, 13, 2, 8.5, 2.5, 13, 1); wall(31.5, 3, 13, 2, 31.5, 2.5, 13, 1);
      o.push(band(8.5, 2, 3, 13), band(31.5, 2, 3, 13));
      o.push(pbox(20, 3, 0, 10, 4, 8, T), card(20, 1, 0, 5, 6, gate()), band(20, 1, 6, 10), ...par(20, 3, 8, 10, 4, T));
      for (const x of [16.5, 23.5]) o.push(lathe(x, 2.5, 10, 2, 2, ONION, domeStripe(), T.stripe), fin(x, 2.5, 11.8));
      for (const [x, z] of [[2, 2], [38, 2], [2, 30], [38, 30]]) o.push(...shift(KIT.kremlin_tower(T, r).parts, x - 2, z - 2));
      putK(o, PALACE[st] ? PALACE[st](T, r) : PALACE.buern(T, r), 20, 22.5); // signature palace per nation
      o.push(...shift(KIT.minaret(T, r).parts, 5.5, 22.5), ...shift(KIT.minaret(T, r).parts, 31.5, 22.5));
      for (const [zx0, zx1] of [[5, 14], [26, 35]]) { let x = zx0, z = 6, rowD = 0;
        for (let k = 0; k < 8; k++) { const id = ['dar', 'dar', 'domed', 'riad'][Math.floor(r() * 4)], kt = KIT[id](T, r); if (x + kt.W > zx1) { x = zx0; z += rowD + 1; rowD = 0; } if (z + kt.D > 18) break;
          o.push(...shift(kt.parts, x, z)); x += kt.W + 1; rowD = Math.max(rowD, kt.D); } }
      return { W: 40, D: 32, parts: o, gate: 20 }; };
    // ── 2026-10-07 world dressing: grayscale foliage / rock / sand textures (tinted per part), foliage + terrain props, 11 unique temples, 10 capital palaces.
    const leafG = () => tmod('leaf_g', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const v = n(x * 5 + 11, y * 7 + 3); px(x, y, v > 0.72 ? '#ffffff' : v < 0.25 ? '#b4b4b4' : '#dadada'); } });
    const leafGS = () => tmod('leaf_g_side', 4, 3, px => { for (let y = 0; y < 3; y++) for (let x = 0; x < 4; x++) { const v = n(x * 3 + 7, y * 5 + 21); px(x, y, y === 2 ? '#9a9a9a' : v > 0.7 ? '#e6e6e6' : '#c2c2c2'); } });
    const plankV = () => tmod('plank_v', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, x === 3 ? '#9a9a9a' : y === 1 ? '#c8c8c8' : '#e0e0e0'); });
    const gateT = fl => mod(fl ? 'pal_gate_R' : 'pal_gate_L', 8, 10, px => { for (let y = 0; y < 10; y++) for (let x0 = 0; x0 < 8; x0++) { const x = fl ? 7 - x0 : x0; let c = x0 % 2 ? '#d4d4d4' : '#ececec'; if (x0 === 3 || x0 === 7) c = '#9c9c9c'; if (y === 0) c = x0 % 2 ? '#bcbcbc' : '#d0d0d0';
        if (y === 2 || y === 7) c = '#b4b4b4'; if (y > 2 && y < 7 && x0 === 8 - y) c = '#c0c0c0'; if ((y === 2 || y === 7) && x0 < 2) c = '#4a4a4a'; px(x, y, c); } });
    const barkG = () => tmod('bark_g', 2, 3, px => { for (let y = 0; y < 3; y++) { px(0, y, '#cfcfcf'); px(1, y, y === 1 ? '#8e8e8e' : '#a8a8a8'); } });
    const rockG = () => tmod('rock_g', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const v = n(x * 9 + 2, y * 4 + 17); px(x, y, y === 3 ? '#8a8a8a' : v > 0.75 ? '#f0f0f0' : v < 0.3 ? '#b0b0b0' : '#d0d0d0'); } });
    const sandG = () => tmod('sand_g', 4, 2, px => { for (let x = 0; x < 4; x++) { px(x, 0, x === 1 ? '#ffffff' : '#ececec'); px(x, 1, x === 3 ? '#c4c4c4' : '#dcdcdc'); } });
    const trk = (x, z, h, w = 0.6, c = '#6e5032') => tb(x, z, 0, w, w, h, barkG(), c, barkG());
    const can = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, leafGS(), c, leafG());
    const pyr = (x, z, y, w, h, c) => py(x, z, y, w, w, h, leafGS(), c);
    const rk = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, rockG(), c, rockG());
    const F = (W, D, parts) => ({ W, D, parts });
    // Cyfrolaef ruins (2026-10-07f): grayscale tile textures (tinted per part) + helpers. tw glass tower · cc concrete · mt metal panel · sc scorched;
    // jag = broken top (grid of random-height stubs) · lean = stacked offset segments (tilted / leaning look) · deb = rubble around a base · glow = corruption crystal.
    const glassT = () => tmod('tower_glass', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, x === 0 || y === 0 ? '#d4d4d4' : n(x * 7 + 3, y * 5 + 1) > 0.8 ? '#141414' : x === 1 && y === 1 ? '#9a9a9a' : '#5a5a5a'); });
    const concT = () => tmod('tower_conc', 4, 5, px => { for (let y = 0; y < 5; y++) for (let x = 0; x < 4; x++) px(x, y, y >= 1 && y <= 2 && x >= 1 ? (n(x + 90, y * 3) > 0.62 ? '#101010' : '#3a3a3a') : y === 4 ? '#9a9a9a' : n(x * 3 + 11, y + 5) > 0.75 ? '#b4b4b4' : '#d0d0d0'); });
    const scorchT = () => tmod('tower_scorch', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const v = n(x * 5 + 21, y * 7 + 2); px(x, y, v > 0.82 ? '#121212' : v > 0.5 ? '#5a5a5a' : v > 0.25 ? '#7a7a7a' : '#9a9a9a'); } });
    const panelT = () => tmod('metal_panel', 4, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) px(x, y, x === 0 || y === 2 ? '#8a8a8a' : n(x + 31, y + 17) > 0.85 ? '#f0f0f0' : '#c8c8c8'); });
    const tw = (x, z, y, w, d, h, t = '#7484ac') => tb(x, z, y, w, d, h, glassT(), t, concT()), cc = (x, z, y, w, d, h, t = '#a09a94') => tb(x, z, y, w, d, h, concT(), t, concT());
    const mt = (x, z, y, w, d, h, t = '#8a8ea0') => tb(x, z, y, w, d, h, panelT(), t, panelT()), sc = (x, z, y, w, d, h, t = '#6a5e66') => tb(x, z, y, w, d, h, scorchT(), t, scorchT());
    const jag = (x, z, y, w, d, cx, cz, hm, f, sd) => { const o = []; for (let i = 0; i < cx; i++) for (let k = 0; k < cz; k++) { const h = hm * n(sd + i * 7, k * 5 + sd); if (h < hm * 0.25) continue; o.push(f(x - w / 2 + (i + 0.5) * w / cx, z - d / 2 + (k + 0.5) * d / cz, y, w / cx, d / cz, h)); } return o; };
    // lean (2026-10-07): segments stacked straight, then the whole stack tilts as one rigid body (dx / dz = old per-segment offset → lean angle); no stair-step gaps.
    const lean = (x, z, y, w, d, segs, sh, dx, dz, f) => R2(Array.from({ length: segs }, (_, k) => f(x, z, y + sh * k, w, d, sh)), -Math.atan2(dx * 1.4, sh * 1.6), Math.atan2(dz * 1.4, sh * 1.6), [x, y, z]);
    const deb = (x, z, cnt, sp, sd) => Array.from({ length: cnt }, (_, k) => rk(x + (n(sd + k, 3) - 0.5) * sp, z + (n(sd, k + 9) - 0.5) * sp * 0.6, 0, 0.8 + n(k, sd) * 1.4, 0.7 + n(sd + 2, k) * 1.1, 0.4 + n(k + 4, sd) * 0.9, k % 3 ? '#8a8480' : '#6a6460'));
    // R2: rotate a group of parts together about piv (see map-core rotP). Parts standing on the ground (y ≈ 0 / piv height) get 2 units of extra foot below it so the
    // raised side of a tilted base never shows a gap under the building.
    const R2 = (parts, tilt, pitch, piv) => parts.map(p => { const gy = piv ? piv[1] : 0, foot = p.kind === 'box' && Math.abs((p.y || 0) - gy) < 0.01 ? { y: (p.y || 0) - 2, h: (p.h || 0) + 2 } : {}; return { ...p, ...foot, tilt, pitch, piv }; });
    const glow = (x, z, y, s = 0.6) => py(x, z, y, s, s, s * 2.4, rockG(), '#b070e0');
    // Tree variants (2026-10-07e): kit(id, …, { v: 0..4 }) seeds VR → builders vary tier count / taper / lobes / strands / limbs; varyTree then scales
    // height (0.82–1.24 by v), width (±14 %), leans the crown and jitters canopy blocks. No v → VR = 0.5 (the base shape).
    let VR = () => 0.5; const vv = (a, b) => a + (b - a) * VR();
    const srng = seed => { let s = seed >>> 0 || 1; return () => { s = Math.imul(s ^ (s >>> 15), 2246822507) + 0x9e3779b9 >>> 0; s ^= s >>> 13; return (s >>> 0) / 4294967296; }; };
    const hstr = str => { let h = 2166136261; for (let i = 0; i < str.length; i++) h = Math.imul(h ^ str.charCodeAt(i), 16777619); return h >>> 0; };
    const varyTree = (k, v) => { const hS = [0.82, 0.92, 1, 1.1, 1.24][v % 5], wS = vv(0.86, 1.14), lean = vv(-0.1, 0.1), cx = k.W / 2, cz = k.D / 2; let top = 0; for (const p of k.parts) top = Math.max(top, (p.y || 0) + (p.h || 0));
      const parts = k.parts.map(p => { const q = { ...p }, y = p.y || 0, crown = y > top * 0.3; q.y = y * hS; if (p.h != null) q.h = p.h * hS; q.x = cx + (p.x - cx) * wS + lean * y; q.z = cz + (p.z - cz) * wS; if (p.w != null) q.w = p.w * wS; if (p.d != null) q.d = p.d * wS;
        if (crown) { q.x += vv(-1, 1) * 0.06 * k.W; q.z += vv(-1, 1) * 0.06 * k.D; if (q.w != null) q.w *= vv(0.9, 1.1); if (q.d != null) q.d *= vv(0.9, 1.1); } return q; });
      return F(k.W * wS, k.D * wS, parts); };
    // Tree builders. conifer: trunk + tiers stacked pyramids (snow = white cap on each tier). broad: 4 stepped canopy blocks (rounded silhouette).
    // droop: dome + hanging strands (willow, wisteria). palm: 3-segment leaning trunk + cross fronds with drooping tips. dead: bare trunk + crooked limbs.
    const conifer = (W, H, tiers0, cols, tc = '#5e4430', snow) => { const tiers = Math.max(2, tiers0 + Math.round(vv(-1, 1.4))), tp = vv(0.52, 0.72), c = W / 2, base = H * vv(0.08, 0.18), o = [trk(c, c, base + 0.6, Math.max(0.6, W * 0.16), tc)], step = (H - base) / tiers, th = step * vv(1.3, 1.6);
      for (let i = 0; i < tiers; i++) { const w = W * (1 - tp * i / tiers) * vv(0.92, 1.06), y = base + step * i * 0.92; o.push(pyr(c, c, y, w, th, cols[Math.min(cols.length - 1, i)])); if (snow) o.push(pyr(c, c, y + th * 0.5, w * 0.54, th * 0.52, '#eef2f4')); }
      return F(W, W, o); };
    const broad = (W, H, cols, tc = '#6e5032', tr = 0.34) => { const c = W / 2, y0 = H * tr * vv(0.85, 1.15), ch = H - y0, o = [trk(c, c, y0 + ch * 0.2, Math.max(0.6, W * 0.14), tc),
      can(c, c, y0, W * 0.78, W * 0.78, ch * 0.3, cols[0]), can(c, c, y0 + ch * 0.22, W * vv(0.9, 1), W * vv(0.86, 0.98), ch * 0.42, cols[1] || cols[0]), can(c + vv(-0.1, 0.1) * W, c, y0 + ch * 0.6, W * vv(0.6, 0.78), W * 0.66, ch * 0.28, cols[2] || cols[1]), can(c + vv(-0.16, 0.12) * W, c, y0 + ch * 0.85, W * 0.38, W * 0.36, ch * 0.15, cols[3] || cols[2])];
      const lobes = Math.floor(vv(0, 3)); for (let k = 0; k < lobes; k++) { const a = vv(0, 6.283), r = W * 0.36; o.push(can(c + Math.cos(a) * r, c + Math.sin(a) * r * 0.8, y0 + ch * vv(0.2, 0.5), W * 0.42, W * 0.4, ch * 0.32, cols[1] || cols[0])); } return F(W, W, o); };
    const droop = (W, H, cols, tc) => { const c = W / 2, o = [trk(c, c, H * 0.55, Math.max(0.6, W * 0.12), tc), can(c, c, H * 0.48, W * 0.92, W * 0.92, H * 0.28, cols[1]), can(c, c, H * 0.74, W * 0.62, W * 0.6, H * 0.2, cols[2])];
      const ns = 6 + Math.floor(vv(0, 5)), a0 = vv(0, 1); for (let k = 0; k < ns; k++) { const a = k * 6.283 / ns + a0, r = W * vv(0.32, 0.42), h = H * vv(0.24, 0.48); o.push(can(c + Math.cos(a) * r, c + Math.sin(a) * r, H * 0.5 - h + 0.2, 0.7, 0.7, h, cols[0])); } return F(W, W, o); };
    const palm = (lean0, H0) => { const lean = lean0 + vv(-0.22, 0.22), H = H0 * vv(0.85, 1.2), x0 = 3, o = []; let x = x0; const seg = H / 3; for (let i = 0; i < 3; i++) { o.push(tb(x, 3, seg * i, 0.6 - i * 0.05, 0.6 - i * 0.05, seg, barkG(), '#9a7a52', barkG())); x += lean; }
      o.push(can(x, 3, H, 6, 1, 0.35, '#4e9a40'), can(x, 3, H, 1, 6, 0.35, '#4e9a40'), can(x, 3, H + 0.3, 1.6, 1.6, 0.6, '#5aa848'), tb(x + 0.5, 3.4, H - 0.4, 0.5, 0.5, 0.4, plainW(), '#6a4a2a', plainW()));
      for (const [dx, dz] of [[-2.8, 0], [2.8, 0], [0, -2.8], [0, 2.8]]) o.push(can(x + dx, 3 + dz, H - 0.6, 0.9, 0.9, 0.6, '#468e3a')); return F(6, 6, o); };
    const dead = c => { const H = vv(5, 7.5), o = [trk(2.5, 2.5, H, 0.7, c)], n = 2 + Math.floor(vv(0, 3)); for (let k = 0; k < n; k++) { const sd = (k & 1) ? 1 : -1, y = H * vv(0.45, 0.85), L = vv(1.2, 2), ax = k > 1 && VR() > 0.5; // limb + upturned tip
        if (ax) { o.push(tb(2.5, 2.5 + sd * L / 2, y, 0.4, L, 0.4, barkG(), c, barkG()), tb(2.5, 2.5 + sd * L, y, 0.4, 0.4, vv(0.8, 1.6), barkG(), c, barkG())); } else o.push(tb(2.5 + sd * L / 2, 2.5, y, L, 0.4, 0.4, barkG(), c, barkG()), tb(2.5 + sd * L, 2.5, y, 0.4, 0.4, vv(0.8, 1.6), barkG(), c, barkG())); }
      return F(5, 5, o); };
    const CYF = [...Array.from({ length: 26 }, (_, i) => ['cy_b' + String(i + 1).padStart(2, '0'), i >= 20 ? 0.6 : 0.3]), ...Array.from({ length: 15 }, (_, i) => ['cy_s' + String(i + 1).padStart(2, '0'), 0.45]), ['p_rubble', 1.5], ['p_rubble2', 1.5], ['p_slab', 1.2], ['p_rebar', 1], ['p_debris', 1.5], ['f_deadc', 1.5], ['f_dead', 0.8], ['p_corruptrock', 1]];
    const CORRUPT = [['p_rubble2', 1.5], ['p_debris', 1], ['p_slab', 0.8], ['f_deadc', 4], ['f_dead', 1], ['p_rubble', 3], ['p_ruin_wall', 2], ['p_ruin_tower', 0.6], ['p_column', 0.8], ['p_corruptrock', 2], ['p_ruin_arch', 0.5]];
    Object.assign(KIT, {
      // Foliage — every part is a box / pyramid (no lathes) so thousands stay cheap. Units: W×D footprint, y up.
      // Trees (2026-10-07c): 2–3× the old size with 3–5 tiers so they read as trees beside bushes (bushes / flowers / brush stay ≤ 2 units).
      f_pine: () => conifer(5, 10, 4, ['#24503a', '#2a5a40', '#2f6446', '#356e4c']),
      f_fir: () => conifer(6, 9, 3, ['#24564a', '#2a6050', '#306a58']),
      f_spruce: () => conifer(4, 11, 5, ['#1e4636', '#224c3a', '#26523e', '#2a5842', '#2e5e46']),
      f_snowpine: () => conifer(5, 10, 4, ['#2a5246', '#2e584a', '#325e4e', '#36644f'], '#5e4430', true),
      f_snowfir: () => conifer(6, 9, 3, ['#2e5a50', '#325e54', '#366458'], '#5e4430', true),
      f_juniper: () => conifer(3, 5, 3, ['#44643e', '#4a6a44', '#52724a']),
      f_violetfir: () => conifer(5, 9, 4, ['#5a3e7a', '#644688', '#6e4e94', '#7a58a2'], '#4a3a4a'),
      f_zpine: () => F(6, 6, [trk(2.6, 3, 2.6, 0.7, '#4a3a30'), tb(3.2, 3, 2.4, 0.6, 0.6, 2.4, barkG(), '#4a3a30', barkG()), can(1.8, 3, 2.6, 3.4, 3, 0.7, '#2e5a3a'), can(4, 3, 3.9, 3.4, 2.8, 0.7, '#346440'), can(2.8, 3, 5.2, 2.8, 2.4, 0.6, '#3a6c46'), can(3.2, 3, 5.8, 1.4, 1.2, 0.4, '#427650')]),
      f_oak: () => broad(6, 8, ['#4a8a36', '#55963e', '#60a246', '#6cae50']),
      f_beech: () => broad(7, 9, ['#336e2e', '#3a7a34', '#42843a', '#4c9042']),
      f_maple: () => broad(6, 8, ['#b0602e', '#c0703a', '#d08440', '#e09a4a']),
      f_birch: () => broad(4, 8, ['#7ab04e', '#86bc58', '#94c862', '#a0d06c'], '#e8e4d8', 0.45),
      f_cherry: () => broad(6, 7, ['#e090ac', '#eaa6be', '#f4bcd0', '#fcd6e4'], '#4a3434', 0.38),
      f_jacaranda: () => broad(7, 8, ['#6a4cae', '#7a5abe', '#8c6cce', '#a488dc'], '#4a3a3a', 0.4),
      f_wisteria: () => droop(7, 7, ['#7a52b0', '#9068c4', '#a884d6'], '#4a3a4a'),
      f_wisteria_w: () => droop(7, 7, ['#cfcae2', '#e2def0', '#f4f2fa'], '#4a3a4a'),
      f_willow: () => droop(8, 8, ['#6e9a3c', '#7caa46', '#8aba50'], '#5e4a34'),
      f_acacia: () => F(7, 6, [trk(3.5, 3, 3.6, 0.5, '#6a4a30'), tb(2.4, 3, 2.2, 0.4, 0.4, 1.8, barkG(), '#6a4a30', barkG()), tb(4.6, 3, 2.6, 0.4, 0.4, 1.4, barkG(), '#6a4a30', barkG()),
        can(3.5, 3, 3.8, 7, 5, 0.6, '#7a8e38'), can(3.2, 3, 4.3, 5, 3.6, 0.5, '#889c40'), can(3.6, 3, 4.7, 3, 2.2, 0.4, '#96aa4a')]),
      f_baobab: () => F(5, 5, [tb(2.5, 2.5, 0, 2.2, 2.2, 4.2, barkG(), '#9a8a74', barkG()), tb(1.2, 2.5, 3.8, 1.6, 0.5, 0.5, barkG(), '#9a8a74', barkG()), tb(3.8, 2.5, 4, 1.6, 0.5, 0.5, barkG(), '#9a8a74', barkG()),
        can(2.5, 2.5, 4.3, 4.8, 4.2, 0.8, '#6a8a3a'), can(2.5, 2.5, 5.1, 2.6, 2.4, 0.5, '#76963f')]),
      f_palm: () => palm(0.3, 7),
      f_palm2: () => palm(-0.35, 6),
      f_jungle: () => { const k = broad(7, 10, ['#226a32', '#2a7a3a', '#32883e', '#3a9646'], '#5a4430', 0.32); k.parts.push(can(1.2, 1.4, 0, 2, 2, 1.2, '#3a9040'), can(5.8, 5.4, 0, 1.6, 1.6, 0.9, '#2e8438')); return k; },
      f_kapok: () => F(9, 8, [tb(4.5, 4, 0, 2.2, 2.2, 1.2, barkG(), '#8a7a64', barkG()), trk(4.5, 4, 7.6, 1, '#8a7a64'), can(4.5, 4, 7.4, 9, 7.6, 1.2, '#2e8040'), can(4.5, 4, 8.6, 6.4, 5.4, 0.9, '#3a9048'), can(4.2, 4, 9.5, 3.6, 3, 0.6, '#46a050'), can(4.5, 4, 4.4, 4.4, 3.6, 0.8, '#2a7438')]),
      f_cypress: () => F(4, 4, [tb(2, 2, 0, 1.8, 1.8, 1.2, barkG(), '#6a5a44', barkG()), trk(2, 2, 3.4, 0.8, '#6a5a44'), can(2, 2, 2.8, 3.4, 3.4, 2.2, '#4a6a3a'), can(2, 2, 4.8, 2.6, 2.6, 2.2, '#52743f'), can(2, 2, 6.8, 1.6, 1.6, 1.6, '#5a7e44'), can(2, 2, 8.2, 0.8, 0.8, 0.8, '#628848')]),
      f_mangrove: () => F(6, 6, [...[[1.4, 1.4], [4.6, 1.4], [1.4, 4.6], [4.6, 4.6], [3, 0.8], [3, 5.2]].map(([x, z]) => tb(x, z, 0, 0.4, 0.4, 1.8, barkG(), '#5a4a3a', barkG())), tb(3, 3, 1.4, 4, 4, 0.5, barkG(), '#5a4a3a', barkG()), trk(3, 3, 3.6, 0.8, '#5a4a3a'),
        can(3, 3, 3.4, 6, 5.6, 1.4, '#3e6a36'), can(3, 3, 4.8, 4, 3.8, 1, '#46763c'), can(3, 3, 5.8, 2, 2, 0.5, '#4e8042')]),
      f_dead: () => dead('#7a7068'),
      f_deadc: () => { const k = dead('#3a3038'); k.parts.push(can(0.8, 2.5, 5.2, 0.5, 0.5, 0.4, '#9a5ac0'), can(4.2, 2.5, 6.2, 0.5, 0.5, 0.4, '#9a5ac0')); return k; },
      f_redwood: () => F(5, 5, [tb(2.5, 2.5, 0, 1.6, 1.6, 1.4, barkG(), '#8a4a32', barkG()), trk(2.5, 2.5, 9, 1.2, '#8a4a32'), can(2.5, 2.5, 5.6, 4.6, 4.4, 2, '#2e5e34'), can(2.5, 2.5, 7.4, 3.8, 3.6, 2, '#346838'), can(2.5, 2.5, 9.2, 2.8, 2.6, 1.8, '#3a723e'), can(2.5, 2.5, 10.8, 1.6, 1.6, 1.2, '#407a44')]),
      f_emergent: () => F(7, 7, [trk(3.5, 3.5, 8, 0.6, '#c8c0b0'), tb(4.6, 3.5, 5.6, 2, 0.4, 0.4, barkG(), '#c8c0b0', barkG()), tb(5.5, 3.5, 5.6, 0.4, 0.4, 1.6, barkG(), '#c8c0b0', barkG()),
        can(3.5, 3.5, 8, 7, 6, 0.8, '#3a8a3a'), can(3.3, 3.5, 8.7, 4.6, 4, 0.6, '#46983e'), can(5.5, 3.5, 7.1, 2.6, 2.4, 0.6, '#3a8a3a')]),
      f_shadepine: () => conifer(5, 14, 6, ['#16241f', '#1a2a24', '#1e2f28', '#22342c', '#263830', '#2a3c34'], '#2a2020'),
      f_mushroom: () => F(4, 4, [tb(2, 2, 0, 1, 1, 3.4, plainW(), '#e8dcc8'), can(2, 2, 3.4, 4, 4, 0.9, '#c04a8a'), can(2, 2, 4.3, 2.8, 2.8, 0.6, '#d85aa0'), tb(0.8, 3.2, 0, 0.5, 0.5, 1, plainW(), '#e8dcc8'), can(0.8, 3.2, 1, 1.4, 1.4, 0.4, '#d85aa0')]),
      // Bushes, brush, ground cover
      f_fern: () => F(2, 2, [can(1, 1, 0, 2, 2, 0.8, '#4aa04a')]),
      f_shrub: () => F(2, 2, [can(1, 1, 0, 1.8, 1.6, 1, '#5a8a3a')]),
      f_scrub: () => F(2, 2, [can(1, 1, 0, 2, 1.6, 0.6, '#8a8a4a'), can(0.6, 1.4, 0, 0.8, 0.8, 0.8, '#7a7a40')]),
      f_drybrush: () => F(2, 2, [can(1, 1, 0, 1.8, 1.4, 0.5, '#a09060'), tb(0.6, 0.8, 0, 0.2, 0.2, 0.9, barkG(), '#8a7050', barkG()), tb(1.3, 1.2, 0, 0.2, 0.2, 0.7, barkG(), '#8a7050', barkG()), can(1.4, 0.6, 0, 0.6, 0.6, 0.4, '#b0a070')]),
      f_flowers: () => F(2, 2, [can(1, 1, 0, 1.8, 1.6, 0.35, '#6aa048'), ...[[0.5, 0.6, '#f0e060'], [1.3, 0.8, '#e86a8a'], [0.9, 1.4, '#f4f4f4'], [1.5, 1.4, '#a87ad8']].map(([x, z, c]) => tb(x, z, 0.35, 0.3, 0.3, 0.15, plainW(), c, plainW()))]),
      f_snowbush: () => F(2, 2, [can(1, 1, 0, 1.8, 1.6, 0.8, '#4a6a54'), can(1, 1, 0.8, 1.4, 1.2, 0.3, '#eef2f4')]),
      f_reeds: () => F(2, 2, [[0.5, 0.6, 1.6], [1.1, 1.2, 2], [1.5, 0.7, 1.4], [0.8, 1.5, 1.2]].map(([x, z, h], k) => tb(x, z, 0, 0.25, 0.25, h, leafGS(), k & 1 ? '#a8a060' : '#6a8a40', leafG()))),
      f_cactus: () => F(3, 3, [can(1.5, 1.5, 0, 0.9, 0.9, 4.4, '#4e8a48'), can(0.5, 1.5, 1.6, 0.6, 0.6, 1.8, '#4e8a48'), can(1, 1.5, 1.6, 0.6, 0.5, 0.5, '#4e8a48'), can(2.5, 1.5, 2.2, 0.6, 0.6, 1.4, '#4e8a48'), can(2, 1.5, 2.2, 0.6, 0.5, 0.5, '#4e8a48')]),
      f_prickly: () => F(2, 2, [can(1, 1, 0, 1, 0.4, 1, '#6a9a50'), can(0.6, 1, 0.8, 0.8, 0.4, 0.8, '#6a9a50'), can(1.5, 1, 0.7, 0.7, 0.4, 0.7, '#6a9a50'), tb(0.6, 1, 1.6, 0.2, 0.2, 0.2, plainW(), '#e05a6a', plainW())]),
      f_haystack: () => F(2, 2, [can(1, 1, 0, 1.8, 1.8, 0.8, '#d8b84a'), py(1, 1, 0.8, 1.8, 1.8, 1, leafGS(), '#e0c058')]),
      f_sheaf: () => F(2, 2, [can(0.6, 0.8, 0, 0.6, 0.6, 1, '#e0c058'), can(1.4, 1.2, 0, 0.6, 0.6, 1, '#d8b84a')]),
      f_hedge: () => F(5, 1, [can(2.5, 0.5, 0, 5, 1, 0.9, '#4a7a3a')]),
      f_tallgrass: () => F(2, 2, [can(1, 1, 0, 2, 1.6, 0.5, '#9aaa5a')]),
      // Terrain props
      p_boulder: () => F(3, 3, [rk(1.4, 1.6, 0, 2.6, 2.2, 1.4, '#8a8680'), rk(1.8, 1.2, 1.4, 1.6, 1.4, 0.6, '#9a968e')]),
      p_rocks: () => F(3, 2, [rk(0.6, 0.8, 0, 1, 0.8, 0.5, '#8a8680'), rk(1.8, 1.2, 0, 0.8, 0.8, 0.7, '#7a7670'), rk(2.5, 0.6, 0, 0.6, 0.6, 0.4, '#9a968e')]),
      p_darkrock: () => F(3, 3, [rk(1.4, 1.6, 0, 2.6, 2.2, 1.6, '#4a4644'), rk(1.8, 1.2, 1.6, 1.6, 1.4, 0.7, '#5a5654')]),
      p_spire: () => F(2, 2, [rk(1, 1, 0, 1.4, 1.2, 3, '#5a5450'), rk(1, 1, 3, 0.8, 0.7, 1.2, '#6a6460')]),
      p_snowrock: () => F(3, 3, [rk(1.4, 1.6, 0, 2.6, 2.2, 1.4, '#8a8a90'), tb(1.4, 1.6, 1.4, 2.4, 2, 0.4, plainW(), '#f2f6f8')]),
      // Dunes (Kathaya only): low sand ridges (gable prisms, no vertical walls) — a barchan with two horns + a double ridge. Need flat ground.
      p_dune: () => F(12, 6, [gb(6, 3, 0, 11, 4, 1.1, sandG(), '#f0d292'), gb(1.6, 4.6, 0, 3, 2.2, 0.6, sandG(), '#ead08e'), gb(10.4, 4.6, 0, 3, 2.2, 0.6, sandG(), '#ead08e')]),
      p_dune2: () => F(8, 4, [gb(4, 2, 0, 7.6, 3, 0.8, sandG(), '#eccf8e'), gb(5, 2.4, 0, 4, 2, 1.1, sandG(), '#f2d696')]),
      // Ice, ruins, junk, marsh
      p_icespike: () => F(4, 4, [py(2, 2, 0, 1.4, 1.4, 6, rockG(), '#d8eef8'), py(0.9, 1.4, 0, 1, 1, 3.6, rockG(), '#bfe0f0'), py(3.1, 2.6, 0, 1.1, 1.1, 4.4, rockG(), '#cce8f4'), py(2.8, 0.9, 0, 0.8, 0.8, 2.6, rockG(), '#e6f6fc')]),
      p_icerock: () => F(4, 3, [rk(2, 1.5, 0, 3.4, 2.6, 1.4, '#b8d4e4'), rk(2.2, 1.4, 1.4, 2.2, 1.6, 0.6, '#d8eaf4'), tb(2.2, 1.4, 2, 2, 1.4, 0.2, plainW(), '#f4f8fa')]),
      p_rubble: () => F(4, 3, [rk(1, 1, 0, 1.2, 1, 0.6, '#8a8078'), rk(2.2, 1.6, 0, 1.4, 1.2, 0.8, '#9a9088'), rk(3.2, 0.8, 0, 0.8, 0.8, 0.5, '#7a6a5e'), rk(1.8, 1.4, 0.6, 1, 0.8, 0.5, '#a09890'), tb(3, 2.2, 0, 1, 0.5, 0.4, stoneT(), '#a0604a', stoneT())]),
      p_ruin_wall: () => F(6, 2, [tb(1, 1, 0, 2, 0.8, 2.8, stoneT(), '#a89c8c', stoneT()), tb(2.6, 1, 0, 1.2, 0.8, 1.8, stoneT(), '#a89c8c', stoneT()), tb(3.8, 1, 0, 1.2, 0.8, 1, stoneT(), '#a89c8c', stoneT()), tb(5.2, 1, 0, 1.6, 0.8, 2.2, stoneT(), '#a89c8c', stoneT()), rk(3.4, 1.7, 0, 0.8, 0.6, 0.4, '#9a9088')]),
      p_ruin_tower: () => F(4, 4, [tb(2, 2, 0, 3, 3, 4, stoneT(), '#9c9080', stoneT()), tb(1, 1.2, 4, 1, 1, 1.2, stoneT(), '#9c9080', stoneT()), tb(2.6, 1, 4, 1.2, 0.8, 0.6, stoneT(), '#9c9080', stoneT()), tb(3, 2.8, 4, 0.8, 1.2, 1.6, stoneT(), '#9c9080', stoneT()), rk(3.6, 3.6, 0, 1, 0.8, 0.5, '#8a8078')]),
      p_ruin_arch: () => F(5, 2, [tb(1, 1, 0, 1, 1, 3.4, stoneT(), '#b0a494', stoneT()), tb(4, 1, 0, 1, 1, 2.2, stoneT(), '#b0a494', stoneT()), tb(1.9, 1, 3.4, 2.8, 1, 0.6, stoneT(), '#b0a494', stoneT()), rk(3.4, 1.4, 0, 1, 0.8, 0.5, '#9a9088')]),
      p_column: () => F(5, 2, [tb(1, 1, 0, 1, 1, 2.4, stoneT(), '#d0c8b8', stoneT()), tb(1, 1, 2.4, 1.2, 1.2, 0.3, stoneT(), '#d0c8b8', stoneT()), tb(3.4, 1, 0, 3, 0.8, 0.8, stoneT(), '#c8c0b0', stoneT())]),
      p_junk: () => F(5, 4, [tb(1.4, 1.4, 0, 2, 1.6, 1.2, corr(), '#8a5a3a', corr()), tb(3.4, 1.2, 0, 1.6, 1.2, 0.8, clap(), '#7a6a5a', clap()), tb(2.4, 2.8, 0, 3.4, 0.4, 0.4, barkG(), '#5a4a3a', barkG()), tb(2, 1.6, 1.2, 1, 1, 0.6, corr(), '#9a6a40', corr()), tb(4.1, 3, 0, 1, 1, 1, plainW(), '#6a6a70', plainW()), rk(0.8, 3, 0, 1, 0.8, 0.4, '#8a8078')]),
      p_wreck: () => F(4, 3, [tb(2, 1.4, 0.3, 3, 1.6, 0.7, clap(), '#7a5a3a', clap()), tb(0.6, 0.4, 0, 1.1, 0.2, 1.1, barkG(), '#4a3a2a', barkG()), tb(3.2, 2.6, 0, 1.8, 0.3, 0.3, barkG(), '#5a4a3a', barkG()), rk(3.4, 0.8, 0, 0.8, 0.6, 0.4, '#8a8078')]),
      p_corruptrock: () => F(3, 3, [rk(1.4, 1.6, 0, 2.6, 2.2, 1.4, '#3a3040'), py(1.8, 1.4, 1.2, 0.8, 0.8, 1.6, rockG(), '#a060c8'), py(0.8, 2.2, 0, 0.6, 0.6, 1.2, rockG(), '#8a4ab0')]),
      p_mudpit: () => F(4, 3, [tb(2, 1.5, 0, 3.6, 2.6, 0.12, plainW(), '#5a4028', plainW()), tb(2, 1.5, 0.12, 2.4, 1.6, 0.06, plainW(), '#46301e', plainW()), tb(1.4, 1.2, 0.18, 0.3, 0.3, 0.15, plainW(), '#7a5a3a', plainW()), tb(2.6, 1.8, 0.18, 0.25, 0.25, 0.12, plainW(), '#7a5a3a', plainW())]),
      p_pond: () => F(5, 4, [tb(2.5, 2, 0, 4.4, 3.2, 0.12, plainW(), '#6e5a3a', plainW()), tb(2.5, 2, 0.1, 3.6, 2.6, 0.08, plainW(), '#4a7a98', plainW()), tb(1.8, 1.6, 0.18, 0.4, 0.4, 0.04, plainW(), '#5a9a40', plainW()), tb(3.2, 2.4, 0.18, 0.4, 0.4, 0.04, plainW(), '#5a9a40', plainW()),
        tb(0.5, 0.6, 0, 0.2, 0.2, 1.4, leafGS(), '#7a9a48', leafG()), tb(0.8, 0.4, 0, 0.2, 0.2, 1, leafGS(), '#a8a060', leafG()), tb(4.4, 3.4, 0, 0.2, 0.2, 1.2, leafGS(), '#7a9a48', leafG()), tb(0.6, 3.3, 0, 0.2, 0.2, 1, leafGS(), '#6a8a40', leafG())]),
      p_wheat: () => F(7, 5, [0, 1, 2, 3].map(i => tb(3.5, 0.8 + i * 1.2, 0, 6.6, 0.8, 0.6, leafGS(), i & 1 ? '#c8a840' : '#dcbc4c', leafG()))),
      // Shallow-water scatter (15, sea / lake shallows + reefs; never rivers). Bases sit below the water plane. w_ice* only in icy water.
      w_stack: () => F(3, 3, [rk(1.5, 1.5, 0, 2.4, 2.2, 5, '#7a746c'), rk(1.5, 1.4, 5, 1.6, 1.4, 1.2, '#8a847c'), tb(1.5, 1.5, 0.6, 2.5, 2.3, 0.5, leafGS(), '#4a6a48', leafG())]),
      w_flat: () => F(5, 4, [rk(2.5, 2, 0, 5, 3.4, 1, '#8a8680'), rk(2.2, 1.8, 1, 2.6, 1.8, 0.4, '#9a968e')]),
      w_twin: () => F(4, 3, [rk(1.2, 1.5, 0, 1.8, 1.6, 2.2, '#7a7670'), rk(3, 1.4, 0, 1.4, 1.2, 1.5, '#8a8680')]),
      w_spikes: () => F(4, 4, [py(1.2, 1.4, 0, 1.2, 1.2, 3.4, rockG(), '#6a6460'), py(2.6, 2.4, 0, 1.4, 1.4, 4.4, rockG(), '#5a5450'), py(3.2, 1, 0, 0.9, 0.9, 2.4, rockG(), '#6a6460'), py(1.4, 3.2, 0, 0.8, 0.8, 1.8, rockG(), '#7a7470')]),
      w_arch: () => F(6, 2, [rk(1, 1, 0, 1.4, 1.4, 3.6, '#7e7870'), rk(5, 1, 0, 1.4, 1.4, 3.2, '#7e7870'), rk(3, 1, 3, 5.4, 1.4, 1, '#8a847c')]),
      w_pebbles: () => F(3, 3, [rk(0.7, 0.8, 0, 0.8, 0.7, 0.9, '#8a8680'), rk(1.9, 1.2, 0, 0.7, 0.6, 0.8, '#7a7670'), rk(1.2, 2.2, 0, 0.6, 0.6, 0.7, '#9a968e'), rk(2.5, 2.4, 0, 0.5, 0.5, 0.6, '#8a8680')]),
      w_algae: () => F(3, 3, [rk(1.5, 1.5, 0, 2.6, 2.2, 1.6, '#6e6a62'), tb(1.5, 1.5, 1.6, 2.2, 1.8, 0.3, leafGS(), '#4e7a3e', leafG()), tb(1.5, 1.5, 0.5, 2.7, 2.3, 0.4, leafGS(), '#3e5e38', leafG())]),
      w_coral: () => F(3, 3, [rk(1, 1.2, 0, 1.4, 1.2, 1, '#c07a6a'), rk(2.2, 1.6, 0, 1, 1, 1.3, '#d0906a'), py(1.6, 2.3, 0, 0.8, 0.8, 1.4, rockG(), '#e0a080'), rk(2.4, 0.8, 0, 0.6, 0.6, 0.8, '#b06a7a')]),
      w_pillar: () => F(2, 2, [rk(1, 1, 0, 1, 1, 4.6, '#76706a'), rk(1, 1, 4.6, 0.7, 0.7, 0.6, '#86807a')]),
      w_jagged: () => F(4, 3, [rk(1, 1.5, 0, 1.4, 1.6, 2.6, '#5e5852'), rk(2.2, 1.4, 0, 1.2, 1.4, 3.4, '#6a645e'), rk(3.3, 1.6, 0, 1.2, 1.2, 1.8, '#5e5852'), py(2.2, 1.4, 3.4, 1.1, 1.2, 1, rockG(), '#6a645e')]),
      w_moss: () => F(4, 3, [rk(2, 1.5, 0, 3.4, 2.4, 1.3, '#7a7268'), rk(2.4, 1.4, 1.3, 1.8, 1.4, 0.6, '#8a8278'), tb(2.4, 1.4, 1.9, 1.6, 1.2, 0.2, leafGS(), '#6a8a48', leafG())]),
      w_tide: () => F(5, 4, [[1, 1, 0.8], [2.4, 0.6, 0.6], [3.9, 1.2, 0.9], [4.2, 2.6, 0.7], [2.8, 3.4, 0.8], [1, 2.8, 0.6]].map(([x, z, h]) => rk(x, z, 0, 1, 0.9, h, '#86827a'))),
      w_spire: () => F(3, 3, [rk(1.5, 1.5, 0, 2, 1.8, 1.8, '#6e6862'), py(1.5, 1.5, 1.8, 1.6, 1.4, 3.2, rockG(), '#7a746e'), rk(2.6, 2.4, 0, 0.7, 0.6, 0.7, '#6e6862')]),
      w_iceberg: () => F(5, 4, [rk(2.5, 2, 0, 4.4, 3.4, 2, '#cfe6f2'), rk(2.2, 1.8, 2, 2.6, 2, 1.6, '#e6f4fa'), py(2, 1.8, 3.6, 1.6, 1.2, 1.4, rockG(), '#f4fafc')]),
      w_icefloe: () => F(4, 3, [tb(2, 1.5, 0, 3.6, 2.6, 0.9, plainW(), '#dceef6', plainW()), tb(3, 1, 0, 1.2, 1, 0.7, plainW(), '#c8e2f0', plainW())]),
      // River rocks (small): lines across drops + mouths, a few along the banks / walls.
      r_rock1: () => F(2, 2, [rk(1, 1, 0, 1.6, 1.4, 1.1, '#8a8680')]),
      r_rock2: () => F(3, 2, [rk(0.9, 1, 0, 1.4, 1.2, 0.9, '#7a7670'), rk(2.2, 1, 0, 1.1, 1, 1.2, '#9a968e')]),
      r_rock3: () => F(2, 2, [rk(1, 1, 0, 1.8, 1.6, 1.6, '#6e6a64'), rk(1.4, 0.8, 1.6, 0.9, 0.8, 0.4, '#7e7a74')]),
      w_lily: () => F(2, 2, [tb(1, 1, 0, 1.4, 1.2, 0.1, plainW(), '#4e8a3a', plainW()), tb(0.6, 1.5, 0, 0.6, 0.5, 0.1, plainW(), '#5a9a44', plainW()), tb(1.2, 0.8, 0.1, 0.35, 0.35, 0.15, plainW(), '#f2d4e2', plainW())]),
      // Cyfrolaef: 20 ruined modern buildings (cy_b01–20), 15 city scatter pieces (cy_s01–15). Crater: 4 rock spikes (p_cspike1–4). Bigger rubble set.
      cy_b01: () => F(10, 9, [...R2([tw(5, 5, 0, 6, 6, 18), ...jag(5, 5, 18, 6, 6, 3, 3, 5, tw, 11)], 0.22, 0, [5, 0, 5]), tw(7.5, 1.5, 0, 5, 2, 2), ...deb(5, 1.2, 5, 8, 1)]),
      cy_b02: () => F(12, 9, [cc(3.5, 5, 0, 6, 6, 1.5), ...lean(3.5, 5, 1.5, 5, 5, 6, 3.2, 0.7, 0, tw), ...deb(9, 2, 5, 6, 2), glow(9.5, 6, 0)]),
      cy_b03: () => F(13, 9, [tw(3.5, 5, 0, 4.5, 4.5, 22, '#7080a8'), ...jag(3.5, 5, 22, 4.5, 4.5, 2, 2, 4, tw, 21), ...R2([tw(9.5, 5, 0, 4.5, 4.5, 11, '#7080a8'), ...jag(9.5, 5, 11, 4.5, 4.5, 3, 3, 6, sc, 23)], -0.4, 0, [9.5, 0, 5]), mt(6.5, 5, 8, 3, 1, 0.8), ...deb(9.5, 1.5, 6, 6, 4)]),
      cy_b04: () => F(10, 10, [cc(5, 8.6, 0, 9, 0.8, 9), cc(1, 5, 0, 0.8, 8, 7), cc(9, 5, 0, 0.8, 8, 5), cc(2.6, 1.4, 0, 3.4, 0.8, 6), cc(7.6, 1.4, 0, 2.4, 0.8, 3), ...jag(5, 8.6, 9, 9, 0.8, 5, 1, 3, cc, 31), ...deb(5, 5, 6, 6, 5)]),
      cy_b05: () => F(12, 11, [cc(6, 5.5, 0, 11, 10, 4), cc(6, 6, 4, 8, 7.5, 4), cc(5.4, 6.4, 8, 5, 5, 4), ...jag(5.4, 6.4, 12, 5, 5, 3, 3, 3, cc, 41), sc(9.4, 2, 4, 2.4, 2, 2), ...deb(10, 1.4, 4, 5, 6)]),
      cy_b06: () => F(16, 12, [...Array.from({ length: 6 }, (_, k) => mt(8, 1.5 + k * 1.8, k * 1.1, 14 - Math.abs(k - 2.5) * 2.4, 1.8, 1.2, '#9aa0b4')), tw(8, 6.5, 6.5, 5, 3, 2, '#90a0d0'), mt(5, 8, 6, 0.6, 0.6, 6), mt(11, 8.4, 7, 0.5, 0.5, 4.5), glow(3, 2, 0, 0.8), glow(13, 3, 0), ...deb(8, 0.8, 7, 12, 7)]),
      cy_b07: () => F(16, 7, [...Array.from({ length: 7 }, (_, k) => mt(1.5 + k * 2.1, 3.5, k * 0.9, 2.2, 4.6 - k * 0.25, 2.6)), mt(13.5, 1.4, 6, 0.4, 2.2, 3), mt(13.5, 5.6, 6, 0.4, 2.2, 3), sc(4, 3.5, 0, 3, 5, 1.2), tw(8, 1.2, 4.2, 8, 0.6, 0.8, '#90a0d0')]),
      cy_b08: () => F(18, 6, [cc(2, 3, 0, 3.6, 4.2, 5), ...jag(2, 3, 5, 3.6, 4.2, 2, 2, 2, cc, 81), tw(10.5, 3, 0, 13, 3.8, 3.4), tw(17, 3, 0, 1.8, 3, 2.2), ...deb(6, 1, 6, 5, 8)]),
      cy_b09: () => F(10, 10, [...[0, 1, 2].flatMap(i => [0, 1, 2].map(k => mt(1.5 + i * 3.5, 1.5 + k * 3.5, 0, 0.6, 0.6, Math.max(2, 12 - (i + k) * 1.6), '#8a6a5a'))), mt(5, 5, 4, 8, 8, 0.5, '#9a9490'), mt(4, 5.5, 8, 6, 7, 0.5, '#9a9490'), mt(3.5, 6, 11, 4, 4, 0.4, '#9a9490'), ...deb(7, 1.4, 5, 6, 9)]),
      cy_b10: () => F(12, 12, [cc(6, 6, 0, 11, 11, 1.5), ...[0, 1, 2, 3, 5, 6].map(k => { const a = k * Math.PI / 4; return cc(6 + Math.cos(a) * 4.4, 6 + Math.sin(a) * 4.4, 1.5, 2.2, 2.2, 2 + n(k, 101) * 4); }), tw(5, 7, 5.5, 5, 4, 1.2, '#8090c0'), glow(7, 4, 1.5, 0.8), ...deb(9, 1.2, 4, 4, 10)]),
      cy_b11: () => F(10, 9, [cc(3, 6, 0, 3, 3, 1.2), mt(3, 6, 1.2, 1.2, 1.2, 19), mt(3, 6, 20, 0.5, 0.5, 5), mt(3, 6, 8, 3, 0.4, 0.4), mt(3, 6, 14, 2.4, 0.4, 0.4), mt(7.5, 3, 0, 4.5, 3.5, 0.8, '#b0b4c0'), mt(7.5, 3, 0.8, 2.5, 2, 0.6, '#b0b4c0')]),
      cy_b12: () => F(14, 7, [...R2([cc(5, 4, 0, 9, 5, 16), ...jag(5, 4, 16, 9, 5, 4, 2, 2, cc, 123)], 0, 0.18, [5, 0, 4]), cc(11, 4, 0, 4, 5, 7), ...jag(11, 4, 7, 4, 5, 3, 2, 5, cc, 121), sc(12.6, 1, 0, 2.6, 1.8, 1.2), ...deb(12, 1.2, 6, 4, 12)]),
      cy_b13: () => F(12, 8, [...R2([tw(4, 4.5, 0, 5, 5, 10, '#8a90c8'), tw(4, 4.5, 10, 3.4, 3.4, 8, '#8a90c8'), tw(4, 4.5, 18, 2, 2, 4, '#8a90c8'), mt(4, 4.5, 22, 0.6, 0.6, 2)], -0.3, 0, [4, 0, 4.5]), mt(9, 2, 0, 6, 0.8, 0.8), mt(11.6, 2, 0, 1, 1, 1.2), glow(9, 5.5, 0)]),
      cy_b14: () => F(16, 12, [cc(5, 8, 0, 9, 7, 4.5), cc(12, 4, 0, 6, 7, 3.5), tw(5, 4.4, 0, 9, 0.6, 3.6, '#7888b0'), sc(12, 7.8, 3.5, 4, 2, 1), ...jag(5, 8, 4.5, 9, 7, 4, 3, 2, cc, 141), ...deb(10, 1.2, 6, 8, 14)]),
      cy_b15: () => F(18, 6, [cc(2, 3, 0, 3, 3, 12), cc(16, 3, 0, 3, 3, 9), ...jag(2, 3, 12, 3, 3, 2, 2, 2, cc, 151), mt(5.5, 3, 10, 5, 2, 1), mt(13, 3, 7.5, 4, 2, 1), mt(8.6, 3, 0, 3, 2, 1.2), ...deb(9, 2, 5, 5, 15), glow(10, 4.6, 0)]),
      cy_b16: () => F(14, 14, [cc(7, 7, 0, 13, 13, 1.2), py(7, 7, 1.2, 12, 12, 19, glassT(), '#7a8cc0'), sc(10.5, 4, 1.2, 4, 3, 6), ...deb(4, 1.2, 6, 6, 16), glow(2, 2, 0)]),
      cy_b17: () => F(14, 8, [mt(6, 4, 0, 10, 6, 0.5), mt(6, 4, 0.5, 9, 5, 5), mt(11.2, 4, 0, 0.8, 6, 6, '#6a6e80'), mt(12.8, 4, 0.6, 1.2, 4, 4.6, '#4a4e60'), sc(2, 4, 0, 3, 4.4, 3), glow(12.8, 4, 5.2), ...deb(7, 0.8, 5, 9, 17)]),
      cy_b18: () => F(12, 12, [cc(6, 6, 0, 10, 10, 3), cc(6, 6, 3, 8, 8, 4), cc(6, 6, 7, 7, 7, 3), cc(6, 6, 10, 8, 8, 2), ...jag(6, 6, 12, 8, 8, 4, 4, 3, cc, 181), glow(6, 3, 12.5, 1), glow(9, 6, 12, 0.8)]),
      cy_b19: () => F(16, 12, [mt(3, 3, 0, 1, 1, 7), mt(13, 3, 0, 1, 1, 9), mt(3, 9, 0, 1, 1, 8), mt(13, 9, 0, 1, 1, 3), ...Array.from({ length: 5 }, (_, k) => mt(8, 1.4 + k * 2.3, 7 + k * 0.6, 13, 2.3, 0.8, '#9aa0b4')), tw(6, 7, 9.5, 4, 3, 3, '#90a0d0'), ...deb(12, 1.2, 5, 5, 19)]),
      cy_b20: () => F(14, 9, [tw(2.5, 5, 0, 3.6, 3.6, 9), sc(7, 5, 0, 3.6, 3.6, 6), tw(11.5, 5, 0, 3.6, 3.6, 13), ...jag(2.5, 5, 9, 3.6, 3.6, 2, 2, 3, tw, 201), ...jag(11.5, 5, 13, 3.6, 3.6, 2, 2, 4, tw, 203), mt(9.2, 5, 10, 4.5, 2.4, 0.5), mt(7, 2, 0, 5, 1, 0.8), ...deb(7, 1.4, 5, 6, 20)]),
      // Crashed / toppled (rotated parts): fallen tower, leaning-on-neighbour, nose-dived spire, crooked stack, tower diving north, snapped-in-half.
      cy_b21: () => F(22, 8, [cc(3, 4, 0, 5, 6, 2), ...R2([tw(3, 4, 0, 5, 5, 18), ...jag(3, 4, 18, 5, 5, 3, 3, 3, tw, 211)], -Math.PI / 2 + 0.06, 0, [3, 0, 4]), ...deb(12, 1, 8, 16, 21), glow(20, 6, 0)]),
      cy_b22: () => F(14, 8, [tw(10.5, 4, 0, 4, 4, 16), ...jag(10.5, 4, 16, 4, 4, 2, 2, 3, tw, 221), ...R2([tw(3.5, 4, 0, 4, 4, 15, '#6a7aa4'), ...jag(3.5, 4, 15, 4, 4, 2, 2, 2, sc, 223)], -0.62, 0, [3.5, 0, 4]), ...deb(6, 1, 5, 8, 22)]),
      cy_b23: () => F(12, 9, [...R2([tw(6, 4.5, 0, 4, 4, 14, '#8a90c8'), py(6, 4.5, 14, 4, 4, 8, glassT(), '#8a90c8'), mt(6, 4.5, -1.2, 5, 5, 1.2)], Math.PI * 0.84, 0, [6, 6, 4.5]), sc(6, 4.5, 0, 9, 7, 0.4), ...deb(6, 2, 8, 10, 23), glow(2, 7, 0, 0.8)]),
      cy_b24: () => F(12, 8, [cc(4, 4, 0, 5.5, 5.5, 1.5), ...Array.from({ length: 6 }, (_, k) => ({ ...tw(4, 4, 1.5 + k * 3, 4.5, 4.5, 3), tilt: -0.07 * k * (k + 1) / 2, piv: [4, 1.5 + k * 3, 4] })), ...deb(9, 1.4, 5, 5, 24)]),
      cy_b25: () => F(12, 18, [...R2([tw(6, 3, 0, 5, 5, 20, '#7484ac'), ...jag(6, 3, 20, 5, 5, 3, 3, 3, tw, 251)], 0, 0.78, [6, 0, 3]), cc(6, 3, 0, 7, 6, 1.2), ...deb(6, 1, 6, 9, 25)]),
      cy_b26: () => F(21, 8, [tw(4, 4, 0, 5, 5, 9), ...jag(4, 4, 9, 5, 5, 3, 3, 2, sc, 261), ...R2([tw(9.5, 4, 0, 5, 5, 10), ...jag(9.5, 4, 10, 5, 5, 3, 3, 2, sc, 263)], -1.3, 0, [9.5, 0, 4]), ...deb(14, 1, 7, 10, 26)]),
      // Crash piles (2026-10-07j): one big composite debris kit each (cheaper than dozens of props) — rubble mound, tilted towers jutting out of the pit,
      // scaffolding, a toppled crane, girders, lamp posts, hull plates, corruption crystals. Placed by ME.CRASH_PILES (fixed spots), not by the foliage lattice.
      cy_pile1: () => { const o = [];
        for (let k = 0; k < 14; k++) o.push(rk(3 + n(k, 401) * 20, 2 + n(k, 402) * 15, n(k, 403) * 3, 3 + n(k, 404) * 5, 2.5 + n(k, 405) * 4, 2 + n(k, 406) * 4, k % 3 ? '#7a7470' : '#5e5852'));
        o.push(...R2([tw(9, 11, 0, 5, 5, 26, '#7080a8'), ...jag(9, 11, 26, 5, 5, 3, 3, 3, tw, 411)], 0.42, -0.2, [9, 0, 11]), ...R2([tw(17, 8, 0, 4, 4, 20, '#6a7aa4'), ...jag(17, 8, 20, 4, 4, 2, 2, 3, sc, 413)], -0.6, 0.15, [17, 0, 8]));
        for (let i = 0; i < 3; i++) for (let k = 0; k < 4; k++) o.push({ ...mt(4 + i * 2.4, 4, k * 3, 0.35, 0.35, 3, '#8a6a5a'), tilt: 0.25, piv: [4, 0, 4] }), o.push({ ...mt(5.2 + i * 2.4 - 1.2, 4, k * 3 + 3, 2.4, 0.3, 0.3, '#8a6a5a'), tilt: 0.25, piv: [4, 0, 4] });
        o.push(...R2([mt(21, 14, 0, 1, 1, 22, '#c8a040'), mt(21, 14, 22, 14, 0.8, 0.8, '#c8a040'), mt(15, 14, 20, 0.4, 0.4, 2, '#5a5a5a')], -1.05, 0.1, [21, 0, 14]));
        for (let k = 0; k < 5; k++) o.push({ ...mt(4 + n(k, 421) * 18, 3 + n(k, 422) * 14, 3 + n(k, 423) * 4, 10, 0.6, 0.6, '#8a6a5a'), tilt: (n(k, 424) - 0.5) * 1.4, pitch: (n(k, 425) - 0.5) * 0.8 });
        for (let k = 0; k < 4; k++) o.push({ ...mt(3 + n(k, 431) * 20, 2 + n(k, 432) * 15, 2 + n(k, 433) * 3, 0.4, 0.4, 6, '#4a4a52'), tilt: (n(k, 434) - 0.5) * 2 });
        o.push({ ...mt(13, 3, 1, 9, 5, 0.8, '#9aa0b4'), tilt: 0.3, pitch: -0.4 }, { ...cc(5, 16, 2, 6, 1, 7), tilt: -0.5 }, glow(12, 6, 4, 1), glow(6, 13, 5, 0.8), glow(20, 4, 3, 0.9));
        return F(26, 20, o); },
      cy_pile2: () => { const o = [];
        for (let k = 0; k < 12; k++) o.push(rk(2 + n(k, 501) * 18, 2 + n(k, 502) * 13, n(k, 503) * 2.5, 3 + n(k, 504) * 4, 2.5 + n(k, 505) * 3, 2 + n(k, 506) * 3.5, k % 2 ? '#86807a' : '#625c58'));
        o.push(...R2([cc(6, 9, 0, 6, 5, 18), ...jag(6, 9, 18, 6, 5, 3, 2, 3, cc, 511)], -0.35, 0, [6, 0, 9]), ...R2([tw(15, 10, 0, 6, 6, 9, '#8090c0'), py(15, 10, 9, 6, 6, 9, glassT(), '#8090c0')], 1.2, 0, [15, 0, 10]));
        for (let i = 0; i < 4; i++) o.push({ ...mt(13 + i * 1.8, 4, 0, 0.35, 0.35, 12, '#8a6a5a'), tilt: -0.18 }, { ...mt(15.5, 4, 3 + i * 3, 6.4, 0.3, 0.3, '#8a6a5a'), tilt: -0.18, piv: [13, 0, 4] });
        for (let k = 0; k < 6; k++) o.push({ ...mt(2 + n(k, 521) * 18, 2 + n(k, 522) * 12, 2 + n(k, 523) * 4, 8, 0.5, 0.5, '#8a6a5a'), tilt: (n(k, 524) - 0.5) * 1.6, pitch: (n(k, 525) - 0.5) });
        o.push({ ...mt(10, 12, 3, 8, 6, 1, '#9aa0b4'), tilt: -0.5, pitch: 0.3 }, { ...mt(3, 2, 0, 4, 2.4, 1, '#7a5a6a'), tilt: 1.3 }, { ...mt(18, 13, 1, 0.4, 0.4, 6, '#4a4a52'), tilt: 0.9 }, glow(4, 4, 3, 0.9), glow(16, 7, 5, 1));
        return F(22, 17, o); },
      cy_pile3: () => { const o = [];
        for (let k = 0; k < 10; k++) o.push(rk(2 + n(k, 601) * 14, 2 + n(k, 602) * 10, n(k, 603) * 2, 2.5 + n(k, 604) * 4, 2 + n(k, 605) * 3, 1.5 + n(k, 606) * 3, '#6e6862'));
        o.push(...Array.from({ length: 7 }, (_, k) => ({ ...mt(2 + k * 2.2, 7, k * 0.9, 2.4, 6 - k * 0.3, 2.4, '#8a8ea0'), pitch: 0.35 })), mt(14, 5, 6, 0.4, 2.4, 3.4), mt(14, 9.6, 6, 0.4, 2.4, 3.4), { ...tw(8, 4, 4, 9, 0.6, 1, '#90a0d0'), pitch: 0.35 });
        o.push({ ...mt(4, 12, 0, 0.4, 0.4, 7, '#4a4a52'), tilt: 0.6 }, { ...mt(12, 12, 0, 0.4, 0.4, 7, '#4a4a52'), tilt: -0.4 }, glow(9, 3, 2, 1.1), glow(15, 12, 3, 0.8));
        return F(18, 14, o); },
      // Palisade stakes (5 variants, nominal top ≈ 10.4 units; map-core scales y / h per stake to reach the wall's constant top).
      pal_1: () => F(1.2, 1.2, [tb(0.6, 0.6, 0, 1, 1, 9, barkG(), '#7a5a3a', barkG()), py(0.6, 0.6, 9, 1, 1, 1.4, barkG(), '#6a4a2e')]),
      pal_2: () => F(1.2, 1.2, [tb(0.6, 0.6, 0, 0.8, 0.8, 9.6, barkG(), '#6e5234', barkG()), py(0.6, 0.6, 9.6, 0.8, 0.8, 1.6, barkG(), '#5e4428')]),
      pal_3: () => F(1.2, 1.2, [tb(0.35, 0.6, 0, 0.55, 0.9, 8.6, barkG(), '#7e5e3c', barkG()), tb(0.85, 0.6, 0, 0.55, 0.9, 9.4, barkG(), '#745436', barkG()), py(0.35, 0.6, 8.6, 0.55, 0.9, 1, barkG(), '#6a4a2e'), py(0.85, 0.6, 9.4, 0.55, 0.9, 1.1, barkG(), '#6a4a2e')]),
      pal_4: () => F(1.2, 1.2, [tb(0.6, 0.6, 0, 1, 1, 9.2, barkG(), '#82603c', barkG()), py(0.6, 0.6, 9.2, 1, 1, 1.3, barkG(), '#6a4a2e'), tb(0.6, 0.6, 6.8, 1.12, 1.12, 0.4, plainW(), '#3a2a1e', plainW()), tb(0.6, 0.6, 2.4, 1.12, 1.12, 0.35, plainW(), '#3a2a1e', plainW())]),
      // Palisade gates (2026-10-07): post + open leaf; leaf texture = vertical planks, Z-brace, iron hinges; _R = same texture mirrored. _x leaf runs along x, _z along z
      // (map-core scales leaf length to the gap and height to the wall). Opened 90° to the wall at every trail / street crossing.
      // Great stone walls (2026-10-07, map-walls.json style "stone"): map-core strings gw_seg every GREATWALL.step px (scaled to the wall height), gw_merlon on the outer
      // parapet, gw_butt buttresses outside, gw_tower every GREATWALL.towerEvery px with gw_door on the inner face; over rivers the segment lifts into a culvert arch + gw_grate.
      gw_seg: () => F(4, 4, [tb(2, 2, 0, 4.6, 4.6, 3, stoneT(), '#6e6250', stoneT()), tb(2, 2, 3, 4.1, 4.1, 12, stoneT(), '#a8987a', stoneT()), tb(2, 2, 15, 4.35, 4.35, 1, plainW(), '#6a5e4c', plainW()), tb(2, 2, 16, 3.8, 3.8, 14, stoneT(), '#b8a98a', stoneT()), tb(2, 2, 30, 4.1, 4.1, 1, plainW(), '#d8ccb0', plainW())]),
      gw_merlon: () => F(1.3, 1.3, [tb(0.65, 0.65, 0, 1.3, 1.3, 2.6, stoneT(), '#cdbf9f', stoneT())]),
      gw_butt: () => F(2.6, 2.6, [tb(1.3, 1.3, 0, 2.6, 2.6, 10, stoneT(), '#948e82', stoneT()), tb(1.3, 1.3, 10, 2, 2, 9, stoneT(), '#9c968a', stoneT()), tb(1.3, 1.3, 19, 1.3, 1.3, 6, stoneT(), '#a49e92', stoneT())]),
      gw_tower: () => { const S = '#cbb994', M = '#dccfae', o = [tb(5.5, 5.5, 0, 11.6, 11.6, 5, stoneT(), '#8e8778', stoneT()), tb(5.5, 5.5, 5, 10.6, 10.6, 18, stoneT(), S, stoneT()), tb(5.5, 5.5, 23, 10.9, 10.9, 1, plainW(), '#857e70', plainW()), tb(5.5, 5.5, 24, 10.2, 10.2, 19, stoneT(), S, stoneT()), tb(5.5, 5.5, 43, 11.6, 11.6, 1.6, plainW(), '#8a8374', plainW())];
        for (let i = 0; i < 5; i++) { const u = 0.8 + i * 2.48; o.push(tb(u, 0.8, 44.6, 1.4, 1.4, 2.8, stoneT(), M, stoneT()), tb(u, 10.2, 44.6, 1.4, 1.4, 2.8, stoneT(), M, stoneT())); if (i && i < 4) o.push(tb(0.8, u, 44.6, 1.4, 1.4, 2.8, stoneT(), M, stoneT()), tb(10.2, u, 44.6, 1.4, 1.4, 2.8, stoneT(), M, stoneT())); }
        for (const y of [12, 32]) o.push(tb(3.6, 10.85, y, 0.6, 0.2, 3, plainW(), '#1e1a16', plainW()), tb(7.4, 10.85, y, 0.6, 0.2, 3, plainW(), '#1e1a16', plainW()), tb(10.85, 5.5, y, 0.2, 0.6, 3, plainW(), '#1e1a16', plainW()), tb(0.15, 5.5, y, 0.2, 0.6, 3, plainW(), '#1e1a16', plainW()));
        return F(11, 11, o); },
      // Brazier on every great-wall tower top (placed by map-core with lift = tower top): iron legs, bowl, coals, big flame (fire: 1).
      gw_brazier: () => { const I = '#2e2a28', o = []; for (const [x, z] of [[3.6, 3.6], [7.4, 3.6], [3.6, 7.4], [7.4, 7.4]]) o.push(tb(x, z, 0, 0.5, 0.5, 2, plainW(), I, plainW()));
        o.push(tb(5.5, 5.5, 1.8, 4.8, 4.8, 1.3, plainW(), '#3a3430', plainW()), tb(5.5, 5.5, 3.1, 5.2, 5.2, 0.3, plainW(), '#4a423c', plainW()), tb(5.5, 5.5, 3.1, 4.2, 4.2, 0.35, coals(), null, coals()), ...[[4.4, 4.6, 0.9], [6.4, 4.8, 1.1], [5.2, 6.4, 1], [6.6, 6.5, 0.8], [4.3, 6.2, 0.7], [5.6, 5.4, 1.2]].map(([x, z, s]) => tb(x, z, 3.35, s, s, s * 0.55, coals(), null, coals())), /* coal bed + lumps (charcoal with ember speckles; embers glow at night) */ { ...tb(5.5, 5.5, 3.2, 3.8, 3.8, 5.4, fireF0(), null, fireF0()), fire: 1 }); return F(11, 11, o); },
      // Campfire (2026-10-08, night camps beside parked coaches): ring of 7 stones, 3 crossed logs, ember bed, flame (fire: 1). Placed by MercVehicles at night only.
      p_campfire: () => { const o = [], C = 2.2; for (let k = 0; k < 9; k++) { const a = k / 9 * Math.PI * 2; o.push(rk(C + Math.cos(a) * 1.75, C + Math.sin(a) * 1.55, 0, 0.75, 0.65, 0.5, k & 1 ? '#7a7670' : '#8e8a82')); }
        o.push({ ...tb(C, C, 0.05, 3.0, 0.45, 0.42, barkG(), '#5e4228', barkG()), tilt: 0.22, piv: [C, 0.25, C] }, { ...tb(C, C, 0.05, 0.45, 3.0, 0.42, barkG(), '#4e3620', barkG()), pitch: 0.22, piv: [C, 0.25, C] }, { ...tb(C, C, 0.05, 2.6, 0.42, 0.4, barkG(), '#6a4a2e', barkG()), tilt: -0.25, piv: [C, 0.25, C] },
          tb(C, C, 0, 2.0, 1.8, 0.25, coals(), null, coals()), { ...tb(C, C, 0.2, 1.7, 1.7, 3.8, fireF0(), null, fireF0()), fire: 1 }); return F(4.4, 4.4, o); },
      gw_door: () => F(3.6, 0.6, [tb(1.8, 0.2, 0, 3.6, 0.4, 8.2, stoneT(), '#7a7468', stoneT()), tb(1.8, 0.45, 0, 2.6, 0.3, 6.6, plankV(), '#6a4a2e', plainW()), tb(1.8, 0.45, 6.6, 1.6, 0.3, 0.7, plankV(), '#5e4228', plainW()), tb(1.8, 0.55, 3.2, 2.6, 0.12, 0.3, plainW(), '#2a2420', plainW())]),
      gw_grate: () => F(4, 0.6, [0.4, 1.2, 2, 2.8, 3.6].map(x => tb(x, 0.3, 0, 0.3, 0.3, 10, plainW(), '#3a3632', plainW())).concat([tb(2, 0.3, 4, 4, 0.3, 0.35, plainW(), '#3a3632', plainW()), tb(2, 0.3, 8, 4, 0.3, 0.35, plainW(), '#3a3632', plainW())])),
      pal_gpost: () => F(1.6, 1.6, [tb(0.8, 0.8, 0, 1.5, 1.5, 11, barkG(), '#5e4428', barkG()), py(0.8, 0.8, 11, 1.5, 1.5, 1.6, barkG(), '#4e3820'), tb(0.8, 0.8, 7.6, 1.62, 1.62, 0.45, plainW(), '#2e2620', plainW()), tb(0.8, 0.8, 2.2, 1.62, 1.62, 0.45, plainW(), '#2e2620', plainW())]),
      pal_gate_x: () => F(4, 0.8, [tb(2, 0.4, 0, 4, 0.8, 8.5, gateT(0), '#b08a5c', gateT(0))]), pal_gate_xR: () => F(4, 0.8, [tb(2, 0.4, 0, 4, 0.8, 8.5, gateT(1), '#b08a5c', gateT(1))]),
      pal_gate_z: () => F(0.8, 4, [tb(0.4, 2, 0, 0.8, 4, 8.5, gateT(0), '#b08a5c', gateT(0))]), pal_gate_zR: () => F(0.8, 4, [tb(0.4, 2, 0, 0.8, 4, 8.5, gateT(1), '#b08a5c', gateT(1))]),
      pal_5: () => F(1.2, 1.2, [tb(0.6, 0.6, 0, 1, 1, 8.2, barkG(), '#6a4e32', barkG()), tb(0.4, 0.6, 8.2, 0.5, 1, 1.4, barkG(), '#6a4e32', barkG()), tb(0.85, 0.5, 8.2, 0.4, 0.8, 0.6, barkG(), '#5e442a', barkG())]),
      // Austyg grand castle: plinth, curtain walls + merlons, 4 round corner towers with blue cones, tall keep with turrets + pyramid roof, twin-tower gatehouse, banners.
      // Town fortresses (2026-10-08): small castles the towns grew around (ME.CASTLES, placed before settlements). ~12 × 12 units, fixed colours per nation look.
      // Vaernebo (Kale Vidneku): ochre pisé kasbah walls + merlons, 4 square corner towers with green tent roofs + gold onions, central keep with a gold dome.
      vb_citadel: () => { const W = '#ead29c', Wd = '#d8bc84', G = '#2f8a5a', Au = '#e8b440', o = [tb(6, 6, 0, 12, 12, 0.6, pise(), Wd, pise())];
        for (const [x, z, w, d] of [[6, 0.8, 10, 1.2], [6, 11.2, 10, 1.2], [0.8, 6, 1.2, 10], [11.2, 6, 1.2, 10]]) { o.push(tb(x, z, 0.6, w, d, 4.2, pise(), W, pise())); const n = Math.round(Math.max(w, d) / 1.6); for (let k = 0; k < n; k++) { const f = (k + 0.5) / n - 0.5; o.push(tb(x + (w > d ? f * w : 0), z + (w > d ? 0 : f * d), 4.8, w > d ? 0.8 : d === 1.2 ? 1.3 : 0.8, w > d ? 1.3 : 0.8, 0.8, pise(), W, pise())); } }
        for (const [x, z] of [[1.2, 1.2], [10.8, 1.2], [1.2, 10.8], [10.8, 10.8]]) o.push(tb(x, z, 0.6, 2.4, 2.4, 6.4, pise(), W, pise()), py(x, z, 7, 2.8, 2.8, 2.6, roofS(), G), lathe(x, z, 9.4, 1, 1.2, ONION, domeStripe(), Au));
        o.push(tb(6, 6.5, 0.6, 5, 5, 7.4, pise(), W, pise()), tb(6, 6.5, 8, 5.4, 5.4, 0.4, pise(), Wd, pise()), lathe(6, 6.5, 8.4, 4, 3.4, DOME, domeRib(), Au), card(6, 0.15, 0.6, 2.6, 3.6, gate())); return F(12, 12, o); },
      // Suorr (Castelo Divirio): red-brick curtain walls, 4 round brick bastions with slate cones, square brick keep with slate pyramid roof + finial, gatehouse.
      su_castle: () => { const S = '#4a4e58', o = [tb(6, 6, 0, 12, 12, 0.6, stoneT(), '#8a7e70', stoneT())];
        for (const [x, z, w, d] of [[6, 0.8, 10, 1.2], [6, 11.2, 10, 1.2], [0.8, 6, 1.2, 10], [11.2, 6, 1.2, 10]]) o.push(tb(x, z, 0.6, w, d, 4.6, brick(), null, brick()), tb(x, z, 5.2, w + 0.2, d + 0.2, 0.4, stoneT(), '#9a9488', stoneT()));
        for (const [x, z] of [[1.2, 1.2], [10.8, 1.2], [1.2, 10.8], [10.8, 10.8]]) o.push(cyl(x, z, 0.6, 2.8, 6.4, brick()), cone(x, z, 7, 3.2, 2.8, roofS(), S));
        o.push(tb(6, 6.8, 0.6, 5, 4.6, 9, brick(), null, brick()), py(6, 6.8, 9.6, 5.6, 5.2, 3.4, roofS(), S), tb(6, 1, 0.6, 3.2, 1.8, 6, brick(), null, brick()), py(6, 1, 6.6, 3.6, 2.2, 1.4, roofS(), S), card(6, 0.05, 0.6, 1.8, 2.8, gate()), fin(6, 6.8, 13)); return F(12, 12, o); },
      // Copari (Caer Baqal, on the cliff edge over the bay): grey stone fort, angular bastions, iron-roofed barracks, tall square signal keep with flag.
      co_fort: () => { const St = '#9a9488', Sd = '#7e786e', Fe = '#8a4a2e', o = [tb(6, 6, 0, 12, 12, 0.8, stoneT(), Sd, stoneT())];
        for (const [x, z, w, d] of [[6, 1, 9, 1.2], [6, 11, 9, 1.2], [1, 6, 1.2, 9], [11, 6, 1.2, 9]]) o.push(tb(x, z, 0.8, w, d, 3.8, stoneT(), St, stoneT()), tb(x, z, 4.6, w, d, 0.3, plainW(), '#6a665e'));
        for (const [x, z] of [[1, 1], [11, 1], [1, 11], [11, 11]]) o.push(tb(x, z, 0.8, 2.8, 2.8, 4.6, stoneT(), St, stoneT()), tb(x, z, 5.4, 3.0, 3.0, 0.4, stoneT(), Sd, stoneT()));
        o.push(tb(4, 7.5, 0.8, 4.4, 3.4, 3, winW(), '#b8b0a2'), gb(4, 7.5, 3.8, 4.8, 3.8, 1.4, corr(), Fe), tb(8, 7.8, 0.8, 3, 3, 10, stoneT(), St, stoneT()), tb(8, 7.8, 10.8, 3.4, 3.4, 0.6, stoneT(), Sd, stoneT()),
          tb(8, 7.8, 11.4, 0.2, 0.2, 3, plainW(), '#2a2a2a'), card(8.9, 7.8, 13, 1.6, 1, flag(), '#c84a2a'), card(6, 0.35, 0.8, 2, 2.8, gate())); return F(12, 12, o); },
      al_castle: () => { const S = '#cfc8bc', R = '#3e5f86', o = [tb(15, 12, 0, 30, 24, 1, stoneT(), '#a8a090', stoneT()), tb(15, 22.5, 1, 26, 1.6, 7, stoneT(), S, stoneT()), tb(15, 1.5, 1, 26, 1.6, 6, stoneT(), S, stoneT()), tb(1.5, 12, 1, 1.6, 20, 6.5, stoneT(), S, stoneT()), tb(28.5, 12, 1, 1.6, 20, 6.5, stoneT(), S, stoneT())];
        for (let k = 0; k < 12; k++) o.push(tb(4 + k * 2, 1.5, 7, 0.9, 1.7, 0.9, stoneT(), S, stoneT()), tb(4 + k * 2, 22.5, 8, 0.9, 1.7, 0.9, stoneT(), S, stoneT()));
        for (const [x, z] of [[2, 2], [28, 2], [2, 22], [28, 22]]) o.push(cyl(x, z, 1, 4.4, 11, stoneT(), S), cone(x, z, 12, 5, 5, stoneT(), R));
        o.push(tb(15, 14, 1, 11, 9, 16, stoneT(), S, stoneT()), tb(15, 14, 17, 8, 6, 4, stoneT(), '#d8d2c6', stoneT()), py(15, 14, 21, 8.4, 6.4, 7, stoneT(), R));
        for (const [x, z] of [[10, 10], [20, 10], [10, 18], [20, 18]]) o.push(cyl(x, z, 1, 2.4, 20, stoneT(), S), cone(x, z, 21, 2.8, 3.4, stoneT(), R));
        o.push(tb(15, 1.5, 1, 6, 3, 9, stoneT(), S, stoneT()), cyl(11.5, 1.5, 1, 3, 11, stoneT(), S), cyl(18.5, 1.5, 1, 3, 11, stoneT(), S), cone(11.5, 1.5, 12, 3.4, 3.6, stoneT(), R), cone(18.5, 1.5, 12, 3.4, 3.6, stoneT(), R), tb(15, 0.1, 1, 2.6, 0.3, 4, plainW(), '#2a2420', plainW()));
        o.push(tb(15, 14, 28, 0.25, 0.25, 4, plainW(), '#5a4a3a', plainW()), tb(16, 14, 30.4, 1.8, 0.12, 1.3, plainW(), '#2f6a9a', plainW()), tb(2, 2, 17, 0.2, 0.2, 2.6, plainW(), '#5a4a3a', plainW()), tb(2.7, 2, 18.6, 1.2, 0.1, 0.9, plainW(), '#2f6a9a', plainW()));
        return F(30, 24, o); },
      cy_s01: () => F(5, 5, [cc(2.5, 2.5, 0, 4.6, 4.6, 0.7), tb(2.5, 2.5, 0.7, 3.6, 3.6, 0.08, plainW(), '#3a3640', plainW()), cc(2.5, 2.5, 0, 1, 1, 2.2), cc(2.5, 2.5, 2.2, 2, 2, 0.4), rk(1.2, 1.2, 0, 0.8, 0.6, 0.4, '#8a8480')]),
      cy_s02: () => F(2, 2, [mt(1, 1, 0, 0.4, 0.4, 6), mt(1.5, 1, 5.8, 1.2, 0.4, 0.3), mt(2, 1, 5.4, 0.5, 0.5, 0.4, '#e0d080')]),
      cy_s03: () => F(6, 2, [mt(3, 1, 0, 5.6, 0.4, 0.4), mt(0.4, 1, 0, 0.6, 0.6, 0.3), mt(5.6, 1, 0, 0.6, 0.5, 0.6, '#c0b070')]),
      cy_s04: () => F(5, 3, [mt(2.5, 1.5, 0, 3.6, 1.8, 0.4, '#3a3a40'), mt(2.5, 1.5, 0.4, 4.6, 2.4, 1, '#7a5a6a'), tw(2.3, 1.5, 1.4, 2.4, 2, 0.8, '#5a6a90')]),
      cy_s05: () => F(9, 3, [mt(4.5, 1.5, 0, 8.6, 2.6, 2.6, '#8a7a50'), tw(4.5, 0.15, 0.9, 7.8, 0.2, 1, '#506080'), sc(7.5, 1.5, 2.6, 2, 2.2, 0.3)]),
      cy_s06: () => F(4, 2, [mt(0.6, 1, 0, 0.3, 0.8, 0.6), mt(3.4, 1, 0, 0.3, 0.8, 0.6), mt(2, 1, 0.6, 3.6, 1, 0.25, '#6a5a4a'), mt(2, 1.4, 0.85, 3.6, 0.2, 0.8, '#6a5a4a')]),
      cy_s07: () => F(4, 4, [cc(2, 2, 0, 3, 3, 1.4), cc(2, 2, 1.4, 1.2, 1, 2, '#c8c0b0'), cc(1.4, 2, 3.4, 0.6, 0.6, 0.8, '#c8c0b0'), rk(3.4, 0.8, 0, 1, 0.8, 0.6, '#c8c0b0'), rk(0.6, 0.6, 0, 0.8, 0.6, 0.5, '#c8c0b0')]),
      cy_s08: () => F(6, 2, [mt(1.5, 1, 0, 0.4, 0.4, 5), mt(4.5, 1, 0, 0.4, 0.4, 3.5), tb(3, 1, 3.6, 5.6, 0.3, 2.4, scorchT(), '#a060a0', panelT())]),
      cy_s09: () => F(6, 2, [0, 1, 2, 3].map(k => cc(0.8 + k * 1.5, 1, 0, 1.2, 0.8, k === 2 ? 0.5 : 0.9, k & 1 ? '#c8b040' : '#b0aca4'))),
      cy_s10: () => F(6, 5, [tb(3, 2.5, 0, 5.4, 4.4, 0.1, plainW(), '#3a3236', plainW()), rk(1, 1, 0, 1, 0.8, 0.6, '#6a6460'), rk(5, 3.8, 0, 1.2, 1, 0.8, '#5a5450'), mt(3.4, 2.6, 0, 1.6, 0.4, 0.6), glow(3, 2.5, 0, 0.5)]),
      cy_s11: () => F(8, 2, [mt(4, 1, 0, 7.6, 0.6, 0.6, '#8a6a5a'), mt(4, 1, 0.6, 7.6, 0.2, 0.2, '#8a6a5a'), mt(1, 1, 0, 0.6, 1.6, 0.8, '#8a6a5a')]),
      cy_s12: () => F(3, 2, [mt(1.5, 1, 0, 2, 1.2, 2.6, '#6a7080'), tw(1.5, 0.35, 1.4, 1.4, 0.1, 0.9, '#60a0c0'), mt(1.5, 1, 2.6, 2.6, 1.6, 0.3)]),
      cy_s13: () => F(5, 3, [mt(1.5, 1.5, 0, 0.5, 0.5, 8), mt(3.5, 1.5, 0, 0.5, 0.5, 5), mt(2.5, 1.5, 5, 2.6, 0.4, 0.4), mt(2, 1.5, 7.5, 1.8, 0.3, 0.3), mt(4.2, 0.6, 0, 1.6, 0.3, 0.3)]),
      cy_s14: () => F(3, 3, [cc(1.5, 1.5, 0, 2.6, 2.6, 0.9), trk(1.5, 1.5, 4, 0.4, '#4a4048'), tb(1, 1.5, 2.6, 1, 0.3, 0.3, barkG(), '#4a4048', barkG()), tb(2.1, 1.5, 3.2, 1, 0.3, 0.3, barkG(), '#4a4048', barkG())]),
      cy_s15: () => F(4, 3, [mt(1.4, 1.5, 0, 1.8, 1.2, 2.8, '#7a3a4a'), tw(1.4, 0.85, 1, 1.2, 0.1, 1.4, '#c0b060'), mt(3, 1.4, 0, 1.6, 1.4, 0.6, '#5a5a66'), mt(3, 1.4, 0.6, 0.4, 0.4, 0.6), glow(3.6, 2.4, 0, 0.4)]),
      p_rubble2: () => F(6, 4, [rk(3, 2, 0, 5, 3.2, 1, '#8a8480'), rk(2.6, 2, 1, 3.4, 2.2, 0.9, '#9a9490'), rk(3, 1.8, 1.9, 1.8, 1.2, 0.6, '#7a7470'), mt(4.6, 1.2, 0.6, 1.8, 0.3, 0.3, '#8a6a5a'), cc(1.2, 3, 0, 1.4, 1, 0.8)]),
      p_slab: () => F(6, 3, [...lean(1.5, 1.5, 0, 2.4, 2.6, 4, 0.5, 1, 0, cc), rk(5, 2.4, 0, 1, 0.8, 0.5, '#8a8480')]),
      p_rebar: () => F(4, 3, [rk(2, 1.5, 0, 3.4, 2.4, 0.8, '#9a9490'), ...[[1, 1, 2.4], [1.8, 1.8, 1.6], [2.8, 1.2, 2]].map(([x, z, h]) => mt(x, z, 0.8, 0.2, 0.2, h, '#7a4a3a'))]),
      p_debris: () => F(5, 4, [cc(1.4, 1.4, 0, 2, 1.6, 1.2), mt(3.4, 2.4, 0, 2.4, 1.6, 0.8), sc(2.6, 3, 0, 1.4, 1, 1.4), rk(4.2, 1, 0, 1, 0.8, 0.5, '#7a7470'), mt(2.4, 1.6, 1.2, 2.8, 0.3, 0.3, '#8a6a5a')]),
      p_cspike1: () => F(4, 4, [rk(2, 2, 0, 2.6, 2.4, 2.2, '#5a5258'), rk(2.4, 2.2, 2.2, 1.8, 1.6, 2.2, '#6a6268'), rk(2.8, 2.4, 4.4, 1.1, 1, 2, '#7a7278'), py(3, 2.5, 6.4, 0.9, 0.9, 1.8, rockG(), '#7a7278')]),
      p_cspike2: () => F(5, 4, [py(1.4, 2, 0, 1.8, 1.8, 5, rockG(), '#5e565c'), py(3, 1.6, 0, 2.2, 2.2, 7.5, rockG(), '#6a6268'), py(4.2, 2.8, 0, 1.4, 1.4, 3.6, rockG(), '#564e54'), rk(2.4, 2.6, 0, 3, 1.6, 0.8, '#4e464c')]),
      p_cspike3: () => F(7, 3, [...lean(1.2, 1.5, 0, 1.4, 1.6, 5, 1.2, 1.1, 0, (x, z, y, w, d, h) => rk(x, z, y, w, d, h, '#625a60')), py(6.7, 1.5, 6, 1.2, 1.4, 1.4, rockG(), '#6e666c'), rk(3, 2.4, 0, 1.6, 1, 0.6, '#4e464c')]),
      p_cspike4: () => F(7, 3, [rk(1, 1.5, 0, 1.6, 1.8, 5.5, '#5a5258'), rk(6, 1.5, 0, 1.6, 1.8, 3, '#5a5258'), rk(2.6, 1.5, 4.8, 2.6, 1.6, 1.2, '#625a60'), rk(4.4, 1.5, 0, 1.2, 1.2, 1, '#4e464c'), glow(5.6, 1, 3, 0.6)]),
      p_driftwood: () => F(3, 1, [tb(1.5, 0.5, 0, 3, 0.4, 0.4, barkG(), '#b0a080', barkG())]),
      p_obsidian: () => F(2, 2, [rk(1, 1, 0, 1, 0.9, 1.6, '#2a2230'), rk(1.5, 1.4, 0, 0.6, 0.6, 0.9, '#3a3040')]),
      // Trade-route details
      p_cart: () => F(3, 2, [tb(1.5, 1, 0.4, 2.4, 1.4, 0.7, clap(), '#8a6a44'), tb(0.7, 0.2, 0, 0.9, 0.2, 0.9, barkG(), '#4a3a2a', barkG()), tb(2.3, 0.2, 0, 0.9, 0.2, 0.9, barkG(), '#4a3a2a', barkG()), can(1.5, 1, 1.1, 1.8, 1, 0.5, '#d8b84a')]),
      p_milestone: () => F(1, 1, [tb(0.5, 0.5, 0, 0.6, 0.5, 1, stoneT(), '#c8c0b0', stoneT())]),
      // Trail scatter (2026-10-07): small, low, no shadow. trpeb = 3 pebbles · trstone = flat half-buried stone · trtuft(d) = green / dry grass tuft · trwheel = broken cart wheel · trsack · trplank.
      p_trpeb: () => F(1, 1, [rk(0.3, 0.4, 0, 0.3, 0.24, 0.16, '#8c8274'), rk(0.66, 0.62, 0, 0.22, 0.2, 0.12, '#a39b8c'), rk(0.5, 0.18, 0, 0.16, 0.14, 0.1, '#776d61')]),
      p_trstone: () => F(1, 1, [rk(0.5, 0.5, 0, 0.72, 0.52, 0.1, '#9a948a'), rk(0.38, 0.42, 0.06, 0.4, 0.3, 0.06, '#b0aa9e')]),
      p_trtuft: () => F(1, 1, [tb(0.3, 0.5, 0, 0.12, 0.12, 0.5, plainW(), '#5e8a3c', plainW()), tb(0.52, 0.42, 0, 0.12, 0.12, 0.72, plainW(), '#6c9e48', plainW()), tb(0.72, 0.56, 0, 0.12, 0.12, 0.44, plainW(), '#4f7a32', plainW()), tb(0.46, 0.66, 0, 0.12, 0.12, 0.36, plainW(), '#78a852', plainW())]),
      p_trtuftd: () => F(1, 1, [tb(0.3, 0.5, 0, 0.12, 0.12, 0.46, plainW(), '#a89a5a', plainW()), tb(0.52, 0.42, 0, 0.12, 0.12, 0.66, plainW(), '#bcae6a', plainW()), tb(0.72, 0.56, 0, 0.12, 0.12, 0.4, plainW(), '#8e8048', plainW())]),
      p_trwheel: () => F(1.4, 1.4, [tb(0.7, 0.18, 0, 1.2, 0.16, 0.14, barkG(), '#5a4630', barkG()), tb(0.7, 1.22, 0, 1.2, 0.16, 0.14, barkG(), '#5a4630', barkG()), tb(0.18, 0.7, 0, 0.16, 0.9, 0.14, barkG(), '#5a4630', barkG()), tb(1.22, 0.7, 0, 0.16, 0.7, 0.14, barkG(), '#5a4630', barkG()), tb(0.7, 0.7, 0, 0.22, 0.22, 0.2, barkG(), '#3e3020', barkG()), tb(0.7, 0.7, 0, 1, 0.1, 0.1, barkG(), '#6e5a3e', barkG()), tb(0.7, 0.7, 0, 0.1, 1, 0.1, barkG(), '#6e5a3e', barkG())]),
      p_trsack: () => F(1, 1, [tb(0.5, 0.45, 0, 0.66, 0.44, 0.34, plainW(), '#b89a6a', plainW()), tb(0.86, 0.45, 0, 0.14, 0.2, 0.2, plainW(), '#8a6e48', plainW()), tb(0.3, 0.75, 0, 0.3, 0.2, 0.12, plainW(), '#c8b07e', plainW())]),
      p_trplank: () => F(1.6, 1, [tb(0.8, 0.4, 0, 1.4, 0.3, 0.1, barkG(), '#8a6a44', barkG()), tb(0.9, 0.7, 0, 0.9, 0.26, 0.08, barkG(), '#a0784a', barkG())]),
      // Unique landmarks (2026-10-07): cave mouths (Mlinzjia, Kardmen Deep) sit on the north rim of a dug pit, opening south; Aerdan South = gothic college campus by Bhrisea.
      lm_cave: () => { const R = (x, z, y, w, d, h, c) => rk(x, z, y, w, d, h, c || '#6e6660'), o = [R(1.4, 3, 0, 2.8, 5, 3.6, '#5e5650'), R(8.6, 3, 0, 2.8, 5, 3.4, '#5e5650'), R(5, 4.6, 0, 4.4, 2.6, 4.4, '#686058'), R(5, 1.6, 3, 5.6, 2.4, 1.6, '#746c64'), R(3.2, 1.2, 0, 1, 1.6, 3.2), R(6.8, 1.2, 0, 1, 1.6, 3.1),
        tb(5, 1.6, 0, 2.8, 1.6, 3, plainW(), '#0e0b10', plainW()), tb(5, 0.9, 0, 2.4, 0.2, 2.6, plainW(), '#1c1418', plainW()), R(4.3, 0.9, 2.5, 0.4, 0.3, 0.5, '#544c46'), R(5.7, 0.9, 2.4, 0.4, 0.3, 0.6, '#544c46'), R(5, 0.9, 2.6, 0.3, 0.3, 0.4, '#4a423e'),
        R(0.6, 0.6, 0, 1.2, 1.2, 0.9, '#7a726a'), R(9.4, 0.8, 0, 1.4, 1.2, 1.1, '#7a726a'), R(2.6, 5.6, 3.6, 2.2, 1.6, 1.2, '#625a54'), R(7.6, 5.4, 3.4, 2, 1.6, 1, '#625a54')]; return F(10, 7, o); },
      lm_cave_snow: () => { const k = KIT.lm_cave(); k.parts.push(tb(1.4, 3.2, 3.6, 2.6, 4.4, 0.4, plainW(), '#eef2f6', plainW()), tb(8.6, 3.2, 3.4, 2.6, 4.4, 0.4, plainW(), '#eef2f6', plainW()), tb(5, 4.6, 4.4, 4.2, 2.4, 0.4, plainW(), '#e4eaf0', plainW()), tb(5, 1.6, 4.6, 5.4, 2.2, 0.35, plainW(), '#f4f7fa', plainW()), tb(2.6, 5.6, 4.8, 2, 1.4, 0.3, plainW(), '#eef2f6', plainW())); return k; },
      lm_college: () => { const S = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, stoneT(), c || '#8e8a86', stoneT()), Wn = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, winW(), c || '#9a948c', stoneT()), slate = '#3a4250', o = [];
        o.push(tb(13, 11, 0, 26, 22, 0.3, stoneT(), '#7a7670', stoneT()));
        o.push(Wn(13, 13.5, 0, 6, 13, 7, '#9a948c'), gb(13, 13.5, 7, 6.4, 13.4, 4, roofS(), slate), Wn(13, 12, 0, 14, 4, 6.4, '#948e86'), gb(13, 12, 6.4, 14.4, 4.4, 3.4, roofS(), slate), S(13, 20.6, 0, 4.4, 2.2, 6, '#8a847c'), py(13, 20.6, 6, 4.6, 2.4, 2.6, roofS(), slate));
        for (const x of [10.4, 15.6]) o.push(S(x, 6.4, 0, 2.6, 2.6, 12, '#a29c94'), S(x, 6.4, 12, 2.2, 2.2, 1.2, '#b0aaa2'), py(x, 6.4, 13.2, 2.2, 2.2, 7, roofS(), slate), tb(x, 5.05, 4, 1, 0.2, 3, winW(), '#c8a040', stoneT()));
        o.push(S(13, 5.6, 0, 2.6, 1.2, 6, '#a29c94'), tb(13, 4.95, 0, 1.6, 0.2, 2.6, plainW(), '#2a2026', plainW()), tb(13, 4.95, 3.4, 1.8, 0.2, 1.8, winW(), '#c8a040', stoneT()), py(13, 13.5, 11, 1.4, 1.4, 5, roofS(), slate));
        for (const z of [9.2, 15, 17.6]) for (const x of [9.2, 16.8]) o.push(S(x, z, 0, 1.6, 0.8, 4.6, '#7e7872'), py(x, z, 4.6, 0.8, 0.8, 1.4, roofS(), slate));
        o.push(Wn(4.6, 7, 0, 7.6, 2.4, 4.4), gb(4.6, 7, 4.4, 8, 2.8, 2, roofS(), slate), Wn(1.4, 12.5, 0, 2.4, 8.6, 4.4), gb(1.4, 12.5, 4.4, 2.8, 9, 2, roofS(), slate), Wn(4.6, 18, 0, 7.6, 2.4, 4.4), gb(4.6, 18, 4.4, 8, 2.8, 2, roofS(), slate), Wn(7.6, 12.5, 0, 1.6, 8.6, 3.2, '#8a847c'),
          can(4.6, 12.5, 0.3, 4.2, 8.4, 0.1, '#5a8a44'), S(4.6, 12.5, 0.4, 1, 1, 1.2, '#b0aaa2'), py(1.4, 7, 6.4, 2, 2, 3, roofS(), slate));
        o.push(Wn(22.2, 9, 0, 6.4, 4.4, 5.4, '#9a948c'), gb(22.2, 9, 5.4, 6.8, 4.8, 3, roofS(), slate), S(22.6, 17, 0, 3, 3, 13, '#a29c94'), tb(22.6, 15.45, 9, 1.2, 0.2, 2, plainW(), '#2a2026', plainW()), py(22.6, 17, 13, 3.4, 3.4, 5, roofS(), slate), Wn(20, 13.4, 0, 2.2, 4, 3.6), gb(20, 13.4, 3.6, 2.6, 4.4, 1.6, roofS(), slate));
        o.push(S(13, 1.2, 0, 6, 2, 3.6, '#8e8a86'), tb(13, 0.15, 0, 2, 0.2, 2.4, plainW(), '#2a2026', plainW()), S(10.4, 1.2, 3.6, 0.9, 1.6, 0.8), S(13, 1.2, 3.6, 0.9, 1.6, 0.8), S(15.6, 1.2, 3.6, 0.9, 1.6, 0.8), can(21, 3, 0.3, 8, 4, 0.1, '#5a8a44'), can(5, 2.6, 0.3, 7, 3, 0.1, '#5a8a44'));
        return F(26, 22, o); },
      p_icespikeB: () => F(3, 3, [py(1.5, 1.5, 0, 1.2, 1.2, 8, rockG(), '#a8dcf0'), py(0.7, 2.2, 0, 0.8, 0.8, 4.6, rockG(), '#8ccbe4'), py(2.3, 0.9, 0, 0.9, 0.9, 5.4, rockG(), '#c4ecf8')]),
      p_icespikeR: () => F(3, 3, [py(1.5, 1.5, 0, 1.1, 1.1, 6.4, rockG(), '#c8e8f4'), py(1.5, 1.5, 2.2, 0.5, 0.5, 2.6, rockG(), '#b04050'), py(2.3, 2.2, 0, 0.8, 0.8, 3.6, rockG(), '#9ad4ea')]),
      p_signpost: () => F(2, 1, [tb(1, 0.5, 0, 0.3, 0.3, 1.8, barkG(), '#7a5a3a', barkG()), tb(1.2, 0.5, 1.3, 1.4, 0.2, 0.4, clap(), '#a0784a')]) });
    // Fallback: land class id → [[kit, weight]], density d (0..1 per lattice sample), clump c (noise mask strength). jungle = forest floor in the hot south.
    // Cacti are not in the fallback (Kathaya only, see FOLIAGE_ZONES). Dunes removed 2026-10-07 (p_dune kits kept unused).
    const FOLIAGE = {
      0: { k: [['f_oak', 3], ['f_birch', 2], ['f_shrub', 3], ['f_flowers', 1], ['p_boulder', 0.3]], d: 0.1, c: 0.6 }, 1: { k: [['f_acacia', 2], ['f_drybrush', 3], ['f_scrub', 2], ['p_rocks', 0.6]], d: 0.07, c: 0.3 },
      2: { k: [['f_oak', 3], ['f_beech', 3], ['f_maple', 1], ['f_birch', 1], ['f_shrub', 1]], d: 0.7, c: 0.4 }, jungle: { k: [['f_jungle', 3], ['f_kapok', 1], ['f_palm', 1], ['f_fern', 2]], d: 0.75, c: 0.4 },
      3: { k: [['f_pine', 3], ['f_fir', 3], ['f_spruce', 2], ['p_boulder', 0.3]], d: 0.7, c: 0.4 }, 4: { k: [['f_wisteria', 3], ['f_violetfir', 3], ['f_mushroom', 2]], d: 0.65, c: 0.5 },
      5: { k: [['f_drybrush', 2], ['p_rocks', 1], ['f_scrub', 1]], d: 0.03, c: 0.2 }, 6: { k: [['p_boulder', 3], ['p_rocks', 3], ['f_juniper', 1]], d: 0.08, c: 0.3 },
      7: { k: [['p_darkrock', 3], ['p_spire', 1], ['f_dead', 1]], d: 0.08, c: 0.3 }, 8: { k: [['f_snowfir', 2], ['p_snowrock', 2], ['f_snowbush', 1]], d: 0.05, c: 0.5 },
      9: { k: [['f_willow', 2], ['f_dead', 2], ['f_reeds', 3], ['p_mudpit', 1]], d: 0.1, c: 0.4 }, 10: { k: [['p_rocks', 2], ['p_driftwood', 1]], d: 0.05, c: 0.2 },
      11: { k: [['f_willow', 3], ['f_cypress', 2], ['f_reeds', 4], ['p_pond', 1]], d: 0.18, c: 0.5 }, 12: { k: [['f_oak', 1], ['f_tallgrass', 3], ['f_scrub', 2], ['f_flowers', 1]], d: 0.05, c: 0.3 },
      13: { k: [['f_tallgrass', 1]], d: 0, c: 0 }, 14: { k: [['p_rocks', 3], ['p_boulder', 2], ['f_juniper', 2], ['f_scrub', 1]], d: 0.08, c: 0.3 },
      15: { k: [['p_obsidian', 2], ['p_spire', 1], ['p_rocks', 1]], d: 0.04, c: 0.2 } };
    // Zones (2026-10-07c, from the user's per-nation / region brief). First entry whose filters ALL match a sample wins, else FOLIAGE[class].
    // Filters: region (names) · regionCat (categories) · nation (name substrings) · cls / clsNot (land class ids: 0 grass, 1 dry grass, 2 forest floor,
    // 3 pine floor, 4 purple forest, 5 sand, 6 rock, 7 dark rock, 8 snow, 9 mud, 10 beach, 11 marsh, 12 prairie, 13 wheat, 14 stony, 15 magma) · tone (0 light,
    // 1 base, 2 dark) · island (land mass < 1500 × 8 px cells) · near { nation, px } (within px of that nation), near { region, px } or near { at: label name, px } · ell { at, dx, dz, rx, rz } (ellipse offset from a label; Shadetrail forest + its maze trails) · seg { a: [x, z], b: [x, z], w } (within w px of a segment, image px) · zMax / zMin (image px)
    // · patch [a, b] (large-scale noise band → splits a nation into areas) · fill { step, d, k } (near.region zones: extra dense lattice of small pieces). d = density, dDark = density on dark tone, c = clump.
    const MEADOW = [['f_flowers', 4], ['f_shrub', 2], ['p_rocks', 1.5], ['f_tallgrass', 2]], GRASSLAND = [['f_acacia', 3], ['f_drybrush', 3], ['p_rocks', 2], ['f_tallgrass', 1]];
    const TAIGA = [['f_pine', 4], ['f_spruce', 3], ['f_fir', 2], ['f_snowpine', 1]], BOREAL = [['f_spruce', 3], ['f_snowfir', 3], ['f_snowpine', 3], ['f_birch', 0.4]];
    // Water scatter. Shallow / reef water classes (sea + lake, never rivers): density per 10 px lattice sample; kit by water class (icy / violet / other).
    // Rivers: r_rock* — every drop (river surface steps ≥ 1 terrace between neighbours) p .55, mouths (≤ 2 cells from sea / lake) p .25, bank cells p .03, walls (bank + level step) p .1.
    const WATER_SCATTER = { shallow: /shallow|reef/i, d: 0.05, dReef: 0.12, icy: /icy/i, violet: /violet/i,
      k: [['w_stack', 1], ['w_flat', 2], ['w_twin', 2], ['w_spikes', 1.5], ['w_arch', 0.4], ['w_pebbles', 4], ['w_algae', 2], ['w_coral', 1], ['w_pillar', 1], ['w_jagged', 1], ['w_moss', 2], ['w_tide', 2], ['w_spire', 0.8]],
      kIcy: [['w_iceberg', 2], ['w_icefloe', 3], ['w_pebbles', 1], ['w_spikes', 0.5]], kViolet: [['w_spikes', 3], ['w_jagged', 2], ['w_spire', 2], ['w_pebbles', 1]],
      river: { kits: [['r_rock1', 3], ['r_rock2', 2], ['r_rock3', 1]], drop: 1, mouth: 0.6, bank: 0.16, wall: 0.4 } };
    // Fixed crash piles (image px; kit footprint centre). Ground = lowest cell under the footprint → piles sit in the pit and jut out of it.
    // Crash sphere (2026-10-07k): the fallen sky city. Base = terrain dome (cheap voxels) raised over the crater's stop point and painted in ruin tones; on top,
    // N buildings borrowed from every nation's kit set (+ Cyfrolaef ruins), recoloured to Cyfrolaef greys (tint = mix(luma, cy, mix) × dark), tilted / pitched
    // at random, half-sunk, overlapping → one jumbled ball of cities. All placed scatter (camera-culled). Godot: dome = heightmap edit, buildings = MultiMesh per kit.
    const CRASH_SPHERE = { c: [1175, 1635], r: 60, top: 18, noise: 1, buildings: 140, spread: 0.95, sink: [0.1, 0.6], tilt: 1.0, pitch: 0.7, flip: 0.12, cy: '#7a6e78', mix: 0.4, dark: 0.85,
      paint: [[[96, 92, 96], [80, 76, 82], 4], [[58, 56, 66], [48, 46, 56], 3], [[110, 72, 54], [92, 60, 46], 2], [[64, 76, 104], [52, 62, 88], 1.5], [[112, 70, 140], [90, 56, 116], 0.8]],
      extra: ['cy_b01', 'cy_b03', 'cy_b05', 'cy_b09', 'cy_b10', 'cy_b12', 'cy_b14', 'cy_b15', 'cy_b16', 'cy_b18', 'cy_b20', 'cy_pile1', 'cy_pile2', 'cy_pile3', 'p_ruin_tower', 'p_ruin_arch', 'cy_s11', 'cy_s08', 'cy_s13'] };
    // Chwahwr (cove): sunken sky-city ruins — Cyfrolaef towers / piles / street pieces half-submerged and tilted in the cove's water. 12 px lattice, density d.
    const SUNKEN = { region: 'Chwahwr', shallows: 'Violet shallows', pad: 2, step: 11, d: 0.5, sink: [0.05, 0.45], tilt: 0.9, pitch: 0.5,
      k: [...Array.from({ length: 26 }, (_, i) => ['cy_b' + String(i + 1).padStart(2, '0'), 1]), ['cy_pile2', 1.5], ['cy_pile3', 1.5], ['cy_s11', 2], ['cy_s13', 1.5], ['cy_s08', 1], ['cy_s02', 1.5], ['p_slab', 2], ['p_rubble2', 1.5]] };
    // Palisade walls (map/map-walls.json): step px between stakes, top = world units above the lowest ground on the wall, minH = shortest stake (units),
    // lean = max roll (rad), crooked = share of stakes leaning up to crookLean, hJit = ± height jitter.
    const GREATWALL = { step: 2.4, height: 44, tower: 72, towerEvery: 46, merlonEvery: 2, buttEvery: 6, out: 2.6, inner: 2.6, buttOut: 4.6, arch: 12, smooth: 4, occR: 5 };
    const PALISADE = { kits: ['pal_1', 'pal_2', 'pal_3', 'pal_4', 'pal_5'], step: 1.3, top: 46, minH: 5, lean: 0.07, crooked: 0.12, crookLean: 0.24, pitch: 0.05, hJit: 0.07 };
    // Standalone grand landmarks (placed before settlements, nearest fitting spot; the town grows around them): [kit, x, z, name].
    // Citadel mounds (2026-10-08, Makaliim): terrain edit before the grid reads levels. Disc r px around c → base + raise terraces (base = median level of the disc);
    // ring outside it steps down 1 terrace per step px; east sector (± cutDeg) gets a dry cut cw px wide at base − 1 instead of the ring, spanned by a decorative
    // arched bridge running E–W across an EAST cut (arches face the camera; bridge kit, not traversable; its footprint is reserved so the town builds around it). Godot: heightmap edit + one MeshInstance.
    const MOUNDS = [{ name: 'Makaliim', c: [1672, 1160], r: 30, raise: 4, step: 3, cutDeg: 16, cw: 10, bridge: 'ml_bridge' }];
    const CASTLES = [['al_castle', 2756, 755, 'Austyg Castle'], ['vb_citadel', 1300, 836, 'Kale Vidneku Citadel'], ['su_castle', 2112, 1091, 'Castelo Divirio Castle'], ['co_fort', 3765, 1285, 'Caer Baqal Fort'], ['ml_citadel', 1672, 1158, 'Makaliim Citadel']]; // town fortresses at the town centres (Caer Baqal: on the plateau's cliff edge over the bay)
    // LANDMARKS: [kit, x, z, name, exact]. exact = sits right there (cave mouth on the pit's north rim, footprint lowest-median level); else SET.landmark ring search + flattened plot. Hover pops the label (temple id mask).
    const LANDMARKS = [['lm_cave', 3521, 1068, 'Mlinzjia', true], ['lm_cave_snow', 3340, 721, 'Kardmen Deep', true], ['lm_college', 3396, 2552, 'Aerdan South', false]];
    // ICE_MOUNTAIN: ice spikes scattered on the Bleeding Mountain cone (c, r image px), n tries; kits weighted.
    const ICE_MOUNTAIN = { c: [3530, 878], r: 40, n: 420, kits: [['p_icespike', 3], ['p_icespikeB', 3], ['p_icespikeR', 1]] };
    const CRASH_PILES = [['cy_pile1', 1176, 1640], ['cy_pile2', 1204, 1622], ['cy_pile3', 1150, 1656], ['cy_pile2', 1230, 1612], ['cy_pile1', 1160, 1615], ['cy_pile3', 1196, 1660], ['cy_pile3', 1335, 1582], ['cy_pile2', 1270, 1600]];
    const FOLIAGE_ZONES = [
      { id: 'makaliim_town', near: { at: 'Makaliim', px: 95 }, k: [['f_palm', 1], ['p_rocks', 1]], d: 0.01, c: 0.2 }, // keep the capital's streets clear (was: acacias / brush between every house)
      { id: 'magma', cls: [15], k: [['p_obsidian', 2], ['p_spire', 1], ['p_rocks', 1]], d: 0.04, c: 0.2 },
      { id: 'shadetrail', ell: { at: 'Shadetrail', dx: 28, dz: 26, rx: 115, rz: 90 }, clsNot: [5, 8, 10], k: [['f_shadepine', 5], ['f_dead', 2], ['f_deadc', 0.5], ['f_fern', 1]], d: 0.95, c: 0.15 },
      { id: 'dead_ring', near: { at: 'Adalville', px: 95 }, clsNot: [10], k: [['f_dead', 5], ['f_deadc', 1]], d: 0.55, c: 0.2 },
      { id: 'flower_ring', near: { at: 'Ancaton', px: 95 }, clsNot: [10], k: [['f_flowers', 6], ['f_shrub', 1]], d: 0.6, c: 0.2 },
      { id: 'prairie_open', region: ["Nathair's Prairie"], k: [['f_tallgrass', 4], ['f_flowers', 4], ['f_reeds', 2]], d: 0.22, c: 0.3 },
      { id: 'prairie_ring', near: { region: "Nathair's Prairie", px: 90 }, clsNot: [5, 6, 7, 8, 10], k: [['f_jungle', 4], ['f_kapok', 1], ['f_redwood', 2], ['f_emergent', 2], ['f_birch', 1]], d: 0.95, c: 0.1 },
      { id: 'bardholt', region: ['Bardholt'], clsNot: [5, 6, 7, 8, 10], k: [['f_jungle', 4], ['f_redwood', 2], ['f_emergent', 2], ['f_birch', 1], ['f_fern', 2], ['f_cherry', 0.6], ['f_wisteria', 0.4], ['f_wisteria_w', 0.3]], d: 0.85, c: 0.3 },
      { id: 'meadow', region: ['Miru Pass'], k: [['f_flowers', 4], ['f_shrub', 2], ['p_rocks', 1.5], ['f_tallgrass', 2]], d: 0.1, c: 0.4 },
      { id: 'icefield', region: ['Belameir Icefield'], k: [['p_icespike', 3], ['p_icerock', 2], ['p_snowrock', 1]], d: 0.09, c: 0.4 },
      // Yrspholahs crash (2026-10-07i): impact bowl (east, 1345,1578) → drag channel → stop scour + pushed heap (west, 1175,1635). seg = distance-to-segment filter.
      { id: 'crater_wreck', seg: { a: [1175, 1635], b: [1199, 1628], w: 42 }, k: [...[...Array.from({ length: 26 }, (_, i) => ['cy_b' + String(i + 1).padStart(2, '0'), i >= 20 ? 1.4 : 0.7])], ['p_rubble2', 3], ['p_debris', 3], ['p_slab', 2], ['cy_s11', 1], ['cy_s10', 1]], d: 1, c: 0, fill: { step: 3, d: 0.6, k: [['p_rubble', 3], ['p_rebar', 2], ['p_debris', 2], ['p_slab', 1], ['cy_s11', 1], ['cy_s03', 0.5], ['cy_s04', 0.5], ['r_rock2', 1]] } },
      { id: 'crater_drag', seg: { a: [1345, 1578], b: [1175, 1635], w: 34 }, k: [['p_debris', 3], ['p_rubble2', 3], ['p_slab', 2], ['p_rebar', 2], ['p_cspike1', 1.5], ['p_cspike3', 1.5], ['cy_s11', 1.5], ['cy_s10', 1.5], ['cy_b21', 0.5], ['cy_b26', 0.4], ['cy_b07', 0.5], ['cy_b17', 0.4], ['cy_b08', 0.3]], d: 1, c: 0, fill: { step: 3, d: 0.5, k: [['p_rubble', 3], ['p_rebar', 2], ['p_debris', 2], ['r_rock1', 2], ['r_rock2', 2], ['cy_s11', 1], ['cy_s03', 0.5]] } },
      { id: 'crater_junkyard', near: { region: 'Yrspholahs', px: 110 }, k: [['p_cspike1', 2], ['p_cspike2', 2], ['p_cspike3', 1.6], ['p_cspike4', 1.2], ['p_rubble', 2], ['p_rubble2', 2], ['p_debris', 2], ['p_slab', 1.2], ['p_rebar', 1], ['p_junk', 1.5], ['p_wreck', 1], ['p_ruin_wall', 1], ['p_column', 0.5], ['cy_b06', 0.5], ['cy_b07', 0.6], ['cy_b17', 0.5], ['cy_b08', 0.3], ['cy_b19', 0.3], ['cy_b21', 0.4], ['cy_b23', 0.5], ['cy_b26', 0.3], ['cy_s10', 1], ['cy_s11', 1], ['f_deadc', 0.4]], d: 1, c: 0.1, fill: { step: 3, d: 0.55, k: [['p_rubble', 3], ['p_rebar', 2], ['p_debris', 2], ['p_slab', 1], ['p_rocks', 2], ['r_rock1', 2], ['r_rock2', 2], ['r_rock3', 1], ['cy_s11', 0.8], ['cy_s10', 0.4], ['p_cspike1', 0.4], ['p_cspike2', 0.3]] } },
      { id: 'corrupted', region: ['Ultimsicao', 'Pretan Sands'], k: CORRUPT, d: 0.22, c: 0.5 },
      { id: 'cyfrolaef_ruins', nation: ['Cyfrolaef'], k: CYF, d: 0.3, c: 0.45 },
      { id: 'corrupted_edge', nation: ['Miliim'], cls: [6, 7, 14], near: { nation: 'Cyfrolaef', px: 320 }, k: CORRUPT, d: 0.14, c: 0.5 },
      { id: 'purple_forest', cls: [4], k: [['f_wisteria', 3], ['f_violetfir', 3], ['f_mushroom', 2]], d: 0.7, c: 0.4 },
      { id: 'taiga', region: ['Bair Taiga'], k: TAIGA, d: 0.95, c: 0.3 },
      { id: 'boreal', region: ['Lugnaf Boreal'], k: BOREAL, d: 0.9, c: 0.3 },
      { id: 'snow_pass', region: ['Vaern Pass'], k: [['p_snowrock', 2], ['f_snowbush', 2]], d: 0.025, c: 0.3 },
      { id: 'sand_island', island: true, cls: [0, 1, 2, 5, 10, 12], k: [['f_palm', 4], ['f_palm2', 3], ['f_shrub', 1], ['p_rocks', 1], ['p_driftwood', 0.5]], d: 0.28, c: 0.3 },
      { id: 'beach_marsh', cls: [10], nation: ['Suorr', 'Copari', 'Miliim'], k: [['p_rocks', 2], ['f_reeds', 3], ['f_tallgrass', 1]], d: 0.1, c: 0.4 },
      { id: 'beach_north', cls: [10], zMax: 1250, k: [['p_rocks', 3], ['p_boulder', 1], ['p_driftwood', 1]], d: 0.07, c: 0.3 },
      { id: 'beach_palm', cls: [10], k: [['f_palm', 3], ['f_palm2', 2], ['p_rocks', 1], ['p_driftwood', 0.5]], d: 0.09, c: 0.3 },
      // Tiir Savanna (2026-10-08): Buern-style dry savanna (acacias, dry brush, rocks) across the whole region, whatever the ground class; a sparser fringe on the
      // sand within 70 px outside it, then the Abmar desert proper (cacti) beyond.
      // Tiir Wood (2026-10-08): dense woodland between Gurulu and Maluvi — acacias + brush on the dry grass / sand, oak-led mixed wood (+ acacias thinning out) on the green
      // meadow land toward Maluvi; fringe ring 40 px around the region.
      { id: 'tiir_wood_dry', region: ['Tiir Wood'], cls: [1, 5, 12, 13, 14], k: [['f_acacia', 6], ['f_baobab', 0.5], ['f_drybrush', 2], ['f_scrub', 2], ['f_tallgrass', 1]], d: 0.55, c: 0.3 },
      { id: 'tiir_wood_green', region: ['Tiir Wood'], clsNot: [6, 7, 8, 10], k: [['f_oak', 6], ['f_acacia', 2], ['f_birch', 1], ['f_shrub', 2], ['f_flowers', 1]], d: 0.7, c: 0.3 },
      { id: 'tiir_wood_fringe', near: { region: 'Tiir Wood', px: 40 }, clsNot: [5, 6, 7, 8, 10], k: [['f_oak', 3], ['f_acacia', 3], ['f_shrub', 2], ['f_scrub', 1]], d: 0.22, c: 0.4 },
      { id: 'savanna_tiir', region: ['Tiir Savanna'], clsNot: [6, 7, 8, 10], k: [['f_acacia', 3], ['f_drybrush', 4], ['p_rocks', 2], ['f_scrub', 1], ['f_tallgrass', 1], ['f_baobab', 0.3]], d: 0.07, c: 0.35 },
      { id: 'savanna_fringe', near: { region: 'Tiir Savanna', px: 70 }, cls: [1, 5, 12], k: [['f_acacia', 1.5], ['f_drybrush', 4], ['p_rocks', 2.5], ['f_scrub', 1]], d: 0.035, c: 0.3 },
      { id: 'desert', nation: ['Kathaya'], cls: [5], k: [['f_cactus', 3], ['f_prickly', 1.5], ['f_drybrush', 3], ['p_rocks', 0.6]], d: 0.06, c: 0.4 },
      { id: 'grassland', region: ['Kathayan Grassland'], k: GRASSLAND, d: 0.08, c: 0.4 },
      { id: 'grassland', nation: ['Kathaya'], k: GRASSLAND, d: 0.06, c: 0.4 },
      { id: 'arid_brush', nation: ['Miliim'], clsNot: [8], k: [['f_drybrush', 4], ['p_rocks', 3], ['p_boulder', 2], ['f_scrub', 2], ['f_juniper', 0.5], ['f_dead', 0.3]], d: 0.12, c: 0.4 },
      { id: 'marsh_dry', nation: ['Suorr'], clsNot: [6, 7, 8], near: { at: 'Capria', px: 380 }, k: [['f_tallgrass', 3], ['f_drybrush', 2], ['f_reeds', 1], ['f_willow', 0.5]], d: 0.04, c: 0.3 },
      { id: 'marsh', nation: ['Suorr'], clsNot: [6, 7, 8], k: [['f_willow', 3], ['f_cypress', 3], ['f_mangrove', 2], ['f_reeds', 4], ['p_pond', 1.5], ['p_mudpit', 1.5], ['f_tallgrass', 1]], d: 0.32, c: 0.5 },
      // Erakha Wood (2026-10-08): dense acacia woodland with bushes around Erakha's Hollow and the land toward Erakhaton (ellipse, soft fringe); the rest of the region stays savanna.
      { id: 'erakha_forest', region: ['Erakha Wood'], ell: { at: "Erakha's Hollow", dx: -70, dz: 10, rx: 200, rz: 130 }, clsNot: [6, 7, 8, 10], k: [['f_acacia', 6], ['f_baobab', 0.6], ['f_scrub', 2], ['f_shrub', 2], ['f_drybrush', 2], ['f_tallgrass', 1]], d: 0.62, c: 0.3 },
      { id: 'erakha_fringe', region: ['Erakha Wood'], ell: { at: "Erakha's Hollow", dx: -70, dz: 10, rx: 260, rz: 175 }, clsNot: [6, 7, 8, 10], k: [['f_acacia', 4], ['f_scrub', 2], ['f_drybrush', 3], ['f_shrub', 1], ['p_rocks', 1]], d: 0.2, c: 0.4 },
      { id: 'pine_oak', nation: ['Buern'], cls: [2, 3], k: [['f_pine', 3], ['f_oak', 3], ['f_fir', 1], ['f_beech', 1], ['f_shrub', 1]], d: 0.8, c: 0.35 },
      { id: 'savanna', nation: ['Buern'], clsNot: [6, 7, 8], k: [['f_acacia', 3], ['f_drybrush', 4], ['p_rocks', 2], ['f_scrub', 0.5], ['f_baobab', 0.4]], d: 0.05, c: 0.3 },
      { id: 'aerdis_dry', nation: ['Aerdis'], cls: [1, 5, 14], k: [['p_rocks', 3], ['f_reeds', 3], ['p_boulder', 1], ['f_tallgrass', 1], ['p_mudpit', 0.5]], d: 0.08, c: 0.4 },
      { id: 'rainforest', nation: ['Aerdis'], clsNot: [5, 6, 7, 8, 10], k: [['f_jungle', 4], ['f_kapok', 1.5], ['f_redwood', 1.5], ['f_emergent', 2], ['f_birch', 1], ['f_fern', 3], ['f_shrub', 1]], d: 0.6, dDark: 0.95, c: 0.3 },
      { id: 'blossom_grove', nation: ['Zukei'], tone: [2], clsNot: [5, 6, 7, 8, 10], k: [['f_cherry', 3], ['f_jacaranda', 2], ['f_wisteria', 2], ['f_wisteria_w', 2], ['f_zpine', 2], ['f_maple', 1]], d: 0.85, c: 0.3 },
      { id: 'blossom_grove', nation: ['Zukei'], cls: [2, 3], k: [['f_cherry', 3], ['f_jacaranda', 2], ['f_wisteria', 2], ['f_wisteria_w', 2], ['f_zpine', 2], ['f_maple', 1]], d: 0.75, c: 0.3 },
      { id: 'blossom_meadow', nation: ['Zukei'], clsNot: [6, 7, 8], k: [['f_flowers', 5], ['f_cherry', 2], ['f_shrub', 2], ['f_jacaranda', 1], ['f_wisteria_w', 0.6], ['f_zpine', 0.6], ['p_rocks', 0.4]], d: 0.16, c: 0.5 },
      { id: 'meadow', regionCat: ['plains', 'prairie'], cls: [0, 1, 12], k: MEADOW, d: 0.1, c: 0.4 },
      { id: 'winter_pines', nation: ['Aldurstein'], cls: [2, 3], k: [['f_snowpine', 4], ['f_snowfir', 1]], d: 0.12, c: 0.5 },
      { id: 'winter', nation: ['Aldurstein'], k: [['f_snowpine', 4], ['f_snowbush', 1], ['p_snowrock', 0.4]], d: 0.025, c: 0.5 },
      { id: 'mountain_rock', nation: ['Rossade'], cls: [6, 7, 14], k: [['p_boulder', 3], ['p_rocks', 3], ['p_snowrock', 3], ['p_spire', 1]], d: 0.2, c: 0.4 },
      { id: 'mountain_snow', nation: ['Rossade'], cls: [8], k: [['p_snowrock', 3], ['p_rocks', 1.5], ['f_snowpine', 1]], d: 0.07, c: 0.4 },
      { id: 'boreal', nation: ['Rossade'], k: BOREAL, d: 0.6, c: 0.4 },
      { id: 'mountain_rock', nation: ['Copari'], cls: [6, 7, 14], k: [['p_rocks', 3], ['p_boulder', 3], ['p_spire', 0.5]], d: 0.15, c: 0.4 },
      { id: 'wheat', nation: ['Copari'], cls: [13], k: [['f_tallgrass', 1]], d: 0, c: 0 },
      { id: 'copari_green', nation: ['Copari'], cls: [2, 3], k: [['f_oak', 2], ['f_birch', 1], ['f_shrub', 2]], d: 0.08, c: 0.5 },
      { id: 'copari_fields', nation: ['Copari'], clsNot: [8], k: [['f_tallgrass', 3], ['f_hedge', 1], ['f_flowers', 1], ['f_oak', 0.3]], d: 0.06, c: 0.5 },
      { id: 'taiga', nation: ['Vaernebo'], cls: [2, 3], k: TAIGA, d: 0.85, c: 0.3 },
      { id: 'snow_plain', nation: ['Vaernebo'], cls: [8], k: [['f_snowpine', 2], ['p_snowrock', 2], ['f_snowbush', 1]], d: 0.03, c: 0.4 } ];
    // Temples: one bespoke design per temple POI (name → kit).
    const gl = () => winGlow();
    Object.assign(KIT, {
      t_stars: () => { const o = [tb(6, 6, 0, 12, 12, 1, stoneT(), '#d8dce8', stoneT()), cyl(6, 6.5, 1, 7, 5, winW(), '#e8ecf4'), lathe(6, 6.5, 6, 7.6, 4, DOME, domeRib(), '#3a4a8a'), fin(6, 6.5, 9.8)];
        for (const [x, z] of [[1.5, 1.5], [10.5, 1.5], [1.5, 10.5], [10.5, 10.5]]) o.push(tb(x, z, 1, 0.8, 0.8, 6, stoneT(), '#e0e4f0', stoneT()), py(x, z, 7, 0.9, 0.9, 1, plainW(), '#f2d33d')); return F(12, 12, o); },
      t_roserun: () => { const o = [tb(6, 5.5, 0, 12, 11, 0.8, stoneT(), '#e8c8c8', stoneT())]; for (let k = 0; k < 8; k++) { const a = k / 8 * Math.PI * 2; o.push(tb(6 + Math.cos(a) * 3.4, 5.5 + Math.sin(a) * 3.4, 0.8, 0.6, 0.6, 4, pisePlain(), '#f4e4e4')); }
        o.push(cyl(6, 5.5, 4.8, 8.4, 0.8, pisePlain(), '#f0d8d8'), lathe(6, 5.5, 5.6, 6, 2.6, DOME, domeRib(), '#d86a8a'), fin(6, 5.5, 8));
        for (const [x, z] of [[1.2, 1.2], [10.8, 1.2], [1.2, 9.8], [10.8, 9.8], [1.2, 5.5], [10.8, 5.5]]) o.push(can(x, z, 0.8, 1.6, 1.4, 1, '#c84a6a')); return F(12, 11, o); },
      t_war: () => { const S = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, stoneT(), c, stoneT()); const o = [S(6, 6, 0, 12, 12, 2.2, '#7a3a30'), S(6, 6.5, 2.2, 9, 9, 2.2, '#8a4434'), S(6, 7, 4.4, 6, 6, 2.2, '#9a4e3a'), bbox(6, 7.2, 6.6, 3, 3, 2.2), S(6, 0.8, 0, 3, 1.6, 2.2, '#6a3028')];
        for (const x of [0.8, 11.2]) o.push(S(x, 0.8, 0, 0.8, 0.8, 5, '#3a2a28'), py(x, 0.8, 5, 1, 1, 1.4, roofS(), '#a03020'), tb(x, 2, 2.2, 0.8, 0.8, 0.4, plainW(), '#ff8a2a')); return F(12, 12, o); },
      t_monk: () => { const S = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, stoneT(), c, stoneT()), o = [S(6, 0.5, 0, 12, 1, 2.5, '#c8b898'), S(6, 11.5, 0, 12, 1, 2.5, '#c8b898'), S(0.5, 6, 0, 1, 10, 2.5, '#c8b898'), S(11.5, 6, 0, 1, 10, 2.5, '#c8b898'), card(6, 0, 0, 2, 2.4, doorS()),
        S(6, 8.5, 0, 6, 4, 4, '#d0c0a0'), gb(6, 8.5, 4, 6.4, 4.4, 2.5, roofS(), '#8a4a30'), S(10, 8.5, 0, 2.2, 2.2, 8, '#d0c0a0'), py(10, 8.5, 8, 2.6, 2.6, 2, roofS(), '#8a4a30'),
        tb(3, 4, 0, 4, 3, 3, clap(), '#8a6a44'), gb(3, 4, 3, 4.4, 3.4, 1.4, roofS(), '#6a4a30'), chim(4.4, 4.6, 3, 2.4), can(8, 4, 0, 3, 3, 0.3, '#6a9a40')];
        for (const x of [2, 3, 4, 5]) o.push(cyl(x, 1.6, 0, 0.8, 1, clap(), '#7a5434')); return F(12, 12, o); },
      t_dragons: () => F(12, 11, [tb(6, 5.5, 0, 12, 11, 1, stoneT(), '#b0a090', stoneT()), tb(6, 6.5, 1, 8, 6, 3, winW(), '#c03a2a'), py(6, 6.5, 4, 10, 8, 1.6, roofS(), '#2a6a4a'), tb(6, 6.5, 5.6, 5, 4, 2, winW(), '#c03a2a'),
        py(6, 6.5, 7.6, 7, 5.6, 1.6, roofS(), '#2a6a4a'), py(6, 6.5, 9.2, 3, 2.4, 1.6, roofS(), '#d8a020'), ...[2, 10].flatMap(x => [cyl(x, 1.6, 1, 0.9, 5, plainW(), '#3a9a5a'), fin(x, 1.6, 6)])]),
      t_knowledge: () => { const o = [tb(6.5, 5.5, 0, 13, 11, 1, stoneT(), '#e8e0d0', stoneT()), tb(6.5, 6.5, 1, 9, 7, 5, winW(), '#e0d8c4'), gb(6.5, 2.4, 6, 12, 2.6, 2, pisePlain(), '#f2ece0'), gb(6.5, 6.5, 6, 9.6, 7.6, 1.6, roofS(), '#8a8a7a'), tb(11, 8, 1, 2.4, 2.4, 7, winW(), '#d8d0bc'), py(11, 8, 8, 2.8, 2.8, 1.6, roofS(), '#8a8a7a')];
        for (let x = 2; x <= 11; x += 1.8) o.push(tb(x, 1.6, 1, 0.7, 0.7, 5, pisePlain(), '#f2ece0')); return F(13, 11, o); },
      t_dead: () => { const S = (x, z, y, w, d, h, c) => tb(x, z, y, w, d, h, stoneT(), c, stoneT()), o = [S(6, 6, 0, 12, 12, 0.8, '#5a5652'), py(6, 6.5, 0.8, 9, 9, 7, stoneT(), '#6a6660'), card(6, 2, 0.8, 2, 2.4, doorS())];
        for (const x of [1.5, 10.5]) { o.push(S(x, 1.5, 0.8, 0.8, 0.8, 5, '#3a3836'), py(x, 1.5, 5.8, 0.9, 0.9, 0.8, stoneT(), '#3a3836')); for (const z of [4.5, 7, 9.5]) o.push(S(x, z, 0.8, 1.2, 2, 0.8, '#8a8680')); } return F(12, 12, o); },
      t_shadows: () => { const o = [tb(6, 6.5, 0, 9, 8, 6, stoneT(), '#2e2a36', stoneT()), gb(6, 6.5, 6, 9.4, 8.4, 3, roofS(), '#3a3048'), card(6, 2.4, 3, 1.6, 2, gl(), '#9a5aff')];
        for (const [x, z, h] of [[1.5, 2, 10], [10.5, 2, 10], [6, 1.5, 14], [1.5, 11, 8], [10.5, 11, 8]]) o.push(tb(x, z, 0, 1.6, 1.6, h, stoneT(), '#26222e', stoneT()), py(x, z, h, 1.8, 1.8, 5, roofS(), '#5a3a7a')); return F(12, 12, o); },
      t_life: () => F(12, 12, [tb(6, 6, 0, 12, 12, 1, stoneT(), '#f2eee4', stoneT()), tb(6, 2.6, 1, 5, 2.4, 0.2, plainW(), '#5aa8d8'), tb(6, 7.5, 1, 1.4, 1.4, 4, barkG(), '#7a5a3a', barkG()),
        can(6, 7.5, 5, 8, 7, 2.4, '#4aa848'), can(6, 7.5, 7.4, 5.6, 5, 1.4, '#5ab858'), can(6, 7.5, 8.8, 3, 3, 0.8, '#6ac868'), ...[[1.8, 10.4], [10.2, 10.4]].flatMap(([x, z]) => [cyl(x, z, 1, 2, 2.4, plainW(), '#f2f0e8'), py(x, z, 3.4, 2.4, 2.4, 1.2, roofS(), '#d8c890')])]),
      t_night: () => F(12, 12, [tb(6, 7, 0, 6, 10, 6, stoneT(), '#3a3a4a', stoneT()), gb(6, 7, 6, 6.4, 10.4, 3.6, roofS(), '#24242e'), ...[3.2, 8.8].flatMap(x => [tb(x, 1.6, 0, 2.4, 2.4, 12, stoneT(), '#30303e', stoneT()), py(x, 1.6, 12, 2.6, 2.6, 7, roofS(), '#1e1e28')]),
        card(6, 1.9, 6, 2, 2, gl(), '#7a8aff'), card(6, 1.9, 0, 2, 3, doorS())]),
      t_elements: () => { const o = [tb(6, 6, 0, 12, 12, 0.5, stoneT(), '#c8c0b0', stoneT()), cyl(6, 6, 0.5, 5, 4, winW(), '#e8e0d0'), lathe(6, 6, 4.5, 5.6, 3, DOME, domeRib(), '#d8c890'), fin(6, 6, 7.4)];
        for (const [x, z, c] of [[1.6, 1.6, '#c84a2a'], [10.4, 1.6, '#3a7ac8'], [1.6, 10.4, '#7a6a3a'], [10.4, 10.4, '#e8eef4']]) o.push(cyl(x, z, 0.5, 2.4, 8, stoneT(), c), cone(x, z, 8.5, 2.8, 3, roofS(), c)); return F(12, 12, o); } });
    const TEMPLES = { 'Temple of Stars': 't_stars', 'Roserun Temple': 't_roserun', 'Temple of War': 't_war', 'Temple of the Drunkard': 't_monk', 'Temple of Dragons': 't_dragons', 'Temple of Knowledge': 't_knowledge',
      'Temple of the Dead': 't_dead', 'Temple of Shadows': 't_shadows', 'Temple of Life': 't_life', 'Church of Eternal Night': 't_night', 'Temple of Elements': 't_elements' };
    // Capital palaces: one signature building per nation style, centered at the back of the walled core (≤ 14 × 11 units, 14–21 tall).
    const PALACE = {
      buern: (T, r) => { const o = [pbox(7, 6, 0, 14, 10, 8, T), ...par(7, 6, 8, 14, 10, T), card(7, 1, 0, 5, 6, gate()), band(7, 1, 6, 14), lathe(7, 6, 8, 7, 2, CYL, pise(), T.wall), lathe(7, 6, 10, 10, 9, ONION, domeRib(), T.dome), fin(7, 6, 18.6)];
        for (const x of [1.5, 12.5]) o.push(...shift(KIT.minaret(T, r).parts, x - 1.5, 7.5)); for (const x of [3.5, 10.5]) o.push(lathe(x, 3, 8, 2.6, 1, CYL, pise(), T.wall), lathe(x, 3, 9, 3.4, 3.4, ONION, domeStripe(), T.stripe), fin(x, 3, 12.2)); return F(14, 11, o); },
      vaernebo: T => { const o = [pbox(7, 5.5, 0, 12, 9, 7, T), card(7, 1, 0, 4, 5, gate()), lathe(7, 5.5, 7, 7, 2, CYL, pise(), T.wall), lathe(7, 5.5, 9, 9, 4.5, DOME, domeRib(), T.dome), fin(7, 5.5, 13.3), lathe(7, 1.5, 5, 5, 2.5, DOME, domeRib(), T.dome)];
        for (const [x, z] of [[0.8, 0.8], [13.2, 0.8], [0.8, 10.2], [13.2, 10.2]]) o.push(cyl(x, z, 0, 1.2, 14, pise(), T.wall), cone(x, z, 14, 1.4, 2.5, roofS(), T.dome)); return F(14, 11, o); },
      rossade: T => { const o = [bbox(7, 6, 0, 12, 9, 6), ...par(7, 6, 6, 12, 9, T, true), card(7, 1.5, 0, 4, 5, gate()), bbox(7, 6, 6, 4, 4, 5), roof(7, 6, 11, 4.4, 4.4, 9, T.tent || T.roof), fin(7, 6, 19.6)];
        [[3, 3], [11, 3], [3, 9], [11, 9]].forEach(([x, z], k) => o.push(cyl(x, z, 6, 2.2, 3, brick()), lathe(x, z, 9, 3, 3.2, ONION, domeStripe(), [T.stripe, T.dome, '#3a8a5a', '#d8a020'][k]), fin(x, z, 12))); return F(14, 11, o); },
      kathaya: T => { const o = [pbox(7, 6, 0, 12, 8, 6, T), gb(7, 6, 6, 12.4, 8.4, 2.5, roofS(), T.roof || '#b0503a'), card(7, 2, 6, 6, 3, pise(), T.wall), card(7, 2, 0, 3, 4, doorS()), tb(7, 1, 4, 10, 1.6, 0.4, clap(), T.wood)];
        for (const x of [1.5, 12.5]) o.push(pbox(x, 2.5, 0, 3, 3, 12, T), py(x, 2.5, 12, 3.4, 3.4, 2, roofS(), T.roof || '#b0503a'), fin(x, 2.5, 14)); for (const x of [3, 5, 9, 11]) o.push(post(x, 1, 0, 4, T.wood)); return F(14, 10, o); },
      aldurstein: T => { const W = T.wood || '#6a4a30', Rf = T.roof || '#3a3a3a', Fa = T.falu || '#9a3a2a'; return F(14, 10, [tb(7, 7, 0, 13, 6, 4, clap(), W), gb(7, 7, 4, 13.6, 6.6, 3.5, roofS(), Rf), tb(7, 3, 0, 6, 6, 5, clap(), Fa), py(7, 3, 5, 7.4, 7.4, 2.5, roofS(), Rf),
        tb(7, 3, 7.5, 4, 4, 2.5, clap(), Fa), py(7, 3, 10, 5, 5, 2.5, roofS(), Rf), tb(7, 3, 12.5, 2.4, 2.4, 2, clap(), Fa), py(7, 3, 14.5, 3, 3, 4, roofS(), Rf), fin(7, 3, 18.5), dp(7, 0)]); },
      zukei: T => { const o = [tb(7, 5.5, 0, 13, 11, 4, stoneT(), T.stone, stoneT())]; let y = 4; for (const w of [10, 8.4, 6.8, 5.2]) { o.push(tb(7, 5.5, y, w, w * 0.8, 2.4, winW(), T.plaster), py(7, 5.5, y + 2.4, w + 1.4, w * 0.8 + 1.4, 1.2, roofS(), T.roof)); y += 3.6; }
        o.push(py(7, 5.5, y, 4, 3.4, 2, roofS(), T.roof), fin(7, 5.5, y + 2)); return F(14, 11, o); },
      suorr: T => { const o = [bbox(7, 6, 0, 13, 8, 8), gb(7, 6, 8, 13.4, 8.4, 3, roofS(), T.slate), bbox(7, 2.5, 0, 3.4, 3.4, 16), card(7, 0.75, 12, 2, 2, clock()), py(7, 2.5, 16, 4, 4, 5, roofS(), T.slate), fin(7, 2.5, 21), dp(4, 2), dp(10, 2)];
        for (const [x, z] of [[0.9, 2.4], [13.1, 2.4], [0.9, 9.6], [13.1, 9.6]]) o.push(bbox(x, z, 8, 1, 1, 4), py(x, z, 12, 1.2, 1.2, 1.6, roofS(), T.slate)); return F(14, 10, o); },
      miliim: T => { const o = [pbox(7, 6, 0, 13, 9, 5, T), ...par(7, 6, 5, 13, 9, T), pbox(7, 6.5, 5, 9, 6, 4, T), ...par(7, 6.5, 9, 9, 6, T), pbox(7, 3.5, 0, 4, 3, 14, T), cone(7, 3.5, 14, 3, 3, pisePlain(), T.wall), card(7, 1.5, 0, 2, 3, doorS())];
        for (const y of [3, 6, 9, 12]) for (const x of [5.6, 7, 8.4]) o.push(tb(x, 1.8, y, 0.3, 0.8, 0.3, barkG(), '#6a4a2a', barkG()));
        for (const x of [1.5, 12.5]) o.push(pbox(x, 3, 0, 2.6, 2.6, 9, T), cone(x, 3, 9, 2.6, 2.4, pisePlain(), T.wall)); return F(14, 11, o); },
      aerdis: T => { const o = [tb(7, 6, 0, 10, 8, 7, stoneT(), T.stone, stoneT()), ...par(7, 6, 7, 10, 8, T), card(7, 2, 0, 3, 4, doorS())];
        for (const [x, z, h] of [[2, 2, 12], [12, 2, 12], [2, 10, 10], [12, 10, 10], [7, 6, 18], [4.5, 8, 14]]) o.push(cyl(x, z, 0, 2.4, h, stoneT(), T.stone), cone(x, z, h, 3, 3.6, roofS(), '#3a6ab0')); o.push(fin(7, 6, 21.6)); return F(14, 11, o); },
      copari: T => { const P = T.plaster || '#e8e4d8', o = [tb(7, 6, 0, 14, 8, 6, winW(), P), gb(7, 1.6, 5.4, 8, 2, 1.8, pisePlain(), '#f2f0e8'), cyl(7, 6, 6, 6, 3, winW(), P), lathe(7, 6, 9, 6.6, 4, DOME, domeRib(), '#8aa0b0'), cyl(7, 6, 13, 1.4, 1.6, plainW(), '#f2f0e8'), fin(7, 6, 14.6), dp(7, 2)];
        for (let x = 3; x <= 11; x += 2) o.push(tb(x, 1.4, 0, 0.6, 0.6, 5.4, pisePlain(), '#f2f0e8')); return F(14, 10, o); } };
    const putK = (o, k, cx, cz) => o.push(...shift(k.parts, cx - k.W / 2, cz - k.D / 2));
    const pal = e => PALS[(e && e.style) || 'buern'] || PALS.buern, W_ = (a, W) => (a.W = W, a);
    for (const id of Object.keys(KIT)) MODELS['buern_' + id] = e => { const k = KIT[id](pal(e), () => 0.3); return W_(k.parts, k.W); };
    MODELS.buern_walled_core = e => { const k = core(pal(e), () => 0.3); return W_(k.parts, k.W); };
    // ── railroad bridge (rusty steel deck truss, side elevation). end = connection piece (stone abutment + sloped end truss; mirror for the far end).
    // mid = seamless repeating panel (post at x 0 only). Both 7 px tall; top rows = deck girder.
    const RUST = ['#3d2416', '#5e3420', '#7a4126', '#8a4b2a', '#a85f34', '#c98a52'];
    const rust = (px, x, y, b) => { const r = n(x * 7 + 3, y * 5 + 1); px(x, y, RUST[r > 0.86 ? Math.min(5, b + 1) : r < 0.14 ? Math.max(0, b - 1) : b]); };
    const ln = (px, x0, y0, x1, y1, b) => { const st = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) || 1; for (let k = 0; k <= st; k++) rust(px, Math.round(x0 + (x1 - x0) * k / st), Math.round(y0 + (y1 - y0) * k / st), b); };
    const bridgeMid = () => mod('bridge_mid', 12, 7, px => { for (let x = 0; x < 12; x++) { rust(px, x, 0, 4); rust(px, x, 1, 3); rust(px, x, 6, 1); }
      for (let y = 2; y < 6; y++) rust(px, 0, y, 2); ln(px, 1, 2, 11, 5, 3); ln(px, 1, 5, 11, 2, 2); for (let x = 1; x < 12; x += 3) px(x, 0, '#d9a066'); });
    // ── universal bridge (stone arch, side elevation; road / foot bridge placeable anywhere). mid = repeating arch span (half pier at x 0 and x 11
    // → 2 px piers when tiled; arch opening transparent). end = abutment (attach piece; mirror for the far end). Both 12 / 8 × 8; row 0 cap, 1 parapet, 2 string course.
    const ST = { cap: '#d6cdbf', cap2: '#e6dfd2', par: '#a69c8f', mor: '#6a6158', str: '#5a524a', sp: '#9c9286', sp2: '#8e8479', vou: '#bdb3a5', vou2: '#7c7368', pier: '#857b70', pierD: '#6a6158' };
    const ashlar = (x, y, a, b) => ((y & 1) ? (x % 4 === 1) : (x % 4 === 3)) ? ST.mor : n(x * 3 + 1, y * 7 + 2) > 0.55 ? a : b;
    const ubridgeMid = () => mod('ubridge_mid', 12, 8, px => { const open = (x, y) => ((x - 5.5) / 4.6) ** 2 + ((y - 8.2) / 5.2) ** 2 < 1;
      for (let x = 0; x < 12; x++) { px(x, 0, n(x, 0) > 0.7 ? ST.cap2 : ST.cap); px(x, 1, ashlar(x, 1, ST.par, ST.sp)); px(x, 2, ST.str); }
      for (let y = 3; y < 8; y++) for (let x = 0; x < 12; x++) { if (open(x, y)) continue;
        if (x === 0 || x === 11) { px(x, y, x === 0 ? ST.pier : ST.pierD); continue; }
        const ring = open(x - 1, y) || open(x + 1, y) || open(x, y + 1) || open(x - 1, y + 1) || open(x + 1, y + 1);
        px(x, y, ring ? ((x + y) & 1 ? ST.vou : ST.vou2) : ashlar(x, y, ST.sp, ST.sp2)); } });
    const ubridgeEnd = () => mod('ubridge_end', 8, 8, px => { for (let x = 0; x < 8; x++) { px(x, 0, n(x, 9) > 0.7 ? ST.cap2 : ST.cap); px(x, 1, ashlar(x, 1, ST.par, ST.sp)); }
      for (let y = 2; y < 8; y++) for (let x = 0; x < 8; x++) { const cul = ((x - 5.5) / 1.6) ** 2 + ((y - 7.6) / 2.2) ** 2 < 1; if (cul) continue;
        if (x < 4) px(x, y, x === 3 ? ST.pierD : ashlar(x, y + 1, ST.pier, ST.sp2)); else px(x, y, y === 2 ? ST.str : ((x - 5.5) / 2.4) ** 2 + ((y - 7.6) / 3) ** 2 < 1 ? ST.vou : ashlar(x, y, ST.sp, ST.sp2)); } });
    const bridgeEnd = () => mod('bridge_end', 8, 7, px => { for (let x = 0; x < 8; x++) { rust(px, x, 0, 4); rust(px, x, 1, 3); }
      for (let y = 2; y < 7; y++) for (let x = 0; x < 3; x++) px(x, y, (y === 4 || (x === 1 && y !== 4 && (y & 1))) ? '#6d665f' : n(x, y) > 0.6 ? '#a29b95' : '#8a827a');
      ln(px, 3, 2, 7, 6, 1); rust(px, 5, 2, 2); rust(px, 5, 3, 2); ln(px, 5, 2, 7, 4, 3); for (let x = 1; x < 8; x += 3) px(x, 0, '#d9a066'); });
    // ── railroad track textures (tiled along the path 1 row per map px): ballast top (across × along), ballast side (along × down),
    // tie top (along track × tie length), tie side, rail top (1 × along), rail side (along × 1).
    const rail = () => M('rail', () => ({
      ballast: mod('rail_ballast', 10, 8, px => { for (let y = 0; y < 8; y++) for (let x = 0; x < 10; x++) { const r = n(x * 5 + 1, y * 3 + 7); px(x, y, x === 0 || x === 9 ? '#6f665c' : r > 0.8 ? '#a39a8e' : r < 0.2 ? '#6f665c' : '#8a8073'); } }),
      ballastSide: mod('rail_ballastSide', 8, 4, px => { for (let y = 0; y < 4; y++) for (let x = 0; x < 8; x++) { const r = n(x * 3 + 2, y * 7 + 5); px(x, y, y === 0 ? '#8a8073' : r > 0.75 ? '#7a7166' : r < 0.25 ? '#4f4840' : '#5f574e'); } }),
      tieTop: mod('rail_tieTop', 2, 8, px => { for (let y = 0; y < 8; y++) for (let x = 0; x < 2; x++) px(x, y, y === 0 || y === 7 ? '#6e4a2c' : (y === 2 || y === 5) ? '#4a3a2e' : x === 0 ? '#8a6240' : '#7a5636'); }),
      tieSide: mod('rail_tieSide', 8, 1, px => { for (let x = 0; x < 8; x++) px(x, 0, n(x, 3) > 0.7 ? '#5a3d24' : '#6e4a2c'); }),
      railTop: mod('rail_railTop', 1, 4, px => { for (let y = 0; y < 4; y++) px(0, y, y === 2 ? '#eef0f4' : '#d8dbe1'); }),
      railSide: mod('rail_railSide', 4, 1, px => { for (let x = 0; x < 4; x++) px(x, 0, x === 3 ? '#7a7f88' : '#8e939c'); }) }));
    // ── UV-unwrap atlases (export + docs): 3 sheets — buildings / terrain / paths. One row per material family, 1 px gaps.
    // Sub-rects (house side, plain stone, swatches) live inside their parent texture.
    const ATLASES = () => { const r = rail(); return { // one row per atlas, 1 px gaps
      buildings: [wall(), gableTri(), roofTile(), stone(), stoneTop(), fenceTex(), flag(), swatches()],
      terrain: [leafTop(), leafSide(), bark()],
      styles: [plainW(), deck(), clap(), winW(), corr(), thatch(), stoneT(), strip(), timber(), shoji(), doorP(), sign(), clock(), winGlow()],
      buern: [pise(), crenel(), brickCrenel(), doorS(), gate(), zellige(), lattice(), awning(), roofS(), domeRib(), domeStripe(), doorT(), finial(), sebka(), brick()],
      paths: [dirt(), bridgeEnd(), bridgeMid(), ubridgeEnd(), ubridgeMid(), r.ballast, r.ballastSide, r.tieTop, r.tieSide, r.railTop, r.railSide] }; };
    const SUBS = () => [wallSide(), stonePlain(), sw(0), sw(1), sw(2), sw(3), pisePlain()];
    function atlas(name) { const mods = ATLASES()[name], rects = {}; let x = 0, H = 0;
      for (const m of mods) { rects[m.id] = { x, y: 0, w: m.width, h: m.height }; x += m.width + 1; H = Math.max(H, m.height); }
      for (const q of SUBS()) { const p = rects[q.s.id]; if (p) rects[q.id] = { x: p.x + q.r[0], y: p.y + q.r[1], w: q.r[2], h: q.r[3], parent: q.s.id }; }
      const c = create(x - 1, H), g = c.getContext('2d'); for (const m of mods) g.drawImage(m, rects[m.id].x, 0);
      return { name, canvas: c, rects }; }
    atlas.names = ['buildings', 'terrain', 'paths', 'buern'];
    const BUSH = new Set(['f_fern', 'f_shrub', 'f_scrub', 'f_drybrush', 'f_flowers', 'f_snowbush', 'f_reeds', 'f_cactus', 'f_prickly', 'f_haystack', 'f_sheaf', 'f_hedge', 'f_tallgrass']);
    const TREES = new Set(Object.keys(KIT).filter(k => k.startsWith('f_') && !BUSH.has(k)));
    // Ruin de-overlap (2026-10-08): in Cyfrolaef tower kits, a part that sits ≥ 30 % inside a larger part with a DIFFERENT tilt / pitch (two leaning stacks crossing,
    // a base slab buried in a fallen tower) is dropped — those intersecting faces were the shard / z-fight artifacts. Sampled on a 5³ lattice in world units.
    const deOverlap = parts => { const K = 1.4, KY = 1.6, keyOf = p => [p.tilt || 0, p.pitch || 0, p.piv ? p.piv.join(',') : ''].join('|'), rot = p => Math.abs(p.tilt || 0) + Math.abs(p.pitch || 0);
      const T = p => { const pv = p.piv || [p.x, p.y || 0, p.z], t = p.tilt || 0, q = p.pitch || 0; return { pv, ct: Math.cos(t), st: Math.sin(t), cq: Math.cos(q), sq: Math.sin(q) }; };
      const toW = (R, X, Y, Z) => { let dx = (X - R.pv[0]) * K, dy = (Y - R.pv[1]) * KY, dz = -(Z - R.pv[2]) * K; let nx = dx * R.ct - dy * R.st; dy = dx * R.st + dy * R.ct; dx = nx; const nz = dz * R.cq - dy * R.sq; dy = dz * R.sq + dy * R.cq; dz = nz; return [dx + R.pv[0] * K, dy + R.pv[1] * KY, dz - R.pv[2] * K]; };
      const inB = (B, R, w) => { let dx = w[0] - R.pv[0] * K, dy = w[1] - R.pv[1] * KY, dz = w[2] + R.pv[2] * K; const nz = dz * R.cq + dy * R.sq; dy = -dz * R.sq + dy * R.cq; dz = nz; const nx = dx * R.ct + dy * R.st; dy = -dx * R.st + dy * R.ct; dx = nx; const X = dx / K + R.pv[0], Y = dy / KY + R.pv[1], Z = -dz / K + R.pv[2], e = 0.06; return Math.abs(X - B.x) < B.w / 2 - e && Y > (B.y || 0) + e && Y < (B.y || 0) + (B.h || 0) - e && Math.abs(Z - B.z) < B.d / 2 - e; };
      const solid = p => (p.kind === 'box' || p.kind === 'lathe') && p.w > 0 && p.d > 0 && (p.h || 0) > 0;
      const hits = (A, B) => { const RA = T(A), RB = T(B); for (let i = 0; i < 6; i++) for (let j = 0; j < 6; j++) for (let k = 0; k < 6; k++) if (inB(B, RB, toW(RA, A.x - A.w / 2 + A.w * (i + 0.5) / 6, (A.y || 0) + (A.h || 0) * (j + 0.5) / 6, A.z - A.d / 2 + A.d * (k + 0.5) / 6))) return true; return false; };
      const G = new Map(); for (const p of parts) if (solid(p)) { const k = keyOf(p); if (!G.has(k)) G.set(k, []); G.get(k).push(p); }
      const groups = [...G.values()], clash = (a, b) => a.some(A => b.some(B => hits(A, B) || hits(B, A)));
      // Settle (2026-10-08): every pair of differently-rotated part groups that interpenetrate → the more-tilted group swings back toward upright about its own pivot
      // (rotation × 0.88 per step) until it just rests against the other (contact allowed, no intersection) — a leaning tower propped on its neighbour; if it would
      // have to stand fully upright and still clashes, the smaller group is removed. Result: 0 interpenetration inside a kit.
      const drop = new Set(); for (let a = 0; a < groups.length; a++) for (let b = a + 1; b < groups.length; b++) { let A = groups[a], B = groups[b]; if (A.some(p => drop.has(p)) || B.some(p => drop.has(p))) continue; if (rot(A[0]) < 1e-6 && rot(B[0]) < 1e-6) continue; if (!clash(A, B)) continue;
          const mov = rot(A[0]) >= rot(B[0]) ? A : B, other = mov === A ? B : A; let ok = false; for (let s = 0; s < 24 && !ok; s++) { for (const p of mov) { p.tilt = (p.tilt || 0) * 0.88; p.pitch = (p.pitch || 0) * 0.88; } ok = !clash(mov, other); }
          if (!ok) { const vol = g => g.reduce((q, p) => q + p.w * p.d * (p.h || 0), 0), small = vol(mov) < vol(other) ? mov : other; for (const p of small) drop.add(p); } }
      const kept = drop.size ? parts.filter(p => !drop.has(p)) : parts;
      // Grounding: a part group left hanging (its lowest part above y 0.2 with nothing under it in plan) drops onto the highest surface below it — the ground or another
      // kept part's top (unrotated plan footprints). Was: removed supports left cy_b24 caps floating.
      const KG = new Map(); for (const p of kept) if (solid(p)) { const k = keyOf(p); if (!KG.has(k)) KG.set(k, []); KG.get(k).push(p); }
      for (const g of KG.values()) { const y0 = Math.min(...g.map(p => p.y || 0)); if (y0 <= 0.2) continue; const base = g.filter(p => (p.y || 0) - y0 < 0.05);
        let top = 0; for (const q of kept) { if (g.includes(q) || !solid(q)) continue; const qt = (q.y || 0) + (q.h || 0); if (qt > y0 + 0.05) continue; if (base.some(p => Math.abs(p.x - q.x) < (p.w + q.w) / 2 && Math.abs(p.z - q.z) < (p.d + q.d) / 2)) top = Math.max(top, qt); }
        const dy = y0 - top; if (dy > 0.05) for (const p of g) { p.y = (p.y || 0) - dy; if (p.piv) p.piv = [p.piv[0], p.piv[1] - dy, p.piv[2]]; } }
      return kept; };
    return { atlas, PALS, MOUNDS, KITS: Object.keys(KIT), kit: (id, style, r, opt) => { opt = opt || {}; const v = opt.v; VR = v != null ? srng(v * 7919 + hstr(id)) : () => 0.5; const k = KIT[id](PALS[style] || PALS.buern, r || Math.random, opt); if (/^cy_b/.test(id) && k && k.parts) k.parts = deOverlap(k.parts); const out = v != null && TREES.has(id) ? varyTree(k, v) : k; VR = () => 0.5; return out; }, TREES, core: (style, r) => CORES[style] ? coreGen(PALS[style], r || Math.random, CORES[style], style) : core(PALS[style] || PALS.buern, r || Math.random, style), FOLIAGE, FOLIAGE_ZONES, WATER_SCATTER, CRASH_PILES, CRASH_SPHERE, SUNKEN, PALISADE, GREATWALL, CASTLES, LANDMARKS, ICE_MOUNTAIN, TEMPLES, PALACES: Object.keys(PALACE),
      model: (type, e) => (MODELS[type] ? MODELS[type](e || {}) : []), bridge: () => ({ end: bridgeEnd(), mid: bridgeMid() }), ubridge: () => ({ end: ubridgeEnd(), mid: ubridgeMid() }), rail, fire: () => ({ strip: fireStrip(), fw: 5 }), litWhite: () => litW(), lightRules: () => Object.keys(LIGHT), SCENE_W: 66 };
  }
  // Night glow colour per nation (name substring → colour key); unlisted nations use default.
  const LIGHT_COLORS = { yellow: '#ffd95a', white: '#fff6e6', orange: '#ff8c2e', default: 'yellow', byNation: { Kathaya: 'yellow', Zukei: 'yellow', Aerdis: 'yellow', Aldurstein: 'yellow', Copari: 'yellow', Suorr: 'white', Vaernebo: 'orange', Rossade: 'orange', Buern: 'orange', Cyfrolaef: 'none', Miliim: 'yellow' } };
  root.MercElements = { make, LIGHT_COLORS };
})(typeof window !== 'undefined' ? window : globalThis);
