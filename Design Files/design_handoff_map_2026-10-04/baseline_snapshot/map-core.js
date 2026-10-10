// World map add-on core. Godot: MapView.tscn (Node3D › MeshInstance3D terrain + Camera3D) + MapCamera.gd.
// Terrain is built from map/map-height.png: gray = height (0 black → 1 white). Water (seas + rivers) = pixels of exactly SEA_GRAY (77, #4d4d4d)
// connected to the map edge (flood fill), or transparent pixels. Isolated SEA_GRAY pixels (e.g. a crater rim passing through 77) stay land.
// Camera: fixed 3/4 pitch, no rotation, always CAM_H world units above the terrain under the screen-center point.
// Pan: grab the terrain point under the cursor and keep it under the cursor. Bounds: the look-at point is clamped to the image rect.
(function () {
  if (window.MercMap) return;
  // PLACEHOLDER icon — own atlas icon_sheet/addon_map_ICONS.png (row 0, 16 px cells). Registered into MercIcons so cell16 / tint work.
  const ICONS = {
    menu: [0, { a: '#ffffff', b: '#8a97ad' }, ['................', '................', '.aaaaaaaaaaaaaa.', '.aaaaaaaaaaaaaa.', '.bbbbbbbbbbbbbb.', '................', '................', '.aaaaaaaaaaaaaa.', '.aaaaaaaaaaaaaa.', '.bbbbbbbbbbbbbb.', '................', '................', '.aaaaaaaaaaaaaa.', '.aaaaaaaaaaaaaa.', '.bbbbbbbbbbbbbb.', '................']],
  };
  const K = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  function entry(col, pal, rows) {
    let x0 = 16, y0 = 16, x1 = -1, y1 = -1;
    rows.forEach((r, y) => r.split('').forEach((c, x) => { if (c !== '.') { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); } }));
    const order = []; let px = '';
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) { const c = rows[y][x]; if (c === '.') { px += '.'; continue; } let i = order.indexOf(c); if (i < 0) { order.push(c); i = order.length - 1; } px += K[i]; }
    return [col, 0, x0, y0, x1 - x0 + 1, y1 - y0 + 1, 0, order.map(c => pal[c]).join(','), px];
  }
  const ensureIcons = () => { const M = window.MercIcons; if (!M) return false; Object.entries(ICONS).forEach(([id, [col, pal, rows]]) => { if (!M.data[id]) M.data[id] = entry(col, pal, rows); }); return true; };

  // Terrain constants (MapView @exports)
  const ASSET_V = '2026-10-08z6'; // bump when map images / palettes change (browser cache-bust; Godot: not needed)
  const SRC = 'map/map-height.png?v=' + ASSET_V;
  // Sea padding baked into the images (px) so the painted sea fills the view at the map edges (camera reach: ±x 1.19h, north 0.73h, south 0.43h).
  // MAP coords (camera bounds, readout, lat/long, guild home, party positions, biomeAt / regionAt) = image px − (left, top); playable rect = image − pad.
  const PAD = { left: 800, top: 500, right: 800, bottom: 300 };
  const play = t => ({ x: PAD.left, z: PAD.top, w: t.W - PAD.left - PAD.right, h: t.H - PAD.top - PAD.bottom });
  // Color layers (same size as the height map). Every opaque pixel is exactly one palette color (light/base/dark tone of a class);
  // the class = biome (MercMap.biomeAt). Land layer covers land incl. the bed under rivers; water layer covers sea, lake and river water.
  const COLOR = { land: 'map/map-color-land.png?v=' + ASSET_V, water: 'map/map-color-water.png?v=' + ASSET_V, landPal: 'map/map-color-palette.json?v=' + ASSET_V, waterPal: 'map/map-water-palette.json?v=' + ASSET_V };
  const TONES = ['light', 'base', 'dark'];
  // Political + label layers (same canvas). nations/regions: one flat color per id (JSON lists id, name, color); transparent = none.
  // label points: canvas px + type (capital / city / poi). Names + placeholder_text are PLACEHOLDERS until the label JSON carries them.
  const LAYERS = { nat: 'map/map-nations.png', natJ: 'map/map-nations.json', reg: 'map/map-region.png', regJ: 'map/map-region.json', lbl: 'map/map-label-points.json' };
  const POI_NAME = { capital: 'Capital', city: 'City', poi: 'Point of Interest' };
  function decodeIds(img, list, W, H) {
    const cv = document.createElement('canvas'); cv.width = W; cv.height = H; const g = cv.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0, W, H);
    const d = g.getImageData(0, 0, W, H).data, map = new Map(list.map(e => [parseInt(e.color.slice(1), 16), e.id])), id = new Uint8Array(W * H);
    for (let i = 0, k = 0; i < W * H; i++, k += 4) if (d[k + 3] >= 128) id[i] = map.get((d[k] << 16) | (d[k + 1] << 8) | d[k + 2]) || 0;
    return id;
  }
  // Region label anchor = the region's pixel nearest its centroid (keeps curved rivers / ring-shaped seas anchored on the region itself).
  function anchors(ids, n, W) { const sx = new Float64Array(n + 1), sz = new Float64Array(n + 1), c = new Float64Array(n + 1), N = ids.length;
    for (let i = 0; i < N; i++) { const r = ids[i]; if (!r) continue; sx[r] += i % W; sz[r] += (i / W) | 0; c[r]++; }
    const best = new Float64Array(n + 1).fill(Infinity), bi = new Int32Array(n + 1).fill(-1);
    for (let i = 0; i < N; i++) { const r = ids[i]; if (!r) continue; const dx = i % W - sx[r] / c[r], dz = ((i / W) | 0) - sz[r] / c[r], dd = dx * dx + dz * dz; if (dd < best[r]) { best[r] = dd; bi[r] = i; } }
    return bi; }
  // → code[i] = classId*4 + tone (0 light, 1 base, 2 dark), 255 = transparent. Semi-transparent edge px (α ≥ 128) snap to the nearest palette color.
  function decodeLayer(img, pal, W, H) {
    const cv = document.createElement('canvas'); cv.width = W; cv.height = H; const g = cv.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0, W, H);
    const d = g.getImageData(0, 0, W, H).data, code = new Uint8Array(W * H).fill(255), rgb = new Uint8Array(256 * 3), exact = new Map(), list = [];
    for (const c of pal.classes) TONES.forEach((tn, k) => { const v = parseInt(c[tn].slice(1), 16), id = c.id * 4 + k; exact.set(v, id); list.push([v >> 16, (v >> 8) & 255, v & 255, id]); rgb.set([v >> 16, (v >> 8) & 255, v & 255], id * 3); });
    for (let i = 0; i < W * H; i++) { const k = i * 4; if (d[k + 3] < 128) continue; const v = (d[k] << 16) | (d[k + 1] << 8) | d[k + 2]; let id = exact.get(v);
      if (id === undefined) { let best = 1e9; for (const [r, gg, b, n] of list) { const e = (r - d[k]) ** 2 + (gg - d[k + 1]) ** 2 + (b - d[k + 2]) ** 2; if (e < best) { best = e; id = n; } } exact.set(v, id); }
      code[i] = id; }
    return { code, rgb, classes: pal.classes };
  }
  const GRID = 4;          // source pixels per mesh vertex (4096×2160 → 1025×541 verts); rivers are ~10 px wide
  const SEA_GRAY = 77;     // exact gray that marks seas and rivers
  const WATER_H = SEA_GRAY / 255; // water surface (0..1 of height scale) = the sea gray, so carved river banks meet it; plain land (gray 128) = 0.5
  const SEA_BED = WATER_H - 0.06; // terrain under water sits below the surface; the flat water mesh then cuts a smooth coastline through the banks
  const WATER = [0.086, 0.129, 0.227]; // #16213a
  const VS = `#version 300 es
in vec3 p; in vec3 c; uniform mat4 m; uniform vec2 inv; uniform vec2 cinv; uniform vec4 nl; out vec3 vc; out vec2 uv; out vec2 cuv;
void main(){ vec3 q=p, cc=c; if(cc.x>=0.0){ float n=floor(cc.x*0.5); cc.x-=2.0*n; if(n>0.5){ if(abs(n-nl.x)<0.5) q.y+=nl.y; else if(abs(n-nl.z)<0.5) q.y+=nl.w; } }
  vc=cc; uv=p.xz*inv; cuv=(p.xz+c.yz)*cinv; gl_Position=m*vec4(q,1.0); }`;
  // Nation lift: voxel vertices carry c.x = 2·nation + shade (top verts = owner block's nation, bottom verts of side faces = neighbor's nation).
  // nl = (hovered id, its lift, previously hovered id, its lift) — both eased, so leaving one nation and entering another cross-fade.
  // Color mode (ct = 1, voxel): c = (face shade, uv nudge x, uv nudge z). Side faces nudge half a cell into their own block so they sample its color.
  const FS = `#version 300 es
precision mediump float; in vec3 vc; in vec2 uv; uniform sampler2D riv; uniform vec3 wc; uniform float rk; uniform float ng; uniform float rs; uniform sampler2D col; uniform float ct; uniform sampler2D nt; uniform float hn; uniform float ha; uniform vec3 oc; uniform sampler2D df; uniform vec4 bn; uniform float da; uniform sampler2D rt; uniform vec4 rb; uniform sampler2D sd; uniform float hs; uniform vec2 sp; in vec2 cuv; out vec4 o;
void main(){ if(ct>0.5){ vec3 k = vc.r<0.0 ? wc : texture(col,cuv).rgb*vc.r;
    if(da>0.001 && vc.r>=0.0){ vec4 nd=texture(nt,cuv); if(nd.b>0.5){ float id=nd.a*255.0, br = abs(id-bn.x)<0.5 ? bn.y : (abs(id-bn.z)<0.5 ? bn.w : 0.0); k*=1.0-0.25*da*(1.0-br); } } // dim dry land outside the focused nation by 25 % (water untouched)
    if(hn>0.5 && vc.r>=0.0){ vec4 nq=texture(nt,cuv); float nb=nq.r*255.0;
      if(abs(nb-hn)<0.5){ // smooth glowing rim: df = distance to the nation boundary (½-res px, linear-filtered)
      float d=texture(df,uv).r*16.0, core=1.0-smoothstep(0.3,1.0,d), glow=exp(-d*0.9)*(1.0-core); vec3 c2 = vc.r>0.99 ? oc : oc*(0.55+0.45*vc.r);
      k=mix(k, c2, ha*clamp(core*0.95+glow*0.55,0.0,1.0)); } }
    o=vec4(k*mix(vec3(1.0),vec3(0.3,0.34,0.55),ng),1.0); return; }
  float r=texture(riv,uv).r; o=vec4(mix(vc,wc,rk*smoothstep(0.5-rs,0.5+rs,r))*mix(vec3(1.0),vec3(0.3,0.34,0.55),ng),1.0); }`; // rk = 1 smooth style (mask banks), 0 voxel style (per-block color) // river = soft ½-res mask, thresholded per pixel → smooth banks

  let terrain = null, loading = null;
  // Load profiler: MercMap.prof = { stage: ms } (cumulative). TM(name, fn) times fn.
  const PROF = {}, TM = (k, f) => { const t0 = performance.now(), r = f(); PROF[k] = (PROF[k] || 0) + performance.now() - t0; return r; };
  function load() {
    if (loading) return loading;
    const get = (url, opt) => new Promise((res, rej) => { const img = new Image(); img.onload = () => res(img); img.onerror = () => opt ? res(null) : rej(new Error('Missing ' + url)); img.src = url; });
    const json = url => fetch(url).then(r => r.ok ? r.json() : null).catch(() => null);
    return (loading = Promise.all([get(SRC), get(RIVER_SRC, true), get(COLOR.land, true), get(COLOR.water, true), json(COLOR.landPal), json(COLOR.waterPal),
      get(LAYERS.nat + '?v=' + ASSET_V, true), json(LAYERS.natJ + '?v=' + ASSET_V), get(LAYERS.reg + '?v=' + ASSET_V, true), json(LAYERS.regJ + '?v=' + ASSET_V), json(LAYERS.lbl + '?v=' + ASSET_V), json('map/map-paths-railroad.json?v=' + ASSET_V), json('map/map-elements.json?v=' + ASSET_V), json('map/map-bridges.json?v=' + ASSET_V + 'h'), json('map/map-paths-trade.json?v=' + ASSET_V + 't'), json('map/map-walls.json?v=' + ASSET_V)]).then(([img, rimg, limg, wimg, lpal, wpal, nimg, nj, gimg, gj, lj, rj, ej, bj, tj, wj]) => { PROF.fetch = performance.now(); const tL0 = performance.now();
      const W = img.naturalWidth, H = img.naturalHeight, gw = Math.ceil(W / GRID) + 1, gh = Math.ceil(H / GRID) + 1;
      const cv = document.createElement('canvas'); cv.width = W; cv.height = H;
      const g = cv.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0);
      const src = g.getImageData(0, 0, W, H).data, N = W * H;
      // Full-res water mask: flood fill from every edge pixel through SEA_GRAY / transparent pixels.
      const isW = i => src[i * 4 + 3] < 128 || src[i * 4] === SEA_GRAY, sea = new Uint8Array(N), st = new Int32Array(N); let sp = 0;
      const push = i => { if (!sea[i] && isW(i)) { sea[i] = 1; st[sp++] = i; } };
      for (let x = 0; x < W; x++) { push(x); push((H - 1) * W + x); } for (let y = 0; y < H; y++) { push(y * W); push(y * W + W - 1); }
      while (sp) { const i = st[--sp], x = i % W; if (x > 0) push(i - 1); if (x < W - 1) push(i + 1); if (i >= W) push(i - W); if (i < N - W) push(i + W); }
      const land = limg && lpal ? decodeLayer(limg, lpal, W, H) : null, water = wimg && wpal ? decodeLayer(wimg, wpal, W, H) : null, RW = W >> 1, RH = H >> 1;
      // Rivers: water-color layer (opaque water px on non-sea land) → painted map-rivers.png → auto-detect. ½-res mask = fraction of each 2×2 that is river.
      let riv; if (water) { riv = new Float32Array(RW * RH); for (let y = 0; y < RH; y++) for (let x = 0; x < RW; x++) { const a = 2 * y * W + 2 * x; let n = 0; for (const o of [a, a + 1, a + W, a + W + 1]) if (water.code[o] !== 255 && !sea[o]) n++; riv[y * RW + x] = n / 4; } }
      else riv = rimg ? maskRivers(rimg, sea, W, H) : findRivers(src, sea, W, H);
      // ½-res land height (avg of land px in each 2×2, 0..1) + water count (0..4) for the voxel builder (blocks down to 2 px).
      const h2 = new Float32Array(RW * RH), w2 = new Uint8Array(RW * RH);
      for (let y = 0; y < RH; y++) for (let x = 0; x < RW; x++) { const a = 2 * y * W + 2 * x; let s = 0, n = 0, nw = 0;
        for (const o of [a, a + 1, a + W, a + W + 1]) { if (sea[o]) nw++; else { s += src[o * 4]; n++; } } h2[y * RW + x] = n ? s / n / 255 : WATER_H; w2[y * RW + x] = nw; }
      // Grid: height = 4×4 box average of land pixels (water pixels count as SEA_BED); vertex is wet if the center pixel is sea.
      // River vertices (riv = 1): height = channel bed (min source px within ±4), colored as water; no water surface over them.
      const h = new Float32Array(gw * gh), wet = new Uint8Array(gw * gh), river = new Uint8Array(gw * gh);
      for (let gy = 0; gy < gh; gy++) for (let gx = 0; gx < gw; gx++) {
        const cx = Math.min(W - 1, gx * GRID), cy = Math.min(H - 1, gy * GRID), gi = gy * gw + gx;
        if (sea[cy * W + cx]) { wet[gi] = 1; h[gi] = SEA_BED; continue; }
        let s = 0, n = 0; for (let dy = -1; dy <= 2; dy++) for (let dx = -1; dx <= 2; dx++) { const x = Math.max(0, Math.min(W - 1, cx + dx)), y = Math.max(0, Math.min(H - 1, cy + dy)), j = y * W + x; s += sea[j] ? SEA_BED : Math.max(src[j * 4], 1) / 255; n++; }
        h[gi] = s / n;
        if (riv[Math.min(RH - 1, cy >> 1) * RW + Math.min(RW - 1, cx >> 1)] > 0.3) { river[gi] = 1; let lo = 255; for (let dy = -4; dy <= 4; dy++) for (let dx = -4; dx <= 4; dx++) { const x = Math.max(0, Math.min(W - 1, cx + dx)), y = Math.max(0, Math.min(H - 1, cy + dy)), j = y * W + x; if (!sea[j]) lo = Math.min(lo, src[j * 4]); } h[gi] = Math.min(h[gi], lo / 255); }
      }
      return (terrain = { W, H, gw, gh, sx: W / (gw - 1), sy: H / (gh - 1), h, wet, river, riv, RW, RH, h2, w2, sea, land, water, ...political(nimg, nj, gimg, gj, lj, W, H), walls: wj, rail: railLayer(rj), els: ej, bridgesSrc: bj && bj.bridges, trade: tj && tj.routes ? tj : null, hb: blur(h.map((v, i) => wet[i] ? WATER_H : v), gw, gh, CAM_BLUR) }, PROF.decode = performance.now() - tL0, terrain);
    }));
  }
  function political(nimg, nj, gimg, gj, lj, W, H) {
    const nat = nimg && nj ? decodeIds(nimg, nj.nations, W, H) : null, reg = gimg && gj ? decodeIds(gimg, gj.regions, W, H) : null;
    const natById = {}, regById = {}; (nj ? nj.nations : []).forEach(n => natById[n.id] = n); (gj ? gj.regions : []).forEach(r => regById[r.id] = r);
    const labels = [];
    if (reg) { const n = Math.max(0, ...gj.regions.map(r => r.id)), a = anchors(reg, n, W);
      // Optional manual placement in map-region.json: "label_x" / "label_y" (image px) override the computed anchor.
      for (const r of gj.regions) { const i = r.label_x != null ? r.label_y * W + r.label_x : a[r.id]; if (i < 0) continue; const ix = i % W, iz = (i / W) | 0, na = nat && nat[i] ? natById[nat[i]] : null;
        labels.push({ key: 'r' + r.id, kind: 'region', type: r.volcano ? (r.dormant ? 'dormant volcano' : 'volcano') : r.category, volcano: !!r.volcano, name: r.name, ix, iz, regionId: r.id, region: r.name, nation: na ? na.name : null, placeholder_text: 'Placeholder text.' }); } }
    // Nation labels: floating 2-line title at the nation pixel nearest its centroid. lead = text up to and incl. the first " of " ("Principality of"), title = the rest.
    if (nat) { const n = Math.max(0, ...nj.nations.map(x => x.id)), a = anchors(nat, n, W);
      for (const x of nj.nations) { const i = a[x.id]; if (i < 0) continue; const k = x.name.indexOf(' of '), lead = k > 0 ? x.name.slice(0, k + 3) : '', title = k > 0 ? x.name.slice(k + 4) : x.name;
        labels.push({ key: 'n' + x.id, kind: 'nation', type: 'nation', name: x.name, lead, title, ix: i % W, iz: (i / W) | 0, nationId: x.id, region: null, nation: x.name, placeholder_text: 'Placeholder text.' }); } }
    if (lj) { const cnt = {}; for (const p of lj.points) { cnt[p.type] = (cnt[p.type] || 0) + 1; const i = p.y * W + p.x; let rg = reg && reg[i] ? regById[reg[i]] : null, na = nat && nat[i] ? natById[nat[i]] : null;
        // Label point off-nation (e.g. over water between a town's isles): nearest nation / region px within 48 px (ring search). JSON "nation" / "region" names override.
        if (p.type !== 'water' && nat && !na) { let hit = -1; for (let r = 1; r <= 48 && hit < 0; r++) for (let dz = -r; dz <= r && hit < 0; dz++) for (let dx = -r; dx <= r; dx += (Math.abs(dz) === r ? 1 : 2 * r)) { const x = p.x + dx, z = p.y + dz; if (x < 0 || z < 0 || x >= W || z >= H) continue; const j = z * W + x; if (nat[j]) { hit = j; break; } } if (hit >= 0) { na = natById[nat[hit]]; if (reg && reg[hit]) rg = regById[reg[hit]]; } } // nation + region both from the nearest nation px
        if (p.nation) na = Object.values(natById).find(n => n.name.includes(p.nation)) || na; if (p.region) rg = Object.values(regById).find(r => r.name === p.region) || rg;
      if (p.type === 'water') { labels.push({ key: 'w' + labels.length, kind: 'region', type: p.sub || 'lake', water: true, name: p.name, ix: p.x, iz: p.y, regionId: null, region: null, nation: null }); continue; } // water:lake etc. — text label, no pin
      labels.push({ key: 'p' + labels.length, kind: 'poi', type: p.volcano ? 'volcano' : p.type, volcano: !!p.volcano, name: p.name || (POI_NAME[p.type] || p.type) + ' ' + cnt[p.type], ix: p.x, iz: p.y, region: rg ? rg.name : null, nation: na ? na.name : null, placeholder_text: 'Placeholder text.' }); } }
    // ½-res distance (½-res px, 0..16) to the nearest nation boundary (nation ≠ 4-neighbor, coasts included). Two-pass chamfer (1, √2).
    let natDF = null; if (nat) { const w = W >> 1, h = H >> 1, n2 = new Uint8Array(w * h), D = new Float32Array(w * h).fill(16);
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) n2[y * w + x] = nat[(2 * y) * W + 2 * x];
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x, v = n2[i]; if (!v) continue; if ((x > 0 && n2[i - 1] !== v) || (x < w - 1 && n2[i + 1] !== v) || (y > 0 && n2[i - w] !== v) || (y < h - 1 && n2[i + w] !== v)) D[i] = 0; }
      const S2 = Math.SQRT2;
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x; let d = D[i]; if (x > 0) d = Math.min(d, D[i - 1] + 1); if (y > 0) { d = Math.min(d, D[i - w] + 1); if (x > 0) d = Math.min(d, D[i - w - 1] + S2); if (x < w - 1) d = Math.min(d, D[i - w + 1] + S2); } D[i] = d; }
      for (let y = h - 1; y >= 0; y--) for (let x = w - 1; x >= 0; x--) { const i = y * w + x; let d = D[i]; if (x < w - 1) d = Math.min(d, D[i + 1] + 1); if (y < h - 1) { d = Math.min(d, D[i + w] + 1); if (x < w - 1) d = Math.min(d, D[i + w + 1] + S2); if (x > 0) d = Math.min(d, D[i + w - 1] + S2); } D[i] = d; }
      natDF = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) natDF[i] = Math.min(255, Math.round(D[i] * 16)); }
    return { nat, reg, natById, regById, labels, natDF };
  }
  // Railroad: station graph. Track geometry is built per build() (prepRail → l.p2 / l.z2, buildOverlay → 3D mesh).
  function railLayer(rj) { if (!rj || !rj.lines) return null; const adj = {};
    for (const l of rj.lines) { (adj[l.from] = adj[l.from] || []).push({ to: l.to, len: l.length_px, l, rev: false }); (adj[l.to] = adj[l.to] || []).push({ to: l.from, len: l.length_px, l, rev: true }); }
    return { stations: rj.stations, lines: rj.lines, adj }; }
  // Rail routing (MAP coords in/out). from/to: station name or {x, z} (snapped to the nearest station). → { stations, points [[x, z]…], km } | null
  function railRoute(from, to) { const r = terrain && terrain.rail; if (!r) return null;
    const snap = a => typeof a === 'string' ? a : r.stations.reduce((b, s) => { const dd = Math.hypot(s.x - PAD.left - a.x, s.y - PAD.top - a.z); return dd < b.d ? { d: dd, n: s.name } : b; }, { d: 1e9, n: null }).n;
    const A = snap(from), B = snap(to); if (!A || !B || !r.adj[A] || !r.adj[B]) return null; const dist = { [A]: 0 }, prev = {}, done = new Set();
    while (true) { let u = null; for (const k in dist) if (!done.has(k) && (u === null || dist[k] < dist[u])) u = k; if (u === null || u === B) break; done.add(u);
      for (const e of r.adj[u]) { const nd = dist[u] + e.len; if (dist[e.to] === undefined || nd < dist[e.to]) { dist[e.to] = nd; prev[e.to] = { u, e }; } } }
    if (dist[B] === undefined) return null; const st = [B], segs = []; for (let k = B; k !== A; k = prev[k].u) { { const e = prev[k].e, p = e.l.p2 || e.l.points; segs.unshift(e.rev ? [...p].reverse() : p); } st.unshift(prev[k].u); }
    const pts = []; for (const s of segs) for (const [x, y] of s) pts.push([x - PAD.left, y - PAD.top]); return { stations: st, points: pts, km: Math.round(dist[B]) }; }
  // Painted river mask (preferred). Same size as the height map; white (R ≥ 128) = river incl. headwaters / snow-melt / waterfalls, black = none.
  // If the file is missing, rivers are auto-detected (findRivers). Returns the same ½-res soft mask as findRivers.
  const RIVER_SRC = 'map/map-rivers.png';
  function maskRivers(img, seaF, W0, H0) {
    const cv = document.createElement('canvas'); cv.width = W0; cv.height = H0; const g = cv.getContext('2d', { willReadFrequently: true }); g.drawImage(img, 0, 0, W0, H0);
    const d = g.getImageData(0, 0, W0, H0).data, W = W0 >> 1, H = H0 >> 1, N = W * H; let f = new Float32Array(N), t = new Float32Array(N);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const a = 2 * y * W0 + 2 * x; let s = 0; for (const o of [a, a + 1, a + W0, a + W0 + 1]) s += (d[o * 4 + 3] > 127 && d[o * 4] >= 128 && !seaF[o]) ? 1 : 0; f[y * W + x] = s / 4; }
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let s = 0; for (let dx = -1; dx <= 1; dx++) s += f[y * W + Math.max(0, Math.min(W - 1, x + dx))]; t[y * W + x] = s / 3; }
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let s = 0; for (let dy = -1; dy <= 1; dy++) s += t[Math.max(0, Math.min(H - 1, y + dy)) * W + x]; f[y * W + x] = s / 3; }
    return f;
  }
  // Auto-detected rivers (used when map/map-rivers.png is absent). Runs at ½ res. Tuned for the posterized/dithered height map.
  //  1. s = height smoothed (box r=2, ×2) to remove dithering + terrace steps; channel depth D = blur(s, r=6 ×2) − s.
  //  2. Candidate = non-sea pixel with D ≥ depth (a narrow trough below its surroundings — rivers, snow-melt gullies, but also hill-base rings).
  //  3. Trace upstream from the sea: BFS from candidates touching the sea through 8-connected candidates whose smoothed height never drops
  //     by more than tol (water flows downhill, so going upstream the bed only rises). The crater/trench never connects (they dip below).
  //  4. Keep only paths whose upstream tip is ≥ minLen px from the sea (backtrack tip → mouth), plus traced pixels attached to them that are
  //     not on the coastal fringe (within coast px of sea). Drops coastline noise and isolated hill rings.
  //  5. Dilate 1, blur 2× (3×3) → soft mask 0..1 (≥ 0.5 = river), uploaded as a linear texture.
  const RIV = { smooth: 2, wide: 6, depth: 2.0, tol: 1.0, minLen: 90, coast: 4 };
  function findRivers(src, seaF, W0, H0) {
    const W = W0 >> 1, H = H0 >> 1, N = W * H, v = new Float32Array(N), sea = new Uint8Array(N), q = new Int32Array(N);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const a = 2 * y * W0 + 2 * x, i = y * W + x; v[i] = (src[a * 4] + src[(a + 1) * 4] + src[(a + W0) * 4] + src[(a + W0 + 1) * 4]) / 4; sea[i] = seaF[a] & seaF[a + W0 + 1]; }
    const box = (f, r) => { const a = Float32Array.from(f), b = new Float32Array(N);
      for (let y = 0; y < H; y++) { let s = 0; const row = y * W, at = x => a[row + Math.max(0, Math.min(W - 1, x))]; for (let x = -r; x <= r; x++) s += at(x); for (let x = 0; x < W; x++) { b[row + x] = s / (2 * r + 1); s += at(x + r + 1) - at(x - r); } }
      for (let x = 0; x < W; x++) { let s = 0; const at = y => b[Math.max(0, Math.min(H - 1, y)) * W + x]; for (let y = -r; y <= r; y++) s += at(y); for (let y = 0; y < H; y++) { a[y * W + x] = s / (2 * r + 1); s += at(y + r + 1) - at(y - r); } }
      return a; };
    const s = box(box(v, RIV.smooth), RIV.smooth), big = box(box(s, RIV.wide), RIV.wide), nearSea = box(Float32Array.from(sea), RIV.coast);
    const cand = new Uint8Array(N); for (let i = 0; i < N; i++) if (!sea[i] && big[i] - s[i] >= RIV.depth) cand[i] = 1;
    const par = new Int32Array(N).fill(-2), dist = new Int32Array(N); let qh = 0, qt = 0;
    for (let i = 2 * W; i < N - 2 * W; i++) if (cand[i]) { for (const o of [-1, 1, -W, W, -2, 2, -2 * W, 2 * W]) if (sea[i + o]) { par[i] = -1; q[qt++] = i; break; } }
    const nb = (i, f) => { const x = i % W, y = (i / W) | 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx, yy = y + dy; if (xx >= 0 && yy >= 0 && xx < W && yy < H) f(yy * W + xx); } };
    while (qh < qt) { const i = q[qh++]; nb(i, j => { if (cand[j] && par[j] === -2 && s[j] >= s[i] - RIV.tol) { par[j] = i; dist[j] = dist[i] + 1; q[qt++] = j; } }); }
    const mark = new Uint8Array(N); for (let i = 0; i < N; i++) if (par[i] !== -2 && dist[i] >= RIV.minLen) { let k = i; while (k >= 0 && !mark[k]) { mark[k] = 1; k = par[k]; } }
    const keep = new Uint8Array(N); qh = qt = 0; for (let i = 0; i < N; i++) if (mark[i]) { keep[i] = 1; q[qt++] = i; }
    while (qh < qt) { const i = q[qh++]; nb(i, j => { if (!keep[j] && par[j] !== -2 && (mark[i] || nearSea[j] === 0)) { keep[j] = 1; q[qt++] = j; } }); }
    let f = new Float32Array(N); for (let i = 0; i < N; i++) if (keep[i]) nb(i, j => { if (!sea[j]) f[j] = 1; });
    const t = new Float32Array(N);
    for (let k = 0; k < 2; k++) { for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let s = 0; for (let dx = -1; dx <= 1; dx++) s += f[y * W + Math.max(0, Math.min(W - 1, x + dx))]; t[y * W + x] = s / 3; }
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let s = 0; for (let dy = -1; dy <= 1; dy++) s += t[Math.max(0, Math.min(H - 1, y + dy)) * W + x]; f[y * W + x] = s / 3; } }
    return f;
  }
  // Camera height reference = terrain blurred over CAM_BLUR grid cells (3 separable box passes ≈ gaussian), so small bumps never move the camera.
  const CAM_BLUR = 24;
  function blur(src, w, h, r) { let a = Float32Array.from(src), b = new Float32Array(a.length);
    const pass = (from, to, len, cnt, stride, step) => { for (let l = 0; l < cnt; l++) { const base = l * stride; let s = 0; const at = i => from[base + Math.max(0, Math.min(len - 1, i)) * step];
      for (let i = -r; i <= r; i++) s += at(i); for (let i = 0; i < len; i++) { to[base + i * step] = s / (2 * r + 1); s += at(i + r + 1) - at(i - r); } } };
    for (let k = 0; k < 3; k++) { pass(a, b, w, h, w, 1); pass(b, a, h, w, 1, w); } return a; }
  // Height (0..1) at image-pixel coords, bilinear. Outside the image = water. field defaults to the raw terrain.
  function sample(t, x, y, f) { f = f || t.h;
    const fx = x / t.sx, fy = y / t.sy; if (fx < 0 || fy < 0 || fx > t.gw - 1 || fy > t.gh - 1) return WATER_H;
    const x0 = Math.min(t.gw - 2, Math.floor(fx)), y0 = Math.min(t.gh - 2, Math.floor(fy)), ax = fx - x0, ay = fy - y0, i = y0 * t.gw + x0;
    return (f[i] * (1 - ax) + f[i + 1] * ax) * (1 - ay) + (f[i + t.gw] * (1 - ax) + f[i + t.gw + 1] * ax) * ay;
  }

  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]], cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; }, dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  function persp(fov, asp, n, f) { const t = 1 / Math.tan(fov / 2); return [t / asp, 0, 0, 0, 0, t, 0, 0, 0, 0, (f + n) / (n - f), -1, 0, 0, 2 * f * n / (n - f), 0]; }
  function view(eye, fw, up, rt) { return [rt[0], up[0], -fw[0], 0, rt[1], up[1], -fw[1], 0, rt[2], up[2], -fw[2], 0, -dot(rt, eye), -dot(up, eye), dot(fw, eye), 1]; }
  function mul(a, b) { const o = new Array(16); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) { let s = 0; for (let k = 0; k < 4; k++) s += a[k * 4 + r] * b[c * 4 + k]; o[c * 4 + r] = s; } return o; }

  // mount(canvas, opts) → { set(opts), center(), destroy() }. opts: locked, camHeight (height at zoom 1× = furthest), zoom (start), zoomMin/Max/Step, heightSmooth (s), pitch (deg), fov (deg), heightScale, pixelScale, onReady
  function mount(canvas, opts) {
    let o = { locked: false, camHeight: 520, zoom: 1.5, zoomMin: 1, zoomMax: 2, zoomStep: 0.25, heightSmooth: 0.9, pitch: 55, fov: 40, heightScale: 160, pixelScale: 2, style: 'voxel', voxel: 2, ...opts }, dead = false, raf = 0, drag = null;
    const gl = canvas.getContext('webgl2', { antialias: false, preserveDrawingBuffer: true }); if (!gl) { if (o.onError) o.onError('WebGL2 unavailable'); return { set() {}, destroy() {} }; }
    const sh = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.error('MercMap shader: ' + gl.getShaderInfoLog(s)); return s; };
    const prog = gl.createProgram(); gl.attachShader(prog, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FS)); gl.linkProgram(prog);
    const uNg = gl.getUniformLocation(prog, 'ng'), uSd = gl.getUniformLocation(prog, 'sd'), uHs = gl.getUniformLocation(prog, 'hs'), uSp = gl.getUniformLocation(prog, 'sp'); let hotNat = 0, hotSid = 0, sidTex = null;
    const uInv = gl.getUniformLocation(prog, 'inv'), uRiv = gl.getUniformLocation(prog, 'riv'), uWc = gl.getUniformLocation(prog, 'wc'), uRk = gl.getUniformLocation(prog, 'rk'), uCol = gl.getUniformLocation(prog, 'col'), uCt = gl.getUniformLocation(prog, 'ct'), uCinv = gl.getUniformLocation(prog, 'cinv'), uRs = gl.getUniformLocation(prog, 'rs'), uNl = gl.getUniformLocation(prog, 'nl'), uNt = gl.getUniformLocation(prog, 'nt'), uHn = gl.getUniformLocation(prog, 'hn'), uHa = gl.getUniformLocation(prog, 'ha'), uOc = gl.getUniformLocation(prog, 'oc'), uBn = gl.getUniformLocation(prog, 'bn'), uRt = gl.getUniformLocation(prog, 'rt'), uRb = gl.getUniformLocation(prog, 'rb'), uDa = gl.getUniformLocation(prog, 'da'), uDf = gl.getUniformLocation(prog, 'df'); let dfTex = null; let natTex = null, railTex = null; let rivTex = null, colTex = null, useColor = false, colInv = [0, 0], deepCol = WATER;
    const uM = gl.getUniformLocation(prog, 'm'), aP = gl.getAttribLocation(prog, 'p'), aC = gl.getAttribLocation(prog, 'c');
    let t = null, nIdx = 0, vbo = null, ibo = null, builtScale = 0, builtKey = '';
    // Overlay program (railroad mesh + map-element sprites): flat vertex color or sprite texel (alpha-tested), same nation lift + dimming as terrain.
    // Vertex: p(3) c(3) a(4) = (lift nation, dim nation, u, v); u < 0 → untextured.
    const VS2 = `#version 300 es
in vec3 p; in vec3 c; in vec4 a; uniform mat4 m; uniform vec4 nl; out vec3 vc; out vec2 tu; out float n0; out vec2 wq; flat out float gn;
void main(){ vec3 q=p; wq=p.xz; float n=a.x; float gq=floor(n/32.0+0.001); gn=n-gq*32.0; if(n>0.5){ float n2=floor(n/32.0+0.001), n1=n-n2*32.0; if(abs(n1-nl.x)<0.5||(n2>0.5&&abs(n2-nl.x)<0.5)) q.y+=nl.y; else if(abs(n1-nl.z)<0.5||(n2>0.5&&abs(n2-nl.z)<0.5)) q.y+=nl.w; } vc=c; n0=a.y; tu=a.zw; gl_Position=m*vec4(q,1.0); }`;
    const FS2 = `#version 300 es
precision mediump float; in vec3 vc; in vec2 tu; in float n0; in vec2 wq; uniform sampler2D st; uniform vec4 bn; uniform float da; uniform sampler2D sd; uniform float hs; uniform vec2 si; flat in float gn; uniform sampler2D gt; uniform float ng; uniform float tm; uniform vec3 gc[12]; uniform vec3 hc; out vec4 o;
void main(){ if(vc.r>50.0){ if(ng<0.5) discard; /* fires (torches, braziers, campfires) only burn at night */ float f=mod(floor(tm*6.0+vc.r),4.0); vec4 s=texture(st,vec2(tu.x+f*vc.g,tu.y)); if(s.a<0.5) discard; o=vec4(s.rgb,1.0); return; } // fire: animated frame, always full bright
  vec3 k=abs(vc); float lm=0.0; if(tu.x>=0.0){ vec4 s=texture(st,tu); if(s.a<0.5) discard; k=s.rgb*abs(vc); lm=vc.b<0.0?0.0:texture(gt,tu).a; }
  if(hs>0.5 && abs(texture(sd,wq*si).r*255.0-hs)<0.5) k=mix(k,hc,0.42)*1.12; // hovered settlement: only its buildings tint, in its nation's highlight colour (hc; terrain untouched)
  float m2=floor(n0/32.0+0.001), m1=n0-m2*32.0; bool hx=abs(m1-bn.x)<0.5||(m2>0.5&&abs(m2-bn.x)<0.5), hz=abs(m1-bn.z)<0.5||(m2>0.5&&abs(m2-bn.z)<0.5);
  float br = hx ? bn.y : (hz ? bn.w : 0.0); k*=1.0-0.25*da*(1.0-br); k*=mix(vec3(1.0),vec3(0.3,0.34,0.55),ng); if(ng>0.5&&lm>0.5){ vec3 g2=gc[int(clamp(gn+0.5,0.0,11.0))]; if(g2.r>=0.0) k=g2; } o=vec4(k,1.0); }`; // nation ids may be a pair a + 32·b (bridges across a border lift / brighten with either nation)
    const prog2 = gl.createProgram(); gl.attachShader(prog2, sh(gl.VERTEX_SHADER, VS2)); gl.attachShader(prog2, sh(gl.FRAGMENT_SHADER, FS2)); gl.linkProgram(prog2);
    const u2 = k => gl.getUniformLocation(prog2, k), u2M = u2('m'), u2Nl = u2('nl'), u2Bn = u2('bn'), u2Da = u2('da'), u2St = u2('st'), u2Sd = u2('sd'), u2Hs = u2('hs'), u2Si = u2('si'), u2Gt = u2('gt'), u2Ng = u2('ng'), u2Tm = u2('tm'), u2Gc = u2('gc'), u2Hc = u2('hc');
    const a2 = [gl.getAttribLocation(prog2, 'p'), gl.getAttribLocation(prog2, 'c'), gl.getAttribLocation(prog2, 'a')];
    let vbo2 = null, ibo2 = null, n2 = 0, spTex = null, glTex = null, GCOL = null, FIRE = null, ovKey = '';
    // Night glow colours per nation id (0–11) from MercElements.LIGHT_COLORS.
    const mkGcol = () => { const LC = (window.MercElements || {}).LIGHT_COLORS, out = new Float32Array(36); if (!LC) return out; for (let id = 0; id < 12; id++) { const nm = (t.natById && t.natById[id] && t.natById[id].name) || '', key = Object.keys(LC.byNation).find(k => nm.includes(k)), ck = (key && LC.byNation[key]) || LC.default, hx = LC[ck]; for (let q = 0; q < 3; q++) out[id * 3 + q] = ck === 'none' || !hx ? -1 : parseInt(hx.slice(1 + q * 2, 3 + q * 2), 16) / 255; } /* 'none' (Cyfrolaef) → −1 = never glows */ return out; };
    const okey = () => o.heightScale + '|' + o.style + o.voxel + '|' + o.pitch + '|' + (window.MercElements ? 1 : 0);
    const cam = { x: 0, z: 0 }; // look-at point in image pixels (x = column, z = row)

    // 3D pixel-art style: the map becomes flat-topped blocks (voxel × voxel source px), heights snapped to TERRACE steps,
    // flat per-face shading (top / south / east / west), no smoothing. Water + river blocks are flat #16213a. Rendered at low res, nearest upscale.
    const TERRACE = 10.5 / 255; // matches the posterized height map's level spacing
    // Trails (2026-10-07): carved TR_CARVE terrace into the block top; colour = biome recipe (TR_REC[group]: T = trail surface, a / ar = mix of land → T for dirt / ruts, rd = rut darkening, wet = puddles).
    const TR_CARVE = 0.15, TR_GRP = (name => /snow|ice/i.test(name) ? 4 : /sand|beach/i.test(name) ? 2 : /rock|stony/i.test(name) ? 3 : /mud/i.test(name) ? 5 : /magma|lava/i.test(name) ? 6 : /dry|wheat/i.test(name) ? 1 : 0), TR_REC = [{ T: [134, 104, 70], a: 0.86, ar: 0.96, rd: 0.8, wet: 1 }, { T: [160, 128, 84], a: 0.84, ar: 0.94, rd: 0.8 }, { a: 1, ar: 1, rd: 0.86 }, { a: 1, ar: 1, rd: 0.8 }, { T: [184, 182, 180], a: 0.85, ar: 0.92, rd: 0.8, wet: 1 }, { a: 1, ar: 1, rd: 0.76, wet: 1 }, { T: [70, 58, 54], a: 0.8, ar: 0.85, rd: 0.8 }];
    const trSurf = (g, L, dk) => dk ? [72, 60, 54] : g === 2 ? [L[0] * 0.84 + 10, L[1] * 0.8 + 6, L[2] * 0.74] : g === 3 ? [L[0] * 0.5 + 84, L[1] * 0.5 + 79, L[2] * 0.5 + 70] : g === 5 ? [L[0] * 0.82, L[1] * 0.8, L[2] * 0.78] : TR_REC[g].T;
    function buildVoxel() {
      // Cells of v2 × v2 half-res px (block = voxel source px, min 2). Faces are run-merged (same height + same neighbor along a row/column)
      // so 2 px blocks stay within GPU budget.
      const { RW, RH, h2, w2, riv } = t, pm = t.pondMask, pp = t.paint, TRS = t.trailCodes && pp ? new Set(Object.values(t.trailCodes)) : null, hs = o.heightScale, v2 = Math.max(1, Math.round(o.voxel / 2)), cw = Math.ceil(RW / v2), ch = Math.ceil(RH / v2), cs = 2 * v2;
      const top = new Float32Array(cw * ch), kind = new Uint8Array(cw * ch); // 0 land, 1 sea, 2 river
      for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) { let s = 0, n = 0, nw = 0, nr = 0, np = 0, ntr = 0;
        for (let y = cy * v2; y < Math.min(RH, cy * v2 + v2); y++) for (let x = cx * v2; x < Math.min(RW, cx * v2 + v2); x++) { const i = y * RW + x; n += 4; nw += w2[i]; s += h2[i] * (4 - w2[i]); if (riv[i] >= 0.5) nr++; if (pm && pm[i]) np++; if (TRS && TRS.has(pp[i])) ntr++; }
        const ci = cy * cw + cx; if (nw * 2 >= n) { kind[ci] = 1; top[ci] = WATER_H; continue; }
        const hv = s / (n - nw);
        const cix = Math.min(t.W - 1, cx * cs + (cs >> 1)), ciy = Math.min(t.H - 1, cy * cs + (cs >> 1)), wcol = !!(t.land && t.water) && t.land.code[ciy * t.W + cix] === 255 && t.water.code[ciy * t.W + cix] !== 255; // colour layer says water
        if (nr * 2 >= n / 4 || wcol) { kind[ci] = 2; top[ci] = Math.max(WATER_H, Math.floor(hv / TERRACE) * TERRACE - TERRACE); continue; }
        top[ci] = Math.max(WATER_H + TERRACE, Math.round(hv / TERRACE) * TERRACE) - (np * 8 >= n ? 0.3 * TERRACE : ntr * 8 >= n ? TR_CARVE * TERRACE : 0); } // ponds: inset 0.3 terrace; trails: carved TR_CARVE terrace
      // Per-block color texture (cw × ch, NEAREST): one palette color per block, from the block's center source px (or its first opaque px).
      // Sea/river blocks use the water layer, land blocks the land layer; each falls back to the other layer, then to gray/#16213a.
      const colored = !!(t.land && t.water); useColor = colored; let NB = new Uint8Array(cw * ch);
      if (colored) { const px = new Uint8Array(cw * ch * 4), half = cs >> 1, TCo = t.paint && t.trailCodes, TRK = TCo ? new Int8Array(cw * ch).fill(-1) : null, LC = TCo ? new Uint8Array(cw * ch).fill(255) : null, PO = TCo ? new Uint8Array(cw * ch) : null, TRI = {};
        if (TCo) [TCo.dirt, TCo.rut, TCo.stone, TCo.grass, TCo.ddirt, TCo.drut].forEach((v, k) => { TRI[v] = k; }); const TGR = new Uint8Array(64); for (const q of ((t.land && t.land.classes) || [])) TGR[q.id] = TR_GRP(q.name);
        // Priority land classes (Magma): if any px of the block has one, the block takes it, so 1–2 px volcano vents stay visible at any block size.
        const prio = new Set((t.land.classes || []).filter(c => /magma|lava/i.test(c.name)).flatMap(c => [c.id * 4, c.id * 4 + 1, c.id * 4 + 2]));
        const pick = (L, cx, cy) => { const x0 = cx * cs, y0 = cy * cs;
          if (L === t.land && prio.size) for (let y = y0; y < Math.min(t.H, y0 + cs); y++) for (let x = x0; x < Math.min(t.W, x0 + cs); x++) { const c = L.code[y * t.W + x]; if (prio.has(c)) return c; }
          const c0 = L.code[Math.min(t.H - 1, y0 + half) * t.W + Math.min(t.W - 1, x0 + half)]; if (c0 !== 255) return c0;
          for (let y = y0; y < Math.min(t.H, y0 + cs); y++) for (let x = x0; x < Math.min(t.W, x0 + cs); x++) { const c = L.code[y * t.W + x]; if (c !== 255) return c; } return 255; };
        for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) { const ci = cy * cw + cx, wl = kind[ci] ? [t.water, t.land] : [t.land, t.water]; let rgb = null, lc = 255;
          for (const L of wl) { const c = pick(L, cx, cy); if (c !== 255) { rgb = [L.rgb[c * 3], L.rgb[c * 3 + 1], L.rgb[c * 3 + 2]]; if (L === t.land) lc = c >> 2; break; } }
          if (!rgb) rgb = kind[ci] ? WATER.map(v => v * 255) : [128, 128, 124];
          if (t.paint && !kind[ci]) { const pc = t.paint[Math.min(RH - 1, (cy * cs + half) >> 1) * RW + Math.min(RW - 1, (cx * cs + half) >> 1)]; if (pc && TRK && TRI[pc] != null) { TRK[ci] = TRI[pc]; LC[ci] = lc; } else if (pc) { rgb = t.paintCols[pc][(cx * 7 + cy * 13) % 5 === 0 ? 1 : 0]; if (PO) PO[ci] = 1; } } // settlement streets / plazas; trails → post pass
          px.set([rgb[0], rgb[1], rgb[2], 255], ci * 4); }
        if (TRK) { // trail post pass: biome surface → 7×7 blur over trail blocks (smooth biome change) + Bayer-dithered blend of own / blurred → ruts (broken, puddles), pebbles, hoofprints → dithered edge fade into the ground (2 blocks)
          const N2 = cw * ch, TT = new Float32Array(N2 * 3), BT = new Float32Array(N2 * 3), FIN = new Float32Array(N2 * 3), tr = [], BAY = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
          const hb = (a, b) => { let h = Math.imul(a | 0, 73856093) ^ Math.imul(b | 0, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }, mx = (A, B, f) => [A[0] + (B[0] - A[0]) * f, A[1] + (B[1] - A[1]) * f, A[2] + (B[2] - A[2]) * f], ml = (A, f) => [A[0] * f, A[1] * f, A[2] * f];
          const LL = ci => [px[ci * 4], px[ci * 4 + 1], px[ci * 4 + 2]], grp = ci => LC[ci] !== 255 ? TGR[LC[ci]] : 0;
          for (let ci = 0; ci < N2; ci++) if (TRK[ci] >= 0) { tr.push(ci); TT.set(trSurf(grp(ci), LL(ci), TRK[ci] >= 4), ci * 3); }
          for (const ci of tr) { const cx = ci % cw, cy = (ci / cw) | 0; let r = 0, g = 0, b = 0, k = 0; for (let dy = -3; dy <= 3; dy++) { const y = cy + dy; if (y < 0 || y >= ch) continue; for (let dx = -3; dx <= 3; dx++) { const x = cx + dx; if (x < 0 || x >= cw) continue; const cj = y * cw + x; if (TRK[cj] < 0 || (TRK[cj] >= 4) !== (TRK[ci] >= 4)) continue; r += TT[cj * 3]; g += TT[cj * 3 + 1]; b += TT[cj * 3 + 2]; k++; } } BT[ci * 3] = r / k; BT[ci * 3 + 1] = g / k; BT[ci * 3 + 2] = b / k; }
          for (const ci of tr) { const cx = ci % cw, cy = (ci / cw) | 0, kd = TRK[ci], g = kd >= 4 ? 6 : grp(ci), REC = TR_REC[g], L = LL(ci), h = hb(cx, cy), rut = kd === 1 || kd === 5;
            let T = [BT[ci * 3], BT[ci * 3 + 1], BT[ci * 3 + 2]]; if (BAY[(cy & 3) * 4 + (cx & 3)] < 8) T = mx(T, [TT[ci * 3], TT[ci * 3 + 1], TT[ci * 3 + 2]], 0.5);
            let k = mx(L, T, rut ? REC.ar : kd === 3 ? 0.3 : REC.a);
            if (rut) { if (h < 0.2) k = mx(L, T, REC.a); else { k = ml(k, REC.rd); if (REC.wet && h > 0.975) k = mx(k, [92, 112, 124], 0.55); } }
            else if (kd === 2 || h < 0.06) k = ml(k, 1.12); else if (h < 0.11) k = ml(k, 0.86);
            FIN.set(ml(k, 0.96 + hb(cx + 71, cy + 13) * 0.08), ci * 3); }
          const land = cj => !kind[cj] && TRK[cj] < 0 && !PO[cj], best = new Uint8Array(N2), src = new Int32Array(N2);
          for (const ci of tr) { const cx = ci % cw, cy = (ci / cw) | 0; let edge = false;
            for (let dy = -2; dy <= 2; dy++) { const y = cy + dy; if (y < 0 || y >= ch) continue; for (let dx = -2; dx <= 2; dx++) { const x = cx + dx; if (x < 0 || x >= cw) continue; const cj = y * cw + x; if (!land(cj)) continue; const d = Math.max(Math.abs(dx), Math.abs(dy)); if (d === 1 && (dx === 0 || dy === 0)) edge = true; if (!best[cj] || d < best[cj]) { best[cj] = d; src[cj] = ci; } } }
            if (edge && hb(cx + 5, cy + 3) < 0.3) FIN.set(mx([FIN[ci * 3], FIN[ci * 3 + 1], FIN[ci * 3 + 2]], LL(ci), 0.45), ci * 3); }
          for (let cj = 0; cj < N2; cj++) { if (!best[cj]) continue; const s = src[cj], C = [FIN[s * 3], FIN[s * 3 + 1], FIN[s * 3 + 2]], h = hb((cj % cw) + 5, ((cj / cw) | 0) + 9), d = best[cj]; let f = 0;
            if (d === 1) f = h < 0.45 ? 0.42 : h < 0.65 ? 0.18 : 0; else f = h < 0.2 ? 0.26 : 0; if (f) { const k = mx(LL(cj), C, f); px[cj * 4] = k[0]; px[cj * 4 + 1] = k[1]; px[cj * 4 + 2] = k[2]; } }
          for (const ci of tr) { px[ci * 4] = Math.min(255, FIN[ci * 3]); px[ci * 4 + 1] = Math.min(255, FIN[ci * 3 + 1]); px[ci * 4 + 2] = Math.min(255, FIN[ci * 3 + 2]); } }
        colTex = colTex || gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, colTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, cw, ch, 0, gl.RGBA, gl.UNSIGNED_BYTE, px);
        for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
        // Per-block nation (R) + border flag (G, unused by the glow rim). Sea / lake blocks = 0 (never lift).
        // River blocks count as their nation even where the river is at sea level (flood-filled as water), so channels lift with the land and
        // never form an inner border; open sea / lakes have no nation in the nations layer → 0.
        NB = new Uint8Array(cw * ch); if (t.nat) for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) { const ci = cy * cw + cx;
          const x0 = cx * cs, y0 = cy * cs; let v = t.nat[Math.min(t.H - 1, y0 + half) * t.W + Math.min(t.W - 1, x0 + half)];
          if (!v) for (let y = y0; y < Math.min(t.H, y0 + cs) && !v; y++) for (let x = x0; x < Math.min(t.W, x0 + cs); x++) { v = t.nat[y * t.W + x]; if (v) break; } NB[ci] = v; }
        // Islets: only a nation's main landmass lifts / outlines. 4-connected same-nation block components smaller than
        // max(ISLET_MIN, 3 % of that nation's largest component) get NB = 0 (still report the nation on hover, just stay flat).
        const NB0 = NB.slice(); // nation before islet removal (for dimming)
        { const ISLET_MIN = 400, lab = new Int32Array(cw * ch), q = new Int32Array(cw * ch), sizes = [0], owner = [0], big = {}; let L = 0;
          for (let s = 0; s < cw * ch; s++) { if (!NB[s] || lab[s]) continue; const v = NB[s]; L++; let qh = 0, qt = 0; q[qt++] = s; lab[s] = L;
            while (qh < qt) { const i = q[qh++], x = i % cw; for (const j of [x > 0 ? i - 1 : -1, x < cw - 1 ? i + 1 : -1, i - cw, i + cw]) if (j >= 0 && j < cw * ch && !lab[j] && NB[j] === v) { lab[j] = L; q[qt++] = j; } }
            sizes[L] = qt; owner[L] = v; big[v] = Math.max(big[v] || 0, qt); }
          // Bridges join components (same nation): an isle chain bridged to the mainland lifts with it. Union-find over labels; size = sum of the joined parts.
          const par = sizes.map((_, k) => k), fd = k => { while (par[k] !== k) k = par[k] = par[par[k]]; return k; }, labAt = (x, z) => { const bx = (x / cs) | 0, bz = (z / cs) | 0; for (let r = 0; r <= 3; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) { const xx = bx + dx, zz = bz + dz; if (xx < 0 || zz < 0 || xx >= cw || zz >= ch) continue; const l = lab[zz * cw + xx]; if (l) return l; } return 0; };
          for (const b of (t.bridgesSrc || [])) { if (!b.a || !b.b) continue; const la = labAt(b.a[0], b.a[1]), lb = labAt(b.b[0], b.b[1]); if (la && lb && owner[la] === owner[lb]) par[fd(la)] = fd(lb); }
          const tot = new Float64Array(sizes.length); for (let k = 1; k < sizes.length; k++) tot[fd(k)] += sizes[k]; for (const v in big) big[v] = 0; for (let k = 1; k < sizes.length; k++) if (fd(k) === k) big[owner[k]] = Math.max(big[owner[k]], tot[k]);
          for (let i = 0; i < cw * ch; i++) if (lab[i] && tot[fd(lab[i])] < Math.max(ISLET_MIN, 0.03 * big[owner[lab[i]]])) NB[i] = 0; }
        const npx = new Uint8Array(cw * ch * 4); for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) { const ci = cy * cw + cx, v = NB[ci]; if (!v) continue;
          const b = (cx > 0 && NB[ci - 1] !== v) || (cx < cw - 1 && NB[ci + 1] !== v) || (cy > 0 && NB[ci - cw] !== v) || (cy < ch - 1 && NB[ci + cw] !== v) || cx === 0 || cy === 0 || cx === cw - 1 || cy === ch - 1;
          npx[ci * 4] = v; npx[ci * 4 + 1] = b ? 255 : 0; npx[ci * 4 + 3] = 255; }
        for (let ci = 0; ci < cw * ch; ci++) { npx[ci * 4 + 2] = kind[ci] === 0 ? 255 : 0; npx[ci * 4 + 3] = NB0[ci]; } // B = dry land, A = nation incl. islets
        t.nb = { NB, NB0, cw, ch, cs };
        if (t.natDF && !dfTex) { dfTex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, dfTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1); gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, t.W >> 1, t.H >> 1, 0, gl.RED, gl.UNSIGNED_BYTE, t.natDF);
          for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.LINEAR], [gl.TEXTURE_MAG_FILTER, gl.LINEAR], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v); }
        natTex = natTex || gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, natTex); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, cw, ch, 0, gl.RGBA, gl.UNSIGNED_BYTE, npx);
        for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v);
        colInv = [1 / (cw * cs), 1 / (ch * cs)]; const dd = t.water.rgb; deepCol = [dd[1 * 3] / 255, dd[1 * 3 + 1] / 255, dd[1 * 3 + 2] / 255]; } // Deep sea base (class 0 tone 1) for the off-map sea
      const hc = cs / 2, FACE = { top: [1, 0, 0], s: [0.62, 0, -hc], n: [0.45, 0, hc], e: [0.5, -hc, 0], w: [0.78, hc, 0] };
      let cap = 1 << 20, V = new Float32Array(cap * 24), I = new Uint32Array(cap * 6), nq = 0;
      // p0, p2 = top verts (nation nA), p1, p3 = bottom verts (nation nB); tops pass nA for both.
      const quad = (p0, p1, p2, p3, c0, c1, c2, nA = 0, nB = nA) => { if (nq >= cap) { cap *= 2; const V2 = new Float32Array(cap * 24); V2.set(V); V = V2; const I2 = new Uint32Array(cap * 6); I2.set(I); I = I2; }
        let k = nq * 24, vi = 0; for (const q of [p0, p1, p2, p3]) { const nn = c0 < 0 ? 0 : (vi & 1 ? nB : nA); vi++; V[k++] = q[0]; V[k++] = q[1]; V[k++] = q[2]; V[k++] = c0 + 2 * nn; V[k++] = c1; V[k++] = c2; }
        const b = nq * 4, j = nq * 6; I[j] = b; I[j + 1] = b + 1; I[j + 2] = b + 2; I[j + 3] = b + 2; I[j + 4] = b + 1; I[j + 5] = b + 3; nq++; };
      const X = cx => Math.min(t.W, cx * cs), Z = cy => Math.min(t.H, cy * cs), TOP = i => top[i] * hs;
      const gray = i => Math.min(1, Math.max(0.3, 0.42 + (top[i] - WATER_H) * 1.25));
      const colOf = (i, f, face) => colored ? (face === 'off' ? [-1, 0, 0] : [FACE[face][0] * (kind[i] && face !== 'top' ? 0.8 : 1), FACE[face][1], FACE[face][2]]) : kind[i] ? [WATER[0] * f, WATER[1] * f, WATER[2] * f] : [gray(i) * f, gray(i) * f, gray(i) * 0.97 * f];
      const at = (cx, cy) => cx < 0 || cy < 0 || cx >= cw || cy >= ch ? WATER_H * hs : TOP(cy * cw + cx);
      const nAt = (cx, cy) => cx < 0 || cy < 0 || cx >= cw || cy >= ch ? 0 : NB[cy * cw + cx];
      // Side face needed when the neighbor is lower, or (skirt) level with it but in another nation — the skirt is zero-height until one side lifts.
      const need = (ty, nb, a, b) => nb < ty || (nb === ty && a !== b);
      // tops: row runs of equal kind + height
      for (let cy = 0; cy < ch; cy++) { let cx = 0; while (cx < cw) { const i = cy * cw + cx; let e = cx + 1; while (e < cw && top[i + e - cx] === top[i] && kind[i + e - cx] === kind[i] && NB[i + e - cx] === NB[i]) e++;
        const y = TOP(i), c = colOf(i, 1, 'top'), x0 = X(cx), x1 = X(e), z0 = Z(cy), z1 = Z(cy + 1); quad([x0, y, z0], [x0, y, z1], [x1, y, z0], [x1, y, z1], c[0], c[1], c[2], NB[i]); cx = e; } }
      // south (+z, f .62) / north (−z, f .45) faces: row runs with same height + same neighbor height
      for (const [dz, f, fc] of [[1, 0.62, 's'], [-1, 0.45, 'n']]) for (let cy = 0; cy < ch; cy++) { let cx = 0; while (cx < cw) { const i = cy * cw + cx, ty = TOP(i), nb = at(cx, cy + dz);
        const na = NB[i], nn = nAt(cx, cy + dz); if (!need(ty, nb, na, nn)) { cx++; continue; } let e = cx + 1;
        while (e < cw && TOP(cy * cw + e) === ty && at(e, cy + dz) === nb && kind[cy * cw + e] === kind[i] && NB[cy * cw + e] === na && nAt(e, cy + dz) === nn) e++;
        const c = colOf(i, f * (kind[i] ? 0.8 : 1), fc), z = Z(cy + (dz > 0 ? 1 : 0)), x0 = X(cx), x1 = X(e);
        if (dz > 0) quad([x0, ty, z], [x0, nb, z], [x1, ty, z], [x1, nb, z], c[0], c[1], c[2], na, nn); else quad([x1, ty, z], [x1, nb, z], [x0, ty, z], [x0, nb, z], c[0], c[1], c[2], na, nn); cx = e; } }
      // east (+x, f .5) / west (−x, f .78) faces: column runs
      for (const [dx, f, fc] of [[1, 0.5, 'e'], [-1, 0.78, 'w']]) for (let cx = 0; cx < cw; cx++) { let cy = 0; while (cy < ch) { const i = cy * cw + cx, ty = TOP(i), nb = at(cx + dx, cy);
        const na = NB[i], nn = nAt(cx + dx, cy); if (!need(ty, nb, na, nn)) { cy++; continue; } let e = cy + 1;
        while (e < ch && TOP(e * cw + cx) === ty && at(cx + dx, e) === nb && kind[e * cw + cx] === kind[i] && NB[e * cw + cx] === na && nAt(cx + dx, e) === nn) e++;
        const c = colOf(i, f * (kind[i] ? 0.8 : 1), fc), x = X(cx + (dx > 0 ? 1 : 0)), z0 = Z(cy), z1 = Z(e);
        if (dx > 0) quad([x, ty, z1], [x, nb, z1], [x, ty, z0], [x, nb, z0], c[0], c[1], c[2], na, nn); else quad([x, ty, z0], [x, nb, z0], [x, ty, z1], [x, nb, z1], c[0], c[1], c[2], na, nn); cy = e; } }
      const F = 20000, X1 = t.W, Z1 = t.H, wy = WATER_H * hs;
      for (const [ax, az, bx, bz] of [[-F, -F, X1 + F, 0], [-F, Z1, X1 + F, Z1 + F], [-F, 0, 0, Z1], [X1, 0, X1 + F, Z1]]) quad([ax, wy, az], [ax, wy, bz], [bx, wy, az], [bx, wy, bz], ...(colored ? [-1, 0, 0] : WATER));
      vbo = vbo || gl.createBuffer(); ibo = ibo || gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, V.subarray(0, nq * 24), gl.STATIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, I.subarray(0, nq * 6), gl.STATIC_DRAW); nIdx = nq * 6; t.quads = nq;
    }
    // In-between style ("terrace"): a faceted low-poly heightfield. Grid step = voxel px. Heights snap to TERRACE levels joined by short ramps
    // (flat ledges + sloped risers instead of vertical cliffs). Flat-shaded per triangle, light quantized to 4 bands, nearest upscale.
    function buildTerrace() {
      const { gw, gh, sx, sy, h, wet } = t, hs = o.heightScale, vs = Math.max(1, Math.round(o.voxel / GRID)), cw = Math.floor((gw - 1) / vs) + 1, ch = Math.floor((gh - 1) / vs) + 1;
      const H = new Float32Array(cw * ch), Wt = new Uint8Array(cw * ch), L = norm([-0.5, 0.9, -0.35]);
      const ss = (a, b, x) => { const k = Math.max(0, Math.min(1, (x - a) / (b - a))); return k * k * (3 - 2 * k); };
      for (let cy = 0; cy < ch; cy++) for (let cx = 0; cx < cw; cx++) { let s = 0, n = 0, nw = 0;
        for (let y = Math.max(0, cy * vs - 1); y <= Math.min(gh - 1, cy * vs + 1); y++) for (let x = Math.max(0, cx * vs - 1); x <= Math.min(gw - 1, cx * vs + 1); x++) { const i = y * gw + x; n++; if (wet[i]) nw++; s += h[i]; }
        const ci = cy * cw + cx, c = h[Math.min(gh - 1, cy * vs) * gw + Math.min(gw - 1, cx * vs)];
        if (wet[Math.min(gh - 1, cy * vs) * gw + Math.min(gw - 1, cx * vs)]) { Wt[ci] = 1; H[ci] = SEA_BED; continue; }
        const hv = s / n, lv = Math.floor(hv / TERRACE), fr = hv / TERRACE - lv; H[ci] = Math.max(WATER_H + 0.004, (lv + ss(0.3, 0.7, fr)) * TERRACE); }
      const tris = (cw - 1) * (ch - 1) * 2, V = new Float32Array(tris * 18 + 4 * 4 * 6 + (cw - 1) * (ch - 1) * 36); let p = 0;
      const X = cx => Math.min((gw - 1) * sx, cx * vs * sx), Z = cy => Math.min((gh - 1) * sy, cy * vs * sy);
      // One flat color per grid cell (both triangles share it) → reads as chunky pixels on the slopes. Base gray steps with the terrace level;
      // light from the cell's average normal, quantized to 4 bands.
      let cg = 0; const tri = (a, b, c) => { for (const q of [a, b, c]) { V[p++] = q[0]; V[p++] = q[1]; V[p++] = q[2]; V[p++] = cg; V[p++] = cg; V[p++] = cg * 0.97; } };
      const cellG = (a, b, c, d) => { const nn = norm([(a[1] + c[1] - b[1] - d[1]) / (2 * (b[0] - a[0] || 1)), 1, (a[1] + b[1] - c[1] - d[1]) / (2 * (c[2] - a[2] || 1))]);
        const band = Math.round((0.5 + 0.7 * Math.max(0, dot(nn, L))) * 4) / 4, lvl = Math.round(Math.min(a[1], b[1], c[1], d[1]) / hs / TERRACE) * TERRACE;
        return Math.min(1, Math.max(0.22, 0.4 + (lvl - WATER_H) * 1.3) * band); };
      for (let cy = 0; cy < ch - 1; cy++) for (let cx = 0; cx < cw - 1; cx++) { const i = cy * cw + cx, P = (x, y) => [X(x), H[y * cw + x] * hs, Z(y)];
        const a = P(cx, cy), b = P(cx + 1, cy), c = P(cx, cy + 1), d = P(cx + 1, cy + 1); cg = cellG(a, b, c, d);
        if (Math.abs(a[1] - d[1]) < Math.abs(b[1] - c[1])) { tri(a, c, d); tri(a, d, b); } else { tri(a, c, b); tri(b, c, d); } }
      const wq = (ax, az, bx, bz) => { const wy = WATER_H * hs; for (const [q0, q1] of [[[ax, az], [ax, bz]], [[bx, az], [ax, bz]]]) { const pts = q0 === undefined ? [] : [[ax, wy, az], [ax, wy, bz], [bx, wy, az], [bx, wy, az], [ax, wy, bz], [bx, wy, bz]]; } 
        for (const q of [[ax, az], [ax, bz], [bx, az], [bx, az], [ax, bz], [bx, bz]]) { V[p++] = q[0]; V[p++] = wy; V[p++] = q[1]; V[p++] = WATER[0]; V[p++] = WATER[1]; V[p++] = WATER[2]; } };
      for (let cy = 0; cy < ch - 1; cy++) for (let cx = 0; cx < cw - 1; cx++) { const i = cy * cw + cx; if (Wt[i] | Wt[i + 1] | Wt[i + cw] | Wt[i + cw + 1]) wq(X(cx), Z(cy), X(cx + 1), Z(cy + 1)); }
      const F = 20000, X1 = (gw - 1) * sx, Z1 = (gh - 1) * sy; for (const r of [[-F, -F, X1 + F, 0], [-F, Z1, X1 + F, Z1 + F], [-F, 0, 0, Z1], [X1, 0, X1 + F, Z1]]) wq(...r);
      const nVert = p / 6, idx = new Uint32Array(nVert); for (let i = 0; i < nVert; i++) idx[i] = i;
      vbo = vbo || gl.createBuffer(); ibo = ibo || gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, V.subarray(0, p), gl.STATIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, idx, gl.STATIC_DRAW); nIdx = nVert;
    }
    // ── Railroad (3D). Per line: resample to 1 px → lateral re-route (DP over offsets ±wander px: each step moves ≤ 1 px sideways, a 1-terrace
    // ground change costs 1.5, a ≥ 2-terrace jump costs 30·d, water 4, offset² · 0.015) → smoothed offsets, tapered to 0 at stations →
    // vertical profile = ground (terrace tops) box-smoothed (r 10, ×3), ends pinned to station ground, bridges ≥ water + 0.6 terrace,
    // then grade-limited so consecutive 1 px samples differ by ≤ grade world px (forward/backward clamps) → smooth angled track that always connects.
    // Terrain under the track (radius cut px) is cut down to the bed's terrace; where the bed is above ground the ballast walls form an embankment.
    const RAIL = { wander: 8, grade: 0.35, cut: 6, bw: 5, bh: 1.0, tieL: 3.6, tieW: 0.7, tieH: 0.9, tieStep: 2.6, gauge: 2.4, railW: 0.6, railH: 1.0, bk: 1.2, trussH: 14.6, gap: 8, abut: 3 };
    // Bridges: every water sample (sea, lake, or river mask > 0.5) is a bridge; land gaps ≤ gap px inside a crossing are bridged too; each run extends
    // abut px onto land (abutments). Deck ≥ water top + trussH + 1.5. Truss = textured side quads (bridge end · mid panels stretched to fit · mirrored end),
    // bk map px per sprite px horizontally, trussH world tall (7 sprite rows · bk / cos 55°). Steel piers at panel joints over water.
    // Universal bridges (map-bridges.json). Snap: centre on water, try ±30° (5° steps) × ±12 px shifts; keep the shortest water crossing
    // (score = span + 0.35·shift + 0.08·|Δ°|). Ends: from each water edge walk out ≤ max(L/2 + 6, edge + 4) px and stop where the ground first
    // reaches (window max − ½ terrace) → the bank rim, +2 px onto land. Deck = straight line rim → rim (terrace heights), never below ground + 0.3 terrace.
    // Deck curves up toward the centre: + hump · sin(π·t), hump = min(0.12 · length, 6) world px. Over the gap the deck is a thin slab (1 world px)
    // so water shows underneath; arch band (ubridge end · mid panels · mirrored end) hangs under it; slim stone piers at mid-panel joints down to the ground.
    const UBR = { bw: 3.2, bk: 1.0, parH: 1.4, parW: 0.7, span: 30, shift: 20, climb: 16, clr: 0.8, hump: 0.12, humpMax: 6, slab: 1, pierW: 0.6 };
    function prepBridges() { t.brP = []; const B = t.bridgesSrc; if (!B) return; const { RW, RH, w2, riv } = t, T = TERRACE, HH = t.h2;
      const J = (x, z) => { const cx = Math.round(x) >> 1, cz = Math.round(z) >> 1; return cx < 0 || cz < 0 || cx >= RW || cz >= RH ? -1 : cz * RW + cx; };
      const wet = (x, z) => { const j = J(x, z); return j < 0 || w2[j] >= 2 || !!(riv && riv[j] > 0.5); };
      const gh = (x, z) => { const j = J(x, z); return j < 0 ? WATER_H : wet(x, z) ? Math.max(WATER_H, Math.floor(HH[j] / T) * T - T) : Math.max(WATER_H + T, Math.round(HH[j] / T) * T); };
      // Rail mask (½-res, track ± 10 px): bridges must not land on / run along the railroad.
      const rail = new Uint8Array(RW * RH); if (t.rail) for (const l of t.rail.lines) for (const p of (l.p2 || [])) for (let dz = -10; dz <= 10; dz += 2) for (let dx = -10; dx <= 10; dx += 2) { const j = J(p[0] + dx, p[1] + dz); if (j >= 0) rail[j] = 1; }
      const onRail = (x, z) => { const j = J(x, z); return j >= 0 && rail[j] === 1; };
      const hard = new Uint8Array(RW * RH); if (t.rail) for (const l of t.rail.lines) for (const p of (l.p2 || [])) for (let dz = -6; dz <= 6; dz += 2) for (let dx = -6; dx <= 6; dx += 2) { if (dx * dx + dz * dz > 40) continue; const j = J(p[0] + dx, p[1] + dz); if (j >= 0) hard[j] = 1; }
      const nearRail = (x, z) => { const j = J(x, z); return j >= 0 && hard[j] === 1; }; // deck px within ~6 px of the track = hard reject
      // Walking level W (the height a merc walks at): the largest plateau = most common dry terrace level within 56 px of the mark, raised to the
      // railroad's ground level if track passes within 64 px. The deck runs level at W; each end walks out of the water and up the bank until the
      // ground reaches W (the plateau edge). Search: ±30° in 5°, ±20 px across, ±8 px along (widened to ±60° / ±48 px if nothing fits).
      // Hard rule: ≤ 2 deck px within 6 px of the track (crossing it is fine, running along it is not). Score = span + 4 per px within 10 px of the rail
      // + small offset/angle cost. No fit at W → try the next lower plateau level.
      const railPts = []; if (t.rail) for (const l of t.rail.lines) for (const p of (l.p2 || [])) railPts.push(p);
      for (const b of B) { const [ax, az] = b.a, [bx, bz] = b.b, L0 = Math.hypot(bx - ax, bz - az) || 1, cx0 = (ax + bx) / 2, cz0 = (az + bz) / 2, th0 = Math.atan2(bz - az, bx - ax); let best = null;
        const hist = new Map(); for (let dz = -56; dz <= 56; dz += 2) for (let dx = -56; dx <= 56; dx += 2) { if (dx * dx + dz * dz > 3136) continue; const x = cx0 + dx, z = cz0 + dz; if (wet(x, z)) continue; const k = Math.round(gh(x, z) / T); hist.set(k, (hist.get(k) || 0) + 1); }
        let mode = null, mc = 0; for (const [k, c] of hist) if (c > mc) { mc = c; mode = k; }
        let railK = null; for (const p of railPts) if (Math.hypot(p[0] - cx0, p[1] - cz0) <= 64 && !wet(p[0], p[1])) { const k = Math.round(gh(p[0], p[1]) / T); if (railK == null || k > railK) railK = k; }
        const W0 = Math.max(mode ?? Math.round((WATER_H + T) / T), railK ?? -1e9), levels = [...hist.keys()].filter(k => k < W0).sort((p, q) => q - p); levels.unshift(W0);
        const maxRun = Math.max(40, L0 * 1.6), reach = 48;
        const tryAt = (Wk, span, shift) => { const Wy = Wk * T; let bst = null;
          for (let dth = -span; dth <= span; dth += 5) { const th = th0 + dth * Math.PI / 180, ux = Math.cos(th), uz = Math.sin(th), px = -uz, pz = ux; let cx = 0, cz = 0; const at = d => [cx + ux * d, cz + uz * d];
            for (let s = -shift; s <= shift; s += 2) for (let r = -8; r <= 8; r += 2) { cx = cx0 + px * s + ux * r; cz = cz0 + pz * s + uz * r; if (!wet(cx, cz)) continue;
              const run = sg => { for (let d = 1; d <= maxRun; d++) if (!wet(...at(d * sg)) && !wet(...at((d + 1) * sg))) return d; return null; };
              const d1 = run(1), d2 = run(-1); if (d1 == null || d2 == null) continue;
              // End = first px whose ground is exactly level W across the deck width (±2 px), with dry ground ≥ W for 2 px beyond → full land contact.
              // Ground above W before that (deck would have to bend) → reject.
              const lvl = (x, z) => wet(x, z) ? -1 : Math.round(gh(x, z) / T), solid = (d, sg) => { for (let k = 0; k <= 2; k++) for (let w = -2; w <= 2; w++) { const p = at((d + k) * sg), l = lvl(p[0] + px * w, p[1] + pz * w); if (k === 0 ? l !== Wk : l < Wk) return false; } return true; }; // end px exactly W across the deck; behind it ground may rise (abutment into a terraced bank) but never drop
              const up = (sg, d0) => { for (let d = d0; d <= d0 + reach; d++) { const p = at(d * sg), l = lvl(...p); if (l < 0 || l > Wk) return null; if (l === Wk && solid(d, sg)) return lvl(...at((d + 1) * sg)) === Wk ? d + 1 : d; } return null; }; // +1 px overlap onto the plateau when it stays at W
              const e1 = up(1, d1), e2 = up(-1, d2); if (e1 == null || e2 == null) continue;
              let rl = 0, nr = 0; for (let d = -e2; d <= e1; d++) { const p = at(d); if (nearRail(...p)) nr++; if (onRail(...p)) rl++; } if (nr > 2) continue;
              const sc = e1 + e2 + 4 * rl + 0.35 * Math.hypot(s, r) + 0.08 * Math.abs(dth);
              if (!bst || sc < bst.sc) bst = { sc, cx, cz, ux, uz, e1, e2, rl, Wy }; } }
          return bst; };
        // tight: true (hand-corrected marks) → stay close to the mark's line (±10° / ±6 px, then ±20° / ±12 px) instead of the wide search.
        for (const Wk of levels) { best = b.tight ? (tryAt(Wk, 10, 6) || tryAt(Wk, 20, 12)) : (tryAt(Wk, UBR.span, UBR.shift) || tryAt(Wk, 60, 48)); if (best) { best.lvDrop = W0 - Wk; break; } }
        if (!best) { t.brDropped = (t.brDropped || []).concat(b.id); continue; }
        const at = (d) => [best.cx + best.ux * d, best.cz + best.uz * d];
        const { e1, e2, Wy } = best, n = Math.max(2, Math.round(e1 + e2) + 1), P = [], G = [];
        for (let i = 0; i < n; i++) { const d = -e2 + (e1 + e2) * i / (n - 1), p = at(d); P.push(p); G.push(gh(p[0], p[1])); }
        const D = G.map(() => Wy); // deck level at W end to end; both ends sit flush on W ground
        t.brP.push({ id: b.id, P, G, D, ux: best.ux, uz: best.uz, snapped: true, walkLevel: Math.round(Wy / T), plateau: mode, railLevel: railK, levelDrop: best.lvDrop, rimDiff: 0, onRail: best.rl }); } }
    const EL = { K: 1.4, KY: 1.6, plotX: 50, plotBack: 44, plotFront: 8, apron: 24, search: 160, step: 4, maxLv: 2, railGap: 8 }; // K map px per sprite px (x, z); KY world per sprite px (y) // map px per sprite px; depth d → K·DZ map px north; flattened plot
    const resample = (pts, st) => { const out = [[pts[0][0], pts[0][1]]]; let carry = st;
      for (let k = 1; k < pts.length; k++) { const [ax, az] = pts[k - 1], [bx, bz] = pts[k], L = Math.hypot(bx - ax, bz - az); let s = carry; while (s <= L) { out.push([ax + (bx - ax) * s / L, az + (bz - az) * s / L]); s += st; } carry = s - L; }
      const e = pts[pts.length - 1], q = out[out.length - 1]; if (Math.hypot(e[0] - q[0], e[1] - q[1]) > 0.3) out.push([e[0], e[1]]); else out[out.length - 1] = [e[0], e[1]]; return out; };
    const nrm = (P, r) => P.map((_, i) => { const A = P[Math.max(0, i - r)], B = P[Math.min(P.length - 1, i + r)], dx = B[0] - A[0], dz = B[1] - A[1], L = Math.hypot(dx, dz) || 1; return [-dz / L, dx / L]; });
    const smooth1 = (a, r, passes) => { let x = Float32Array.from(a); const n = x.length; for (let p = 0; p < passes; p++) { const y = new Float32Array(n); for (let i = 0; i < n; i++) { let s = 0, c = 0; for (let k = Math.max(0, i - r); k <= Math.min(n - 1, i + r); k++) { s += x[k]; c++; } y[i] = s / c; } x = y; } return x; };
    function prepRail() { const r = t.rail; if (!r) return; const { RW, RH, w2 } = t, H0 = t.h2o, H = t.h2, T = TERRACE, G = RAIL.grade / o.heightScale, LMIN = Math.round((WATER_H + T) / T);
      const cell = (x, z) => Math.min(RH - 1, Math.max(0, Math.round(z) >> 1)) * RW + Math.min(RW - 1, Math.max(0, Math.round(x) >> 1));
      const lvl = (x, z) => { const i = cell(x, z); return w2[i] >= 2 || t.riv[i] > 0.5 ? -1 : Math.max(LMIN, Math.round(H0[i] / T)); };
      const wtop = (x, z) => { const i = cell(x, z); return w2[i] >= 2 ? WATER_H : Math.max(WATER_H, (Math.round(H0[i] / T) - 1) * T); };
      for (const l of r.lines) { const P = resample(l.points, 1), n = P.length, N = nrm(P, 4), K = RAIL.wander, S = 2 * K + 1;
        const cost = new Float32Array(n * S).fill(1e9), back = new Int8Array(n * S), lv = new Int16Array(n * S);
        for (let i = 0; i < n; i++) for (let k = 0; k < S; k++) lv[i * S + k] = lvl(P[i][0] + N[i][0] * (k - K), P[i][1] + N[i][1] * (k - K));
        cost[K] = 0;
        for (let i = 1; i < n; i++) for (let k = 0; k < S; k++) { const L = lv[i * S + k], off = k - K; let best = 1e9, bk = 0;
          for (let dk = -1; dk <= 1; dk++) { const kp = k + dk; if (kp < 0 || kp >= S) continue; const Lp = lv[(i - 1) * S + kp]; let tc = 0;
            if (L >= 0 && Lp >= 0) { const d = Math.abs(L - Lp); tc = d === 0 ? 0 : d === 1 ? 1.5 : 30 * d; } const c = cost[(i - 1) * S + kp] + tc + Math.abs(dk) * 0.05; if (c < best) { best = c; bk = dk; } }
          cost[i * S + k] = best + 0.015 * off * off + (L < 0 ? 4 : 0); back[i * S + k] = bk; }
        let off = new Float32Array(n); for (let i = n - 1, k = K; i >= 0; i--) { off[i] = k - K; k += back[i * S + k]; }
        off = smooth1(off, 6, 3); for (let i = 0; i < n; i++) off[i] *= Math.min(1, i / 12, (n - 1 - i) / 12);
        const P2 = P.map((p, i) => [p[0] + N[i][0] * off[i], p[1] + N[i][1] * off[i]]), g = new Float32Array(n), wet = new Uint8Array(n);
        for (let i = 0; i < n; i++) { const L = lvl(P2[i][0], P2[i][1]); wet[i] = L < 0 ? 1 : 0; g[i] = L < 0 ? NaN : L * T; }
        { let last = -1; for (let i = 0; i < n; i++) if (!isNaN(g[i])) { if (last < 0) for (let k = 0; k < i; k++) g[k] = g[i]; else for (let k = last + 1; k < i; k++) g[k] = g[last] + (g[i] - g[last]) * (k - last) / (i - last); last = i; }
          if (last < 0) g.fill(LMIN * T); else for (let k = last + 1; k < n; k++) g[k] = g[last]; }
        const BR = wet.slice(); { let last = -1; for (let i = 0; i < n; i++) if (BR[i]) { if (last >= 0 && i - last > 1 && i - last <= RAIL.gap) for (let k = last + 1; k < i; k++) BR[k] = 1; last = i; }
          const ex = BR.slice(); for (let i = 0; i < n; i++) if (BR[i]) for (let k = Math.max(0, i - RAIL.abut); k <= Math.min(n - 1, i + RAIL.abut); k++) ex[k] = 1; BR.set(ex); }
        const wt = new Float32Array(n).fill(NaN); for (let i = 0; i < n; i++) if (wet[i]) wt[i] = wtop(P2[i][0], P2[i][1]);
        const z = smooth1(g, 10, 3); z[0] = g[0]; z[n - 1] = g[n - 1]; for (let i = 0; i < n; i++) if (wet[i]) z[i] = Math.max(z[i], wt[i] + (RAIL.trussH + 1.5) / o.heightScale);
        for (let it = 0; it < 8; it++) { for (let i = 1; i < n - 1; i++) z[i] = Math.min(z[i - 1] + G, Math.max(z[i - 1] - G, z[i])); for (let i = n - 2; i > 0; i--) z[i] = Math.min(z[i + 1] + G, Math.max(z[i + 1] - G, z[i])); }
        const C = RAIL.cut; for (let i = 0; i < n; i++) { if (BR[i]) continue; const cutTo = Math.floor(z[i] / T + 1e-4) * T; for (let dz = -C; dz <= C; dz += 2) for (let dx = -C; dx <= C; dx += 2) { if (dx * dx + dz * dz > C * C) continue; const j = cell(P2[i][0] + dx, P2[i][1] + dz); if (w2[j] < 2 && H[j] > cutTo) H[j] = cutTo; } }
        l.p2 = P2; l.z2 = z; l.br = BR; l.wt = wt; } }
    // Map elements. Placement rule (also keeps the plot ≥ railGap px off any track): the plot (±plotX, plotBack north, plotFront south) AND a front apron (apron px further south, toward the camera)
    // must be land, and the plot may span ≤ maxLv terrace levels. If the authored point fails, the nearest passing point (rings of step px, up to
    // search px) is used; ties prefer moving south ("down"), then the smallest sideways shift. The plot is then flattened to its median terrace.
    function prepEls() { let __pt = performance.now(); const MK = k => { const n = performance.now(); PROF['els.' + k] = (PROF['els.' + k] || 0) + n - __pt; __pt = n; }; t.elsP = []; const els = t.els && t.els.elements; if (!els) return; const { RW, RH, w2 } = t, H = t.h2, T = TERRACE;
      const J = (x, z) => Math.min(RH - 1, Math.max(0, z >> 1)) * RW + Math.min(RW - 1, Math.max(0, x >> 1));
      const occ = new Uint8Array(RW * RH); if (t.rail) for (const l of t.rail.lines) for (const p of (l.p2 || [])) for (let dz = -EL.railGap; dz <= EL.railGap; dz += 2) for (let dx = -EL.railGap; dx <= EL.railGap; dx += 2) occ[J(Math.round(p[0] + dx), Math.round(p[1] + dz))] = 1; // track + railGap px stays clear
      // Universal bridges are placed before elements (trade routes need their ends): deck ± 5 px and 8 px past each end stay clear → no plot flattens the banks under them.
      for (const b of (t.brP || [])) { const P = b.P, n = P.length; if (n < 2) continue; for (let d = -8; d <= n + 8; d += 1) { const k = Math.max(0, Math.min(n - 1, d)), ex = d < 0 ? d : d >= n ? d - n + 1 : 0, cx = P[k][0] + b.ux * ex, cz = P[k][1] + b.uz * ex; for (let w = -5; w <= 5; w += 1) occ[J(Math.round(cx - b.uz * w), Math.round(cz + b.ux * w))] = 1; } }
      // Plot grows with the model footprint (scene W × max depth · K) so big models (capitals) sit on one flattened pad.
      const ME = window.MercElements ? window.MercElements.make((w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }) : null;
      const dims = e => { const L = ME ? ME.model(e.type, e) : [], W = L.W || (ME ? ME.SCENE_W : 66); let zb = 0; for (const p of L) zb = Math.max(zb, p.z + (p.d || 0) / 2);
        return { px: Math.max(EL.plotX, Math.ceil(W * EL.K / 2) + 4), pb: Math.max(EL.plotBack, Math.ceil(zb * EL.K) + 4) }; };
      let PX = EL.plotX, PB = EL.plotBack, PF = EL.plotFront;
      const score = (cx, cy) => { let wet = 0, lo = 1e9, hi = -1e9; for (let z = cy - PB; z <= cy + EL.plotFront + EL.apron; z += 2) for (let x = cx - PX; x <= cx + PX; x += 2) { const j = J(x, z);
          if (w2[j] >= 2 || (t.riv && t.riv[j] > 0.5) || (occ[j] && z <= cy + EL.plotFront)) wet++; else if (z <= cy + EL.plotFront) { const lv = Math.round(H[j] / T); if (lv < lo) lo = lv; if (lv > hi) hi = lv; } }
        return wet * 100 + Math.max(0, hi - lo - EL.maxLv); };
      const place = e => { let best = null; for (let r = 0; r <= EL.search; r += EL.step) { for (let dz = -r; dz <= r; dz += EL.step) for (let dx = -r; dx <= r; dx += EL.step) { if (Math.max(Math.abs(dx), Math.abs(dz)) !== r) continue;
          const s = score(e.x + dx, e.y + dz), k = s * 1e6 + (dz < 0 ? 1000 : 0) + Math.abs(dx) * 2 + Math.abs(dz); if (!best || k < best.k) best = { k, s, dx, dz }; }
        if (best && best.s === 0) break; } return best; };
      const each = (e, f) => { for (let z = e.y - PB; z <= e.y + PF; z += 2) for (let x = e.x - PX; x <= e.x + PX; x += 2) { const j = Math.min(RH - 1, Math.max(0, z >> 1)) * RW + Math.min(RW - 1, Math.max(0, x >> 1)); if (w2[j] < 2) f(j); } };
      MK('pre');
      // Settlements (type "settlement"): MercSettlements builds streets + buildings on location (shared grid → no overlaps; own-nation dry land only).
      const SET = window.MercSettlements, sites = els.filter(e => e.type === 'settlement'), gen = [];
      // Auto sites: every city / capital label in a nation with a style (SET.NATION_STYLE) that has no authored settlement of the same name.
      if (SET && SET.NATION_STYLE) { const have = new Set(sites.map(s => s.name));
        for (const l of (t.labels || [])) if (l.kind === 'poi' && (l.type === 'city' || l.type === 'capital') && SET.NATION_STYLE[l.nation] && !have.has(l.name)) { have.add(l.name);
          sites.push({ id: 'set_' + l.key, type: 'settlement', kind: l.type, style: SET.NATION_STYLE[l.nation], name: l.name, x: l.ix, y: l.iz }); }
        for (const [nm, pts] of Object.entries(SET.ISLE_SITES || {})) { const par = sites.find(s => s.name === nm); if (par) pts.forEach((p, k) => sites.push({ id: par.id + '_isle' + k, type: 'settlement', kind: 'city', style: par.style, name: nm, x: p[0], y: p[1], sub: true })); } } t.paint = null; t.paintCols = null; t.gocc = null; t.pondMask = null;
      // Crash sphere dome (ME.CRASH_SPHERE): raise the terrain to a spherical cap (level = lo + (top − lo)·√(1 − (r/R)²) ± blocky noise) before the grid reads levels.
      const CSP = ME && ME.CRASH_SPHERE, csh = (x, z) => { let h = Math.imul(x | 0, 73856093) ^ Math.imul(z | 0, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
      if (CSP) { const [sx, sz] = CSP.c, R = CSP.r; for (let z = (sz - R) >> 1; z <= (sz + R) >> 1; z++) for (let x = (sx - R) >> 1; x <= (sx + R) >> 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; const j = z * RW + x; if (w2[j] >= 2) continue;
          const r = Math.hypot(x * 2 + 1 - sx, z * 2 + 1 - sz) * (1 + 0.08 * Math.sin(Math.atan2(z * 2 - sz, x * 2 - sx) * 7)); if (r > R) continue; const lo = Math.round(H[j] / T), f = Math.sqrt(1 - (r / R) ** 2);
          const nz = Math.round((csh(x >> 1, z >> 1) - 0.5) * 2 * CSP.noise + (csh(x, z + 7) < 0.08 ? 1 : 0)), lv = Math.max(lo, Math.round(lo + (CSP.top - lo) * f) + (f > 0.15 ? nz : 0)); H[j] = lv * T; } }
      // Citadel mounds (ME.MOUNDS): raised castle grounds + south cut for a decorative bridge (see map-elements MOUNDS). t.moundBridges feeds the bridge placement below.
      t.moundBridges = []; for (const M of ((ME && ME.MOUNDS) || [])) { const [mx, mz] = M.c, Rr = M.r, ring = M.raise * M.step, lv0 = []; for (let z = (mz - Rr) >> 1; z <= (mz + Rr) >> 1; z++) for (let x = (mx - Rr) >> 1; x <= (mx + Rr) >> 1; x++) { const j = z * RW + x; if (j >= 0 && j < RW * RH && w2[j] < 2 && Math.hypot(x * 2 + 1 - mx, z * 2 + 1 - mz) <= Rr) lv0.push(Math.round(H[j] / T)); }
        if (!lv0.length) continue; lv0.sort((p, q) => p - q); const base = lv0[lv0.length >> 1], top = base + M.raise, cut = M.cutDeg * Math.PI / 180;
        for (let z = (mz - Rr - ring) >> 1; z <= (mz + Rr + ring) >> 1; z++) for (let x = (mx - Rr - ring) >> 1; x <= (mx + Rr + ring + M.cw) >> 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; const j = z * RW + x; if (w2[j] >= 2 || (t.riv && t.riv[j] > 0.5)) continue;
          const dx = x * 2 + 1 - mx, dz = z * 2 + 1 - mz, r = Math.hypot(dx, dz), a = Math.abs(Math.atan2(dz, dx)), cur = Math.round(H[j] / T); let L = null;
          if (r <= Rr) L = top; else if (a <= cut && r <= Rr + M.cw) L = base - 1; else if (r <= Rr + ring) L = Math.max(cur, top - Math.ceil((r - Rr) / M.step));
          if (L != null) H[j] = Math.max(WATER_H / T + 1, L) * T; }
        t.moundBridges.push({ name: M.name, kit: M.bridge, z: mz, x0: mx + Rr - 3, x1: mx + Rr + M.cw + 3, low: (base - 1) * T, rise: (M.raise + 1) * T }); }
      if (SET && ME && sites.length) { const N = RW * RH, grid = { RW, RH, lvlMin: Math.round((WATER_H + T) / T), dry0: new Uint8Array(N), wet: new Uint8Array(N), dry: new Uint8Array(N), nat: new Uint8Array(N), lvl: new Int16Array(N), occ: new Uint8Array(N), paint: new Uint8Array(N), cols: [null] };
        for (let j = 0; j < N; j++) { const x = j % RW, z = (j / RW) | 0; grid.dry[j] = w2[j] < 2 && !(t.riv && t.riv[j] > 0.5) && !occ[j] ? 1 : 0; grid.dry0[j] = w2[j] < 2 && !(t.riv && t.riv[j] > 0.5) ? 1 : 0; grid.wet[j] = w2[j] >= 2 && !(t.riv && t.riv[j] > 0.5) ? 1 : 0; grid.lvl[j] = Math.round(H[j] / T);
          grid.nat[j] = t.nat ? t.nat[Math.min(t.H - 1, 2 * z + 1) * t.W + Math.min(t.W - 1, 2 * x + 1)] : 0; }
        // Crash sphere paint: ruin tones by 3 px blocks (weights CSP.paint[i][2]).
        if (CSP) { const codes = CSP.paint.map(p => grid.cols.push([p[0], p[1]]) - 1), tw = CSP.paint.reduce((a, p) => a + p[2], 0), [sx, sz] = CSP.c;
          for (let z = (sz - CSP.r) >> 1; z <= (sz + CSP.r) >> 1; z++) for (let x = (sx - CSP.r) >> 1; x <= (sx + CSP.r) >> 1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; const j = z * RW + x; if (!grid.dry0[j] || Math.hypot(x * 2 + 1 - sx, z * 2 + 1 - sz) > CSP.r * 0.97) continue;
            let v = csh(Math.floor(x / 1.5), Math.floor(z / 1.5) + 31) * tw, k = 0; for (; k < CSP.paint.length - 1; k++) { if ((v -= CSP.paint[k][2]) <= 0) break; } grid.paint[j] = codes[k]; grid.occ[j] = 3; } }
        // Track data for stations: trackPts [x, z, ux, uz] (image px + unit direction), railHard = ≤ 4 px of the centerline, near13 = ≤ 14 px.
        grid.railHard = new Uint8Array(N); grid.near13 = new Uint8Array(N); grid.trackPts = []; grid.stations = t.rail ? t.rail.stations.map(s => ({ name: s.name, x: s.x, z: s.y })) : [];
        if (t.rail) for (const l of t.rail.lines) { const P = l.p2 || []; for (let i = 0; i < P.length; i++) { const a = P[Math.max(0, i - 2)], b = P[Math.min(P.length - 1, i + 2)], dx = b[0] - a[0], dz = b[1] - a[1], dd = Math.hypot(dx, dz) || 1, p = P[i];
          grid.trackPts.push([p[0], p[1], dx / dd, dz / dd]);
          for (let dz2 = -14; dz2 <= 14; dz2 += 2) for (let dx2 = -14; dx2 <= 14; dx2 += 2) { const r2 = dx2 * dx2 + dz2 * dz2; if (r2 > 196) continue; const j = J(Math.round(p[0] + dx2), Math.round(p[1] + dz2)); grid.near13[j] = 1; if (r2 <= 16) grid.railHard[j] = 1; } } }
        const codes = {}, rgb = h => { const v = parseInt(h.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; };
        grid.code = (style, k) => { const key = style + '|' + k; if (!codes[key]) { const P = ME.PALS[style] || ME.PALS.buern; codes[key] = grid.cols.length; grid.cols.push(P[k].map(rgb)); } return codes[key]; };
        // Settlement ids: cells a site claimed (buildings + kept streets/plaza) → id (1-based, t.setList[id] = name). Each site only scans its own bbox.
        const sid = new Uint8Array(N); t.setList = [null];
        // Neighbors = every other settlement site + every city / capital / POI / volcano label point (image px). Growth leans away from them.
        const pts = sites.map(s => [s.x, s.y, s.name, 1]).concat((t.labels || []).filter(l => l.kind === 'poi' && l.type !== 'city' && l.type !== 'capital').map(l => [l.ix, l.iz, l.name, 0])); // [x, z, name, isSettlement]
        MK('settle0');
        // Temples (placed BEFORE settlements since 2026-10-07i, so a temple inside a town keeps its spot and the town grows around it): bespoke kit per temple POI (ME.TEMPLES), nearest fitting spot; label pin moves onto it.
        if (SET.landmark && ME.TEMPLES) for (const l of t.labels) { const kid = l.kind === 'poi' && ME.TEMPLES[l.name]; if (!kid) continue; const e = SET.landmark({ x: l.ix, y: l.iz, name: l.name }, grid, ME, EL.K, kid, 'tpl_' + l.key);
          if (e) { e.temple = l.name; gen.push(e); l.ix = Math.round(e.x); l.iz = Math.round(e.y - e.plot.pb * 0.4); } }
        // Unique landmarks (ME.LANDMARKS): exact = placed as given (cave mouth on its pit rim; base = lower median of the footprint; footprint + pit Ø 10 px → occ 3); else nearest fitting spot (flattened).
        if (ME.LANDMARKS) ME.LANDMARKS.forEach(([kid, x, z, nm, exact], i) => { let e = null;
          if (exact) { const k0 = ME.kit(kid, 'buern', () => 0.4), S2 = 2, k = { W: k0.W * S2, D: k0.D * S2, parts: k0.parts.map(p => { const q = { ...p }; for (const f of ['x', 'z', 'y', 'w', 'd', 'h']) if (q[f] != null) q[f] *= S2; return q; }) }, fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2, v = [];
            for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const j = zz * RW + xx; v.push(H[j]); grid.occ[j] = grid.occ[j] || 1; }
            for (let dz = -3; dz <= 3; dz++) for (let dx = -3; dx <= 3; dx++) { const j = J(x + dx * 2, z + 7 + dz * 2); if (j >= 0 && !grid.occ[j]) grid.occ[j] = 3; } v.sort((p, q) => p - q);
            e = { id: 'lm_' + i, type: 'gen', kit: kid, settlement: null, nf: true, gyRaw: Math.max(WATER_H + T, Math.round(v[(v.length * 0.35) | 0] / T) * T), L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }; }
          else if (SET.landmark) e = SET.landmark({ x, y: z, name: nm }, grid, ME, EL.K, kid, 'lm_' + i);
          if (e) { e.temple = nm; gen.push(e); const lb = t.labels.find(l => l.kind === 'poi' && l.name === nm); if (lb) { lb.ix = Math.round(e.x); lb.iz = Math.round(e.y - e.plot.pb * (exact ? 0.15 : 0.4)); } } });
        // Mound bridges: decorative arched bridge over the citadel cut (gyRaw = cut floor, deck = plateau top); footprint + 1 cell reserved before the town grows.
        for (const B of (t.moundBridges || [])) { if (!B.kit || !ME.kit) continue; const len = (B.x1 - B.x0) / EL.K, k = ME.kit(B.kit, 'buern', () => 0.5, { len, h: B.rise * o.heightScale / EL.KY }), fw = k.W * EL.K, fd = k.D * EL.K, x0 = B.x0, z0 = B.z - fd / 2;
          for (let zz = Math.floor(z0 / 2) - 1; zz <= Math.ceil((z0 + fd) / 2); zz++) for (let xx = Math.floor(x0 / 2) - 1; xx <= Math.ceil((x0 + fw) / 2); xx++) if (xx >= 0 && zz >= 0 && xx < RW && zz < RH) grid.occ[zz * RW + xx] = grid.occ[zz * RW + xx] || 1;
          gen.push({ id: 'mb_' + B.name, type: 'gen', kit: B.kit, settlement: null, nf: true, gyRaw: B.low, L: Object.assign(k.parts, { W: k.W }), x: x0 + fw / 2, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); }
        if (SET.landmark && ME.CASTLES) ME.CASTLES.forEach(([kid, x, z, nm], i) => { const e = SET.landmark({ x, y: z, name: nm }, grid, ME, EL.K, kid, 'cst_' + i); if (e) { e.castle = nm; gen.push(e); } });
        // Landmark cells (temples, placed before towns) are reserved: towns never claim them, so the temple keeps its own hover id (was: nearest town's bbox claimed it → hovering the temple lit that town).
        const LMK = new Uint8Array(N), fpOf = e => [Math.floor((e.x - e.plot.px) / 2), Math.ceil((e.x + e.plot.px) / 2) - 1, Math.floor((e.y - e.plot.pb) / 2), Math.ceil(e.y / 2) - 1];
        for (const e of gen) if (e.temple) { const [x0, x1, z0, z1] = fpOf(e); for (let z = z0 - 1; z <= z1 + 1; z++) for (let x = x0 - 1; x <= x1 + 1; x++) if (x >= 0 && z >= 0 && x < RW && z < RH) LMK[z * RW + x] = 1; }
        // Ownership (2026-10-08): a town claims exactly the cells its own generate() call occupied or painted (diff of occ / paint inside its 260 px box before vs after).
        // Was: every occupied / painted unclaimed cell in the box → a town generated before a neighbour's pre-placed castle / bridge (Makaliim Citadel) claimed it (hover said "Rebnok").
        sites.forEach((s, k) => { s.nbrs = pts.filter(p => p[2] !== s.name && Math.hypot(p[0] - s.x, p[1] - s.y) > 4); const B = 260, bx0 = Math.max(0, (s.x - B) >> 1), bx1 = Math.min(RW - 1, (s.x + B) >> 1), bz0 = Math.max(0, (s.y - B) >> 1), bz1 = Math.min(RH - 1, (s.y + B) >> 1), bw = bx1 - bx0 + 1, snapO = new Uint8Array(bw * (bz1 - bz0 + 1)), snapP = new Uint8Array(bw * (bz1 - bz0 + 1));
          for (let z = bz0; z <= bz1; z++) for (let x = bx0; x <= bx1; x++) { const j = z * RW + x, q = (z - bz0) * bw + x - bx0; snapO[q] = grid.occ[j]; snapP[q] = grid.paint[j]; }
          gen.push(...SET.generate(s, grid, ME, EL.K)); const pid = s.sub ? t.setList.indexOf(s.name) : -1, id = pid > 0 ? pid : Math.min(255, k + 1); if (pid <= 0) t.setList[id] = s.name;
          for (let z = bz0; z <= bz1; z++) for (let x = bx0; x <= bx1; x++) { const j = z * RW + x, q = (z - bz0) * bw + x - bx0; if (!sid[j] && !LMK[j] && ((grid.occ[j] && grid.occ[j] !== snapO[q]) || (grid.paint[j] && grid.paint[j] !== snapP[q]))) sid[j] = id; } });
        // Town fortresses / citadel bridges belong to their town: footprint cells → the site whose name starts the castle's name ('Makaliim Citadel' → Makaliim).
        for (const e of gen) { const nm = e.castle || (/^mb_/.test(e.id || '') ? e.id.slice(3) : null); if (!nm || !e.plot) continue; const site = sites.find(q => !q.sub && nm.startsWith(q.name)); const id = site ? t.setList.indexOf(site.name) : -1; if (id <= 0) continue; const [x0, x1, z0, z1] = fpOf(e); for (let z = z0; z <= z1; z++) for (let x = x0; x <= x1; x++) if (x >= 0 && z >= 0 && x < RW && z < RH) { const j = z * RW + x; if (!sid[j] || !LMK[j]) sid[j] = id; } }
        // Render mask = ids dilated 2 cells (closes the 1-cell gaps between buildings → one outline per city). Hit mask = dilated 2 cells + 8 cells north,
        // because the cursor ray over a roof meets the ground behind (north of) the building.
        const sR = new Uint8Array(N), sH = new Uint8Array(N), stamp = (A, x, z, v, z0, z1, r) => { for (let dz = z0; dz <= z1; dz++) for (let dx = -r; dx <= r; dx++) { const xx = x + dx, zz = z + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH && !A[zz * RW + xx]) A[zz * RW + xx] = v; } };
        for (let j = 0; j < N; j++) { const v = sid[j]; if (!v) continue; const x = j % RW, z = (j / RW) | 0; stamp(sR, x, z, v, -2, 2, 2); stamp(sH, x, z, v, -8, 2, 2); }
        // Rail stations no settlement claimed → standalone station building.
        { const claimed = new Set(gen.filter(e => e.stationName).map(e => e.stationName)); if (SET.station) for (const s of grid.stations) if (!claimed.has(s.name)) gen.push(...SET.station(s, grid, ME, EL.K));
          // Station labels sit on their building (pin = building front-center).
          for (const e of gen) if (e.stationName && !e.settlement) { const lb = t.labels.find(l => l.kind === 'poi' && l.name === e.stationName); if (lb && !/junction/i.test(lb.name)) { /* junction labels stay on the junction */ lb.ix = Math.round(e.x); lb.iz = Math.round(e.y - e.plot.pb * 0.4); } } }
        // City / capital labels centred on their settlement (2026-10-08): pin = midpoint of the 5–95 % range of the main site's building footprint centres
        // (x and z separately; isle sub-sites, stations, temples excluded). Authored JSON points are only layout seeds. t.labelsRecentred = [name, oldX, oldZ, x, z].
        { const recentred = [];
          for (const lb of t.labels) { if (lb.kind !== 'poi' || (lb.type !== 'city' && lb.type !== 'capital')) continue; const main = sites.find(q => q.name === lb.name && !q.sub); if (!main) continue; const X = [], Z = [];
            for (const e of gen) { if (e.settlement !== main.id || !e.plot) continue; X.push(e.x); Z.push(e.y - e.plot.pb / 2); }
            if (X.length < 3) continue; X.sort((p, q) => p - q); Z.sort((p, q) => p - q); const qt = (A, f) => A[Math.min(A.length - 1, Math.floor(A.length * f))], nx = Math.round((qt(X, 0.05) + qt(X, 0.95)) / 2), nz = Math.round((qt(Z, 0.05) + qt(Z, 0.95)) / 2);
            if (Math.hypot(nx - lb.ix, nz - lb.iz) > 2) recentred.push([lb.name, lb.ix, lb.iz, nx, nz]); lb.ix = nx; lb.iz = nz; }
          t.labelsRecentred = recentred; }
        MK('temples+settle');
        // ── World dressing (2026-10-07). Order: temples → trade routes → foliage / terrain props; each layer avoids the earlier ones via grid.occ.
        const hh = (x, z) => { let h = Math.imul(x | 0, 73856093) ^ Math.imul(z | 0, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
        // Kit ids may carry a tree variant (f_pine#3). Scatter kits (rocks, ruins, bushes, water / river rocks) render SCAT_S × their authored size.
        const SCAT = /^(p_(rocks|boulder|snowrock|darkrock|spire|obsidian|driftwood|icespike|icerock|rubble|ruin|column|junk|wreck|corruptrock|slab|rebar|debris|cspike)|w_|r_|f_(fern|shrub|scrub|drybrush|flowers|snowbush|reeds|cactus|prickly|hedge|tallgrass))/, SCAT_S = 1.5, TREES = ME.TREES || new Set();
        const scaleKit = (k, S) => ({ W: k.W * S, D: k.D * S, parts: k.parts.map(p => { const q = { ...p }; for (const f of ['x', 'z', 'y', 'w', 'd', 'h']) if (q[f] != null) q[f] *= S; return q; }) });
        const kc = {}, kitOf = id => kc[id] || (kc[id] = (() => { const [b, v] = id.split('#'), k = ME.kit(b, 'buern', () => 0.4, v != null ? { v: +v } : undefined); return SCAT.test(b) ? scaleKit(k, SCAT_S) : k; })()), inTown = { on: false }, free = j => grid.dry[j] && !grid.occ[j] && !grid.paint[j] && !grid.railHard[j] && (inTown.on || !sR[j]);
        // extOf(kit) (2026-10-07): model-unit rect [x0, x1, z0, z1] covering every part after its tilt / pitch (same rotation as rotP) — leaning ruins reserve the ground they lean over.
        const extOf = k => k.ext || (k.ext = (() => { let x0 = 0, x1 = k.W, z0 = 0, z1 = k.D, tl = false; for (const p of k.parts) { if (!p.tilt && !p.pitch) continue; tl = true; const pv = p.piv || [p.x, p.y || 0, p.z];
          for (const sx of [-1, 1]) for (const sz of [-1, 1]) for (const yy of [p.y || 0, (p.y || 0) + (p.h || 0)]) { let dx = (p.x + sx * (p.w || 0) / 2 - pv[0]) * EL.K, dy = (yy - pv[1]) * EL.KY, dz = -(p.z + sz * (p.d || 0) / 2 - pv[2]) * EL.K;
            if (p.tilt) { const c = Math.cos(p.tilt), sn = Math.sin(p.tilt), nx = dx * c - dy * sn; dy = dx * sn + dy * c; dx = nx; } if (p.pitch) { const c = Math.cos(p.pitch), sn = Math.sin(p.pitch), nz = dz * c - dy * sn; dy = dz * sn + dy * c; dz = nz; }
            const X = pv[0] + dx / EL.K, Z = pv[2] - dz / EL.K; x0 = Math.min(x0, X); x1 = Math.max(x1, X); z0 = Math.min(z0, Z); z1 = Math.max(z1, Z); } } const r = [x0, x1, z0, z1]; r.tilted = tl; return r; })());
        const lvl0 = j => grid.lvl[j], FLAT_KIT = /^p_(dune|pond|mudpit|wheat|ruin|column|junk|wreck|rubble)/, prop = (id, x, z, tag) => { const k = kitOf(id), fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2;
          // Ground: flat kits (dunes, ponds, mud, wheat, ruins, junk) need one terrace level under the whole footprint; others ≤ 1 level step. Sits on the lowest cell.
          const flat = FLAT_KIT.test(id); let lo = 1e9, hi = -1e9, gmin = 1e9;
          for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH || !free(zz * RW + xx)) return false; const j = zz * RW + xx, l = grid.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; if (H[j] < gmin) gmin = H[j]; }
          if (hi - lo > (flat ? 0 : /^cy_b/.test(id) ? 3 : 1)) return false; // ruined towers may straddle 3 levels (sit on the lowest → half-buried, jumbled)
          const ex = extOf(k); if (ex.tilted) { const ax0 = x + (ex[0] - k.W / 2) * EL.K - 2, ax1 = x + (ex[1] - k.W / 2) * EL.K + 2, az0 = z0 + fd - ex[3] * EL.K - 2, az1 = z0 + fd - ex[2] * EL.K + 2; // + 2 px gap to the next piece
            for (let zz = Math.floor(az0 / 2); zz <= Math.ceil(az1 / 2) - 1; zz++) for (let xx = Math.floor(ax0 / 2); xx <= Math.ceil(ax1 / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) return false; const j = zz * RW + xx; if (grid.occ[j] && !(xx >= Math.floor(x0 / 2) && xx <= Math.ceil((x0 + fw) / 2) - 1 && zz >= Math.floor(z0 / 2) && zz <= Math.ceil((z0 + fd) / 2) - 1)) return false; }
            for (let zz = Math.floor(az0 / 2); zz <= Math.ceil(az1 / 2) - 1; zz++) for (let xx = Math.floor(ax0 / 2); xx <= Math.ceil(ax1 / 2) - 1; xx++) grid.occ[zz * RW + xx] = 3; }
          for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) grid.occ[zz * RW + xx] = 3;
          gen.push({ id: tag, type: 'gen', kit: id, settlement: null, nf: true, gyMin: gmin, L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); return true; };
        // Temples + standalone stations join the settlement id masks (own id, t.setList name = label name) → hovering the building pops its label and
        // hovering the label tints the building, like cities.
        for (const e of gen) { const nm = e.temple || (e.stationName && !e.settlement ? e.stationName : null); if (!nm || t.setList.length >= 255) continue; const id = t.setList.push(nm) - 1;
          const x0 = Math.floor((e.x - e.plot.px) / 2), x1 = Math.ceil((e.x + e.plot.px) / 2) - 1, z0 = Math.floor((e.y - e.plot.pb) / 2), z1 = Math.ceil(e.y / 2) - 1;
          for (let z = z0; z <= z1; z++) for (let x = x0; x <= x1; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; sid[z * RW + x] = id; sR[z * RW + x] = id; for (let dz = -8; dz <= 0; dz++) if (z + dz >= 0) sH[(z + dz) * RW + x] = id; stamp(sR, x, z, id, -2, 2, 2); stamp(sH, x, z, id, -8, 2, 2); } } // footprint (+ 8 rows north for the hit mask) forced to own id
        MK('dress0');
        // Trade routes (2026-10-07d, routed at load). Pairs = map/map-paths-trade.json (a → b, label names) ∪ each node's TR.knn nearest nodes (< TR.knnPx),
        // routed shortest-first so later routes merge onto earlier ones (reuse discount) → junctions instead of parallel tracks. A* on the ½-res grid; cell cost:
        // 1 + noise · streets TR.street · settlement mask + TR.town · terrace-edge proximity (3×3 + TR.edge1, else 5×5 + TR.edge2) · mountain-category regions
        // + TR.mountain, pass / canyon + TR.pass · forest land classes + TR.forest (+ TR.forestDark on dark tone), forest-category regions + TR.forestCatC · rail · avoid
        // mask (Muhl Flats + its rock blob) · reused × TR.reuse. Impassable: water (sea, lake AND rivers — no fords), buildings / props, TR.avoidNation (Cyfrolaef).
        // Step costs: terrace step + TR.slope1, ≥ 2 levels + TR.cliff · 60 · Δ (only when no ramp exists). Universal bridges = edges between their approach points (TR.stub px straight out of each end).
        // Settlement ends: source / goal = every street cell of that settlement (multi-source) → trails start / end on the town's outer street. Unroutable pairs
        // and pairs with an end in an avoided nation are dropped (t.tradeStats.fails). Then: unused bridges linked from both ends; TR.special POIs get dark
        // trails (Shadetrail). Drawing: path → 1 px resample → box smoothing (radius TR.smR, TR.smIt passes; a point only moves if it stays passable, on the same
        // terrace and off terrace edges) → small wobble → rut · dirt · rut.
        if (t.trade) { const tq0 = performance.now(), PC = c => grid.cols.push(c) - 1, TC = { dirt: PC([[150, 118, 78], [160, 128, 86]]), rut: PC([[110, 82, 52], [100, 76, 48]]), stone: PC([[152, 148, 138], [128, 124, 116]]), grass: PC([[118, 140, 70], [108, 128, 62]]), ddirt: PC([[74, 60, 52], [66, 54, 46]]), drut: PC([[46, 38, 34], [42, 34, 30]]) };
          const TR = { avoidNation: ['Cyfrolaef'], avoid: ['Muhl Flats'], avoidBiome: ['Rock'], avoidReach: 360, avoidPad: 6, avoidC: 40, street: 0.35, town: 6, rock: 14, squeeze: 30, manSnap: 24, spurR: 280, spurMul: 3, spurMax: 1, slope1: 10, cliff: 60, drop: 22, bank: 6, edge1: 6, edge2: 2.5,
            mountain: 8, mountainCat: ['mountains', 'mountain', 'ridge', 'highlands', 'rocks'], pass: -0.5, passCat: ['pass', 'canyon'], forest: 2.5, forestDark: 1.5, forestCat: ['forest', 'wood', 'thicket', 'boreal forest', 'taiga', 'pines'], forestCatC: 1.5,
            rail: 10, nearRail: 1.2, reuse: 0.5, noise: 1.2, noiseF: 9, hW: 1.3, stub: 10, maxExp: 1500000, linkExp: 500000, knn: 2, knnPx: 520, smR: 14, smIt: 10, kink: 55, jExt: 4, wob: 1, wobL: 55, special: [], block: [] };
          const sm = f => f * f * (3 - 2 * f), vq = (x, z) => { const xi = Math.floor(x), zi = Math.floor(z), fx = sm(x - xi), fz = sm(z - zi); return (hh(xi, zi) * (1 - fx) + hh(xi + 1, zi) * fx) * (1 - fz) + (hh(xi, zi + 1) * (1 - fx) + hh(xi + 1, zi + 1) * fx) * fz; };
          const fi = j => (2 * ((j / RW) | 0) + 1) * t.W + 2 * (j % RW) + 1, lvl = grid.lvl;
          // Avoid mask: avoid-region cells + the connected avoidBiome blob touching them (flood ≤ avoidReach px from the region), dilated avoidPad cells.
          const AV = new Uint8Array(N); if (t.reg && t.regById) { const ids = new Set(Object.values(t.regById).filter(r => TR.avoid.includes(r.name)).map(r => r.id)), P = TR.avoidPad, A0 = new Uint8Array(N), q = [];
            const cls = new Set(((t.land && t.land.classes) || []).filter(c => TR.avoidBiome.includes(c.name)).map(c => c.id)), isB = j => { const c = t.land ? t.land.code[fi(j)] : 255; return c !== 255 && cls.has(c >> 2); };
            let sx = 0, sz = 0; if (ids.size) for (let j = 0; j < N; j++) if (ids.has(t.reg[fi(j)])) { A0[j] = 1; q.push(j); sx += j % RW; sz += (j / RW) | 0; }
            if (q.length) { const cx = sx / q.length, cz = sz / q.length, R2 = (TR.avoidReach / 2) ** 2; for (let h = 0; h < q.length; h++) { const j = q[h], x = j % RW;
                for (const n of [j - 1, j + 1, j - RW, j + RW]) { if (n < 0 || n >= N || A0[n] || !isB(n)) continue; const nx = n % RW, nz = (n / RW) | 0; if ((nx - cx) ** 2 + (nz - cz) ** 2 > R2 || Math.abs(nx - x) > 1) continue; A0[n] = 1; q.push(n); } } }
            for (const j of q) { const x = j % RW, z = (j / RW) | 0; for (let dz = -P; dz <= P; dz++) for (let dx = -P; dx <= P; dx++) { const xx = x + dx, zz = z + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH) AV[zz * RW + xx] = 1; } } }
          // Terrace-edge masks: 1 where the (2r+1)² window spans > 1 level.
          const edgeMask = r => { const mn = new Int16Array(N), mx = new Int16Array(N), E = new Uint8Array(N);
            for (let z = 0; z < RH; z++) for (let x = 0; x < RW; x++) { let lo = 32767, hi = -32768; for (let k = -r; k <= r; k++) { const v = lvl[z * RW + Math.min(RW - 1, Math.max(0, x + k))]; if (v < lo) lo = v; if (v > hi) hi = v; } mn[z * RW + x] = lo; mx[z * RW + x] = hi; }
            for (let z = 0; z < RH; z++) for (let x = 0; x < RW; x++) { let lo = 32767, hi = -32768; for (let k = -r; k <= r; k++) { const j = Math.min(RH - 1, Math.max(0, z + k)) * RW + x; if (mn[j] < lo) lo = mn[j]; if (mx[j] > hi) hi = mx[j]; } E[z * RW + x] = hi > lo ? 1 : 0; } return E; };
          const EG1 = edgeMask(1), EG2 = edgeMask(2), regAdd = new Float32Array(256);
          // Cliff-top mask (2026-10-08): a cell whose 3×3 neighbourhood holds a cell ≥ 2 levels lower (or water / river ≥ 2 levels below) = on a drop-off edge → + TR.drop.
          const DROP = new Uint8Array(N); for (let z = 1; z < RH - 1; z++) for (let x = 1; x < RW - 1; x++) { const j = z * RW + x; if (!grid.dry0[j]) continue; const L0 = lvl[j]; for (let dz = -1; dz <= 1 && !DROP[j]; dz++) for (let dx = -1; dx <= 1; dx++) { const n = j + dz * RW + dx; if (L0 - lvl[n] >= 2) { DROP[j] = 1; break; } } }
          for (const r of Object.values(t.regById || {})) regAdd[r.id & 255] = (TR.mountainCat.includes(r.category) ? TR.mountain : 0) + (TR.passCat.includes(r.category) ? TR.pass : 0) + (TR.forestCat.includes(r.category) ? TR.forestCatC : 0);
          const badNat = new Set(Object.values(t.natById || {}).filter(n => TR.avoidNation.some(q => n.name.includes(q))).map(n => n.id));
          const BLK = new Uint8Array(N); for (const [bx, bz, br] of (TR.block || [])) for (let zz = (bz - br) >> 1; zz <= (bz + br) >> 1; zz++) for (let xx = (bx - br) >> 1; xx <= (bx + br) >> 1; xx++) if (xx >= 0 && zz >= 0 && xx < RW && zz < RH && Math.hypot(xx * 2 - bx, zz * 2 - bz) <= br) BLK[zz * RW + xx] = 1;
          const CB = new Float32Array(N); for (let j = 0; j < N; j++) { const oc = grid.occ[j]; let c;
            if (oc === 1 || oc === 3 || !grid.dry0[j] || badNat.has(grid.nat[j]) || BLK[j]) c = -1; else if (oc === 2) c = TR.street;
            else { const code = t.land ? t.land.code[fi(j)] : 255, cl = code === 255 ? -1 : code >> 2;
              c = Math.max(0.5, 1 + TR.noise * vq((j % RW) / TR.noiseF, ((j / RW) | 0) / TR.noiseF) + (sR[j] ? TR.town : 0) + (EG1[j] ? TR.edge1 : EG2[j] ? TR.edge2 : 0) + (DROP[j] ? TR.drop : 0) + (t.reg ? regAdd[t.reg[fi(j)] & 255] : 0) + (cl === 2 || cl === 3 || cl === 4 ? TR.forest + ((code & 3) === 2 ? TR.forestDark : 0) : 0) + (cl === 6 || cl === 7 || cl === 14 ? TR.rock : 0)); }
            if (c > 0) { if (grid.railHard[j]) c += TR.rail; else if (grid.near13[j]) c += TR.nearRail; if (AV[j]) c += TR.avoidC; } CB[j] = c; }
          // Banks (2026-10-08): no trail on the 1-cell strip along sea / lake / river (it read as running in the water or over the bank wall) except within 7 cells of a
          // bridge end; cells 2–3 away cost + TR.bank. The squeeze fallback can still use the strip where no other land path exists (narrow spits).
          { const WET = j => !grid.dry0[j], NB = new Uint8Array(N); for (const b of (t.brP || [])) for (const E of [b.P[0], b.P[b.P.length - 1]]) { const cx = Math.round(E[0]) >> 1, cz = Math.round(E[1]) >> 1; for (let dz = -7; dz <= 7; dz++) for (let dx = -7; dx <= 7; dx++) { const xx = cx + dx, zz = cz + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH) NB[zz * RW + xx] = 1; } }
            let nb1 = 0; for (let z = 3; z < RH - 3; z++) for (let x = 3; x < RW - 3; x++) { const j = z * RW + x; if (CB[j] < 0 || grid.occ[j] === 2 || NB[j]) continue; let d = 9; for (let dz = -3; dz <= 3 && d > 1; dz++) for (let dx = -3; dx <= 3; dx++) if (WET(j + dz * RW + dx)) d = Math.min(d, Math.max(Math.abs(dx), Math.abs(dz))); if (d <= 1) { CB[j] = -1; nb1++; } else if (d <= 3) CB[j] += TR.bank; } t.bankCells = nb1; }
          // Bridge edges.
          const JP = new Map(), BR = []; for (const b of (t.brP || [])) { const P = b.P, n = P.length; if (n < 2) continue;
            const ends = [[P[0], -1], [P[n - 1], 1]].map(([E, sg]) => { for (let s = TR.stub; s >= 2; s -= 2) { const A = [E[0] + b.ux * sg * s, E[1] + b.uz * sg * s], c = J(Math.round(A[0]), Math.round(A[1])); if (CB[c] >= 0) return { E, A, c }; } return null; });
            if (!ends[0] || !ends[1]) continue; const k = BR.length, cost = Math.hypot(ends[1].A[0] - ends[0].A[0], ends[1].A[1] - ends[0].A[1]) / 2 * 0.8; BR.push({ id: b.id, ends, used: false });
            for (const [i, o] of [[0, 1], [1, 0]]) { const c = ends[i].c; if (!JP.has(c)) JP.set(c, []); JP.get(c).push({ to: ends[o].c, cost, k, from: i }); } }
          // A* from a source list (goal < 0 → Dijkstra to the first cell passing isGoal). Heuristic = octile distance × TR.hW.
          const used = new Uint8Array(N), stp = new Uint32Array(N), G = new Float32Array(N), PAR = new Int32Array(N); let sid0 = 0;
          const DX = [1, -1, 0, 0, 1, 1, -1, -1], DZ = [0, 0, 1, -1, 1, -1, 1, -1], DC = [1, 1, 1, 1, Math.SQRT2, Math.SQRT2, Math.SQRT2, Math.SQRT2];
          const search = (srcs, goal, isGoal, maxExp, skipK, CC = CB) => { const id = ++sid0, gx = goal >= 0 ? goal % RW : 0, gz = goal >= 0 ? (goal / RW) | 0 : 0;
            const hf = j => { if (goal < 0) return 0; const dx = Math.abs(j % RW - gx), dz = Math.abs(((j / RW) | 0) - gz); return (Math.max(dx, dz) + 0.4142 * Math.min(dx, dz)) * TR.hW; };
            const HF = [], HJ = [], push = (f, j) => { let i = HF.length; HF.push(f); HJ.push(j); while (i > 0) { const p = (i - 1) >> 1; if (HF[p] <= f) break; HF[i] = HF[p]; HJ[i] = HJ[p]; i = p; } HF[i] = f; HJ[i] = j; };
            const pop = () => { const j = HJ[0], lf = HF.pop(), lj = HJ.pop(), n = HF.length; if (n) { let i = 0; for (;;) { let c = 2 * i + 1; if (c >= n) break; if (c + 1 < n && HF[c + 1] < HF[c]) c++; if (HF[c] >= lf) break; HF[i] = HF[c]; HJ[i] = HJ[c]; i = c; } HF[i] = lf; HJ[i] = lj; } return j; };
            for (const s of srcs) { stp[s] = id; G[s] = 0; PAR[s] = -1; push(hf(s), s); } let exp = 0;
            while (HF.length) { const fT = HF[0], j = pop(), gj = G[j]; if (fT > gj + hf(j) + 1e-3) continue;
              if (isGoal(j)) { const path = []; for (let k = j; k >= 0; k = PAR[k]) path.push(k); return path.reverse(); }
              if (++exp > maxExp) return null; const x = j % RW, z = (j / RW) | 0, lj = lvl[j];
              for (let q = 0; q < 8; q++) { const xx = x + DX[q], zz = z + DZ[q]; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const n = zz * RW + xx, c = CC[n]; if (c < 0) continue;
                if (q > 3 && (CC[j + DX[q]] < 0 || CC[j + DZ[q] * RW] < 0)) continue;
                const dl = Math.abs(lvl[n] - lj), ng = gj + (used[n] ? c * TR.reuse : c) * DC[q] + (dl === 1 ? TR.slope1 : dl > 1 ? TR.cliff * dl * 60 : 0) /* ≥ 2-level steps (ledges / cliff edges): last resort only (2026-10-08) */;
                if (stp[n] === id && G[n] <= ng) continue; stp[n] = id; G[n] = ng; PAR[n] = j; push(ng + hf(n), n); }
              const jp = JP.get(j); if (jp) for (const e of jp) { if (e.k === skipK) continue; const n = e.to, ng = gj + e.cost; if (stp[n] === id && G[n] <= ng) continue; stp[n] = id; G[n] = ng; PAR[n] = j; push(ng + hf(n), n); } }
            return null; };
          // Nodes: settlement → its street cells; other POIs → nearest passable dry cell (south preferred).
          const lab = {}; for (const l of t.labels) if (l.kind === 'poi') lab[l.name] = l; const setIx = nm => (t.setList ? t.setList.indexOf(nm) : -1);
          const townCells = new Map(); for (let j = 0; j < N; j++) if (grid.occ[j] === 2 && sid[j] && CB[j] >= 0) { const v = sid[j]; if (!townCells.has(v)) townCells.set(v, []); townCells.get(v).push(j); }
          const pass = j => CB[j] >= 0, snap = (x, z, f = pass) => { const cx = Math.round(x) >> 1, cz = Math.round(z) >> 1;
            for (let r = 0; r <= 60; r++) { let best = -1, bd = 1e9; for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) { if (Math.max(Math.abs(dx), Math.abs(dz)) !== r) continue; const xx = cx + dx, zz = cz + dz; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const j = zz * RW + xx; if (!f(j)) continue; const d = dx * dx + dz * dz + (dz < 0 ? 0.5 : 0); if (d < bd) { bd = d; best = j; } }
              if (best >= 0) return best; } return -1; };
          const nodeCache = {}, node = (nm, fb) => { if (nm in nodeCache) return nodeCache[nm]; const l = lab[nm], p = l ? [l.ix, l.iz] : fb; let r = null;
            if (p && !(t.nat && badNat.has(t.nat[Math.round(p[1]) * t.W + Math.round(p[0])]))) { const ti = setIx(nm), tc = ti > 0 ? townCells.get(ti) : null;
              if (tc && tc.length) r = { nm, p, cells: tc, town: ti, aim: snap(p[0], p[1], j => grid.occ[j] === 2 && sid[j] === ti) }; else { const c = snap(p[0], p[1]); if (c >= 0) r = { nm, p, cells: [c], town: 0, aim: c }; } }
            return (nodeCache[nm] = r); };
          const pairs = new Map(), addPair = (x, y, pa, pb, auto) => { if (x === y || (auto && (t.trade.noAuto || []).some(n => n === x || n === y))) return; const k = x < y ? x + '|' + y : y + '|' + x; if (!pairs.has(k)) pairs.set(k, { a: x, b: y, pa, pb, auto: !!auto }); };
          const atP = nm => (nm[0] === '@' ? nm.slice(1).split(',').map(Number) : null), P0 = rt => (rt.pts && rt.pts.length ? rt.pts : null);
          for (const rt of t.trade.routes) addPair(rt.a, rt.b, atP(rt.a) || (P0(rt) && rt.pts[0]), atP(rt.b) || (P0(rt) && rt.pts[rt.pts.length - 1]));
          const names = [...new Set([...pairs.values()].flatMap(p => [p.a, p.b]))].filter(nm => nm[0] !== '@'), pos = {}; for (const p of pairs.values()) { pos[p.a] = pos[p.a] || (lab[p.a] ? [lab[p.a].ix, lab[p.a].iz] : p.pa); pos[p.b] = pos[p.b] || (lab[p.b] ? [lab[p.b].ix, lab[p.b].iz] : p.pb); }
          for (const nm of names) { const p = pos[nm]; names.filter(o => o !== nm).map(o => [o, Math.hypot(pos[o][0] - p[0], pos[o][1] - p[1])]).filter(e => e[1] < TR.knnPx).sort((u, v) => u[1] - v[1]).slice(0, TR.knn).forEach(([o]) => addPair(nm, o, p, pos[o], true)); }
          // Manual (@x,z) pairs route last; each @ end snaps onto the network (trail / street within TR.manSnap px) so drawn trails always join it.
          const isM = p => p.a[0] === '@' || p.b[0] === '@', PL = [...pairs.values()].map(p => ({ ...p, d: Math.hypot(pos[p.a][0] - pos[p.b][0], pos[p.a][1] - pos[p.b][1]) })).sort((u, v) => (isM(u) - isM(v)) || u.d - v.d);
          // Path → pieces split at bridge jumps (tail / head = straight stubs into the deck ends).
          const pieces = []; let routed = 0, links = 0, CBr = null; const fails = [], squeezed = [], autoSkipped = [], MANE = [];
          const run = (path, head, dark) => { const old = path.map(j => used[j]); let cur = { cells: [path[0]], old: [old[0]], head: head || null, tail: null, dark };
            for (let i = 1; i < path.length; i++) { const a = path[i - 1], b = path[i];
              if (Math.abs(b % RW - a % RW) > 1 || Math.abs(((b / RW) | 0) - ((a / RW) | 0)) > 1) { const e = (JP.get(a) || []).find(q => q.to === b); if (e) { const B = BR[e.k], f = B.ends[e.from], g2 = B.ends[1 - e.from]; B.used = true; cur.tail = [f.A, f.E]; pieces.push(cur); cur = { cells: [b], old: [old[i]], head: [g2.E, g2.A], tail: null, dark }; continue; } }
              cur.cells.push(b); cur.old.push(old[i]); } pieces.push(cur); for (const j of path) used[j] = 1; };
          const mCnt = {}; for (const rt of t.trade.routes) for (const nm of [rt.a, rt.b]) if (nm[0] === '@') mCnt[nm] = (mCnt[nm] || 0) + 1;
          // Only chain ENDS (an @ point used by one route) snap onto the network; interior points stay where they were drawn.
          const manNode = (nm, fb) => { const n0 = node(nm, fb); if (!n0 || nm[0] !== '@' || mCnt[nm] > 1) return n0; const p = n0.p, R = TR.manSnap >> 1, cx = Math.round(p[0]) >> 1, cz = Math.round(p[1]) >> 1; let best = -1, bd = 1e9;
              for (let dz = -R; dz <= R; dz++) for (let dx = -R; dx <= R; dx++) { const xx = cx + dx, zz = cz + dz; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const j = zz * RW + xx; if (!(used[j] || grid.occ[j] === 2) || CB[j] < 0) continue; const d = dx * dx + dz * dz; if (d < bd) { bd = d; best = j; } }
              return best >= 0 ? { ...n0, cells: [best], aim: best } : n0; };
          for (const pr of PL) { const man = isM(pr), A = man ? manNode(pr.a, pr.pa) : node(pr.a, pr.pa), B = man ? manNode(pr.b, pr.pb) : node(pr.b, pr.pb); if (!A || !B) { fails.push(pr.a + ' → ' + pr.b + ' (no node)'); continue; } if (A.town && A.town === B.town) continue;
            const isG = B.town ? (j => sid[j] === B.town && grid.occ[j] === 2) : (j => j === B.aim);
            let path = null; if (man && A.cells.length === 1 && !B.town) { /* drawn segment: A* confined to a 5-cell corridor around the drawn line (no detours through towns / around terraces) */ const ax = A.cells[0] % RW, az = (A.cells[0] / RW) | 0, bx = B.aim % RW, bz = (B.aim / RW) | 0, L2 = (bx - ax) ** 2 + (bz - az) ** 2 || 1, CBc = new CB.constructor(N).fill(-1);
              for (let z = Math.min(az, bz) - 5; z <= Math.max(az, bz) + 5; z++) for (let x = Math.min(ax, bx) - 5; x <= Math.max(ax, bx) + 5; x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; const tt = Math.max(0, Math.min(1, ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / L2)); if (Math.hypot(x - ax - tt * (bx - ax), z - az - tt * (bz - az)) <= 5) CBc[z * RW + x] = CB[z * RW + x]; }
              path = search(A.cells, B.aim, isG, TR.maxExp, -1, CBc); }
            if (!path) path = search(A.cells, B.aim, isG, TR.maxExp, -1);
            // Fallback: a pair boxed in by buildings / props (dry land, not water / avoided nation) may squeeze past them at cost TR.squeeze per cell → never left unconnected.
            if (!path) { if (!CBr) { CBr = CB.slice(); for (let j = 0; j < N; j++) if (CBr[j] < 0 && grid.dry0[j] && !badNat.has(grid.nat[j])) CBr[j] = TR.squeeze; } path = search(A.cells, B.aim, isG, TR.maxExp, -1, CBr); if (path) squeezed.push(pr.a + ' → ' + pr.b); }
            if (path) { routed++; if (man) MANE.push(path[0], path[path.length - 1]); run(path); } else (pr.auto ? autoSkipped : fails).push(pr.a + ' → ' + pr.b); } // auto = nearest-neighbour extra (not in the routes file): no land path → skipped, not a failure
          const net = j => used[j] || grid.occ[j] === 2;
          for (let k = 0; k < BR.length; k++) { const B = BR[k]; if (B.used) continue; for (const en of B.ends) { const path = search([en.c], -1, j => j !== en.c && grid.occ[j] === 2 && sid[j] > 0, 900, k) || search([en.c], -1, j => j !== en.c && net(j), TR.linkExp, k); /* town street within reach first: isle bridges join their town, not a far trail */ if (path) { links++; run(path, [en.E, en.A]); } } }
          // Orphan towns (2026-10-08): union-find over trail cells (8-neighbour, bridge stub cells joined to the far end); each town = a hub joining every trail
          // cell within 2 cells of its own streets. Towns whose hub shares no component with another town (no authored route, nearest town beyond TR.knnPx, or only a
          // trail that stops short of the streets — e.g. Rasaido) get one trail from their streets to the nearest trail cell outside their component. noAuto towns skipped.
          const orphanLinks = []; { const NOA0 = new Set(t.setList.map((n, i) => (t.trade.noAuto || []).includes(n) ? i : -1).filter(v => v > 0));
            const TC = k => !!used[k] && grid.occ[k] !== 2; // trail cells only (a path's street cells are marked used too, but streets are no trail)
            const build = () => { const P = new Int32Array(N).fill(-1), f = a => { while (P[a] !== a) { P[a] = P[P[a]]; a = P[a]; } return a; }, un = (a, b) => { a = f(a); b = f(b); if (a !== b) P[a] = b; };
              for (let k = 0; k < N; k++) if (TC(k)) P[k] = k; for (let k = 0; k < N; k++) { if (!TC(k)) continue; const x = k % RW, z = (k / RW) | 0; for (const [dx, dz] of [[1, 0], [0, 1], [1, 1], [-1, 1]]) { const xx = x + dx, zz = z + dz; if (xx >= 0 && xx < RW && zz < RH && TC(zz * RW + xx)) un(k, zz * RW + xx); } }
              const near1 = c0 => { const x = c0 % RW, z = (c0 / RW) | 0; for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const k = (z + dz) * RW + x + dx; if (k >= 0 && k < N && TC(k)) return k; } return -1; };
              for (const B of BR) if (B.ends && B.ends.length === 2) { const a = near1(B.ends[0].c), b = near1(B.ends[1].c); if (a >= 0 && b >= 0) un(a, b); }
              const hub = new Map(); for (const [tid, tc] of townCells) { const st = tc.filter(k => grid.occ[k] === 2); let r = -1; for (const k0 of (st.length ? st : tc)) { const x = k0 % RW, z = (k0 / RW) | 0; for (let dz = -2; dz <= 2; dz++) for (let dx = -2; dx <= 2; dx++) { const k = (z + dz) * RW + x + dx; if (k >= 0 && k < N && TC(k)) { if (r < 0) r = k; else un(r, k); } } } hub.set(tid, r); }
              const cnt = new Map(); for (const [tid, r] of hub) if (r >= 0) { const q = f(r); cnt.set(q, (cnt.get(q) || 0) + 1); } return { f, hub, cnt }; };
            for (let pass = 0; pass < 3; pass++) { const { f, hub, cnt } = build(), main = [...cnt].sort((a, b) => b[1] - a[1])[0], P0ok = k => !main || f(k) === main[0] || cnt.get(f(k)) > 1; /* link into a component that already holds ≥ 2 towns */ let any = false;
              for (const [tid, tc] of townCells) { if (NOA0.has(tid) || !tc.length) continue; const r = hub.get(tid), root = r >= 0 ? f(r) : -1; if (root >= 0 && cnt.get(root) > 1) continue;
                const path = search(tc, -1, k => TC(k) && P0ok(k) && (root < 0 || f(k) !== root), TR.maxExp, -1); if (path) { run(path); routed++; for (const k of path) used[k] = used[k] || 1; orphanLinks.push(t.setList[tid]); any = true; } else if (pass === 2) autoSkipped.push(t.setList[tid] + ' (orphan, no land path)'); }
              if (!any) break; } }
          // Detour spurs (2026-10-07e): per settlement, trail cells ≤ TR.spurR px away whose network distance (BFS over trails + streets from the town) is
          // > TR.spurMul × straight distance (or unreachable) → nearest such cell per 45° sector; ≤ TR.spurMax spurs per town, nearest first, path ≤ 1.7 × straight.
          let spurs = 0; { const ND = new Int32Array(N).fill(-1), Rc = TR.spurR >> 1;
            const NOA = new Set(t.setList.map((n, i) => (t.trade.noAuto || []).includes(n) ? i : -1).filter(v => v > 0)); /* every id named so (isle quarters share the name) */ for (const [tid, tc] of townCells) { if (NOA.has(tid)) continue; const q = tc.slice(); for (const j of q) ND[j] = 0; const lim = Math.ceil(Rc * TR.spurMul);
              for (let h = 0; h < q.length; h++) { const j = q[h], d = ND[j]; if (d >= lim) continue; const x = j % RW; for (let k = 0; k < 8; k++) { const xx = x + DX[k]; if (xx < 0 || xx >= RW) continue; const n = j + DX[k] + DZ[k] * RW; if (n < 0 || n >= N || ND[n] >= 0 || !net(n)) continue; ND[n] = d + 1; q.push(n); } }
              let sx = 0, sz = 0; for (const j of tc) { sx += j % RW; sz += (j / RW) | 0; } const cx = Math.round(sx / tc.length), cz = Math.round(sz / tc.length), best = [];
              for (let dz = -Rc; dz <= Rc; dz += 2) for (let dx = -Rc; dx <= Rc; dx += 2) { const r = Math.hypot(dx, dz); if (r < 14 || r > Rc) continue; const xx = cx + dx, zz = cz + dz; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const n = zz * RW + xx; if (!used[n] || sid[n]) continue;
                const nd = ND[n]; if (nd >= 0 && nd <= TR.spurMul * r) continue; const sc = Math.floor((Math.atan2(dz, dx) + Math.PI) / (Math.PI / 4)) % 8; if (!best[sc] || r < best[sc].r) best[sc] = { n, r }; }
              for (const j of q) ND[j] = -1; let made = 0;
              for (const c of best.filter(Boolean).sort((a, b) => a.r - b.r)) { if (made >= TR.spurMax) break; const path = search(tc, c.n, j => j === c.n, TR.linkExp, -1); if (path && path.length <= 1.7 * c.r + 6) { run(path); made++; spurs++; } } } }
          // Special trails: branches from the POI to the network; each later branch may not reuse the earlier ones (cells blocked ± 2) → a trail through the POI.
          // Maze (Shadetrail): inside the 'shadetrail' foliage ellipse, cell cost = 1 + 6 · noise(3.5 cells)² (wiggly); nodes = the POI + sp.nodes points ≥ 18 px apart;
          // each node → its sp.knn nearest (shared cells merge → branching tangle); the sp.exits nodes nearest the rim link out to the normal network. All dark.
          const mazeOf = sp => { const l = lab[sp.at], Z = (ME.FOLIAGE_ZONES || []).find(z => z.id === 'shadetrail' && z.ell), E = Z && Z.ell; if (!l || !E) return false;
            const ex = l.ix + E.dx, ez = l.iz + E.dz, inE = (x, z) => ((x - ex) / E.rx) ** 2 + ((z - ez) / E.rz) ** 2 <= 1, saved = [];
            for (let z = Math.floor((ez - E.rz) / 2); z <= Math.ceil((ez + E.rz) / 2); z++) for (let x = Math.floor((ex - E.rx) / 2); x <= Math.ceil((ex + E.rx) / 2); x++) { if (x < 0 || z < 0 || x >= RW || z >= RH) continue; const j = z * RW + x; if (CB[j] < 0 || !inE(x * 2 + 1, z * 2 + 1)) continue; saved.push([j, CB[j]]); CB[j] = 1 + 6 * vq(x / 3.5 + 50, z / 3.5 + 50) ** 2; }
            const nodes = [snap(l.ix, l.iz)].filter(c => c >= 0); for (let k = 0; k < 600 && nodes.length < sp.nodes + 1; k++) { const a = hh(k, 991) * 6.283, r = Math.sqrt(hh(k, 992)) * 0.9, c = J(Math.round(ex + Math.cos(a) * r * E.rx), Math.round(ez + Math.sin(a) * r * E.rz));
              if (CB[c] < 0 || nodes.some(n => Math.hypot(n % RW - c % RW, ((n / RW) | 0) - ((c / RW) | 0)) < 9)) continue; nodes.push(c); }
            const d2 = (a, b) => (a % RW - b % RW) ** 2 + (((a / RW) | 0) - ((b / RW) | 0)) ** 2, done = new Set();
            for (const a of nodes) for (const b of nodes.filter(b => b !== a).sort((p, q) => d2(a, p) - d2(a, q)).slice(0, sp.knn)) { const k = Math.min(a, b) + '|' + Math.max(a, b); if (done.has(k)) continue; done.add(k); const path = search([a], b, j => j === b, TR.linkExp, -1); if (path) run(path, null, true); }
            const rim = n => ((n % RW * 2 - ex) / E.rx) ** 2 + ((((n / RW) | 0) * 2 - ez) / E.rz) ** 2;
            for (const a of nodes.slice().sort((p, q) => rim(q) - rim(p)).slice(0, sp.exits)) { const path = search([a], -1, j => net(j) && !inE((j % RW) * 2 + 1, ((j / RW) | 0) * 2 + 1), TR.linkExp, -1); if (path) run(path, null, true); }
            for (let i = saved.length - 1; i >= 0; i--) CB[saved[i][0]] = saved[i][1]; t.mazeNodes = nodes.length; return true; };
          for (const sp of TR.special) { if (sp.maze && mazeOf(sp)) continue; const l = lab[sp.at]; if (!l) continue; const s = snap(l.ix, l.iz); if (s < 0) continue; const saved = [];
            for (let bI = 0; bI < sp.branches; bI++) { const path = search([s], -1, j => j !== s && net(j), TR.linkExp * 2, -1); if (!path) break; run(path, null, sp.dark);
              for (const j of path) { const x = j % RW, z = (j / RW) | 0; if (Math.hypot(x - (s % RW), z - ((s / RW) | 0)) < 8) continue; for (let dz = -2; dz <= 2; dz++) for (let dx = -2; dx <= 2; dx++) { const n = (z + dz) * RW + x + dx; if (n >= 0 && n < N && CB[n] >= 0) { saved.push([n, CB[n]]); CB[n] = -1; } } } }
            for (let i = saved.length - 1; i >= 0; i--) CB[saved[i][0]] = saved[i][1]; }
          // Paint.
          const isDirt = c => c === TC.dirt || c === TC.ddirt, isRut = c => c === TC.rut || c === TC.drut;
          // Bridge-deck mask: cells under a universal bridge deck (± bw + 1 px) are never painted (trail stubs end at the deck; no track drawn under the bridge).
          const BM = new Uint8Array(N); for (const b of (t.brP || [])) { const P = b.P; for (let i = 0; i < P.length; i++) for (let w = -(UBR.bw + 1); w <= UBR.bw + 1; w += 1) { const j = J(Math.round(P[i][0] - b.uz * w), Math.round(P[i][1] + b.ux * w)); if (j >= 0) BM[j] = 1; } } t.brMask = BM;
          const pnt = (x, z, code) => { const xx = Math.round(x) >> 1, zz = Math.round(z) >> 1; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) return; const j = zz * RW + xx; if (BM[j]) return; const p0 = grid.paint[j];
            if (!grid.dry0[j] || grid.occ[j] === 1 || grid.occ[j] === 3 || grid.railHard[j] || (p0 && p0 < TC.dirt)) return; if (isRut(code) && isDirt(p0)) return; grid.paint[j] = code; grid.occ[j] = grid.occ[j] || 2; };
          const cellOf = (x, z) => J(Math.round(x), Math.round(z)), okAt = (x, z, l0, e0) => { const j = cellOf(x, z); return (CB[j] >= 0 || used[j]) && lvl[j] === l0 && (!EG1[j] || e0); }; // may cut across trail cells (rounder junction corners)
          const smooth = raw => { let P = raw.length > 1 ? resample(raw, 1) : raw.slice(); const n = P.length, L0 = P.map(p => lvl[cellOf(p[0], p[1])]), E0 = P.map(p => EG1[cellOf(p[0], p[1])]);
            for (let it = 0; it < TR.smIt; it++) { const Q = P.map(p => p.slice()); for (let i = 1; i < n - 1; i++) { const r = Math.min(TR.smR, i, n - 1 - i); let sx = 0, sz = 0; for (let k = -r; k <= r; k++) { sx += P[i + k][0]; sz += P[i + k][1]; }
              const x = sx / (2 * r + 1), z = sz / (2 * r + 1); if (okAt(x, z, L0[i], E0[i])) Q[i] = [x, z]; } P = Q; } return { P, L0, E0 }; };
          // Unkink (2026-10-07): no corner sharper than TR.kink° (heading change between the 6 px before and after a point). The sharpest point of each corner is
          // replaced over ±r px (r 8 → 48): a big detour (path > 1.5 × chord) by the straight chord, otherwise a quadratic curve with the corner as control point.
          // Accepted only when every new px is passable, on a terrace level the original stretch already used, and never steps ≥ 2 levels between neighbours (2026-10-08: cut corners used to run off ledges). Repeats ≤ 6 passes.
          const DECK = new Uint8Array(N); for (const br of (t.brP || [])) for (const p of br.P) for (let dz = -3; dz <= 3; dz += 1) for (let dx = -3; dx <= 3; dx += 1) { const j = cellOf(p[0] + dx, p[1] + dz); if (j >= 0) DECK[j] = 1; } // bridge decks count as passable for unkink
          const unkink = (P, L0, E0) => { const W = 6, TH = TR.kink * Math.PI / 180; let fixed = 0;
            const ang = i => { const ax = P[i][0] - P[i - W][0], az = P[i][1] - P[i - W][1], bx = P[i + W][0] - P[i][0], bz = P[i + W][1] - P[i][1]; return Math.abs(Math.atan2(ax * bz - az * bx, ax * bx + az * bz)); };
            for (let pass = 0; pass < 6; pass++) { let any = false;
              for (let i = W; i < P.length - W; i++) { if (ang(i) <= TH) continue; let m = i; for (let k = i + 1; k < Math.min(P.length - W, i + 2 * W); k++) if (ang(k) > ang(m)) m = k; let done = false;
                for (let r = 8; r <= 64 && !done; r += 4) { const a = Math.max(0, m - r), b = Math.min(P.length - 1, m + r); if (m - a < 3 || b - m < 3) break; const own = new Set(); for (let k = a; k <= b; k++) own.add(cellOf(P[k][0], P[k][1])); let lo = 1e9, hi = -1e9; for (let k = a; k <= b; k++) { const j = cellOf(P[k][0], P[k][1]); if (j >= 0) { lo = Math.min(lo, lvl[j]); hi = Math.max(hi, lvl[j]); } }
                  const A = P[a], C = P[m], B = P[b], chord = Math.hypot(B[0] - A[0], B[1] - A[1]), S = [];
                  if (b - a > 1.5 * chord) { S.push([A[0], A[1]], [B[0], B[1]]); } else for (let q = 0; q <= 4 * r; q++) { const u = q / (4 * r), w0 = (1 - u) * (1 - u), w1 = 2 * u * (1 - u), w2 = u * u; S.push([w0 * A[0] + w1 * C[0] + w2 * B[0], w0 * A[1] + w1 * C[1] + w2 * B[1]]); }
                  const R2 = resample(S, 1); let ok = R2.length >= 2, pj = -1; if (ok) for (const p of R2) { const j = cellOf(p[0], p[1]); if (j < 0 || !(CB[j] >= 0 || used[j] || DECK[j] || own.has(j)) || lvl[j] < lo || lvl[j] > hi || (pj >= 0 && Math.abs(lvl[j] - lvl[pj]) > 1 && !DECK[j] && !DECK[pj])) { ok = false; break; } pj = j; }
                  if (!ok) continue; P.splice(a, b - a + 1, ...R2); L0.splice(a, b - a + 1, ...R2.map(() => -1)); E0.splice(a, b - a + 1, ...R2.map(() => 1)); done = true; any = true; fixed++; i = Math.max(W, a + R2.length - 1); }
                if (!done) i += W; }
              if (!any) break; }
            return { P, L0, E0, fixed }; };
          // Merge (2026-10-07e): a route only draws the cells no earlier route used (runs), each run extended TR.jExt cells into the shared trail (curve blends into it); that junction end snaps
          // to the earlier trail's drawn centre line (CLX / CLZ, ≤ 5 cells) and gets a dirt disc → one clean painted junction, no doubled parallel tracks.
          // Dead-end prune (2026-10-07): union of all route cells, thinned (simple-point removal) + leaf-eroded back to junctions; anchored at destination
          // cells (named nodes) and bridge ends. Cells left only on spurs that lead nowhere are dropped from the pieces before drawing.
          { const U = new Uint8Array(N), TM = new Uint8Array(N); for (const pc of pieces) { for (const j of pc.cells) U[j] = 1; if (pc.head) TM[pc.cells[0]] = 1; if (pc.tail) TM[pc.cells[pc.cells.length - 1]] = 1; }
            for (const nm in nodeCache) { const r = nodeCache[nm]; if (r && nm[0] !== '@') for (const j of r.cells) TM[j] = 1; } for (const [, tc] of townCells) for (const j of tc) TM[j] = 1; /* every town's streets anchor (2026-10-08: towns without a route pair, e.g. Rasaido, lost their link to erosion) */ for (const j of MANE) TM[j] = 1; /* drawn (manual) route ends are anchors: user trails never pruned */ // drawn-chain ends are anchors too (user trails never pruned)
            const OF = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]], nb = j => { const x = j % RW, z = (j / RW) | 0, o = []; for (const [dx, dz] of OF) { const xx = x + dx, zz = z + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH && U[zz * RW + xx]) o.push([dx, dz]); } return o; };
            const simple = o => { if (o.length <= 1) return true; const seen = [0], q = [0]; while (q.length) { const a = o[q.pop()]; o.forEach((b, k) => { if (!seen.includes(k) && Math.abs(a[0] - b[0]) <= 1 && Math.abs(a[1] - b[1]) <= 1) { seen.push(k); q.push(k); } }); } return seen.length === o.length; };
            const Q = []; for (let j = 0; j < N; j++) if (U[j]) Q.push(j); let qi = 0, it = 0;
            while (qi < Q.length && it < 4e6) { it++; const j = Q[qi++]; if (!U[j] || TM[j]) continue; const o = nb(j); if (!simple(o)) continue; U[j] = 0; const x = j % RW, z = (j / RW) | 0; for (const [dx, dz] of o) Q.push((z + dz) * RW + x + dx); }
            const K = j => { const x = j % RW, z = (j / RW) | 0; for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx, zz = z + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH && U[zz * RW + xx]) return true; } return false; };
            let cut = 0; const P2 = []; for (const pc of pieces) { let seg = null; const n = pc.cells.length; for (let i = 0; i < n; i++) { const j = pc.cells[i]; if (K(j)) { if (!seg) seg = { cells: [], old: [], head: i === 0 ? pc.head : null, tail: null, dark: pc.dark }; seg.cells.push(j); seg.old.push(pc.old[i]); if (i === n - 1) seg.tail = pc.tail; } else { cut++; if (seg) { if (seg.cells.length > 1) P2.push(seg); seg = null; } } }
              if (seg && seg.cells.length > 1) P2.push(seg); } pieces.length = 0; pieces.push(...P2); t.tradePruned = cut; }
          const runs = []; for (const pc of pieces) { const n = pc.cells.length; let i = 0; while (i < n) { if (pc.old[i]) { i++; continue; } let e = i; while (e + 1 < n && !pc.old[e + 1]) e++;
            const a = Math.max(0, i - TR.jExt), b = Math.min(n - 1, e + TR.jExt); runs.push({ cells: pc.cells.slice(a, b + 1), jA: a < i, jB: b > e, head: i === 0 ? pc.head : null, tail: e === n - 1 ? pc.tail : null, dark: pc.dark }); i = e + 1; } }
          const CLX = new Float32Array(N).fill(-1), CLZ = new Float32Array(N), snapCL = p => { const cx = Math.round(p[0]) >> 1, cz = Math.round(p[1]) >> 1; let best = null, bd = 1e9;
            for (let dz = -5; dz <= 5; dz++) for (let dx = -5; dx <= 5; dx++) { const xx = cx + dx, zz = cz + dz; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const j = zz * RW + xx; if (CLX[j] < 0) continue; const d = (CLX[j] - p[0]) ** 2 + (CLZ[j] - p[1]) ** 2; if (d < bd) { bd = d; best = [CLX[j], CLZ[j]]; } } return best || p; };
          // Trail scatter (2026-10-07): pebbles / half-buried stones on the tread (every 9 px), grass tufts at the edges (grassy / dry / mud, every 5 px), rare dropped wheel / sack / plank.
          // tprop: footprint may be trail cells (not buildings / walls / rail / bridge decks), ≤ 1 level; sits on the lowest cell, dropped TR_CARVE terrace when centred on a trail cell.
          const TGR2 = new Uint8Array(64); for (const q of ((t.land && t.land.classes) || [])) TGR2[q.id] = (name => /snow|ice/i.test(name) ? 4 : /sand|beach/i.test(name) ? 2 : /rock|stony/i.test(name) ? 3 : /mud/i.test(name) ? 5 : /magma|lava/i.test(name) ? 6 : /dry|wheat/i.test(name) ? 1 : 0)(q.name); const TGc = (x, z) => { const xi = Math.max(0, Math.min(t.W - 1, Math.round(x))), zi = Math.max(0, Math.min(t.H - 1, Math.round(z))), cd = t.land ? t.land.code[zi * t.W + xi] : 255; return cd === 255 ? 0 : TGR2[cd >> 2]; };
          const trSet = new Set(Object.values(TC)), tprop = (id, x, z, tag) => { const k = kitOf(id), fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2; let lo = 1e9, hi = -1e9, gmin = 1e9;
            for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) return false; const j = zz * RW + xx, p0 = grid.paint[j];
              if (!grid.dry0[j] || grid.occ[j] === 1 || grid.occ[j] === 3 || grid.railHard[j] || BM[j] || (p0 && !trSet.has(p0))) return false; const l = grid.lvl[j]; if (l < lo) lo = l; if (l > hi) hi = l; if (H[j] < gmin) gmin = H[j]; }
            if (hi - lo > 0) return false; const jc = J(Math.round(x), Math.round(z)), on = jc >= 0 && trSet.has(grid.paint[jc]);
            gen.push({ id: tag, type: 'gen', kit: id, settlement: null, nf: true, gyRaw: Math.max(WATER_H + T, Math.round(gmin / T) * T) - (on ? 0.15 * T : 0), L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); return true; };
          // Pass 1 (2026-10-07): centre lines for every run (smooth → bridge stubs → unkink), then prune dead spurs, then paint (pass 2).
          let kinksFixed = 0; const LNS = runs.map(pc => { const raw = pc.cells.map(j => [(j % RW) * 2 + 1, ((j / RW) | 0) * 2 + 1]); if (pc.jA) raw[0] = snapCL(raw[0]); if (pc.jB) raw[raw.length - 1] = snapCL(raw[raw.length - 1]); const sm2 = smooth(raw); let line = sm2.P, L0 = sm2.L0, E0 = sm2.E0;
            if (pc.head) { const h = resample(pc.head, 1); line = h.concat(line); L0 = h.map(() => -1).concat(L0); E0 = h.map(() => 1).concat(E0); } if (pc.tail) { const tl = resample(pc.tail, 1); line = line.concat(tl); L0 = L0.concat(tl.map(() => -1)); E0 = E0.concat(tl.map(() => 1)); }
            for (let it = 0; it < 6; it++) { let ch = false; for (let i = 1; i < line.length - 1; i++) { const ax = line[i][0] - line[i - 1][0], az = line[i][1] - line[i - 1][1], bx = line[i + 1][0] - line[i][0], bz = line[i + 1][1] - line[i][1], p3 = line[Math.max(0, i - 3)], q3 = line[Math.min(line.length - 1, i + 3)], dv = Math.hypot(line[i][0] - (p3[0] + q3[0]) / 2, line[i][1] - (p3[1] + q3[1]) / 2), gap = Math.hypot(line[i + 1][0] - line[i - 1][0], line[i + 1][1] - line[i - 1][1]); if (gap <= 3 && (ax * bx + az * bz < 0 || (Math.abs(ax) + Math.abs(az) < 0.05) || dv > 2.6)) { line.splice(i, 1); L0.splice(i, 1); E0.splice(i, 1); ch = true; i--; } } if (!ch) break; } // despike: drop points that step backwards or sit > 2.6 px off the chord of their ±3 neighbours (stub / snap joins) — only where the neighbours stay ≤ 3 px apart (2026-10-08: unguarded, it ate whole stretches, e.g. Hafna → Aliunu)
            const uk = unkink(line, L0, E0); kinksFixed += uk.fixed; line = uk.P; L0 = uk.L0; E0 = uk.E0; { const P2 = [line[0]], A2 = [L0[0]], B2 = [E0[0]]; for (let q = 1; q < line.length; q++) { const g = Math.hypot(line[q][0] - line[q - 1][0], line[q][1] - line[q - 1][1]), m = Math.ceil(g / 1.5); for (let s2 = 1; s2 < m; s2++) { const f = s2 / m; P2.push([line[q - 1][0] + (line[q][0] - line[q - 1][0]) * f, line[q - 1][1] + (line[q][1] - line[q - 1][1]) * f]); A2.push(L0[q]); B2.push(E0[q]); } P2.push(line[q]); A2.push(L0[q]); B2.push(E0[q]); } line = P2; L0 = A2; E0 = B2; } /* fill gaps > 1.5 px (straight) */ { const LVc = (p) => { const j = cellOf(p[0], p[1]); return j >= 0 ? lvl[j] : 0; }, deckAt = p => { const j = cellOf(p[0], p[1]); return j >= 0 && DECK[j]; }; for (let i = 1; i < line.length; i++) { if (deckAt(line[i]) || deckAt(line[i - 1]) || Math.abs(LVc(line[i]) - LVc(line[i - 1])) < 2) continue; let best = null, bd = 7; for (const q of raw) { const d = Math.hypot(q[0] - line[i][0], q[1] - line[i][1]); if (d < bd && Math.abs(LVc(q) - LVc(line[i - 1])) < 2) { bd = d; best = q; } } if (best) line[i] = [best[0], best[1]]; } } /* ledge guard: a smoothed / stub point that lands ≥ 2 levels off its neighbour snaps back onto the A* cell path */ for (let it = 0; it < 8; it++) { let ch = false; for (let i = 2; i < line.length - 2; i++) { const p = line[i - 2], q = line[i], r = line[i + 2], ax = q[0] - p[0], az = q[1] - p[1], bx = r[0] - q[0], bz = r[1] - q[1], la = Math.hypot(ax, az), lb = Math.hypot(bx, bz); if (la < 1e-3 || lb < 1e-3 || (ax * bx + az * bz) / (la * lb) < -0.2) { if (Math.hypot(line[i + 1][0] - line[i - 1][0], line[i + 1][1] - line[i - 1][1]) <= 3) { line.splice(i, 1); L0.splice(i, 1); E0.splice(i, 1); ch = true; i--; } } } if (!ch) break; } /* hook removal: > 100° heading flip over ± 2 points (tiny zig-zags at snap joins) */ { const P2 = [line[0]], A2 = [L0[0]], B2 = [E0[0]]; for (let q = 1; q < line.length; q++) { const g = Math.hypot(line[q][0] - line[q - 1][0], line[q][1] - line[q - 1][1]), m = Math.ceil(g / 1.5); for (let s2 = 1; s2 < m; s2++) { const f = s2 / m; P2.push([line[q - 1][0] + (line[q][0] - line[q - 1][0]) * f, line[q - 1][1] + (line[q][1] - line[q - 1][1]) * f]); A2.push(L0[q]); B2.push(E0[q]); } P2.push(line[q]); A2.push(L0[q]); B2.push(E0[q]); } line = P2; L0 = A2; E0 = B2; } /* gap fill again (ledge guard may move points) */ for (const p of line) { const j = cellOf(p[0], p[1]); if (j >= 0) { CLX[j] = p[0]; CLZ[j] = p[1]; } } const A0 = line[0], B0 = line[line.length - 1], ext = line.reduce((m, p) => Math.max(m, Math.hypot(p[0] - A0[0], p[1] - A0[1])), 0); return { line, L0, E0, cut: ext < 4 && Math.hypot(B0[0] - A0[0], B0[1] - A0[1]) < 4 }; }); // degenerate loops (< 4 px) dropped
          // Ramps (2026-10-08): wherever a trail still steps ≥ 2 terrace levels between neighbouring points (steep hillside, cliff-top town edge), the terrain under it
          // is regraded into a ramp: over ± 3 px per level of the step, target level runs linearly from the low side to the high side; the trail cells and their
          // 8 neighbours (not buildings, walls, rail, water, bridge decks) are set to it. Max 1 level between neighbouring trail points afterwards. t.trailRamps = count.
          // Bridge-end trims (2026-10-08): a trail end that still touches water (≤ 1 cell) next to a bridge (end ≤ 16 px away) is shortened point by point until it
          // doesn't — the deck / abutment covers the last px, coaches hop onto the bridge line from ≤ 14 px. → 0 trail px on or beside water.
          { const BE = (t.brP || []).flatMap(b => [b.P[0], b.P[b.P.length - 1]]), wetN = p => { const j = cellOf(p[0], p[1]); if (j < 0) return false; const x = j % RW, z = (j / RW) | 0; for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx, zz = z + dz; if (xx >= 0 && zz >= 0 && xx < RW && zz < RH && !grid.dry0[zz * RW + xx]) return true; } return false; };
            let nT = 0; for (const R0 of LNS) { if (R0.cut) continue; for (const end of [0, 1]) { let guard = 0; while (R0.line.length > 12 && guard++ < 40) { const k = end ? R0.line.length - 1 : 0, p = R0.line[k]; if (!wetN(p) || !BE.some(q => Math.hypot(q[0] - p[0], q[1] - p[1]) < 16)) break; if (end) { R0.line.pop(); R0.L0.pop(); R0.E0.pop(); } else { R0.line.shift(); R0.L0.shift(); R0.E0.shift(); } nT++; } } } t.bridgeTrims = nT; }
          const rampPass = () => { let nR = 0; const HL = j => Math.round(H[j] / T), lvAt = p => { const j = cellOf(p[0], p[1]); return j >= 0 ? HL(j) : 0; }, /* rendered level (H), not grid.lvl: street plots can differ */ setL = (j, L) => { if (j < 0 || grid.occ[j] === 1 || grid.occ[j] === 3 || !grid.dry0[j] || (grid.railHard && grid.railHard[j]) || DECK[j]) return; lvl[j] = L; H[j] = L * T; };
            for (let pass = 0; pass < 4; pass++) { const nR0 = nR; for (const R0 of LNS) { const P = R0.line; for (let i = 1; i < P.length; i++) { const a = lvAt(P[i - 1]), b = lvAt(P[i]), ja = cellOf(P[i - 1][0], P[i - 1][1]), jb = cellOf(P[i][0], P[i][1]); if (Math.abs(b - a) < 2 || DECK[ja] || DECK[jb]) continue;
                const lo = Math.min(a, b), hi = Math.max(a, b), W = Math.ceil((3 + pass * 2) * (hi - lo)), i0 = Math.max(0, i - W), i1 = Math.min(P.length - 1, i + W), L0v = lvAt(P[i0]), L1v = lvAt(P[i1]); nR++;
                for (let k = i0; k <= i1; k++) { const f = (k - i0) / Math.max(1, i1 - i0), L = Math.round(L0v + (L1v - L0v) * f), j = cellOf(P[k][0], P[k][1]); if (j < 0) continue; const x = j % RW, z = (j / RW) | 0;
                  for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) { const xx = x + dx, zz = z + dz; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const n = zz * RW + xx; if (dx || dz) { if (Math.abs(HL(n) - L) <= 1) continue; } setL(n, dx || dz ? (HL(n) > L ? L + 1 : L - 1) : L); } }
                i = i1; } } if (nR === nR0) break; } t.trailRamps = (t.trailRamps || 0) + nR; }; /* passes widen the ramp (3 → 9 px per level) until no step ≥ 2 is left */ rampPass(); t.__ramp = rampPass; /* re-run after plot flattening (prepEls end): building plots re-level the street beside them */
          // Dead spurs: a line end that touches no other line (8 px), no settlement / street (8 px), no bridge end (12 px) and no capital / city / POI label (40 px)
          // leads nowhere (e.g. a trail running off into a lake) → the whole line is dropped; repeated until stable (a chain of spur pieces goes back to its junction).
          { const LG = new Map(), LK = (x, z) => (Math.round(x) >> 3) * 4096 + (Math.round(z) >> 3); LNS.forEach((R0, li) => R0.line.forEach(p => { const k = LK(p[0], p[1]); if (!LG.has(k)) LG.set(k, new Set()); LG.get(k).add(li); }));
            const BE = (t.brP || []).flatMap(b => [b.P[0], b.P[b.P.length - 1]]), DEST = (t.labels || []).filter(l => l.type === 'capital' || l.type === 'city' || l.type === 'poi');
            const live = (p, li) => { for (let dz = -8; dz <= 8; dz += 8) for (let dx = -8; dx <= 8; dx += 8) { const S = LG.get(LK(p[0] + dx, p[1] + dz)); if (S) for (const lj of S) if (lj !== li && !LNS[lj].cut && LNS[lj].line.some(q => Math.abs(q[0] - p[0]) < 8 && Math.abs(q[1] - p[1]) < 8 && Math.hypot(q[0] - p[0], q[1] - p[1]) < 8)) return true; }
              for (let dz = -8; dz <= 8; dz += 2) for (let dx = -8; dx <= 8; dx += 2) { const j = cellOf(p[0] + dx, p[1] + dz); if (j >= 0 && (sid[j] || grid.occ[j] === 2)) return true; }
              return BE.some(q => Math.hypot(q[0] - p[0], q[1] - p[1]) < 12) || DEST.some(l => Math.hypot(l.ix - p[0], l.iz - p[1]) < 40); };
            const cutL = []; for (let ch = true; ch;) { ch = false; LNS.forEach((R0, li) => { if (R0.cut || R0.line.length < 2) return; const A = R0.line[0], B = R0.line[R0.line.length - 1]; if (!live(A, li) || !live(B, li)) { R0.cut = true; ch = true; cutL.push([Math.round(A[0]), Math.round(A[1]), Math.round(B[0]), Math.round(B[1])]); } }); }
            t.tradeCut = cutL; t.tradeKinksFixed = kinksFixed; t.tradeGaps = []; LNS.forEach((R0, li) => { if (R0.cut) return; for (let q = 1; q < R0.line.length; q++) { const g = Math.hypot(R0.line[q][0] - R0.line[q - 1][0], R0.line[q][1] - R0.line[q - 1][1]); if (g > 3) t.tradeGaps.push([li, q, Math.round(g), Math.round(R0.line[q][0]), Math.round(R0.line[q][1])]); } }); if (t.tradeGaps.length) console.warn('[trade] gaps > 3 px', JSON.stringify(t.tradeGaps.slice(0, 20))); }
          t.tradeLines = []; let acc = 0, np = 0, acc2 = 0, acc3 = 0, acc4 = 0, ntp = 0; runs.forEach((pc, pi) => { const R0 = LNS[pi]; if (R0.cut) return; let line = R0.line, L0 = R0.L0, E0 = R0.E0;
            const n = line.length, ph = hh(pi, 1) * 6.283, hs0 = pc.head ? TR.stub : 0, ts0 = pc.tail ? TR.stub : 0, cD = pc.dark ? TC.ddirt : TC.dirt, cR = pc.dark ? TC.drut : TC.rut;
            for (let i = 0; i < n; i++) { const a = line[Math.max(0, i - 2)], b = line[Math.min(n - 1, i + 2)], dl = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1, px = -(b[1] - a[1]) / dl, pz = (b[0] - a[0]) / dl;
              let [x, z] = line[i]; const tp = Math.max(0, Math.min(1, (i - hs0) / 16, (n - 1 - i - ts0) / 16)), o = tp * TR.wob * Math.sin(i / TR.wobL + ph);
              if (o && L0[i] >= 0) { const wx = x + px * o, wz = z + pz * o; if (okAt(wx, wz, L0[i], E0[i])) { x = wx; z = wz; } }
              const v = hh(Math.round(x), Math.round(z)); pnt(x, z, pc.dark ? cD : v < 0.07 ? TC.stone : v < 0.13 ? TC.grass : cD); pnt(x + px * 2, z + pz * 2, cR); pnt(x - px * 2, z - pz * 2, cR);
              const rx = Math.round(x), rz = Math.round(z);
              if ((acc2 += 1) >= 9) { acc2 = 0; const g = TGc(x, z), v3 = hh(rx * 3 + 5, rz * 7 + 3); if (g !== 4 && g !== 6 && v3 < (g === 3 ? 0.7 : 0.4)) { const so = (hh(rx + 9, rz + 4) - 0.5) * 2.6; if (tprop(v3 < 0.15 || g === 3 ? 'p_trstone' : 'p_trpeb', Math.round(x + px * so), Math.round(z + pz * so), 'tp_' + ntp)) ntp++; } }
              if (!pc.dark && (acc3 += 1) >= 5) { acc3 = 0; const g = TGc(x, z), v4 = hh(rx + 17, rz + 29); if ((g === 0 || g === 1 || g === 5) && v4 < 0.42) { const sd = v4 < 0.21 ? 3.4 : -3.4; if (tprop(g === 1 ? 'p_trtuftd' : 'p_trtuft', Math.round(x + px * sd), Math.round(z + pz * sd), 'tt_' + ntp)) ntp++; } }
              if (!pc.dark && (acc4 += 1) >= 320) { const v5 = hh(rx + 3, rz + 91); if (tprop(v5 < 0.33 ? 'p_trwheel' : v5 < 0.66 ? 'p_trsack' : 'p_trplank', Math.round(x + px * 1.4), Math.round(z + pz * 1.4), 'tw_' + ntp)) { ntp++; acc4 = 0; } }
              if (!pc.dark && (acc += 1) > 110) { const sd = v < 0.5 ? 5 : -5, id = v < 0.3 ? 'p_cart' : 'p_milestone'; if (prop(id, Math.round(x + px * sd), Math.round(z + pz * sd), 'tr_' + np)) { np++; acc = 0; } } }
            if (!pc.dark) t.tradeLines.push(line); /* vehicles: coach routes */
            for (const [f, P] of [[pc.jA, line[0]], [pc.jB, line[n - 1]]]) if (f && P) for (let dz = -3; dz <= 3; dz++) for (let dx = -3; dx <= 3; dx++) if (dx * dx + dz * dz <= 7) pnt(P[0] + dx, P[1] + dz, cD); });
          t.tradeProps = np; t.trailScatter = ntp; t.trailCodes = TC; t.tradeStats = { pairs: PL.length, routed, failed: fails.length, fails, squeezed, autoSkipped, bridges: BR.length, bridgesOnRoutes: BR.filter(b => b.used).length, bridgeLinks: links, orphanLinks, spurs, ms: Math.round(performance.now() - tq0) };
          console.log('[trade]', JSON.stringify(t.tradeStats)); }
        MK('trade');
        // Crash sphere buildings: every nation's settlement kits + CSP.extra, recoloured, rotated, half-sunk on the dome (golden-angle spiral, jittered).
        if (CSP) { const SETs = window.MercSettlements, ids = [...new Set([...Object.entries((SETs && SETs.STYLES) || {}).flatMap(([sty, S]) => Object.keys(S.kits || {}).map(k => sty + '|' + k)), ...CSP.extra.map(k => 'cyfrolaef|' + k)])];
          const cyc = [parseInt(CSP.cy.slice(1, 3), 16), parseInt(CSP.cy.slice(3, 5), 16), parseInt(CSP.cy.slice(5, 7), 16)], hx = v => '#' + v.map(q => Math.max(0, Math.min(255, Math.round(q))).toString(16).padStart(2, '0')).join('');
          const recol = h => { const v = h && h[0] === '#' ? [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)] : [200, 196, 200], l = 0.3 * v[0] + 0.59 * v[1] + 0.11 * v[2]; return hx(v.map((q, i) => ((l * (1 - CSP.mix) + cyc[i] * CSP.mix) * 0.5 + q * 0.1) * CSP.dark * 1.6)); };
          const [sx, sz] = CSP.c; let nb = 0;
          for (let i = 0; i < CSP.buildings; i++) { const pick = ids[Math.floor(csh(i, 811) * ids.length)], [sty, kid] = pick.split('|'); let k; try { k = ME.kit(kid, sty === 'cyfrolaef' ? 'buern' : sty, () => csh(i, 812)); } catch (er) { continue; } if (!k || !k.parts) continue;
            const a = i * 2.39996 + csh(i, 813) * 0.6, rr = Math.sqrt((i + 0.5) / CSP.buildings) * CSP.r * CSP.spread, x = sx + Math.cos(a) * rr, z = sz + Math.sin(a) * rr, j = J(Math.round(x), Math.round(z));
            const flip = csh(i, 814) < CSP.flip, tl = flip ? Math.PI * (0.6 + csh(i, 815) * 0.5) * (csh(i, 816) < 0.5 ? -1 : 1) : (csh(i, 817) - 0.5) * 2 * CSP.tilt, pt = (csh(i, 818) - 0.5) * 2 * CSP.pitch, piv = [k.W / 2, 0, k.D / 2];
            const parts = k.parts.map(p => ({ ...p, tint: recol(p.tint), tintFaces: null, tilt: tl + (p.tilt || 0), pitch: pt + (p.pitch || 0), piv }));
            const sink = (CSP.sink[0] + csh(i, 819) * (CSP.sink[1] - CSP.sink[0])) * T, fd = k.D * EL.K;
            gen.push({ id: 'csp_' + i, type: 'gen', kit: kid, settlement: null, nf: true, gyRaw: Math.max(WATER_H + T, H[j] - sink), L: Object.assign(parts, { W: k.W }), x, y: z + fd / 2, plot: { px: k.W * EL.K / 2, pb: fd } }); nb++; }
          t.crashSphere = nb; }
        MK('crashSphere');
        // Sunken ruins (ME.SUNKEN): water cells of the named region (never rivers); footprint must be open water; base below the water plane, random tilt.
        if (ME.SUNKEN && t.reg && t.regById) { const SK = ME.SUNKEN, rid = (Object.values(t.regById).find(r => r.name === SK.region) || {}).id, shC = 0, wcl = (t.water && t.water.classes) || [], wid = n => (wcl.find(k => k.name === n) || {}).id, shMap = {};
          for (const [f, to] of [['Deep sea', 'Shallows'], ['Sea', 'Shallows'], ['Icy deep sea', 'Icy shallows'], ['Icy sea', 'Icy shallows'], ['Murky deep sea', 'Murky shallows'], ['Murky sea', 'Murky shallows'], ['Violet deep sea', 'Violet shallows'], ['Violet sea', 'Violet shallows']]) if (wid(f) != null && wid(to) != null) shMap[wid(f)] = wid(to); let ns = 0, tot = 0; for (const [, w] of SK.k) tot += w;
          if (rid) for (let z = 4; z < t.H - 4; z += SK.step) for (let x = 4; x < t.W - 4; x += SK.step) { const jx = x + Math.floor(csh(x, z + 3) * SK.step * 0.6), jz = z + Math.floor(csh(x + 3, z) * SK.step * 0.6); if (jx >= t.W || jz >= t.H || t.reg[jz * t.W + jx] !== rid || csh(jx * 3, jz * 7) > SK.d) continue;
            let v = csh(jx + 11, jz + 13) * tot, id = SK.k[0][0]; for (const [kk, w] of SK.k) { if ((v -= w) <= 0) { id = kk; break; } } const k = kitOf(id), fw = k.W * EL.K, fd = k.D * EL.K, x0 = jx - fw / 2, z0 = jz - fd / 2, cells = []; let ok = true;
            for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1 && ok; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) { ok = false; break; } const j = zz * RW + xx; if (w2[j] < 2 || (t.riv && t.riv[j] > 0.5) || grid.occ[j]) { ok = false; break; } cells.push(j); }
            if (!ok) continue; for (const j of cells) grid.occ[j] = 3;
            // Shallows ring: rounded halo (Euclidean distance to the footprint, noisy edge); each pixel keeps its own tone (light/base/dark) and only swaps to the
            // matching shallows class (sea → Shallows, violet → Violet shallows, …), dithered out over the outer ring, so the water texture shows through.
            if (shMap) { const R = SK.pad + 1.5, X0 = x0, X1 = x0 + fw, Z0 = z0, Z1 = z0 + fd; for (let zz = Math.floor(Z0 - R); zz <= Math.ceil(Z1 + R); zz++) for (let xx = Math.floor(X0 - R); xx <= Math.ceil(X1 + R); xx++) { if (xx < 0 || zz < 0 || xx >= t.W || zz >= t.H) continue;
              const pi = zz * t.W + xx, cd = t.water.code[pi]; if (cd === 255) continue; const to = shMap[cd >> 2]; if (to == null) continue; const ddx = Math.max(X0 - xx, 0, xx - X1), ddz = Math.max(Z0 - zz, 0, zz - Z1), dd = Math.hypot(ddx, ddz) + (csh(xx * 5, zz * 3) - 0.5) * 1.6;
              if (dd > R || (dd > R - 1.5 && csh(xx + 17, zz + 29) < (dd - (R - 1.5)) / 1.5)) continue; t.water.code[pi] = (to << 2) | (cd & 3); } }

            const tl = (csh(jx, jz + 21) - 0.5) * 2 * SK.tilt, pt = (csh(jx + 21, jz) - 0.5) * 2 * SK.pitch, piv = [k.W / 2, 0, k.D / 2], sink = (SK.sink[0] + csh(jx + 5, jz + 9) * (SK.sink[1] - SK.sink[0])) * T;
            gen.push({ id: 'sk_' + ns, type: 'gen', kit: id, settlement: null, nf: true, gyRaw: WATER_H - sink, L: Object.assign(k.parts.map(p => ({ ...p, tilt: tl + (p.tilt || 0), pitch: pt + (p.pitch || 0), piv })), { W: k.W }), x: jx, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); ns++; }
          t.sunken = ns; }
        MK('sunken');
        // Palisade walls (t.walls ← map/map-walls.json, ME.PALISADE): stakes along each polyline; constant absolute top; skipped on water / trails / streets / buildings.
        if (t.walls && ME.PALISADE) { const PA = ME.PALISADE, hs = o.heightScale; let nw = 0, ng = 0; for (const w of t.walls.walls || []) { if (w.style === 'stone') continue; const pts = resample(w.pts, PA.step); if (pts.length < 2) continue;
            const gyOf = p => { const j = J(Math.round(p[0]), Math.round(p[1])); return Math.max(WATER_H + T, Math.round(H[j] / T) * T); }; let lo = 1e9; for (const p of pts) { const j = J(Math.round(p[0]), Math.round(p[1])); if (grid.dry0[j]) lo = Math.min(lo, gyOf(p)); }
            const topW = lo * hs + PA.top, ok0 = j => j >= 0 && grid.dry0[j] && grid.occ[j] !== 1 && grid.occ[j] !== 2, pnt0 = pts.map(p => { const j = J(Math.round(p[0]), Math.round(p[1])); return !!grid.paint[j]; });
            const gate = pts.map((_, i) => { if (!pnt0[i]) return false; let a = i, b = i; while (a > 0 && pnt0[a - 1]) a--; while (b < pts.length - 1 && pnt0[b + 1]) b++; return b - a < 7; }); const gGy = pts.map(() => null), brG = []; // bridge gates: wall line crosses a bridge deck (a→b, ends stretched 4 px) → gate centred on the crossing, posts at deck level
            for (const br of (t.brP || [])) { if (!br.P || br.P.length < 2) continue; const a = br.P[0], b = br.P[br.P.length - 1], L = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1, ux = (b[0] - a[0]) / L, uz = (b[1] - a[1]) / L, A2 = [a[0] - ux * 4, a[1] - uz * 4], B2 = [b[0] + ux * 4, b[1] + uz * 4]; let bi = -1, bd = 3.5;
              pts.forEach((p, k) => { const s = Math.max(0, Math.min(1, ((p[0] - A2[0]) * (B2[0] - A2[0]) + (p[1] - A2[1]) * (B2[1] - A2[1])) / ((L + 8) * (L + 8)))), d = Math.hypot(p[0] - (A2[0] + (B2[0] - A2[0]) * s), p[1] - (A2[1] + (B2[1] - A2[1]) * s)); if (d < bd) { bd = d; bi = k; } });
              if (bi >= 0) brG.push([bi, br.D ? Math.max(...br.D) : Math.max(gyOf(a), gyOf(b))]); }
            if (brG.length) for (let i = 0; i < pts.length; i++) if (gate[i] && brG.some(([k]) => Math.abs(k - i) * PA.step < 16)) gate[i] = false; // drop trail-paint gates next to a bridge gate (no double doors)
            for (const [k, gy] of brG) { gate[k] = true; gGy[k] = gy; }
            { const GO = 5 / PA.step, mid = []; for (let i = 0; i < pts.length; i++) if (gate[i] && !(i > 0 && gate[i - 1])) { let b = i; while (b + 1 < pts.length && gate[b + 1]) b++; mid.push((i + b) / 2); }
              for (const m of mid) { const gy0 = gGy[Math.round(m)] ?? gGy.slice(Math.max(0, Math.floor(m - GO)), Math.ceil(m + GO) + 1).find(v => v != null) ?? null; for (let k = Math.max(0, Math.ceil(m - GO)); k <= Math.min(pts.length - 1, Math.floor(m + GO)); k++) { gate[k] = true; if (gy0 != null) gGy[k] = gy0; } } } // short paint run = trail crossing → gate; long = street along the wall → keep stakes
            pts.forEach((p0, i) => { if (gate[i]) return; const q0 = pts[Math.max(0, i - 1)], q1 = pts[Math.min(pts.length - 1, i + 1)], dl = Math.hypot(q1[0] - q0[0], q1[1] - q0[1]) || 1, nx = -(q1[1] - q0[1]) / dl, nz = (q1[0] - q0[0]) / dl;
              let p = null; for (const s of [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]) { const c2 = [p0[0] + nx * s, p0[1] + nz * s]; if (ok0(J(Math.round(c2[0]), Math.round(c2[1])))) { p = c2; break; } } if (!p) return; const j = J(Math.round(p[0]), Math.round(p[1]));
              const gy = gyOf(p), v = Math.floor(csh(i, 901 + nw) * 5), k = kitOf(PA.kits[v]), hU = Math.max(PA.minH, (topW - gy * hs) / EL.KY) * (1 + (csh(i, 902) - 0.5) * 2 * PA.hJit), f = hU / 10.4;
              const crook = csh(i, 903) < PA.crooked, tl = (csh(i, 904) - 0.5) * 2 * (crook ? PA.crookLean : PA.lean), pt = (csh(i, 905) - 0.5) * 2 * PA.pitch, piv = [k.W / 2, 0, k.D / 2];
              const parts = k.parts.map(q => ({ ...q, y: (q.y || 0) * f, h: q.h * f, tilt: tl, pitch: pt, piv })); grid.occ[j] = grid.occ[j] || 3;
              gen.push({ id: 'pal_' + w.id + '_' + i, type: 'gen', kit: PA.kits[v], settlement: null, nf: true, gyRaw: gy, L: Object.assign(parts, { W: k.W }), x: p[0], y: p[1] + k.D * EL.K / 2, plot: { px: k.W * EL.K / 2, pb: k.D * EL.K } }); nw++; });
            // Gates: each gate run (trail crossing) gets a post on both sides + a leaf per post, swung open 90° (axis-snapped) to the same side.
            for (let i = 0; i < pts.length; i++) { if (!gate[i] || (i > 0 && gate[i - 1])) continue; let b = i; while (b + 1 < pts.length && gate[b + 1]) b++; const A = pts[Math.max(0, i - 1)], Bp = pts[Math.min(pts.length - 1, b + 1)];
              const gx = Bp[0] - A[0], gz = Bp[1] - A[1], gl = Math.hypot(gx, gz) || 1, nx = -gz / gl, nz = gx / gl, alongX = Math.abs(nx) >= Math.abs(nz), sg = alongX ? Math.sign(nx) || 1 : Math.sign(nz) || 1, Lp = Math.max(3.5, gl / 2 - 0.4); (t.palGatePos = t.palGatePos || []).push([Math.round((A[0] + Bp[0]) / 2), Math.round((A[1] + Bp[1]) / 2)]);
              const runGy = gGy[i]; [A, Bp].forEach((P, s) => { const j = J(Math.round(P[0]), Math.round(P[1])); if (runGy == null && (j < 0 || !grid.dry0[j])) return; const gy = runGy ?? gyOf(P), hU = Math.max(PA.minH, (topW - gy * hs) / EL.KY), kp = kitOf('pal_gpost'), fp = hU * 1.18 / 11;
                gen.push({ id: 'palg_' + w.id + '_' + i + '_p' + s, type: 'gen', kit: 'pal_gpost', settlement: null, nf: true, gyRaw: gy, L: Object.assign(kp.parts.map(q => ({ ...q, y: (q.y || 0) * fp, h: q.h * fp })), { W: kp.W }), x: P[0], y: P[1] + kp.D * EL.K / 2, plot: { px: kp.W * EL.K / 2, pb: kp.D * EL.K } });
                const id = 'pal_gate_' + (alongX ? 'x' : 'z') + (s ? 'R' : ''), kl = kitOf(id), fl = Lp / (4 * EL.K), fh = hU * 0.85 / 8.5, cx = P[0] + (alongX ? sg * Lp / 2 : 0), cz = P[1] + (alongX ? 0 : sg * Lp / 2);
                const parts = kl.parts.map(q => ({ ...q, x: alongX ? q.x * fl : q.x, w: alongX ? q.w * fl : q.w, z: alongX ? q.z : q.z * fl, d: alongX ? q.d : q.d * fl, y: (q.y || 0) * fh, h: q.h * fh })), W2 = alongX ? kl.W * fl : kl.W, D2 = alongX ? kl.D : kl.D * fl;
                gen.push({ id: 'palg_' + w.id + '_' + i + '_l' + s, type: 'gen', kit: id, settlement: null, nf: true, gyRaw: gy, L: Object.assign(parts, { W: W2 }), x: cx, y: cz + D2 * EL.K / 2, plot: { px: W2 * EL.K / 2, pb: D2 * EL.K } }); ng++; });
              { const P0 = A, P1 = Bp, wx = Math.abs(P1[0] - P0[0]) >= Math.abs(P1[1] - P0[1]), L = Math.max(2, wx ? Math.abs(P1[0] - P0[0]) : Math.abs(P1[1] - P0[1])) + 1.6, cx = (P0[0] + P1[0]) / 2, cz = (P0[1] + P1[1]) / 2, gy = runGy ?? Math.min(gyOf(P0), gyOf(P1)), hU = Math.max(PA.minH, (topW - gy * hs) / EL.KY) * 1.12, wS = L / EL.K;
                const parts = [{ ...kitOf('pal_gpost').parts[0], x: wx ? wS / 2 : 0.6, z: wx ? 0.6 : wS / 2, w: wx ? wS : 1.2, d: wx ? 1.2 : wS, y: hU, h: 1.4, tint: '#4e3820' }, { ...kitOf('pal_gpost').parts[0], x: wx ? wS / 2 : 0.6, z: wx ? 0.6 : wS / 2, w: wx ? wS : 1.3, d: wx ? 1.3 : wS, y: hU - 3.2, h: 0.6, tint: '#2e2620' }], W2 = wx ? wS : 1.2, D2 = wx ? 1.2 : wS;
                gen.push({ id: 'palg_' + w.id + '_' + i + '_lintel', type: 'gen', kit: 'pal_gpost', settlement: null, nf: true, gyRaw: gy, L: Object.assign(parts, { W: W2 }), x: cx, y: cz + D2 * EL.K / 2, plot: { px: W2 * EL.K / 2, pb: D2 * EL.K } }); } } }
          t.palisadeStakes = nw; t.palisadeGates = ng; }
        const occW0 = t.walls && ME.GREATWALL ? grid.occ.slice() : null;
        // Great stone walls (style "stone", ME.GREATWALL): w.out = side facing the enemy ('n' | 's' | 'e' | 'w'); doors on the inner face (w.doors !== false).
        // Ends: w.extendA / w.extendB = px to run on past the drawn ends (A stops at the first sea cell → reaches the shore). Walkway top = local max ground (± smooth pts) + height;
        // river cells → culvert (segment lifted GREATWALL.arch units off the water + iron grate). Cells under the wall become occ 3 (no foliage / scatter / trails).
        if (t.walls && ME.GREATWALL) { const GW = ME.GREATWALL, hs = o.heightScale; let ns = 0, nt = 0, nc = 0; const gyOf = p => { const j = J(Math.round(p[0]), Math.round(p[1])); return Math.max(WATER_H + T, Math.round(H[j] / T) * T); };
          const wetJ = j => j < 0 || t.w2[j] >= 2 || !!(t.riv && t.riv[j] > 0.5), seaJ = j => j < 0 || (t.w2[j] >= 2 && !(t.riv && t.riv[j] > 0.5));
          for (const w of t.walls.walls || []) { if (w.style !== 'stone') continue; let P = w.pts.map(p => p.slice());
            const ext = (P0, P1, L, stopSea) => { const dx = P0[0] - P1[0], dz = P0[1] - P1[1], d = Math.hypot(dx, dz) || 1, o2 = []; for (let s = 2; s <= L; s += 2) { const q = [P0[0] + dx / d * s, P0[1] + dz / d * s]; const j = J(Math.round(q[0]), Math.round(q[1])); if (stopSea && seaJ(j)) { o2.push(q); break; } o2.push(q); } return o2; };
            if (w.extendA) P = ext(P[0], P[1], w.extendA, true).reverse().concat(P); if (w.extendB) P = P.concat(ext(P[P.length - 1], P[P.length - 2], w.extendB, false));
            const pts = resample(P, GW.step), n = pts.length; if (n < 2) continue; const ov = { n: [0, -1], s: [0, 1], e: [1, 0], w: [-1, 0] }[w.out || 'n'];
            const rivJ = j => j >= 0 && !seaJ(j) && wetJ(j), band = (p, i, f) => { const q0 = pts[Math.max(0, i - 1)], q1 = pts[Math.min(n - 1, i + 1)], dl = Math.hypot(q1[0] - q0[0], q1[1] - q0[1]) || 1, tx = (q1[0] - q0[0]) / dl, tz = (q1[1] - q0[1]) / dl; for (let a = -GW.step / 2; a <= GW.step / 2; a += 1) for (let b = -GW.occR; b <= GW.occR; b += 1) { const j = J(Math.round(p[0] + tx * a - tz * b), Math.round(p[1] + tz * a + tx * b)); if (f(j)) return true; } return false; };
            const W0 = pts.map((p, i) => band(p, i, wetJ)), RV = pts.map((p, i) => band(p, i, rivJ)), G = pts.map((p, i) => { const j = J(Math.round(p[0]), Math.round(p[1])), wet = W0[i] || (RV[i - 1] || RV[i + 1]); return { j, wet, riv: RV[i] || RV[i - 1] || RV[i + 1], gy: wet ? WATER_H : gyOf(p) }; });
            const dg = G.filter(g => !g.wet).map(g => g.gy).sort((u, v) => u - v), lvl = dg.length ? dg[Math.floor((dg.length - 1) * (w.level ?? 0.7))] : WATER_H + T, top = G.map(g => Math.max((lvl * hs + GW.height), g.gy * hs + 10 * EL.KY)); // one level walkway along the whole wall (w.level = ground percentile); only rises where the ground pokes above it (mountain ends)
            const W_NATPT = [1495,1569]; /* a Cyfrolaef pixel: great walls lift with Cyfrolaef */ const put = (kid, x, z, gy, fy, id, lift) => { const k = kitOf(kid); if (!k) return; const parts = k.parts.map(q => ({ ...q, y: (q.y || 0) * fy + (lift || 0), h: q.h * fy })); gen.push({ id, type: 'gen', kit: kid, settlement: null, nf: true, wall: 1, natPt: w.natPt || W_NATPT, noLift: !!w.noLift, gyRaw: gy, L: Object.assign(parts, { W: k.W }), x, y: z + k.D * EL.K / 2, plot: { px: k.W * EL.K / 2, pb: k.D * EL.K } }); };
            let lastT = -1e9, acc = 0; const nearRivB = i => G.slice(Math.max(0, i - 2), i + 3).some(q => q.riv);
            for (let i = 0; i < n; i++) { const p = pts[i], q0 = pts[Math.max(0, i - 2)], q1 = pts[Math.min(n - 1, i + 2)], dl = Math.hypot(q1[0] - q0[0], q1[1] - q0[1]) || 1; let nx = -(q1[1] - q0[1]) / dl, nz = (q1[0] - q0[0]) / dl; if (nx * ov[0] + nz * ov[1] < 0) { nx = -nx; nz = -nz; }
              const g = G[i], hU = Math.max(8, (top[i] - g.gy * hs) / EL.KY); if (i) acc += GW.step;
              for (let dz = -GW.occR; dz <= GW.occR; dz += 2) for (let dx = -GW.occR; dx <= GW.occR; dx += 2) { const j = J(Math.round(p[0] + dx), Math.round(p[1] + dz)); if (j >= 0 && !grid.occ[j]) grid.occ[j] = 3; }
              if (g.wet) { const lift = GW.arch, fy = (hU - GW.arch) / 31; put('gw_seg', p[0], p[1], g.gy, fy, 'gw_' + w.id + '_' + i, lift); if (g.riv) { put('gw_grate', p[0] + nx * GW.occR * 0.7, p[1] + nz * GW.occR * 0.7, g.gy, GW.arch / 10, 'gwg_' + w.id + '_' + i); put('gw_grate', p[0] - nx * GW.occR * 0.7, p[1] - nz * GW.occR * 0.7, g.gy, GW.arch / 10, 'gwh_' + w.id + '_' + i); } nc++; }
              else put('gw_seg', p[0], p[1], g.gy, hU / 31, 'gw_' + w.id + '_' + i);
              const tw = top[i] / EL.KY, wy = (u) => u; ns++;
              if (i % GW.merlonEvery === 0) { const mx = p[0] + nx * GW.out, mz = p[1] + nz * GW.out, gyM = g.gy; put('gw_merlon', mx, mz, gyM, 1, 'gwm_' + w.id + '_' + i, hU - 0.3); put('gw_merlon', p[0] - nx * GW.inner, p[1] - nz * GW.inner, gyM, 0.55, 'gwi_' + w.id + '_' + i, hU - 0.3); }
              if (!g.wet && !nearRivB(i) && i % GW.buttEvery === 3) put('gw_butt', p[0] + nx * GW.buttOut, p[1] + nz * GW.buttOut, g.gy, hU * 0.72 / 25, 'gwb_' + w.id + '_' + i);
              const nearRiv = G.slice(Math.max(0, i - 3), i + 4).some(q => q.riv); if (!nearRiv && !g.riv && (acc - lastT >= GW.towerEvery || i === 0 || i === n - 1) && !(i === n - 1 && acc - lastT < GW.towerEvery * 0.4)) { lastT = acc; const hT = Math.max(hU + 14, ((top[i] + GW.tower - GW.height) - g.gy * hs) / EL.KY); put('gw_tower', p[0], p[1], g.gy, hT / 47.4, 'gwt_' + w.id + '_' + i); nt++; put('gw_brazier', p[0], p[1], g.gy, 1, 'gwz_' + w.id + '_' + i, 44.6 * hT / 47.4); t.gwBraziers = (t.gwBraziers || 0) + 1;
                if (w.doors !== false) { const ix = -ov[0], iz = -ov[1], half = 11 * EL.K / 2; if (iz > 0) put('gw_door', p[0], p[1] + half, g.gy, 1, 'gwd_' + w.id + '_' + i); else if (iz < 0) put('gw_door', p[0], p[1] - half - 0.8, g.gy, 1, 'gwd_' + w.id + '_' + i); } } } }
          t.greatWall = { segs: ns, towers: nt, culverts: nc, gratePts: gen.filter(e => /^gwg_/.test(e.id)).map(e => [Math.round(e.x), Math.round(e.y), e.id]) }; }
        // Ice mountain (ME.ICE_MOUNTAIN): ice spikes over the Bleeding Mountain cone (prop rules: free cells, ≤ 1 level step), denser toward the peak.
        if (ME.ICE_MOUNTAIN) { const IM = ME.ICE_MOUNTAIN, tot = IM.kits.reduce((s, q) => s + q[1], 0); let ni = 0; for (let i = 0; i < IM.n; i++) { const a = hh(i, 4401) * 6.283, rr = IM.r * Math.sqrt(hh(i, 4402)) * (0.35 + 0.65 * hh(i, 4403));
          let v = hh(i, 4404) * tot, kid = IM.kits[0][0]; for (const [k2, w2] of IM.kits) if ((v -= w2) <= 0) { kid = k2; break; } const x = Math.round(IM.c[0] + Math.cos(a) * rr), z = Math.round(IM.c[1] + Math.sin(a) * rr), k = kitOf(kid), fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2; let ok = true, gmin = 1e9; const cl = [];
          for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1 && ok; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { const j = zz * RW + xx; if (xx < 0 || zz < 0 || xx >= RW || zz >= RH || !grid.dry0[j] || grid.occ[j] || grid.paint[j]) { ok = false; break; } cl.push(j); if (H[j] < gmin) gmin = H[j]; }
          if (!ok) continue; for (const j of cl) grid.occ[j] = 3; gen.push({ id: 'ice_' + i, type: 'gen', kit: kid, settlement: null, nf: true, gyRaw: Math.max(WATER_H + T, Math.round(gmin / T) * T), L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); ni++; } t.iceSpikes = ni; }
        // Crash piles (ME.CRASH_PILES): fixed composite debris kits; footprint cells taken (occ 3) unless a building / street is there; base = lowest cell.
        if (ME.CRASH_PILES) ME.CRASH_PILES.forEach(([id, x, z], i) => { const k = kitOf(id), fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2; let gmin = 1e9;
          for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) continue; const j = zz * RW + xx; if (grid.dry0[j] && H[j] < gmin) gmin = H[j]; if (!grid.occ[j]) grid.occ[j] = 3; }
          gen.push({ id: 'pile_' + i, type: 'gen', kit: id, settlement: null, nf: true, gyRaw: Math.max(WATER_H + T, gmin), L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); });
        if (occW0) for (let j = 0; j < N; j++) if (grid.occ[j] === 3 && occW0[j] !== 3) { sid[j] = 0; sR[j] = 0; sH[j] = 0; } for (const e of gen) if (e.wall) { const x0 = Math.floor((e.x - e.plot.px) / 2), x1 = Math.ceil((e.x + e.plot.px) / 2) - 1, z0 = Math.floor((e.y - e.plot.pb) / 2), z1 = Math.ceil(e.y / 2) - 1; for (let z = z0; z <= z1; z++) for (let x = x0; x <= x1; x++) if (x >= 0 && z >= 0 && x < RW && z < RH) { const j = z * RW + x; sid[j] = 0; sR[j] = 0; sH[j] = 0; } } /* great-wall cells belong to no town (Westville hover lit the wall) */
        MK('walls+piles');
        // Foliage + terrain props (2026-10-07c): jittered 6 px lattice. Zone = first ME.FOLIAGE_ZONES entry whose filters all match the sample (see map-elements.js),
        // else ME.FOLIAGE[land class]. Keep prob = d (dDark on dark tone) × (1 − c + c · 2 · noise(70 px)) → clumped forests; kit = weighted pick. Skips settlements,
        // trails, rail ≤ 14 px. Island = non-sea land mass < 1500 cells of 8 px. near.nation = within px of that nation (8 px BFS). t.foliageZones = count per zone id.
        if (ME.FOLIAGE && t.land) { const FO = ME.FOLIAGE, vn = (x, z) => { const xi = Math.floor(x), zi = Math.floor(z), fx = x - xi, fz = z - zi, a = hh(xi, zi), b = hh(xi + 1, zi), c2 = hh(xi, zi + 1), d = hh(xi + 1, zi + 1); return (a * (1 - fx) + b * fx) * (1 - fz) + (c2 * (1 - fx) + d * fx) * fz; };
          const natIds = s => new Set(Object.values(t.natById || {}).filter(n => s.some(q => n.name.includes(q))).map(n => n.id)), regIds = (nm, ct) => new Set(Object.values(t.regById || {}).filter(r => (nm || []).includes(r.name) || (ct || []).includes(r.category)).map(r => r.id));
          const CS = 8, CW = Math.ceil(t.W / CS), CH = Math.ceil(t.H / CS), CN = CW * CH, ctr = i => { const x = Math.min(t.W - 1, (i % CW) * CS + 4), z = Math.min(t.H - 1, ((i / CW) | 0) * CS + 4); return z * t.W + x; };
          const nb4 = (j, f) => { const x = j % CW; if (x > 0) f(j - 1); if (x < CW - 1) f(j + 1); if (j >= CW) f(j - CW); if (j + CW < CN) f(j + CW); };
          const isl = new Uint8Array(CN); { const seen = new Uint8Array(CN), q = new Int32Array(CN); for (let i = 0; i < CN; i++) { if (seen[i] || t.sea[ctr(i)]) continue; let qh = 0, qt = 0; q[qt++] = i; seen[i] = 1;
            while (qh < qt) nb4(q[qh++], n => { if (!seen[n] && !t.sea[ctr(n)]) { seen[n] = 1; q[qt++] = n; } }); if (qt < 1500) for (let k = 0; k < qt; k++) isl[q[k]] = 1; } }
          const nearNat = (nm, px, isReg) => { const ids = isReg ? regIds([nm]) : natIds([nm]), L = isReg ? t.reg : t.nat, D = new Int32Array(CN).fill(-1), q = [], Rr = Math.ceil(px / CS); if (L) for (let i = 0; i < CN; i++) if (ids.has(L[ctr(i)])) { D[i] = 0; q.push(i); }
            for (let h = 0; h < q.length; h++) { const j = q[h]; if (D[j] >= Rr) continue; nb4(j, n => { if (D[n] < 0) { D[n] = D[j] + 1; q.push(n); } }); } return Uint8Array.from(D, v => v >= 0 ? 1 : 0); };
          const ZS = (ME.FOLIAGE_ZONES || []).map(z => ({ z, n: z.nation && natIds(z.nation), r: (z.region || z.regionCat) && regIds(z.region, z.regionCat), c: z.cls && new Set(z.cls), x: z.clsNot && new Set(z.clsNot), tn: z.tone && new Set(z.tone),
            nm: z.near && (z.near.nation || z.near.region) ? nearNat(z.near.nation || z.near.region, z.near.px, !z.near.nation) : null, at: z.near && z.near.at ? (t.labels.find(l => l.name === z.near.at) || { ix: -1e9, iz: -1e9 }) : null, el: z.ell ? t.labels.find(l => l.name === z.ell.at) || null : null }));
          const segD = (x, z, S) => { const [ax, az] = S.a, [bx, bz] = S.b, vx = bx - ax, vz = bz - az, L2 = vx * vx + vz * vz || 1, f = Math.max(0, Math.min(1, ((x - ax) * vx + (z - az) * vz) / L2)); return Math.hypot(x - ax - vx * f, z - az - vz * f); };
          const zoneAt = (x, z, code) => { const cls = code >> 2, tone = code & 3, i = z * t.W + x, ci = ((z / CS) | 0) * CW + ((x / CS) | 0), na = t.nat ? t.nat[i] : 0, rg = t.reg ? t.reg[i] : 0;
            for (const q of ZS) { const Z = q.z; if (q.c && !q.c.has(cls)) continue; if (q.x && q.x.has(cls)) continue; if (q.tn && !q.tn.has(tone)) continue; if (q.n && !q.n.has(na)) continue; if (q.r && !q.r.has(rg)) continue;
              if (Z.island && !isl[ci]) continue; if (Z.zMax != null && z > Z.zMax) continue; if (Z.zMin != null && z < Z.zMin) continue; if (q.nm && !q.nm[ci]) continue; if (q.at && Math.hypot(q.at.ix - x, q.at.iz - z) > Z.near.px) continue;
              if (Z.seg && segD(x, z, Z.seg) > Z.seg.w) continue;
              if (Z.ell) { const E = Z.ell; if (!q.el || ((x - q.el.ix - E.dx) / E.rx) ** 2 + ((z - q.el.iz - E.dz) / E.rz) ** 2 > 1) continue; }
              if (Z.patch) { const p = vn(x / 500 + 31, z / 500 + 17); if (p < Z.patch[0] || p >= Z.patch[1]) continue; } return Z; }
            return cls === 2 && z > t.H * 0.62 ? FO.jungle : FO[cls]; };
          // Ponds / mud pits (2026-10-07e): carved, not kits. Blob radius 3–8 px (3- and 5-lobe wobble, 0.8–1.2 ellipse); rim (+3 px) must be one terrace, interior free.
          // Cells: paint = nearest water colour × 0.8 (mud: brown), t.pondMask → buildVoxel drops the block top 0.3 terrace (inset). Ponds get 1–3 lily pads and
          // 4–8 reed clumps around the rim; mud pits 2–3 reeds.
          const PM = t.pondMask = new Uint8Array(N), pcode = {}, MUD = grid.cols.push([[86, 62, 40], [70, 50, 32]]) - 1, WC = new Int16Array(CN).fill(-1);
          if (t.water) { const q = []; for (let i = 0; i < CN; i++) { const c = t.water.code[ctr(i)]; if (c !== 255) { WC[i] = c; q.push(i); } } for (let h = 0; h < q.length; h++) { const j = q[h]; nb4(j, n => { if (WC[n] < 0) { WC[n] = WC[j]; q.push(n); } }); } }
          const pond = (x, z, wet) => { const Rr = 3 + hh(x + 1, z + 2) * 5, e = 0.8 + hh(x + 4, z + 9) * 0.4, p1 = hh(x, z + 3) * 6.28, p2 = hh(x + 3, z) * 6.28, l0 = grid.lvl[J(x, z)], cx = x >> 1, cz = z >> 1, rc = Math.ceil(Rr * 1.4 / 2) + 2, cells = [];
            for (let dz = -rc; dz <= rc; dz++) for (let dx = -rc; dx <= rc; dx++) { const xx = cx + dx, zz = cz + dz; if (xx < 1 || zz < 1 || xx >= RW - 1 || zz >= RH - 1) return false; const j = zz * RW + xx, ox = dx * 2 / e, oz = dz * 2 * e, r = Math.hypot(ox, oz), a = Math.atan2(oz, ox), rr = Rr * (1 + 0.16 * Math.sin(3 * a + p1) + 0.09 * Math.sin(5 * a + p2));
              if (r <= rr + 3 && (grid.lvl[j] !== l0 || !grid.dry0[j])) return false; if (r <= rr) { if (!free(j)) return false; cells.push(j); } }
            if (cells.length < 4) return false; let code = MUD;
            if (wet) { const wc = WC[((z / CS) | 0) * CW + ((x / CS) | 0)], key = wc < 0 ? 'd' : wc; if (pcode[key] == null) { const rgb = wc < 0 ? [60, 100, 120] : [t.water.rgb[wc * 3], t.water.rgb[wc * 3 + 1], t.water.rgb[wc * 3 + 2]]; pcode[key] = grid.cols.length < 250 ? grid.cols.push([rgb.map(v => Math.round(v * 0.8)), rgb.map(v => Math.round(v * 0.72))]) - 1 : MUD; } code = pcode[key]; }
            for (const j of cells) { grid.paint[j] = code; grid.occ[j] = 3; PM[j] = 1; }
            const surf = Math.max(WATER_H + T, l0 * T) - 0.3 * T;
            if (wet) { const lk = kitOf('w_lily'), nl = 1 + Math.floor(hh(x + 8, z + 1) * 3); for (let k = 0; k < nl; k++) { const j = cells[Math.floor(hh(x + k * 13, z + 5) * cells.length)];
              gen.push({ id: 'ly_' + x + '_' + z + '_' + k, type: 'gen', kit: 'w_lily', settlement: null, nf: true, gyRaw: surf + 0.01 * T, L: Object.assign(lk.parts, { W: lk.W }), x: (j % RW) * 2 + 1, y: ((j / RW) | 0) * 2 + 1 + lk.D * EL.K / 2, plot: { px: lk.W * EL.K / 2, pb: lk.D * EL.K } }); } }
            const nr = wet ? 4 + Math.floor(hh(x + 2, z + 8) * 5) : 2 + Math.floor(hh(x + 2, z + 8) * 2); for (let k = 0; k < nr; k++) { const a = hh(x + k * 7, z + k * 3) * 6.283, d = Rr * 1.05 + 1.5 + hh(x + k, z - k) * 3; prop('f_reeds', Math.round(x + Math.cos(a) * d / e), Math.round(z + Math.sin(a) * d * e), 'pr_' + x + '_' + z + '_' + k); }
            return true; };
          const zc = {}; let nf = 0; for (let z = 3; z < t.H - 3; z += 6) for (let x = 3; x < t.W - 3; x += 6) { const v = hh(x + 7, z + 3), jx = x + Math.floor(v * 5) - 2, jz = z + Math.floor(hh(x, z + 11) * 5) - 2, j = J(jx, jz); if (!free(j) || grid.near13[j]) continue;
            const code = t.land.code[jz * t.W + jx]; if (code === 255) continue; const B = zoneAt(jx, jz, code); if (!B) continue; const d = B.dDark != null && (code & 3) === 2 ? B.dDark : B.d;
            const pr = d * (1 - B.c + B.c * 2 * vn(jx / 70, jz / 70)); if (hh(jx * 3 + 1, jz * 5 + 2) > pr) continue;
            let tot = 0; for (const [, w] of B.k) tot += w; let q = hh(jx + 13, jz + 29) * tot, id = B.k[0][0]; for (const [k, w] of B.k) { if ((q -= w) <= 0) { id = k; break; } }
            const zk = B.id || 'class'; if (id === 'p_pond' || id === 'p_mudpit') { if (pond(jx, jz, id === 'p_pond')) { nf++; zc[zk] = (zc[zk] || 0) + 1; } continue; }
            if (TREES.has(id)) id += '#' + Math.floor(hh(jx + 41, jz + 7) * 5);
            if (prop(id, jx, jz, 'fo_' + nf)) { nf++; zc[zk] = (zc[zk] || 0) + 1; } }
          // Fill pass: zones with fill { step, d, k } (near.region only) get an extra dense lattice of small pieces over their near-mask.
          for (const q of ZS) { const Z = q.z, Fl = Z.fill; if (!Fl || !q.nm) continue; let tot = 0; for (const [, w] of Fl.k) tot += w;
            for (let ci = 0; ci < CN; ci++) { if (!q.nm[ci]) continue; const bx = (ci % CW) * CS, bz = ((ci / CW) | 0) * CS;
              for (let z = bz; z < bz + CS; z += Fl.step) for (let x = bx; x < bx + CS; x += Fl.step) { if (x < 3 || z < 3 || x >= t.W - 3 || z >= t.H - 3 || hh(x * 5 + 3, z * 3 + 7) > Fl.d || !free(J(x, z))) continue;
                let v = hh(x + 3, z + 5) * tot, id = Fl.k[0][0]; for (const [k, w] of Fl.k) { if ((v -= w) <= 0) { id = k; break; } } if (prop(id, x, z, 'fl_' + nf)) { nf++; zc[Z.id + '_fill'] = (zc[Z.id + '_fill'] || 0) + 1; } } } }
          for (const q of ZS) { const Z = q.z, Fl = Z.fill; if (!Fl || !Z.seg) continue; const Sg = Z.seg; let tot = 0; for (const [, w] of Fl.k) tot += w;
            const x0 = Math.max(3, Math.min(Sg.a[0], Sg.b[0]) - Sg.w), x1 = Math.min(t.W - 3, Math.max(Sg.a[0], Sg.b[0]) + Sg.w), z0 = Math.max(3, Math.min(Sg.a[1], Sg.b[1]) - Sg.w), z1 = Math.min(t.H - 3, Math.max(Sg.a[1], Sg.b[1]) + Sg.w);
            for (let z = z0; z < z1; z += Fl.step) for (let x = x0; x < x1; x += Fl.step) { if (segD(x, z, Sg) > Sg.w || hh(x * 5 + 3, z * 3 + 7) > Fl.d || !free(J(x, z))) continue;
              let v = hh(x + 3, z + 5) * tot, id = Fl.k[0][0]; for (const [k, w] of Fl.k) { if ((v -= w) <= 0) { id = k; break; } } if (prop(id, x, z, 'fs_' + nf)) { nf++; zc[Z.id + '_fill'] = (zc[Z.id + '_fill'] || 0) + 1; } } }
          // Town greenery (2026-10-07j): free cells inside settlement masks (yards, block interiors) get the local zone's trees / bushes (no rocks, ruins,
          // ponds), 4 px lattice, density TOWN_G.d; 1-cell gap from buildings and streets (prop footprint must be free).
          { const TG = { d: 0.55, step: 4 }; inTown.on = true; let ng = 0;
            for (let z = 3; z < t.H - 3; z += TG.step) for (let x = 3; x < t.W - 3; x += TG.step) { const j = J(x, z); if (!sR[j] || !free(j) || grid.near13[j]) continue; if (hh(x * 7 + 1, z * 3 + 5) > TG.d) continue;
              const code = t.land.code[z * t.W + x]; if (code === 255) continue; const B = zoneAt(x, z, code); if (!B) continue; const K2 = B.k.filter(([k]) => /^f_/.test(k) && !/reeds|mushroom|cactus|prickly|dead/.test(k)); if (!K2.length) continue;
              let tot = 0; for (const [, w] of K2) tot += w; let v = hh(x + 3, z + 9) * tot, id = K2[0][0]; for (const [k, w] of K2) { if ((v -= w) <= 0) { id = k; break; } } if (TREES.has(id)) id += '#' + Math.floor(hh(x + 41, z + 7) * 5);
              let near = false; for (const n of [j - 1, j + 1, j - RW, j + RW]) if (grid.occ[n] === 1 || grid.occ[n] === 2) near = true; if (near) continue;
              if (prop(id, x, z, 'tg_' + ng)) { ng++; nf++; } } inTown.on = false; zc.town_green = ng; }
          t.foliage = nf; t.foliageZones = zc; }
        MK('foliage+ponds');
        // Water scatter (ME.WATER_SCATTER): shallow / reef sea + lake cells on a jittered 10 px lattice (never rivers), base 0.6 terrace under the water plane.
        // River rocks: per river cell — drop (a 4-neighbour river cell's surface is ≥ 1 terrace lower), mouth (sea / lake ≤ 2 cells), bank / wall land cells beside the river.
        if (ME.WATER_SCATTER && t.water) { const WS = ME.WATER_SCATTER, wc = t.water.classes || [], idsOf = re => new Set(wc.filter(c => re.test(c.name)).map(c => c.id));
          const SH = idsOf(WS.shallow), RF = idsOf(/reef/i), IC = idsOf(WS.icy), VI = idsOf(WS.violet), pk = (K, v) => { let tot = 0; for (const [, w] of K) tot += w; let q = v * tot; for (const [k, w] of K) if ((q -= w) <= 0) return k; return K[0][0]; };
          const isRiv = j => !!(t.riv && t.riv[j] > 0.5), seaW = j => w2[j] >= 2 && !isRiv(j), rtop = j => Math.max(WATER_H, Math.floor(H[j] / T) * T - T);
          const wprop = (id, x, z, gy, okC, tag) => { const k = kitOf(id), fw = k.W * EL.K, fd = k.D * EL.K, x0 = x - fw / 2, z0 = z - fd / 2, cells = [];
            for (let zz = Math.floor(z0 / 2); zz <= Math.ceil((z0 + fd) / 2) - 1; zz++) for (let xx = Math.floor(x0 / 2); xx <= Math.ceil((x0 + fw) / 2) - 1; xx++) { if (xx < 0 || zz < 0 || xx >= RW || zz >= RH) return false; const j = zz * RW + xx; if (!okC(j) || grid.occ[j] || occ[j]) return false; cells.push(j); }
            for (const j of cells) grid.occ[j] = 3; gen.push({ id: tag, type: 'gen', kit: id, settlement: null, nf: true, gyRaw: gy, L: Object.assign(k.parts, { W: k.W }), x, y: z0 + fd, plot: { px: fw / 2, pb: fd } }); return true; };
          let nw = 0, nr = 0; for (let z = 5; z < t.H - 5; z += 10) for (let x = 5; x < t.W - 5; x += 10) { const jx = x + Math.floor(hh(x + 3, z) * 7) - 3, jz = z + Math.floor(hh(x, z + 5) * 7) - 3, j = J(jx, jz); if (!seaW(j)) continue;
            const code = t.water.code[jz * t.W + jx]; if (code === 255) continue; const c = code >> 2; if (!SH.has(c)) continue; if (hh(jx * 7 + 3, jz * 3 + 1) > (RF.has(c) ? WS.dReef : WS.d)) continue;
            if (wprop(pk(IC.has(c) ? WS.kIcy : VI.has(c) ? WS.kViolet : WS.k, hh(jx + 5, jz + 9)), jx, jz, WATER_H - 0.08 * T, seaW, 'ws_' + nw)) nw++; }
          const RV = WS.river; for (let j = 0; j < N; j++) { if (!isRiv(j)) continue; const x = j % RW, z = (j / RW) | 0; if (x < 2 || z < 2 || x >= RW - 2 || z >= RH - 2) continue; const r0 = Math.round(rtop(j) / T);
            let p = 0; for (const n of [j - 1, j + 1, j - RW, j + RW]) if (isRiv(n) && Math.round(rtop(n) / T) < r0) p = Math.max(p, RV.drop);
            if (!p) { let m = false; for (let dz = -2; dz <= 2 && !m; dz++) for (let dx = -2; dx <= 2; dx++) if (seaW(j + dz * RW + dx)) { m = true; break; } if (m) p = RV.mouth; }
            if (p && hh(x * 5 + 1, z * 7 + 3) < p && wprop(pk(RV.kits, hh(x, z + 3)), x * 2 + 1, z * 2 + 1, rtop(j) - 0.08 * T, isRiv, 'rr_' + nr)) nr++; }
          for (let j = 0; j < N; j++) { if (!grid.dry0[j] || isRiv(j)) continue; const x = j % RW, z = (j / RW) | 0; if (x < 1 || z < 1 || x >= RW - 1 || z >= RH - 1) continue; let nb = -1; for (const n of [j - 1, j + 1, j - RW, j + RW]) if (isRiv(n)) { nb = n; break; } if (nb < 0) continue;
            const p = lvl0(j) - Math.round(rtop(nb) / T) >= 2 ? RV.wall : RV.bank; if (hh(x * 3 + 7, z * 5 + 1) < p && prop(pk(RV.kits, hh(x + 1, z)), x * 2 + 1, z * 2 + 1, 'rb_' + nr)) nr++; }
          t.waterScatter = nw; t.riverRocks = nr; }
        t.sid = sR; t.sidHit = sH; t.gocc = grid.occ; t.gRail = grid.railHard; t.paint = grid.paint; t.paintCols = grid.cols; t.settleCount = gen.length; }
      for (const e of gen) { if (e.nf) { const j = J(Math.round(e.x), Math.round(e.y - e.plot.pb / 2)); t.elsP.push({ ...e, gy: e.gyRaw != null ? e.gyRaw : Math.max(WATER_H + T, e.gyMin != null ? e.gyMin : H[j]), fits: true, moved: [0, 0] }); continue; } // foliage / props sit on the terrain, no flatten
        PX = e.plot.px; PB = e.plot.pb; PF = 0; const v = []; each(e, j => v.push(H[j])); if (!v.length) continue; v.sort((p, q) => p - q);
        const gy = e.low ? Math.max(WATER_H + T, Math.round(v[0] / T) * T) : Math.max(WATER_H + T, Math.round(v[v.length >> 1] / T) * T); each(e, j => { H[j] = gy; }); t.elsP.push({ ...e, gy, fits: true, moved: [0, 0] }); } // low = docks: plot cut down to the lowest land level
      PF = EL.plotFront;
      for (const e0 of els) { if (e0.type === 'settlement') continue; ({ px: PX, pb: PB } = dims(e0)); const pl = place(e0), e = { ...e0, x: e0.x + pl.dx, y: e0.y + pl.dz, moved: [pl.dx, pl.dz], fits: pl.s === 0 }, v = []; each(e, j => v.push(H[j])); if (!v.length) continue; v.sort((p, q) => p - q); const gy = Math.max(WATER_H + T, Math.round(v[v.length >> 1] / T) * T); each(e, j => { H[j] = gy; }); t.elsP.push({ ...e, gy }); } if (t.__ramp) { try { t.__ramp(); } catch (er) { console.warn('[ramp]', er && er.message); } t.__ramp = null; } } /* trail ramps after plot flattening (still inside prepEls) */
    function buildOverlay() { ovKey = okey(); ovGen++; const hs = o.heightScale, NBI = t.nb; let cap = 1 << 17, V = new Float32Array(cap * 40), I = new Uint32Array(cap * 6), nq = 0;
      const natAt = (x, z) => { if (!NBI) return [0, 0]; const i = Math.min(NBI.ch - 1, Math.max(0, (z / NBI.cs) | 0)) * NBI.cw + Math.min(NBI.cw - 1, Math.max(0, (x / NBI.cs) | 0)); return [NBI.NB[i], NBI.NB0[i]]; };
      let segNat = null; const quad = (pts, col, uv, nat) => { nat = nat || segNat; if (nq >= cap) { cap *= 2; const V2 = new Float32Array(cap * 40); V2.set(V); V = V2; const I2 = new Uint32Array(cap * 6); I2.set(I); I = I2; }
        let k = nq * 40; for (let q = 0; q < 4; q++) { const p = pts[q], nn = nat || natAt(p[0], p[2]); V[k++] = p[0]; V[k++] = p[1]; V[k++] = p[2]; V[k++] = col[0]; V[k++] = col[1]; V[k++] = col[2]; V[k++] = nn[0]; V[k++] = nn[1]; V[k++] = uv ? uv[q][0] : -1; V[k++] = uv ? uv[q][1] : -1; }
        const b = nq * 4, j = nq * 6; I[j] = b; I[j + 1] = b + 1; I[j + 2] = b + 2; I[j + 3] = b + 2; I[j + 4] = b + 1; I[j + 5] = b + 3; nq++; };
      const C3 = h => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255], mulc = (c, f) => [c[0] * f, c[1] * f, c[2] * f];
      const shade = (nx, nz) => nz * nz * (nz > 0 ? 0.62 : 0.45) + nx * nx * (nx > 0 ? 0.5 : 0.78); // same face light as voxel sides (S .62, N .45, E .5, W .78)
      const RT = C3('#d8dbe1'), RSd = C3('#8e939c'), TT = C3('#8a6240'), TS = C3('#6e4a2c'), BAL = C3('#8a8073'), DECK = C3('#4a3226'), PIER = C3('#7a4126'), RUSTC = C3('#a85f34'), hsh = i => { let h = (i * 2654435761) >>> 0; h ^= h >>> 15; return (h % 1000) / 1000; };
      // Atlas sub-rect UVs (columns c0..c1, rows r0..r1 of sprite s) in quad order p0 (c0,r0) · p1 (c0,r1) · p2 (c1,r0) · p3 (c1,r1).
      const uvc = (s, c0, c1, r0, r1) => { const [u0, u1, v1] = UV.get(s), U = c => u0 + (u1 - u0) * c / s.width, Vv = r => v1 * r / s.height; return [[U(c0), Vv(r0)], [U(c0), Vv(r1)], [U(c1), Vv(r0)], [U(c1), Vv(r1)]]; };
      const box = (cx, cz, ux, uz, hu, vx, vz, hv, y0, y1, top, side, tt, ts) => { const P = (su, sv) => [cx + ux * su * hu + vx * sv * hv, cz + uz * su * hu + vz * sv * hv];
        const a = P(-1, -1), b = P(-1, 1), c = P(1, -1), d = P(1, 1); quad([[a[0], y1, a[1]], [b[0], y1, b[1]], [c[0], y1, c[1]], [d[0], y1, d[1]]], tt ? [1, 1, 1] : top, tt ? uvc(tt, 0, tt.width, 0, tt.height) : null);
        for (const [p, q, nx, nz] of [[a, b, -ux, -uz], [c, d, ux, uz], [a, c, -vx, -vz], [b, d, vx, vz]]) quad([[p[0], y1, p[1]], [p[0], y0, p[1]], [q[0], y1, q[1]], [q[0], y0, q[1]]], ts ? [shade(nx, nz), shade(nx, nz), shade(nx, nz)] : mulc(side, shade(nx, nz)), ts ? uvc(ts, 0, ts.width, 0, ts.height) : null); };
      // Sprite atlas: dithered contact shadow (0,0 16×6) · bridge end · bridge mid · element layers. UV.get(canvas) → [u0, u1, v1].
      const mkc = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }, E = window.MercElements ? window.MercElements.make(mkc) : null;
      const BRG = E && E.bridge ? E.bridge() : null, groups = E && t.elsP ? t.elsP.map(e => ({ e, L: e.L || E.model(e.type, e) })) : [], sprites = [];
      const RTX = E && E.rail ? E.rail() : null, UB = E && E.ubridge ? E.ubridge() : null; if (BRG) sprites.push(BRG.end, BRG.mid); if (UB) sprites.push(UB.end, UB.mid); if (RTX) sprites.push(...Object.values(RTX)); const FX = E && E.fire ? E.fire() : null, LW = E && E.litWhite ? E.litWhite() : null; if (FX) sprites.push(FX.strip); if (LW) sprites.push(LW); vhKit = window.MercVehicles ? window.MercVehicles.make(mkc) : null; if (vhKit) { sprites.push(...vhKit.textures()); if (E && E.kit) { const k = E.kit('p_campfire', null, () => 0.5); vhKit.campfire = Object.assign(k.parts, { W: k.W }); } } const seen = new Set(); for (const L of [...groups.map(g => g.L), (vhKit && vhKit.campfire) || []]) for (const p of L) for (const t0 of Object.values(p.tex)) { const s = t0.s || t0; if (!seen.has(s)) { seen.add(s); sprites.push(s); } } // + campfire (vehicle-drawn element kit)
      const UV = new Map(); if (sprites.length) { let AW = 18, AH = 8; for (const s of sprites) { AW += s.width + 2; AH = Math.max(AH, s.height); }
        const cv = mkc(AW, AH), cg = cv.getContext('2d'), sd = cg.createImageData(16, 6);
        for (let y = 0; y < 6; y++) for (let x = 0; x < 16; x++) { const dx = (x - 7.5) / 8, dy = (y - 2.5) / 3; if (dx * dx + dy * dy < 1 && ((x + y) & 1) === 0) { const q = (y * 16 + x) * 4; sd.data[q] = 20; sd.data[q + 1] = 24; sd.data[q + 2] = 16; sd.data[q + 3] = 255; } }
        cg.putImageData(sd, 0, 0); UV.set('shadow', [0, 16 / AW, 6 / AH]); let ax = 18; for (const s of sprites) { cg.drawImage(s, ax, 0); UV.set(s, [ax / AW, (ax + s.width) / AW, s.height / AH]); ax += s.width + 2; }
        { const gcv = mkc(AW, AH), gg = gcv.getContext('2d'); let bx = 18; for (const s of sprites) { if (s.light) gg.drawImage(s.light, bx, 0); bx += s.width + 2; } // light-map atlas (same layout)
          glTex = glTex || gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, glTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, gcv);
          for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v); }
        FIRE = FX && UV.get(FX.strip) ? { uv: UV.get(FX.strip), s: FX.strip } : null;
        spTex = spTex || gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, spTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, cv);
        for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v); }
      if (t.rail) for (const l of t.rail.lines) { const P = l.p2, Z = l.z2, n = P ? P.length : 0; if (n < 2) continue; const N = nrm(P, 2), BRm = l.br || new Uint8Array(n);
        const Y = i => Z[i] * hs + RAIL.bh, YB = i => Z[i] * hs - 3 * TERRACE * hs, off = (i, s) => [P[i][0] + N[i][0] * s, P[i][1] + N[i][1] * s];
        // One nation per segment (its midpoint): on hover the track splits cleanly at the border (lifted piece + flat piece) instead of stretching.
        for (let i = 0; i < n - 1; i++) { segNat = natAt((P[i][0] + P[i + 1][0]) / 2, (P[i][1] + P[i + 1][1]) / 2); const j = i + 1, onB = BRm[i] && BRm[j], bc = mulc(onB ? DECK : BAL, 0.9 + 0.18 * hsh(i >> 1)), a = off(i, -RAIL.bw), b = off(i, RAIL.bw), c = off(j, -RAIL.bw), d = off(j, RAIL.bw);
          const yb0 = onB ? Y(i) - 1 : YB(i), yb1 = onB ? Y(j) - 1 : YB(j); // bridge deck: thin edge; land: ballast embankment down into the ground
          const tx = RTX && !onB, r8 = i % 8, r4 = i % 4, fv = 0.94 + 0.12 * hsh(i >> 1); // textured from the atlas (ballast / ties / rails); bridge deck stays flat
          quad([[a[0], Y(i), a[1]], [c[0], Y(j), c[1]], [b[0], Y(i), b[1]], [d[0], Y(j), d[1]]], tx ? [fv, fv, fv] : bc, tx ? uvc(RTX.ballast, 0, 10, r8, r8 + 1) : null);
          for (const [p0, p1, sg] of [[a, c, -1], [b, d, 1]]) { const sh = shade(N[i][0] * sg, N[i][1] * sg); quad([[p0[0], Y(i), p0[1]], [p0[0], yb0, p0[1]], [p1[0], Y(j), p1[1]], [p1[0], yb1, p1[1]]], tx ? [sh, sh, sh] : mulc(bc, sh), tx ? uvc(RTX.ballastSide, r8, r8 + 1, 0, 4) : null); }
          if (onB) for (const sg of [-1, 1]) { const o0 = off(i, sg * (RAIL.bw - 0.9)), o1 = off(i, sg * (RAIL.bw + 0.05)), p0 = off(j, sg * (RAIL.bw - 0.9)), p1 = off(j, sg * (RAIL.bw + 0.05)), yt0 = Y(i) + 0.7, yt1 = Y(j) + 0.7, rc = mulc(RUSTC, 0.85 + 0.3 * hsh(i * 3 + sg));
            quad([[o0[0], yt0, o0[1]], [p0[0], yt1, p0[1]], [o1[0], yt0, o1[1]], [p1[0], yt1, p1[1]]], rc); quad([[o1[0], yt0, o1[1]], [o1[0], Y(i), o1[1]], [p1[0], yt1, p1[1]], [p1[0], Y(j), p1[1]]], mulc(rc, shade(N[i][0] * sg, N[i][1] * sg))); } // rusty top chords: the bridge reads from above on any heading
          for (const sg of [-1, 1]) { const gq = RAIL.gauge * sg, w = RAIL.railW, y0i = Y(i) + RAIL.tieH, y0j = Y(j) + RAIL.tieH, y1i = y0i + RAIL.railH, y1j = y0j + RAIL.railH;
            const i0 = off(i, gq - w), i1 = off(i, gq + w), j0 = off(j, gq - w), j1 = off(j, gq + w);
            quad([[i0[0], y1i, i0[1]], [j0[0], y1j, j0[1]], [i1[0], y1i, i1[1]], [j1[0], y1j, j1[1]]], RTX ? [1, 1, 1] : RT, RTX ? uvc(RTX.railTop, 0, 1, r4, r4 + 1) : null);
            for (const [p0, p1, s2] of [[i0, j0, -1], [i1, j1, 1]]) { const sh = shade(N[i][0] * s2, N[i][1] * s2) / 0.62; quad([[p0[0], y1i, p0[1]], [p0[0], y0i, p0[1]], [p1[0], y1j, p1[1]], [p1[0], y0j, p1[1]]], RTX ? [sh, sh, sh] : mulc(RSd, sh * 0.62), RTX ? uvc(RTX.railSide, r4, r4 + 1, 0, 1) : null); } } }
        // Buffer stops (2026-10-07k): at a line end no other line shares (dead end), a red-and-white buffer beam on two posts + a sloped back brace + sleeper pad.
        for (const [ei, di] of [[0, 1], [n - 1, n - 2]]) { const E = P[ei], shared = t.rail.lines.some(o => o !== l && o.p2 && o.p2.length && [o.p2[0], o.p2[o.p2.length - 1]].some(q => Math.hypot(q[0] - E[0], q[1] - E[1]) < 6)); if (shared) continue;
          const ux = E[0] - P[di][0], uz = E[1] - P[di][1], ul = Math.hypot(ux, uz) || 1, dx = ux / ul, dz = uz / ul, nx = -dz, nz = dx, y0 = Y(ei), cx = E[0] - dx * 1.2, cz = E[1] - dz * 1.2; segNat = natAt(E[0], E[1]);
          box(cx - dx * 0.8, cz - dz * 0.8, dx, dz, 1.6, nx, nz, RAIL.bw, y0 - 0.2, y0 + 0.5, TT, TS);
          for (const sg of [-1, 1]) box(cx + nx * sg * RAIL.gauge, cz + nz * sg * RAIL.gauge, dx, dz, 0.45, nx, nz, 0.45, y0, y0 + 3.4, C3('#5a4a3a'), C3('#4a3a2a'));
          for (const sg of [-1, 1]) box(cx + dx * 1 + nx * sg * RAIL.gauge, cz + dz * 1 + nz * sg * RAIL.gauge, dx, dz, 0.9, nx, nz, 0.35, y0, y0 + 1.8, C3('#5a4a3a'), C3('#4a3a2a'));
          for (let k = -3; k <= 2; k++) { const w = (RAIL.gauge + 1) / 3; box(cx - dx * 0.5 + nx * (k + 0.5) * w, cz - dz * 0.5 + nz * (k + 0.5) * w, dx, dz, 0.45, nx, nz, w / 2, y0 + 2.2, y0 + 3.3, k & 1 ? C3('#f2efe6') : C3('#c8302a'), k & 1 ? C3('#c8c4bc') : C3('#9a241e')); }
          for (const sg of [-1, 1]) box(cx - dx * 0.95 + nx * sg * 1.2, cz - dz * 0.95 + nz * sg * 1.2, dx, dz, 0.25, nx, nz, 0.6, y0 + 2.3, y0 + 3.1, C3('#2a2a2e'), C3('#1e1e22')); t.railStops = (t.railStops || 0) + 1; }
        for (let s = 1.3; s < n - 1; s += RAIL.tieStep) { const i = Math.round(s); segNat = natAt(P[i][0], P[i][1]); const nx = N[i][0], nz = N[i][1]; box(P[i][0], P[i][1], nz, -nx, RAIL.tieW, nx, nz, RAIL.tieL, Y(i) - 0.2, Y(i) + RAIL.tieH, TT, TS, RTX && RTX.tieTop, RTX && RTX.tieSide); }
        if (BRG && UV.size) { const cum = new Float32Array(n); for (let i = 1; i < n; i++) cum[i] = cum[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]);
          const idxAt = a => { let lo = 0, hi = n - 1; while (hi - lo > 1) { const md = (lo + hi) >> 1; if (cum[md] <= a) lo = md; else hi = md; } return lo; };
          const ptAt = (a, so) => { const k = idxAt(a), f = Math.min(1, Math.max(0, (a - cum[k]) / ((cum[k + 1] - cum[k]) || 1))), nx = N[k][0] + (N[k + 1][0] - N[k][0]) * f, nz = N[k][1] + (N[k + 1][1] - N[k][1]) * f;
            return [P[k][0] + (P[k + 1][0] - P[k][0]) * f + nx * so, (Z[k] + (Z[k + 1] - Z[k]) * f) * hs + RAIL.bh, P[k][1] + (P[k + 1][1] - P[k][1]) * f + nz * so, k, nx, nz]; };
          const piece = (a0, a1, u0, u1, v1) => { if (a1 - a0 < 0.05) return; const st = [a0]; for (let k = idxAt(a0) + 1; k < n && cum[k] < a1; k++) if (cum[k] > a0) st.push(cum[k]); st.push(a1);
            for (const sg of [-1, 1]) for (let q = 0; q < st.length - 1; q++) { const A = ptAt(st[q], sg * (RAIL.bw + 0.05)), B = ptAt(st[q + 1], sg * (RAIL.bw + 0.05)), ua = u0 + (u1 - u0) * (st[q] - a0) / (a1 - a0), ub = u0 + (u1 - u0) * (st[q + 1] - a0) / (a1 - a0);
              segNat = natAt((A[0] + B[0]) / 2, (A[2] + B[2]) / 2); quad([[A[0], A[1] + 0.3, A[2]], [A[0], A[1] + 0.3 - RAIL.trussH, A[2]], [B[0], B[1] + 0.3, B[2]], [B[0], B[1] + 0.3 - RAIL.trussH, B[2]]], [1, 1, 1], [[ua, 0], [ua, v1], [ub, 0], [ub, v1]]); } };
          const [eu0, eu1, ev] = UV.get(BRG.end), [mu0, mu1, mv] = UV.get(BRG.mid), endW = BRG.end.width * RAIL.bk, midW = BRG.mid.width * RAIL.bk;
          for (let s = 0; s < n; s++) { if (!BRm[s]) continue; let e = s; while (e + 1 < n && BRm[e + 1]) e++;
            const aS = cum[s], aE = cum[e], Lr = aE - aS, nMid = Math.max(0, Math.round((Lr - 2 * endW) / midW)), eW = nMid ? endW : Lr / 2, mW = nMid ? (Lr - 2 * endW) / nMid : 0;
            piece(aS, aS + eW, eu0, eu1, ev); for (let k = 0; k < nMid; k++) piece(aS + eW + k * mW, aS + eW + (k + 1) * mW, mu0, mu1, mv); piece(aE - eW, aE, eu1, eu0, ev); // far end mirrored
            for (let k = 0; k <= nMid && nMid; k++) { const p = ptAt(aS + eW + k * mW, 0), wv = l.wt[p[3]]; if (!(wv >= 0)) continue; const yt = p[1] + 0.3 - RAIL.trussH, yb = wv * hs - 2; // steel pier into the water
              segNat = natAt(p[0], p[2]); if (yt > yb) box(p[0], p[2], p[5], -p[4], 0.9, p[4], p[5], RAIL.bw * 0.6, yb, yt, PIER, PIER); }
            s = e; } } }
      // Universal bridges: stone deck + parapets on both sides; arch band (end · mid × k · mirrored end) below the deck where it clears the ground.
      if (t.brP && UB && UV.size) { const STN = C3('#9c9286'), CAP = C3('#d6cdbf'), PIERC = C3('#857b70'), UH = UB.mid.height * UBR.bk / Math.cos(55 * Math.PI / 180);
        for (const br of t.brP) { const nA = natAt(br.P[0][0], br.P[0][1]), nB = natAt(br.P[br.P.length - 1][0], br.P[br.P.length - 1][1]), pair = (x, y) => (x && y && x !== y ? x + 32 * y : x || y);
          const BN = [pair(nA[0], nB[0]), pair(nA[1], nB[1])]; // whole bridge = one unit: lifts / brightens when either end's nation is hovered
          const { P, G, D } = br, n = P.length, nx = -br.uz, nz = br.ux, HMP = Math.min(UBR.hump * (n - 1), UBR.humpMax), hump = a => HMP * Math.sin(Math.PI * Math.min(1, Math.max(0, a / (n - 1)))), Y = i => D[i] * hs + 0.6 + hump(i), off = (i, s) => [P[i][0] + nx * s, P[i][1] + nz * s];
          for (let i = 0; i < n - 1; i++) { const j = i + 1; segNat = BN; const a = off(i, -UBR.bw), b = off(i, UBR.bw), c = off(j, -UBR.bw), d = off(j, UBR.bw), dc = mulc(STN, 0.92 + 0.12 * hsh(i));
            quad([[a[0], Y(i), a[1]], [c[0], Y(j), c[1]], [b[0], Y(i), b[1]], [d[0], Y(j), d[1]]], dc);
            const yb = k => Math.max(Y(k) - UBR.slab, Math.min(Y(k) - UBR.slab, G[k] * hs)) ; // thin slab edge (no fill down to the ground)
            for (const [p0, p1, sg] of [[a, c, -1], [b, d, 1]]) quad([[p0[0], Y(i), p0[1]], [p0[0], yb(i), p0[1]], [p1[0], Y(j), p1[1]], [p1[0], yb(j), p1[1]]], mulc(dc, shade(nx * sg, nz * sg)));
            quad([[a[0], yb(i), a[1]], [b[0], yb(i), b[1]], [c[0], yb(j), c[1]], [d[0], yb(j), d[1]]], mulc(dc, 0.55)); // underside
            for (const sg of [-1, 1]) { const o0 = off(i, sg * (UBR.bw - UBR.parW)), o1 = off(i, sg * (UBR.bw + 0.05)), p0 = off(j, sg * (UBR.bw - UBR.parW)), p1 = off(j, sg * (UBR.bw + 0.05)), y0 = Y(i) + UBR.parH, y1 = Y(j) + UBR.parH;
              quad([[o0[0], y0, o0[1]], [p0[0], y1, p0[1]], [o1[0], y0, o1[1]], [p1[0], y1, p1[1]]], CAP); quad([[o0[0], y0, o0[1]], [o0[0], Y(i), o0[1]], [p0[0], y1, p0[1]], [p0[0], Y(j), p0[1]]], mulc(CAP, shade(-nx * sg, -nz * sg))); } }
          const onB = D.map((dd, i) => dd - G[i] >= UBR.clr * TERRACE); let s = 0; while (s < n && !onB[s]) s++; let e = n - 1; while (e > s && !onB[e]) e--;
          if (e - s >= 2) { const Lr = e - s, endW = UB.end.width * UBR.bk, midW = UB.mid.width * UBR.bk, nMid = Math.max(0, Math.round((Lr - 2 * endW) / midW)), eW = nMid ? endW : Lr / 2, mW = nMid ? (Lr - 2 * endW) / nMid : 0;
            const ptAt = (a, so) => { const k = Math.min(n - 2, Math.floor(a)), f = a - k; return [P[k][0] + (P[k + 1][0] - P[k][0]) * f + nx * so, (D[k] + (D[k + 1] - D[k]) * f) * hs + 0.6 + hump(a) + UBR.parH, P[k][1] + (P[k + 1][1] - P[k][1]) * f + nz * so, k]; };
            const piece = (a0, a1, u0, u1, v1) => { for (const sg of [-1, 1]) { const A = ptAt(a0, sg * (UBR.bw + 0.06)), B2 = ptAt(a1, sg * (UBR.bw + 0.06)); segNat = BN;
              quad([[A[0], A[1], A[2]], [A[0], A[1] - UH, A[2]], [B2[0], B2[1], B2[2]], [B2[0], B2[1] - UH, B2[2]]], [1, 1, 1], [[u0, 0], [u0, v1], [u1, 0], [u1, v1]]); } };
            const [eu0, eu1, ev] = UV.get(UB.end), [mu0, mu1, mv] = UV.get(UB.mid);
            piece(s, s + eW, eu0, eu1, ev); for (let k = 0; k < nMid; k++) piece(s + eW + k * mW, s + eW + (k + 1) * mW, mu0, mu1, mv); piece(e - eW, e, eu1, eu0, ev);
            for (let k = 0; k <= nMid && nMid; k++) { const p = ptAt(s + eW + k * mW, 0), g = G[p[3]] * hs - TERRACE * hs, yt = p[1] - UH + 0.2; segNat = BN; if (yt > g) box(p[0], p[2], br.ux, br.uz, UBR.pierW, nx, nz, UBR.bw * 0.8, g, yt, PIERC, PIERC); } }
          // Torches (2026-10-07): a pillar rises out of each parapet above every pier (no piers: arch ends; no arch: deck ends), torch bowl + crossed fire quads on top.
          const noFire = [nA[0], nB[0]].some(id => id && t.natById && t.natById[id] && /Cyfrolaef/.test(t.natById[id].name)); if (FIRE && !noFire) { const pos = []; if (e - s >= 2) { const Lr = e - s, endW = UB.end.width * UBR.bk, midW = UB.mid.width * UBR.bk, nM = Math.max(0, Math.round((Lr - 2 * endW) / midW)), eW2 = nM ? endW : Lr / 2, mW2 = nM ? (Lr - 2 * endW) / nM : 0; if (nM) for (let k = 0; k <= nM; k++) pos.push(s + eW2 + k * mW2); else pos.push(s, e); } else pos.push(Math.min(n - 1, 1), Math.max(0, n - 2));
            const fu0 = FIRE.uv[0], fv1 = FIRE.uv[2], fdu = (FIRE.uv[1] - FIRE.uv[0]) / FIRE.s.width, fu1 = fu0 + fdu * FIRE.s.fw, IRON = C3('#3a3430');
            for (const a of pos) { const k = Math.max(0, Math.min(n - 2, Math.floor(a))), f = Math.min(1, a - k), yD = (D[k] + (D[k + 1] - D[k]) * f) * hs + 0.6 + hump(a);
              for (const sg of [-1, 1]) { const so = sg * (UBR.bw - UBR.parW / 2), x = P[k][0] + (P[k + 1][0] - P[k][0]) * f + nx * so, z = P[k][1] + (P[k + 1][1] - P[k][1]) * f + nz * so, yT = yD + UBR.parH + 2.2; segNat = BN;
                box(x, z, br.ux, br.uz, 0.6, nx, nz, 0.6, yD, yT, CAP, STN); box(x, z, br.ux, br.uz, 0.75, nx, nz, 0.75, yT, yT + 0.3, CAP, CAP); box(x, z, br.ux, br.uz, 0.4, nx, nz, 0.4, yT + 0.3, yT + 0.75, IRON, IRON);
                const fc = [100 + (Math.abs(Math.sin(x * 12.9898 + z * 78.233) * 43758.5453) % 4), fdu * FIRE.s.fw, 0], y0 = yT + 0.6, y1 = yT + 3.6, w = 0.95;
                for (const [qx, qz] of [[br.ux, br.uz], [nx, nz]]) quad([[x - qx * w, y1, z - qz * w], [x - qx * w, y0, z - qz * w], [x + qx * w, y1, z + qz * w], [x + qx * w, y0, z + qz * w]], fc, [[fu0, 0], [fu0, fv1], [fu1, 0], [fu1, fv1]]);
                t.fireTorches = (t.fireTorches || 0) + 1; (t.fireSrc || (t.fireSrc = new Map())).set('t' + Math.round(x * 2) + ',' + Math.round(z * 2), [x, y1, z]); } } } } } // fireSrc: smoke sources (see MercVehicles smoke)
      segNat = null;
      // Semi-3D elements: every face except the back (north) wall. Faces lit like voxel sides but brighter (textures carry their own shading).
      const LT = { top: 1, s: 0.9, w: 0.96, e: 0.76, rs: 0.98, rn: 0.82 }; let curTint = null, curTF = null, curFace = '', curRot = null, curFire = null, curNoLit = false, curXf = null, curC = null;
      const CYF = new Set(Object.values(t.natById || {}).filter(n => /Cyfrolaef/.test(n.name)).map(n => n.id)), CRL = (t.labels || []).find(l => l.name === 'Yrspholahs'), noLitAt = (x, z) => { const xi = Math.max(0, Math.min(t.W - 1, Math.round(x))), zi = Math.max(0, Math.min(t.H - 1, Math.round(z))); return (t.nat && CYF.has(t.nat[zi * t.W + xi])) || (CRL && Math.hypot(x - CRL.ix, z - CRL.iz) < 260); };
      // Rotated parts (2026-10-07g): p.tilt (rad, roll in the x–y plane; + = top toward −x) / p.pitch (rad, + = top leans north) about p.piv [x, y, z] (model units) or the part's base centre.
      const rotP = q => { const Rr = curRot, cx = Rr.c[0], cy = Rr.c[1], cz = Rr.c[2]; let dx = q[0] - cx, dy = q[1] - cy, dz = q[2] - cz;
        if (Rr.t) { const c = Math.cos(Rr.t), s = Math.sin(Rr.t), nx = dx * c - dy * s; dy = dx * s + dy * c; dx = nx; } if (Rr.p) { const c = Math.cos(Rr.p), s = Math.sin(Rr.p), nz = dz * c - dy * s; dy = dz * s + dy * c; dz = nz; } return [cx + dx, cy + dy, cz + dz]; };
      // Vehicles (2026-10-07, map-vehicles.js): group.vh = { yaw, pitch } → every point turns about the group centre (pitch = nose up in x–y, then yaw in x–z); faces lit from their
      // real normal (top 1 · S .9 · W .96 · E .76 · N .82, undersides darker) and boxes also draw the back (north) face. group.sh = { x, z, y, w, d } → dithered ground shadow.
      const mkXf = (cx, cy, cz, v) => { const cw = Math.cos(v.yaw || 0), sw = Math.sin(v.yaw || 0), cp = Math.cos(v.pitch || 0), sp = Math.sin(v.pitch || 0); return q => { const dx = q[0] - cx, dy = q[1] - cy, dz = q[2] - cz, x1 = dx * cp - dy * sp, y1 = dx * sp + dy * cp; return [cx + x1 * cw - dz * sw, cy + y1, cz + x1 * sw + dz * cw]; }; };
      const nLit = P => { const ax = P[3][0] - P[0][0], ay = P[3][1] - P[0][1], az = P[3][2] - P[0][2], bx = P[1][0] - P[2][0], by = P[1][1] - P[2][1], bz = P[1][2] - P[2][2]; let nx = ay * bz - az * by, ny = az * bx - ax * bz, nz = ax * by - ay * bx; const L = Math.hypot(nx, ny, nz); if (L < 1e-9) return 1; nx /= L; ny /= L; nz /= L;
        const mx = (P[0][0] + P[3][0]) / 2 - curC[0], my = (P[0][1] + P[3][1]) / 2 - curC[1], mz = (P[0][2] + P[3][2]) / 2 - curC[2], dd = nx * mx + ny * my + nz * mz; if (dd < -1e-4 || (Math.abs(dd) <= 1e-4 && nz < 0)) { nx = -nx; ny = -ny; nz = -nz; }
        const hz = nx * nx + nz * nz, sd = hz > 1e-6 ? (nz * nz * (nz > 0 ? 0.9 : 0.82) + nx * nx * (nx > 0 ? 0.76 : 0.96)) / hz : 1; return ny >= 0 ? sd + (1 - sd) * ny : sd * (1 + 0.4 * ny); };
      // Scatter (2026-10-07g): elements flagged nf (foliage, terrain / water / river props, lilies, trail props, Cyfrolaef ruins) are NOT baked into the static
      // overlay; scEmit(groups) writes them into a separate buffer that drawGround rebuilds for the camera rect only (same rule as ground cover). opts.cullScatter = false → bake all.
      // Lift nation: the element's front-centre; if that is water (docks / harbours / shipyards reach into the sea → 0), the first land sample in its footprint.
      const natOfEl = e => { if (e.noLift) return [0, 0]; if (e.natPt) return natAt(e.natPt[0], e.natPt[1]); let n = natAt(e.x, e.y); if (n[0]) return n; const pb = (e.plot && e.plot.pb) || 8, px = (e.plot && e.plot.px) || 8; for (const fz of [0.3, 0.6, 0.9, 1.2]) for (const fx of [0, -0.5, 0.5, -0.9, 0.9]) { const m = natAt(e.x + fx * px, e.y - fz * pb); if (m[0]) return m; } return n; };
      // Perf: small scatter (rocks, debris, water / river props, lilies, trail props, ground kits) casts no contact shadow; trees (f_*) keep theirs.
      // Lit parts (2026-10-07): a dark (luma ≤ 0.14), thin (min(w, d) ≤ 0.35), upright (h ≥ 0.4) plain_white part = window / door slab → its plain faces swap to lit_white (same look by day, glows at night).
      const NOLIT = /^(cy_|lm_cave|f_|p_|r_|w_|ice|gw_grate)/, litSwap = (p, kit) => { if (!LW || !p.tint || p.fire || !p.tex || NOLIT.test(kit || '')) return p.tex; const q = C3(p.tint); if (q[0] * 0.3 + q[1] * 0.59 + q[2] * 0.11 > 0.14 || Math.min(p.w || 0, p.d || 0) > 0.35 || (p.h || 0) < 0.4) return p.tex;
        const o2 = {}; let any = false; for (const [k, v] of Object.entries(p.tex)) { const s = (v && v.s) || v; if (s && s.id === 'plain_white' && !(v && v.r)) { o2[k] = LW; any = true; } else o2[k] = v; } return any ? o2 : p.tex; };
      const emitGroups = gs => { for (const g of gs) { if (g.noLit == null) g.noLit = !!noLitAt(g.e.x, g.e.y - 2); g.noSh = !!g.e.nf && !/^(f_|cy_|pal_|gw_)/.test(g.e.kit || ''); const nat = natOfEl(g.e), gy = g.e.gy * hs + 0.03, SW = g.L.W || E.SCENE_W, K = EL.K, KY = EL.KY, [s0, s1, sv] = UV.get('shadow'); curXf = g.vh ? mkXf(g.e.x, gy, g.e.y, g.vh) : null; if (g.sh) { const [t0, t1, tv] = g.sh.tex && UV.get(g.sh.tex) ? UV.get(g.sh.tex) : [s0, s1, sv]; for (const q of g.sh.cells) { const U = k => [t0 + (t1 - t0) * q[5 + 2 * k], tv * q[6 + 2 * k]]; quad([[q[0], q[4], q[1]], [q[0], q[4], q[3]], [q[2], q[4], q[1]], [q[2], q[4], q[3]]], [1, 1, 1], [U(0), U(1), U(2), U(3)], nat); } } // g.sh.tex: camp dirt patch; else the shadow ellipse. airship: per-block cells, per-corner UVs (rotated with heading)
        const WX = x => g.e.x + (x - SW / 2) * K, WZ = z => g.e.y - z * K, WY = y => yb + y * KY, F0 = (t0, pts, l, mir) => { if (curXf) { pts = (curRot ? pts.map(rotP) : pts).map(curXf); l = nLit(pts); } const s = t0.s || t0, tn = curTint && (!curTF || curTF.includes(curFace)) ? curTint : null, lc = tn ? [l * tn[0], l * tn[1], l * tn[2]] : [l, l, l], r = t0.r || [0, 0, s.width, s.height], uvq = UV.get(s); if (!uvq) { (window.__uvMiss = window.__uvMiss || new Set()).add(s.id || s.width + "x" + s.height); return; } const [u0, u1, v1] = uvq, du = (u1 - u0) / s.width, dv = v1 / s.height, lcF = curFire != null ? [100 + curFire, du * (s.fw || 5), 0] : curNoLit ? [lc[0], lc[1], -lc[2] - 1e-4] : lc; // module or sub-rect, stretched to the face
          let ua = u0 + r[0] * du, ub = u0 + (r[0] + r[2]) * du; const va = r[1] * dv, vb = (r[1] + r[3]) * dv; if (mir) [ua, ub] = [ub, ua]; quad(curRot && !curXf ? pts.map(rotP) : pts, lcF, [[ua, va], [ua, vb], [ub, va], [ub, vb]], nat); };
        // Tiled textures (.tile): face split into texture-sized cells, 1 texel per model unit, anchored bottom-left (partial cells use the bottom rows).
        const L3 = (a, b) => Math.hypot((b[0] - a[0]) / K, (b[1] - a[1]) / KY, (b[2] - a[2]) / K), LP = (a, b, u) => [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u];
        const F = (t0, pts, l, mir) => { const s = t0.s || t0; if (!s.tile || t0.r) return F0(t0, pts, l, mir);
          const w = Math.max(L3(pts[0], pts[2]), L3(pts[1], pts[3])), h = Math.max(L3(pts[0], pts[1]), L3(pts[2], pts[3])), TW = s.width, TH = s.height;
          if (w < 0.01 || h < 0.01) return; const nu = Math.max(1, Math.ceil(w / TW - 0.02)), nv = Math.max(1, Math.ceil(h / TH - 0.02)), B = (u, v) => LP(LP(pts[0], pts[2], u), LP(pts[1], pts[3], u), v);
          for (let i = 0; i < nu; i++) { const ua = i * TW / w, ub = Math.min(1, (i + 1) * TW / w); for (let j = 0; j < nv; j++) { const vb = 1 - j * TH / h, va = Math.max(0, 1 - (j + 1) * TH / h), th = (vb - va) * h;
            F0({ s, r: [0, TH - th, (ub - ua) * w, th] }, [B(ua, va), B(ua, vb), B(ub, va), B(ub, vb)], l, mir); } } };
        // wl parts (boats, piles, quays) start at the water surface; toDeck parts get h = water → element ground (+ h).
        const WL = WATER_H * hs + 0.04; let yb = gy;
        for (const p0 of g.L) { const p = p0.wl ? { ...p0, h: p0.toDeck ? (gy - WL) / KY + (p0.h || 0) : p0.h } : p0; yb = p.wl ? WL : gy; const x0 = WX(p.x - p.w / 2), x1 = WX(p.x + p.w / 2), cx = WX(p.x), cz = WZ(p.z), T0 = g.noLit ? p.tex : litSwap(p, g.e.kit); curNoLit = g.noLit; curTint = p.tint ? C3(p.tint) : null; curFire = p.fire ? (Math.abs(Math.sin(g.e.x * 12.9898 + g.e.y * 78.233 + p.x) * 43758.5453) % 4) : null; if (p.fire && !curXf) (t.fireSrc || (t.fireSrc = new Map())).set('e' + Math.round(cx * 2) + ',' + Math.round(cz * 2), [cx, WY((p.y || 0) + (p.h || 0)), cz]); curTF = p.tintFaces || null; curRot = p.tilt || p.pitch ? { t: p.tilt || 0, p: p.pitch || 0, c: p.piv ? [WX(p.piv[0]), WY(p.piv[1]), WZ(p.piv[2])] : [WX(p.x), WY(p.y || 0), WZ(p.z)] } : null;
          curC = curXf ? curXf(curRot ? rotP([cx, WY((p.y || 0) + (p.h || 0) / 2), cz]) : [cx, WY((p.y || 0) + (p.h || 0) / 2), cz]) : null; const T = new Proxy(T0, { get: (o, k) => { curFace = k; return o[k]; } }); // records which face is being drawn (for tintFaces)
          if (p.kind === 'card') { const z = cz, y0 = WY(p.y), y1 = WY(p.y + p.h); F(T.front, [[x0, y1, z], [x0, y0, z], [x1, y1, z], [x1, y0, z]], 1); continue; }
          const zn = WZ(p.z + (p.d || 0) / 2), zs = WZ(p.z - (p.d || 0) / 2), y0 = WY(p.y || 0), y1 = WY((p.y || 0) + (p.h || 0));
          if (p.kind === 'decal') { const y = gy + 0.08; F(T.top, [[x0, y, zn], [x0, y, zs], [x1, y, zn], [x1, y, zs]], 1); continue; }
          if (p.kind === 'box') { if (!p.y && !p.wl && !g.noSh) { const f = Math.min(1, (y1 - y0) / 6), sw = (x1 - x0) * (0.5 + 0.12 * f), ox = 1.5 * f; /* drop shadow scales with part height (f = h / 6 world, ≤ 1): low bushes / brush keep it tucked under the base instead of a detached blob */ quad([[cx - sw + ox, gy + 0.05, zn + f], [cx - sw + ox, gy + 0.05, zs + 0.4 + 1.8 * f], [cx + sw + ox, gy + 0.05, zn + f], [cx + sw + ox, gy + 0.05, zs + 0.4 + 1.8 * f]], [1, 1, 1], [[s0, 0], [s0, sv], [s1, 0], [s1, sv]], nat); }
            F(T.top, [[x0, y1, zn], [x0, y1, zs], [x1, y1, zn], [x1, y1, zs]], LT.top); F(T.front, [[x0, y1, zs], [x0, y0, zs], [x1, y1, zs], [x1, y0, zs]], LT.s);
            F(T.left, [[x0, y1, zn], [x0, y0, zn], [x0, y1, zs], [x0, y0, zs]], LT.w); F(T.right, [[x1, y1, zs], [x1, y0, zs], [x1, y1, zn], [x1, y0, zn]], LT.e); if (curXf) F(T.back || T.front, [[x1, y1, zn], [x1, y0, zn], [x0, y1, zn], [x0, y0, zn]], LT.rn); continue; }
          if (p.kind === 'gable') { const zc = cz; F(T.s, [[x0, y1, zc], [x0, y0, zs], [x1, y1, zc], [x1, y0, zs]], LT.rs); F(T.n, [[x1, y1, zc], [x1, y0, zn], [x0, y1, zc], [x0, y0, zn]], LT.rn);
            const lx = WX(p.x - p.w / 2 + 1), rx = WX(p.x + p.w / 2 - 1), gzn = WZ(p.z + p.d / 2 - 1), gzs = WZ(p.z - p.d / 2 + 1);
            F(T.l, [[lx, y1, zc], [lx, y0, gzn], [lx, y1, zc], [lx, y0, gzs]], LT.w); F(T.r, [[rx, y1, zc], [rx, y0, gzs], [rx, y1, zc], [rx, y0, gzn]], LT.e); continue; }
          if (p.kind === 'lathe') { const S = 12, pr = p.prof, tx = T.side, TW = tx.width, TH = tx.height, R0 = p.w / 2;
            for (let k = 0; k < pr.length - 1; k++) { const [ta, ra] = pr[k], [tb, rb] = pr[k + 1], ya = WY(p.y + ta * p.h), yb = WY(p.y + tb * p.h);
              for (let j = 0; j < S; j++) { const a0 = j / S * 6.2832, a1 = (j + 1) / S * 6.2832, am = (a0 + a1) / 2, cs = Math.cos(am), sn = Math.sin(am);
                const l = (cs > 0 ? 0.76 : 0.96) * cs * cs + (sn < 0 ? 0.95 : 0.82) * sn * sn + (rb < ra ? 0.05 * (ra - rb) / Math.max(0.01, tb - ta) : 0);
                const Q = (r, a, y) => [WX(p.x + Math.cos(a) * r * R0), y, WZ(p.z + Math.sin(a) * r * R0)];
                F({ s: tx, r: [j / S * TW, (1 - tb) * TH, TW / S, (tb - ta) * TH] }, [Q(rb, a0, yb), Q(ra, a0, ya), Q(rb, a1, yb), Q(ra, a1, ya)], Math.min(1.05, l)); } } continue; }
          if (p.kind === 'pyr') { const A = [cx, y1, cz]; F(T.s, [A, [x0, y0, zs], A, [x1, y0, zs]], LT.rs); F(T.n, [A, [x1, y0, zn], A, [x0, y0, zn]], LT.rn);
            F(T.l, [A, [x0, y0, zn], A, [x0, y0, zs]], LT.w); F(T.r, [A, [x1, y0, zs], A, [x1, y0, zn]], LT.e); } } } };
      const cull = o.cullScatter !== false; emitGroups(cull ? groups.filter(g => !g.e.nf) : groups); scAll = cull ? groups.filter(g => g.e.nf) : [];
      scEmit = gs => { const sv = [V, I, nq, cap]; cap = scV ? scV.length / 40 : 1 << 16; V = scV || new Float32Array(cap * 40); I = scI || new Uint32Array(cap * 6); nq = 0; emitGroups(gs); const out = { V, I, nq }; scV = V; scI = I; [V, I, nq, cap] = sv; return out; };
      vhEmit = gs => { const sv = [V, I, nq, cap]; cap = vhV ? vhV.length / 40 : 1 << 14; V = vhV || new Float32Array(cap * 40); I = vhI || new Uint32Array(cap * 6); nq = 0; emitGroups(gs); curXf = null; const out = { V, I, nq }; vhV = V; vhI = I; [V, I, nq, cap] = sv; return out; };
      vbo2 = vbo2 || gl.createBuffer(); ibo2 = ibo2 || gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, vbo2); gl.bufferData(gl.ARRAY_BUFFER, V.subarray(0, nq * 40), gl.STATIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo2); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, I.subarray(0, nq * 6), gl.STATIC_DRAW); n2 = nq * 6; t.ovQuads = nq; }
    function drawOverlay(mm) { if (okey() !== ovKey) TM('overlay', buildOverlay); if (!n2) return; gl.useProgram(prog2); gl.uniformMatrix4fv(u2M, false, mm);
      gl.uniform4f(u2Nl, hov.a, hov.la, hov.b, hov.lb); gl.uniform4f(u2Bn, br.a, br.va, br.b, br.vb); gl.uniform1f(u2Da, dim.v);
      gl.activeTexture(gl.TEXTURE5); gl.bindTexture(gl.TEXTURE_2D, spTex || rivTex); gl.uniform1i(u2St, 5);
      gl.activeTexture(gl.TEXTURE6); gl.bindTexture(gl.TEXTURE_2D, sidTex || rivTex); gl.uniform1i(u2Sd, 6); gl.uniform1f(u2Hs, sidTex ? hotSid : 0); { const hcol = hotNat ? outlineOf(hotNat) : [0.949, 0.549, 0.157]; gl.uniform3f(u2Hc, hcol[0], hcol[1], hcol[2]); } gl.uniform2f(u2Si, 1 / (2 * t.RW), 1 / (2 * t.RH));
      if (!GCOL) GCOL = mkGcol(); gl.activeTexture(gl.TEXTURE7); gl.bindTexture(gl.TEXTURE_2D, glTex || spTex || rivTex); gl.uniform1i(u2Gt, 7); gl.uniform1f(u2Ng, o.night ? 1 : 0); gl.uniform1f(u2Tm, (performance.now() / 1000) % 1000); gl.uniform3fv(u2Gc, GCOL);
      gl.bindBuffer(gl.ARRAY_BUFFER, vbo2);
      [[3, 0], [3, 12], [4, 24]].forEach(([k, of], q) => { if (a2[q] < 0) return; gl.enableVertexAttribArray(a2[q]); gl.vertexAttribPointer(a2[q], k, gl.FLOAT, false, 40, of); });
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo2); gl.drawElements(gl.TRIANGLES, n2, gl.UNSIGNED_INT, 0); drawGround(); drawVehicles(); for (const q of a2) if (q >= 0) gl.disableVertexAttribArray(q); }
    // Ground scatter + sea ice (2026-10-07e): built only for the camera's ground footprint + pad (75 px at zoomMin → 25 px at zoomMax), rebuilt when the
    // view leaves the built rect (Godot: MultiMesh per visible chunk). Ground: per ½-res cell (skips water, settlements, trails / streets / ponds, occupied cells,
    // rail): land class → kind; colour from the land pixel under it. grass = 2 blades (+ flower head on light grass / prairie, more in plains / prairie / meadow
    // regions) · gravel = 1–3 lumps · sand = flat speck · wheat = 3 stalks + heads · snow = lump. Sea ice: icy sea classes (not lakes), 10 px lattice,
    // p = ice.p0 + ice.p1 · (1 − z / (H · ice.north))^1.5, 7 shapes (floe · plateau · pressure ridge · tabular berg · floe cluster · spire berg · blockade),
    // footprint must be open water. Off: opts.groundScatter = false.
    const GS = { pad: [75, 25], southPad: 60, kind: { 0: 'grass', 1: 'grass', 2: 'grass', 3: 'grass', 4: 'grass', 5: 'sand', 6: 'gravel', 7: 'gravel', 8: 'snow', 9: 'grass', 10: 'sand', 11: 'grass', 12: 'grass', 13: 'wheat', 14: 'gravel' },
      d: { grass: 0.8, sand: 0.5, gravel: 0.6, snow: 0.65, wheat: 0.95 }, dForest: 0.35, flowerP: 0.12, meadowFlowerP: 0.4, meadowCat: ['plains', 'prairie', 'meadow', 'meadows'],
      FL: [[0.96, 0.95, 0.9], [0.98, 0.86, 0.3], [0.95, 0.55, 0.65], [0.7, 0.5, 0.9], [0.9, 0.35, 0.3]],
      ice: { re: /^icy (deep sea|sea|shallows)$/i, north: 0.55, p0: 0.03, p1: 0.6, denseZ: 0, denseP: 0.9, // denseZ: px south of the play-area top (and all of the north padding) → pack ice on ANY sea class, p = denseP
         fp: [[9, 6], [16, 11], [18, 4], [11, 7], [10, 8], [6, 5], [17, 9]] } };
    // Ground-cover clump variants: GV[kind][0..11] = primitives { t: 'b' blade | 'f' flat | 'l' lump, dx, dz (px from the cell centre), w, d, h, y, cf (× pixel colour), fl (flower colour) }.
    const GV = (() => { const hq = (a, b) => { let h = Math.imul(a, 73856093) ^ Math.imul(b, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; }, V = {};
      [['grass', 1], ['flowers', 2], ['gravel', 3], ['sand', 4], ['wheat', 5], ['snow', 6]].forEach(([kd, kn]) => { V[kd] = []; for (let v = 0; v < 12; v++) { const r = k => hq(kn * 100 + v, k), P = [];
        if (kd === 'grass' || kd === 'flowers') { const n = 4 + Math.floor(r(1) * 4), H = 2.2 + r(2) * 2.2, sp = 1.1 + r(3) * 0.6;
          for (let i = 0; i < n; i++) { const a = n > 1 ? (i / (n - 1) - 0.5) * 2 : 0; P.push({ t: 'b', dx: a * sp + (r(10 + i) - 0.5) * 0.4, dz: (r(20 + i) - 0.5) * 1.4, w: 0.5 + r(30 + i) * 0.4, h: H * (0.55 + 0.45 * (1 - Math.abs(a))) * (0.8 + r(40 + i) * 0.4), cf: 0.84 + r(50 + i) * 0.36 }); }
          if (kd === 'flowers') { const m = 2 + Math.floor(r(4) * 3); for (let i = 0; i < m; i++) { const fh = H * (0.9 + r(60 + i) * 0.5), dx = (r(70 + i) - 0.5) * 2, dz = (r(80 + i) - 0.5) * 1.2; P.push({ t: 'b', dx, dz, w: 0.28, h: fh, cf: 0.8 }, { t: 'f', dx, dz, y: fh, w: 0.95, d: 0.85, fl: Math.floor(r(90 + i) * 5) }); } } }
        else if (kd === 'gravel') { const n = 4 + Math.floor(r(1) * 4); for (let i = 0; i < n; i++) P.push({ t: 'l', dx: (r(10 + i) - 0.5) * 2.4, dz: (r(20 + i) - 0.5) * 2, w: 0.5 + r(30 + i) * 0.9, d: 0.45 + r(40 + i) * 0.7, h: 0.3 + r(50 + i) * 0.5, cf: 0.75 + r(60 + i) * 0.5 }); }
        else if (kd === 'sand') { const n = 2 + Math.floor(r(1) * 3); for (let i = 0; i < n; i++) P.push({ t: 'f', dx: (r(10 + i) - 0.5) * 1.6, dz: (i - n / 2) * 0.75, w: 1.6 + r(20 + i) * 1.2, d: 0.45, cf: r(30 + i) < 0.5 ? 1.1 : 0.9 }); }
        else if (kd === 'wheat') { const n = 6 + Math.floor(r(1) * 4); for (let i = 0; i < n; i++) { const h = 3.2 + r(10 + i) * 1.8, dx = (r(20 + i) - 0.5) * 2.4, dz = (r(30 + i) - 0.5) * 1.6; P.push({ t: 'b', dx, dz, w: 0.36, h, cf: 1 + r(40 + i) * 0.15 }, { t: 'b', dx, dz: dz + 0.01, y: h - 0.3, w: 0.7, h: 1.1, cf: 0.85 }); } }
        else { const n = 3 + Math.floor(r(1) * 3); for (let i = 0; i < n; i++) P.push({ t: 'l', dx: (r(10 + i) - 0.5) * 2.2, dz: (r(20 + i) - 0.5) * 1.8, w: 1.2 + r(30 + i), d: 1 + r(40 + i) * 0.8, h: 0.3 + r(50 + i) * 0.4, cf: 1 + r(60 + i) * 0.05 }); }
        V[kd].push(P); } }); return V; })();
    let gsV = null, gsI = null, gsVbo = null, gsIbo = null, gsN = 0, gsRect = null, gsKey = -1, ovGen = 0;
    // Vehicles (2026-10-07): MercVehicles.sim moves trains / coaches / airships every frame (real elapsed time, 0.1 s substeps); only groups inside the view rect
    // (+40 px, +80 south; airships +160 south) are emitted into a small dynamic buffer and drawn with the element shader. o.vehicles = false hides them.
    // Camps (night): MercVehicles reports [x, z, r] per lit campfire; ground cover + scatter inside r + 2 px are left out (rebuild ≤ 1 / s when the in-view set changes).
    const campsIn = Rc => (vhSim && o.night ? vhSim.camps : []).filter(q => q[0] > Rc[0] - 10 && q[0] < Rc[2] + 10 && q[1] > Rc[1] - 10 && q[1] < Rc[3] + 10); let campKey = '', campT = 0;
    let vhEmit = null, vhKit = null, vhSim = null, vhV = null, vhI = null, vhVbo = null, vhIbo = null, vhT = 0;
    function vhData() { const hs = o.heightScale, T = TERRACE, { RW, RH, w2 } = t, HH = t.h2, riv = t.riv;
      const J = (x, z) => { const cx = Math.round(x) >> 1, cz = Math.round(z) >> 1; return cx < 0 || cz < 0 || cx >= RW || cz >= RH ? -1 : cz * RW + cx; };
      const deck = new Float32Array(RW * RH).fill(NaN); for (const br of (t.brP || [])) { const { P, D } = br, n = P.length, HMP = Math.min(UBR.hump * (n - 1), UBR.humpMax);
        for (let i = 0; i < n; i++) { const y = D[i] * hs + 0.6 + HMP * Math.sin(Math.PI * i / Math.max(1, n - 1)); for (let dz = -4; dz <= 4; dz += 2) for (let dx = -4; dx <= 4; dx += 2) { const j = J(P[i][0] + dx, P[i][1] + dz); if (j >= 0 && !(deck[j] >= y)) deck[j] = y; } } }
      const ground = (x, z) => { const j = J(x, z); if (j < 0) return WATER_H * hs; if (deck[j] === deck[j]) return deck[j]; return w2[j] >= 2 || (riv && riv[j] > 0.5) ? WATER_H * hs : (Math.max(WATER_H + T, Math.round(HH[j] / T) * T) - TR_CARVE * T) * hs; };
      const top = (x, z) => { const j = J(x, z); if (j < 0) return WATER_H * hs; return w2[j] >= 2 || (riv && riv[j] > 0.5) ? WATER_H * hs : Math.max(WATER_H + T, Math.round(HH[j] / T) * T) * hs; };
      const CYF = new Set(Object.values(t.natById || {}).filter(n => /Cyfrolaef/.test(n.name)).map(n => n.id)), CRL = (t.labels || []).find(l => l.name === 'Yrspholahs');
      const avoid = (x, z) => { if (CRL && Math.hypot(x - CRL.ix, z - CRL.iz) < 300) return true; const xi = Math.round(x), zi = Math.round(z); return xi >= 0 && zi >= 0 && xi < t.W && zi < t.H && !!(t.nat && CYF.has(t.nat[zi * t.W + xi])); };
      const rail = ((t.rail && t.rail.lines) || []).filter(l => l.p2 && l.p2.length > 1).map(l => ({ id: l.id, from: l.from, to: l.to, pts: l.p2.map((p, i) => [p[0], p[1], l.z2[i] * hs + RAIL.bh + RAIL.tieH + RAIL.railH]) }));
      const trails = (t.tradeLines || []).map(L => L.map(p => [p[0], p[1], ground(p[0], p[1])]));
      const cities = (t.labels || []).filter(l => (l.type === 'capital' || l.type === 'city') && !avoid(l.ix, l.iz)).map(l => [l.ix, l.iz, l.name]);
      const bridges = (t.brP || []).map(br => { const { P, D } = br, n = P.length, HMP = Math.min(UBR.hump * (n - 1), UBR.humpMax); return P.map((p, i) => [p[0], p[1], D[i] * hs + 0.6 + HMP * Math.sin(Math.PI * i / Math.max(1, n - 1))]); });
      const sid = t.sid, inTown = (x, z) => { if (!sid) return false; for (let dz = -6; dz <= 6; dz += 2) for (let dx = -6; dx <= 6; dx += 2) { const j = J(x + dx, z + dz); if (j >= 0 && sid[j]) return true; } return false; };
      const townAt = (x, z) => { if (!sid) return null; let best = null, bd = 1e9; for (let dz = -8; dz <= 8; dz += 2) for (let dx = -8; dx <= 8; dx += 2) { const j = J(x + dx, z + dz); if (j >= 0 && sid[j] && dx * dx + dz * dz < bd) { bd = dx * dx + dz * dz; best = t.setList[sid[j]]; } } return best; };
      const stations = (t.elsP || []).filter(e => (e.stationName || e.kit === 'station') && e.plot).map(e => [e.x, e.y - e.plot.pb / 2, e.stationName || ((townAt(e.x, e.y - e.plot.pb / 2) || 'Town') + ' Station')]); // unnamed town stations: '<Town> Station' // train stops: station building footprint centres
      return { rail, trails, bridges, inTown, townAt, cities, ground, top, stations, counts: o.vehicleCounts || { trains: 1, coaches: 1, ships: 1 }, /* vehicleCounts: 1 each (2026-10-08: each tied to a contract) */ terrace: T * hs, hAt: (x, z) => sample(t, x, z, t.hb) * hs, avoid, seed: 7 }; }
    function drawVehicles() { const VM = window.MercVehicles; if (!VM || !vhEmit || !vhKit || o.vehicles === false) { t.vhVis = 0; return; }
      if (!vhSim) { const q0 = performance.now(); vhSim = t.vhSim = VM.sim(vhData()); t.vhInitMs = Math.round(performance.now() - q0); vhT = 0; }
      const now = performance.now(), dt = vhT ? Math.min(10, (now - vhT) / 1000) : 0; vhT = now; if (vhSim.setNight) vhSim.setNight(!!o.night); vhSim.step(dt); t.vhStepMs = performance.now() - now;
      const v = viewRect(), gs = vhSim.groups([v[0] - 40, v[1] - 40, v[2] + 40, v[3] + 80], vhKit, o.heightScale, { fires: t.fireSrc ? [...t.fireSrc] : [], smoke: rig.zoom >= 1.01 && !!o.night, view: v }); /* fire smoke only at night (fires are out by day) */ t.vhVis = gs.length; { const k = gsRect ? campsIn(gsRect).map(q => Math.round(q[0]) + ',' + Math.round(q[1])).join('|') : ''; if (k !== campKey && now - campT > 1000) { campKey = k; campT = now; gsRect = null; req(); } } if (!gs.length) return; // smoke only past 100 % zoom, sources inside the view rect
      const r = vhEmit(gs); t.vhQuads = r.nq; vhVbo = vhVbo || gl.createBuffer(); vhIbo = vhIbo || gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, vhVbo); gl.bufferData(gl.ARRAY_BUFFER, r.V.subarray(0, r.nq * 40), gl.DYNAMIC_DRAW); [[3, 0], [3, 12], [4, 24]].forEach(([k, of], q) => { if (a2[q] < 0) return; gl.enableVertexAttribArray(a2[q]); gl.vertexAttribPointer(a2[q], k, gl.FLOAT, false, 40, of); });
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, vhIbo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, r.I.subarray(0, r.nq * 6), gl.DYNAMIC_DRAW); gl.drawElements(gl.TRIANGLES, r.nq * 6, gl.UNSIGNED_INT, 0); t.vhMs = performance.now() - now; }
    let scEmit = null, scAll = [], scV = null, scI = null, scVbo = null, scIbo = null, scN = 0; // culled scatter elements (see buildOverlay)
    // Scatter elements in the rect (+ GS.southPad: tall pieces just south of the view lean up into it) → scatter buffer.
    function buildScatter(Rc) { if (!scEmit) { scN = 0; return; } const z1 = Rc[3] + GS.southPad, CP = campsIn(Rc), gs = scAll.filter(g => g.e.x >= Rc[0] && g.e.x <= Rc[2] && g.e.y >= Rc[1] && g.e.y <= z1 && !(CP.length && CP.some(q => Math.hypot(g.e.x - q[0], g.e.y - 1 - q[1]) < q[2] + (/^f_/.test(g.e.kit || '') && !/^f_(fern|shrub|scrub|drybrush|flowers|tallgrass|reeds)/.test(g.e.kit) ? 12 : 2)))), r = scEmit(gs);
      scVbo = scVbo || gl.createBuffer(); scIbo = scIbo || gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, scVbo); gl.bufferData(gl.ARRAY_BUFFER, r.V.subarray(0, r.nq * 40), gl.DYNAMIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, scIbo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, r.I.subarray(0, r.nq * 6), gl.DYNAMIC_DRAW); scN = r.nq * 6; t.scatterShown = gs.length; t.scatterTotal = scAll.length; t.scatterQuads = r.nq; }
    function viewRect() { const c = camNow(), w = canvas.clientWidth || 1, h = canvas.clientHeight || 1, ty = Math.tan(o.fov * Math.PI / 360), tx = ty * w / h, y = refY() - 20; let x0 = 1e9, z0 = 1e9, x1 = -1e9, z1 = -1e9;
      for (const [nx, ny] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) { const d = norm([c.fw[0] + c.rt[0] * nx * tx + c.up[0] * ny * ty, c.fw[1] + c.rt[1] * nx * tx + c.up[1] * ny * ty, c.fw[2] + c.rt[2] * nx * tx + c.up[2] * ny * ty]);
        const s = d[1] < -1e-4 ? Math.min(4000, (y - c.eye[1]) / d[1]) : 4000, px = c.eye[0] + d[0] * s, pz = c.eye[2] + d[2] * s; x0 = Math.min(x0, px); x1 = Math.max(x1, px); z0 = Math.min(z0, pz); z1 = Math.max(z1, pz); } return [x0, z0, x1, z1]; }
    function buildGround(Rc) { const { RW, RH, h2, w2, riv } = t, hs = o.heightScale, T = TERRACE, L = t.land, NBI = t.nb, oc = t.gocc, sid = t.sid, pt = t.paint, rl = t.gRail;
      const hh = (x, z) => { let h = Math.imul(x | 0, 73856093) ^ Math.imul(z | 0, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
      const meadow = new Uint8Array(256); for (const r of Object.values(t.regById || {})) if (GS.meadowCat.includes(r.category)) meadow[r.id & 255] = 1;
      const cx0 = Math.max(2, Math.floor(Rc[0] / 2)), cz0 = Math.max(2, Math.floor(Rc[1] / 2)), cx1 = Math.min(RW - 3, Math.ceil(Rc[2] / 2)), cz1 = Math.min(RH - 3, Math.ceil(Rc[3] / 2));
      let cap = gsV ? gsV.length / 40 : 1 << 16, V = gsV || new Float32Array(cap * 40), I = gsI || new Uint32Array(cap * 6), nq = 0, n0 = 0, n1 = 0;
      const Q = (pts, c) => { if (nq >= cap) { cap *= 2; const V2 = new Float32Array(cap * 40); V2.set(V); V = V2; const I2 = new Uint32Array(cap * 6); I2.set(I); I = I2; }
        let k = nq * 40; for (let q = 0; q < 4; q++) { const p = pts[q]; V[k++] = p[0]; V[k++] = p[1]; V[k++] = p[2]; V[k++] = c[0]; V[k++] = c[1]; V[k++] = c[2]; V[k++] = n0; V[k++] = n1; V[k++] = -1; V[k++] = -1; }
        const b = nq * 4, j = nq * 6; I[j] = b; I[j + 1] = b + 1; I[j + 2] = b + 2; I[j + 3] = b + 2; I[j + 4] = b + 1; I[j + 5] = b + 3; nq++; };
      const cl1 = v => Math.min(1, v), mul = (c, f) => [cl1(c[0] * f), cl1(c[1] * f), cl1(c[2] * f)], bk = [];
      const blade = (x, y, z, w, h, c) => Q([[x - w / 2, y + h, z], [x - w / 2, y, z], [x + w / 2, y + h, z], [x + w / 2, y, z]], c);
      const flat = (x, y, z, w, d, c) => Q([[x - w / 2, y, z - d / 2], [x - w / 2, y, z + d / 2], [x + w / 2, y, z - d / 2], [x + w / 2, y, z + d / 2]], c);
      const lump = (x, y, z, w, d, h, c) => { flat(x, y + h, z, w, d, c); blade(x, y, z + d / 2, w, h, [c[0] * 0.72, c[1] * 0.72, c[2] * 0.72]); };
      const box3 = (cx, cz, w, d, y0, h, c) => { const x0 = cx - w / 2, x1 = cx + w / 2, z0 = cz - d / 2, z1 = cz + d / 2, y1 = y0 + h; Q([[x0, y1, z0], [x0, y1, z1], [x1, y1, z0], [x1, y1, z1]], c);
        Q([[x0, y1, z1], [x0, y0, z1], [x1, y1, z1], [x1, y0, z1]], mul(c, 0.8)); Q([[x1, y1, z1], [x1, y0, z1], [x1, y1, z0], [x1, y0, z0]], mul(c, 0.7)); Q([[x0, y1, z0], [x0, y0, z0], [x0, y1, z1], [x0, y0, z1]], mul(c, 0.86)); };
      const CPg = campsIn(Rc); for (let cz = cz0; cz <= cz1; cz++) for (let cx = cx0; cx <= cx1; cx++) { const j = cz * RW + cx; if (w2[j] >= 2 || (riv && riv[j] > 0.5) || (oc && oc[j]) || (sid && sid[j]) || (pt && pt[j])) continue; if (CPg.length && CPg.some(q => Math.hypot(cx * 2 + 1 - q[0], cz * 2 + 1 - q[1]) < q[2] + 1.5)) continue; // camp clearing
        if (rl && (rl[j] || rl[j - 1] || rl[j + 1] || rl[j - RW] || rl[j + RW])) continue; if (t.brMask && t.brMask[j]) continue;
        const r0 = hh(cx * 3 + 11, cz * 7 + 5), px = cx * 2 + Math.floor(hh(cx, cz + 1) * 2), pz = cz * 2 + Math.floor(hh(cx + 1, cz) * 2), code = L.code[pz * t.W + px]; if (code === 255) continue;
        const cls = code >> 2, kd = GS.kind[cls]; if (!kd) continue; const d = cls === 2 || cls === 3 || cls === 4 ? GS.dForest : GS.d[kd]; if (r0 > d) continue;
        const base = [L.rgb[code * 3] / 255, L.rgb[code * 3 + 1] / 255, L.rgb[code * 3 + 2] / 255], y = Math.max(WATER_H + T, Math.round(h2[j] / T) * T) * hs + 0.02;
        if (NBI) { const i = Math.min(NBI.ch - 1, Math.max(0, (pz / NBI.cs) | 0)) * NBI.cw + Math.min(NBI.cw - 1, Math.max(0, (px / NBI.cs) | 0)); n0 = NBI.NB[i]; n1 = NBI.NB0[i]; }
        const x = cx * 2 + 0.3 + hh(cx + 5, cz + 3) * 1.4, z = cz * 2 + 0.3 + hh(cx + 2, cz + 9) * 1.4, r1 = hh(cx + 17, cz + 23), r2 = hh(cx + 29, cz + 31);
        // Clumps (2026-10-07h): 12 prebuilt variants per kind (GV), mirrored at random → 24 looks; each clump spans ~2.6 px so neighbouring cells overlap (no bare ground).
        const fp = kd === 'grass' ? (t.reg && meadow[t.reg[pz * t.W + px] & 255] ? GS.meadowFlowerP : (cls === 0 && (code & 3) === 0) || cls === 12 ? GS.flowerP * 2 : cls === 0 ? GS.flowerP : 0) : 0;
        const vk = kd === 'grass' && r2 < fp ? 'flowers' : kd, VV = GV[vk][Math.floor(r1 * 12)], mx = hh(cx + 61, cz + 67) < 0.5 ? -1 : 1, ox = cx * 2 + 1 + (hh(cx + 5, cz + 3) - 0.5) * 0.6, oz = cz * 2 + 1 + (hh(cx + 2, cz + 9) - 0.5) * 0.6, gr = (base[0] + base[1] + base[2]) / 3;
        const mid = (GKI[vk] * 12 + Math.floor(r1 * 12)) * 2 + (mx < 0 ? 1 : 0); (bk[mid] || (bk[mid] = [])).push(ox, y, oz, base[0], base[1], base[2], n0, n1); }
      { let tot = 0; for (const B of bk) if (B) tot += B.length; const D = new Float32Array(tot); let o2 = 0; giDraw = []; bk.forEach((B, m) => { if (!B || !B.length) return; D.set(B, o2); giDraw.push([m, o2 / 8, B.length / 8]); o2 += B.length; });
        giInit(); gl.bindBuffer(gl.ARRAY_BUFFER, GI.ib); gl.bufferData(gl.ARRAY_BUFFER, D, gl.DYNAMIC_DRAW); t.groundInst = tot / 8; }
      let nIce = 0; if (t.water && GS.ice) { const G = GS.ice, IC = new Set((t.water.classes || []).filter(c => G.re.test(c.name)).map(c => c.id)), W0 = [0.97, 0.99, 1], W1 = [0.88, 0.94, 0.98], W2 = [0.76, 0.86, 0.93], wy = WATER_H * hs - 0.4; n0 = 0; n1 = 0;
        const open = (x, z) => { if (x < 0 || z < 0 || x >= t.W || z >= t.H) return false; const j = Math.min(RH - 1, z >> 1) * RW + Math.min(RW - 1, x >> 1); return w2[j] >= 2 && !(riv && riv[j] > 0.5) && !(oc && oc[j]); };
        if (IC.size) for (let z = Math.floor(Rc[1] / 10) * 10; z <= Rc[3]; z += 10) for (let x = Math.floor(Rc[0] / 10) * 10; x <= Rc[2]; x += 10) { const jx = x + Math.floor(hh(x, z + 77) * 6), jz = z + Math.floor(hh(x + 77, z) * 6); if (jx < 0 || jz < 0 || jx >= t.W || jz >= t.H) continue;
          const c = t.water.code[jz * t.W + jx], dense = jz < PAD.top + G.denseZ; if (!dense && (c === 255 || !IC.has(c >> 2))) continue; const f = Math.max(0, 1 - jz / (t.H * G.north)); if (hh(jx * 3, jz * 5 + 1) > (dense ? G.denseP : G.p0 + G.p1 * f ** 1.5)) continue;
          const ty = Math.floor(hh(jx + 9, jz + 3) * 7), [fw, fd] = G.fp[ty]; let ok = true; for (const a of [-0.5, 0, 0.5]) for (const b of [-0.5, 0, 0.5]) if (!open(Math.round(jx + a * fw), Math.round(jz + b * fd))) ok = false; if (!ok) continue;
          const r = k => hh(jx + k * 31, jz + k * 17); nIce++;
          if (ty === 0) box3(jx, jz, 5 + r(1) * 4, 3 + r(2) * 3, wy, 0.9, W1);
          else if (ty === 1) { const w = 10 + r(1) * 6, d = 7 + r(2) * 4; box3(jx, jz, w, d, wy, 2, W1); box3(jx + (r(3) - 0.5) * w * 0.3, jz - d * 0.1, w * 0.5, d * 0.5, wy + 2, 1.2, W0); }
          else if (ty === 2) { const n = 5 + Math.floor(r(1) * 3); for (let k = 0; k < n; k++) box3(jx + (k - n / 2) * 2.2, jz + (r(k + 2) - 0.5) * 1.5, 2.4, 2 + r(k + 5) * 1.2, wy, 1.4 + r(k + 9) * 2, k & 1 ? W1 : W2); }
          else if (ty === 3) { const h = 4.5 + r(3) * 2; box3(jx, jz, 8 + r(1) * 3, 5 + r(2) * 2, wy, h, W1); box3(jx - 0.5, jz - 0.3, 6, 3.5, wy + h, 0.4, W0); }
          else if (ty === 4) { const n = 4 + Math.floor(r(1) * 3); for (let k = 0; k < n; k++) box3(jx + (r(k + 2) - 0.5) * 9, jz + (r(k + 7) - 0.5) * 7, 1.6 + r(k + 4) * 2.4, 1.2 + r(k + 5) * 2, wy, 0.5 + r(k + 6) * 0.6, W1); }
          else if (ty === 5) { let y = wy, w = 4 + r(1) * 1.5; for (let k = 0; k < 4; k++) { const h = 1.4 + r(k + 2) * 1.2; box3(jx + (r(k + 5) - 0.5) * 0.8, jz, w, w * 0.8, y, h, k === 3 ? W0 : W1); y += h; w *= 0.68; } }
          else { const sd = r(3) < 0.5 ? -1 : 1, L2 = 12 + r(1) * 4; box3(jx, jz, L2, 1.8, wy, 2.4 + r(2), W1); box3(jx + sd * L2 * 0.42, jz - 3, 1.8, 6, wy, 2.2 + r(4), W2); for (let k = 0; k < 3; k++) box3(jx + (r(k + 6) - 0.5) * L2, jz + 1.6, 1, 0.9, wy, 0.6 + r(k + 8) * 0.5, W0); } } }
      gsV = V; gsI = I; gsVbo = gsVbo || gl.createBuffer(); gsIbo = gsIbo || gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, gsVbo); gl.bufferData(gl.ARRAY_BUFFER, V.subarray(0, nq * 40), gl.DYNAMIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gsIbo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, I.subarray(0, nq * 6), gl.DYNAMIC_DRAW); gsN = nq * 6; t.groundQuads = nq; t.groundIce = nIce; t.groundRect = Rc.map(Math.round); }
    // Ground-cover instancing (perf 2026-10-07): each clump look (6 kinds × 12 variants × mirror = 144 meshes, local coords, per-vertex colour factor + mode) is uploaded
    // ONCE; buildGround only writes per-clump instances (pos, ground colour, nation pair) and drawGround issues one drawElementsInstanced per mesh.
    // Distance fade: clumps shrink to nothing between fd.z and fd.w px from the view centre (radius widens as you zoom in). Godot: MultiMeshInstance3D per mesh.
    const GKI = { grass: 0, flowers: 1, gravel: 2, sand: 3, wheat: 4, snow: 5 }; let GI = null, giDraw = null;
    function giInit() { if (GI) return; const VS3 = `#version 300 es
in vec3 lp; in vec4 cm; in vec3 ip; in vec3 ic; in vec2 inn; uniform mat4 m; uniform vec4 nl; uniform vec4 fd; out vec3 vc; out vec2 tu; out float n0; out vec2 wq; flat out float gn;
void main(){ gn=0.0; tu=vec2(-1.0); n0=inn.y; float s=1.0-smoothstep(fd.z,fd.w,distance(ip.xz,fd.xy)); if(s<0.04){ gl_Position=vec4(2.0,2.0,2.0,1.0); vc=vec3(0.0); wq=vec2(0.0); return; }
  vec3 q=ip+vec3(lp.x*mix(0.6,1.0,s),lp.y*s,lp.z); wq=q.xz; float n=inn.x; if(n>0.5){ float n2=floor(n/32.0+0.001), n1=n-n2*32.0; if(abs(n1-nl.x)<0.5||(n2>0.5&&abs(n2-nl.x)<0.5)) q.y+=nl.y; else if(abs(n1-nl.z)<0.5||(n2>0.5&&abs(n2-nl.z)<0.5)) q.y+=nl.w; }
  float gr=(ic.r+ic.g+ic.b)/3.0; vec3 b=cm.w>1.5 ? ic*0.6+vec3(gr*0.4) : ic; vc=(cm.w>0.5&&cm.w<1.5) ? cm.xyz : min(b*cm.xyz,vec3(1.0)); gl_Position=m*vec4(q,1.0); }`;
      const p = gl.createProgram(); gl.attachShader(p, sh(gl.VERTEX_SHADER, VS3)); gl.attachShader(p, sh(gl.FRAGMENT_SHADER, FS2)); gl.linkProgram(p);
      const verts = [], idx = [], meshes = [];
      for (const kd of Object.keys(GKI)) for (let v = 0; v < 12; v++) for (const mx of [1, -1]) { const i0 = idx.length, Qm = (pts, cf, md) => { const b = verts.length / 7; for (const q of pts) verts.push(q[0], q[1], q[2], cf[0], cf[1], cf[2], md); idx.push(b, b + 1, b + 2, b + 2, b + 1, b + 3); };
        for (const q of GV[kd][v]) { const md = q.fl != null ? 1 : kd === 'gravel' ? 2 : 0, cf = q.fl != null ? GS.FL[q.fl] : [q.cf, q.cf, q.cf], x = q.dx * mx, z = q.dz, w = q.w / 2;
          if (q.t === 'b') { const y = q.y || 0; Qm([[x - w, y + q.h, z], [x - w, y, z], [x + w, y + q.h, z], [x + w, y, z]], cf, md); }
          else if (q.t === 'f') { const y = q.y || 0.05, d = q.d / 2; Qm([[x - w, y, z - d], [x - w, y, z + d], [x + w, y, z - d], [x + w, y, z + d]], cf, md); }
          else { const d = q.d / 2, h = q.h; Qm([[x - w, h, z - d], [x - w, h, z + d], [x + w, h, z - d], [x + w, h, z + d]], cf, md); Qm([[x - w, h, z + d], [x - w, 0, z + d], [x + w, h, z + d], [x + w, 0, z + d]], cf.map(f => f * 0.72), md); } }
        meshes.push({ i0, n: idx.length - i0 }); }
      const va = gl.createVertexArray(); gl.bindVertexArray(va); const vb = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, vb); gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(verts), gl.STATIC_DRAW);
      const A = k => gl.getAttribLocation(p, k), aLp = A('lp'), aCm = A('cm'), aIp = A('ip'), aIc = A('ic'), aIn = A('inn');
      gl.enableVertexAttribArray(aLp); gl.vertexAttribPointer(aLp, 3, gl.FLOAT, false, 28, 0); gl.enableVertexAttribArray(aCm); gl.vertexAttribPointer(aCm, 4, gl.FLOAT, false, 28, 12);
      const eb = gl.createBuffer(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, eb); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, new Uint32Array(idx), gl.STATIC_DRAW);
      const ib = gl.createBuffer(); gl.bindBuffer(gl.ARRAY_BUFFER, ib); for (const a of [aIp, aIc, aIn]) { if (a < 0) continue; gl.enableVertexAttribArray(a); gl.vertexAttribDivisor(a, 1); }
      gl.bindVertexArray(null); const U = k => gl.getUniformLocation(p, k);
      GI = { p, va, ib, meshes, aIp, aIc, aIn, u: { m: U('m'), nl: U('nl'), fd: U('fd'), bn: U('bn'), da: U('da'), st: U('st'), sd: U('sd'), hs: U('hs'), si: U('si'), ng: U('ng'), tm: U('tm'), gt: U('gt'), gc: U('gc') } }; t.groundMeshes = meshes.length; }
    function drawGround() { if (!t.land || !t.gocc) return; const v = viewRect(), z01 = (rig.zoom - o.zoomMin) / Math.max(0.01, o.zoomMax - o.zoomMin), pad = GS.pad[0] + (GS.pad[1] - GS.pad[0]) * Math.max(0, Math.min(1, z01));
      if (!gsRect || gsKey !== ovGen || v[0] < gsRect[0] || v[1] < gsRect[1] || v[2] > gsRect[2] || v[3] > gsRect[3]) { gsKey = ovGen; gsRect = [v[0] - pad, v[1] - pad, v[2] + pad, v[3] + pad]; const q0 = performance.now(); if (o.groundScatter !== false) buildGround(gsRect); else gsN = 0; const q1 = performance.now(); buildScatter(gsRect); t.groundMs = Math.round(q1 - q0); t.scatterMs = Math.round(performance.now() - q1); }
      const att = () => [[3, 0], [3, 12], [4, 24]].forEach(([k, of], q) => { if (a2[q] < 0) return; gl.enableVertexAttribArray(a2[q]); gl.vertexAttribPointer(a2[q], k, gl.FLOAT, false, 40, of); });
      if (scN) { gl.bindBuffer(gl.ARRAY_BUFFER, scVbo); att(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, scIbo); gl.drawElements(gl.TRIANGLES, scN, gl.UNSIGNED_INT, 0); }
      if (gsN) { gl.bindBuffer(gl.ARRAY_BUFFER, gsVbo); att(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, gsIbo); gl.drawElements(gl.TRIANGLES, gsN, gl.UNSIGNED_INT, 0); } // sea ice (plain quads)
      if (!GI || !giDraw || !giDraw.length) return; const G = (u) => gl.getUniform(prog2, u), u = GI.u; gl.useProgram(GI.p);
      gl.uniformMatrix4fv(u.m, false, G(u2M)); gl.uniform4fv(u.nl, G(u2Nl)); gl.uniform4fv(u.bn, G(u2Bn)); gl.uniform1f(u.da, G(u2Da)); gl.uniform1i(u.st, G(u2St)); gl.uniform1i(u.sd, G(u2Sd)); gl.uniform1f(u.hs, G(u2Hs)); gl.uniform2fv(u.si, G(u2Si)); gl.uniform1f(u.ng, G(u2Ng)); gl.uniform1f(u.tm, G(u2Tm)); gl.uniform1i(u.gt, 7); gl.uniform3fv(u.gc, GCOL || mkGcol());
      const cxv = (v[0] + v[2]) / 2, czv = (v[1] + v[3]) / 2, RR = 0.5 * Math.hypot(v[2] - v[0], v[3] - v[1]), zf = Math.max(0, Math.min(1, z01)); gl.uniform4f(u.fd, cxv, czv, RR * (0.42 + 0.4 * zf), RR * (0.8 + 0.45 * zf));
      gl.bindVertexArray(GI.va); gl.bindBuffer(gl.ARRAY_BUFFER, GI.ib);
      for (const [m, first, cnt] of giDraw) { const ofs = first * 32, M = GI.meshes[m]; if (GI.aIp >= 0) gl.vertexAttribPointer(GI.aIp, 3, gl.FLOAT, false, 32, ofs); if (GI.aIc >= 0) gl.vertexAttribPointer(GI.aIc, 3, gl.FLOAT, false, 32, ofs + 12); if (GI.aIn >= 0) gl.vertexAttribPointer(GI.aIn, 2, gl.FLOAT, false, 32, ofs + 24);
        gl.drawElementsInstanced(gl.TRIANGLES, M.n, gl.UNSIGNED_INT, M.i0 * 4, cnt); }
      gl.bindVertexArray(null); gl.useProgram(prog2); }
    function build() {
      builtScale = o.heightScale; builtKey = o.style + o.voxel; useColor = false; vhSim = null;
      if (!t.h2o) t.h2o = t.h2; t.h2 = t.h2o.slice(); TM('rail', prepRail); TM('bridges', prepBridges); TM('els', prepEls); ovKey = '';
      if (t.sid) { sidTex = sidTex || gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, sidTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1); gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, t.RW, t.RH, 0, gl.RED, gl.UNSIGNED_BYTE, t.sid);
        for (const [k, v] of [[gl.TEXTURE_MIN_FILTER, gl.NEAREST], [gl.TEXTURE_MAG_FILTER, gl.NEAREST], [gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE], [gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE]]) gl.texParameteri(gl.TEXTURE_2D, k, v); }
      if (o.style === 'voxel') { TM('voxel', buildVoxel); ensureRivTex(); return; }
      if (o.style === 'terrace') { buildTerrace(); ensureRivTex(); return; }
      buildSmooth(); }
    function ensureRivTex() {
      if (rivTex) return; const px = new Uint8Array(t.RW * t.RH); for (let i = 0; i < px.length; i++) px[i] = Math.round(t.riv[i] * 255);
      rivTex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, rivTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, t.RW, t.RH, 0, gl.RED, gl.UNSIGNED_BYTE, px);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE); }
    function buildSmooth() {
      const { gw, gh, sx, sy, h, wet } = t, hs = o.heightScale, NV = gw * gh, v = new Float32Array(NV * 12), L = norm([-0.5, 0.9, -0.35]), wy = WATER_H * hs;
      for (let y = 0; y < gh; y++) for (let x = 0; x < gw; x++) {
        const i = y * gw + x, k = i * 6, hy = h[i] * hs;
        v[k] = x * sx; v[k + 1] = hy; v[k + 2] = y * sy;
        const hl = h[y * gw + Math.max(0, x - 1)] * hs, hr = h[y * gw + Math.min(gw - 1, x + 1)] * hs, hu = h[Math.max(0, y - 1) * gw + x] * hs, hd = h[Math.min(gh - 1, y + 1) * gw + x] * hs;
        const n = norm([(hl - hr) / (2 * sx), 1, (hu - hd) / (2 * sy)]), lit = 0.45 + 0.75 * Math.max(0, dot(n, L)), g = Math.min(1, Math.max(h[i], 0.2) * lit);
        v[k + 3] = v[k + 4] = v[k + 5] = g;
        const w = (NV + i) * 6; v[w] = x * sx; v[w + 1] = wy; v[w + 2] = y * sy; v[w + 3] = WATER[0]; v[w + 4] = WATER[1]; v[w + 5] = WATER[2];
      }
      const idx = []; for (let y = 0; y < gh - 1; y++) for (let x = 0; x < gw - 1; x++) { const a = y * gw + x, b = a + 1, c = a + gw, d = c + 1; idx.push(a, c, b, b, c, d); }
      // Water quads only where the cell touches water, so inland lows (craters) below sea level stay dry.
      for (let y = 0; y < gh - 1; y++) for (let x = 0; x < gw - 1; x++) { const a = y * gw + x, b = a + 1, c = a + gw, d = c + 1; if (wet[a] | wet[b] | wet[c] | wet[d]) idx.push(NV + a, NV + c, NV + b, NV + b, NV + c, NV + d); }
      // Outer water frame (map edge → far out) so the sea surface never ends at the map border (no gap showing the sea bed).
      const F = 20000, X1 = (gw - 1) * sx, Z1 = (gh - 1) * sy, fr = [[-F, -F, X1 + F, 0], [-F, Z1, X1 + F, Z1 + F], [-F, 0, 0, Z1], [X1, 0, X1 + F, Z1]], base = 2 * NV, fv = new Float32Array(fr.length * 24);
      fr.forEach(([ax, az, bx, bz], q) => { [[ax, az], [ax, bz], [bx, az], [bx, bz]].forEach(([px, pz], c) => { const o = (q * 4 + c) * 6; fv[o] = px; fv[o + 1] = wy; fv[o + 2] = pz; fv[o + 3] = WATER[0]; fv[o + 4] = WATER[1]; fv[o + 5] = WATER[2]; });
        const b0 = base + q * 4; idx.push(b0, b0 + 1, b0 + 2, b0 + 2, b0 + 1, b0 + 3); });
      const vv = new Float32Array(v.length + fv.length); vv.set(v); vv.set(fv, v.length);
      const ia = new Uint32Array(idx);
      if (!rivTex) { const px = new Uint8Array(t.RW * t.RH); for (let i = 0; i < px.length; i++) px[i] = Math.round(t.riv[i] * 255);
        rivTex = gl.createTexture(); gl.bindTexture(gl.TEXTURE_2D, rivTex); gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, t.RW, t.RH, 0, gl.RED, gl.UNSIGNED_BYTE, px);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE); }
      vbo = vbo || gl.createBuffer(); ibo = ibo || gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.bufferData(gl.ARRAY_BUFFER, vv, gl.STATIC_DRAW);
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo); gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, ia, gl.STATIC_DRAW); nIdx = ia.length; builtScale = hs;
    }
    // Camera rig state. y = smoothed terrain reference height (eases via critically-damped spring), zoom eases toward a 0.25-snapped target.
    const rig = { y: 0, vy: 0, zoom: 1.5, zoomTo: 1.5, last: 0 };
    const refY = () => sample(t, cam.x, cam.z, t.hb) * o.heightScale;
    // Camera basis. Camera sits south (+z) of the look-at point, looking north and down at `pitch`. Height above terrain = camHeight / zoom.
    function camNow() {
      const p = o.pitch * Math.PI / 180, hgt = o.camHeight / rig.zoom, back = hgt / Math.tan(p);
      const eye = [cam.x, rig.y + hgt, cam.z + back], fw = norm([0, -Math.sin(p), -Math.cos(p)]), rt = [1, 0, 0], up = cross(rt, fw);
      return { eye, fw, rt, up };
    }
    function ray(c, e) { const r = canvas.getBoundingClientRect(), nx = ((e.clientX - r.left) / r.width) * 2 - 1, ny = 1 - ((e.clientY - r.top) / r.height) * 2, ty = Math.tan(o.fov * Math.PI / 360), tx = ty * r.width / r.height;
      return norm([c.fw[0] + c.rt[0] * nx * tx + c.up[0] * ny * ty, c.fw[1] + c.rt[1] * nx * tx + c.up[1] * ny * ty, c.fw[2] + c.rt[2] * nx * tx + c.up[2] * ny * ty]); }
    const surf = (x, z) => Math.max(sample(t, x, z), sample(t, x, z, t.hb) > WATER_H + 0.08 ? 0 : WATER_H); // water surface near water, raw terrain inland
    // Heightfield ray march → first terrain/water hit (world coords).
    function hit(c, d) { const hs = o.heightScale; let s = 0, prev = 0;
      for (; s < 20000; s += 4) { const p = [c.eye[0] + d[0] * s, c.eye[1] + d[1] * s, c.eye[2] + d[2] * s]; if (p[1] <= surf(p[0], p[2]) * hs) break; prev = s; if (p[1] < 0) break; }
      let lo = prev, hi = s; for (let i = 0; i < 12; i++) { const m = (lo + hi) / 2, p = [c.eye[0] + d[0] * m, c.eye[1] + d[1] * m, c.eye[2] + d[2] * m]; if (p[1] <= surf(p[0], p[2]) * hs) hi = m; else lo = m; }
      return [c.eye[0] + d[0] * hi, c.eye[1] + d[1] * hi, c.eye[2] + d[2] * hi]; }
    const clamp = () => { const p = play(t); cam.x = Math.max(p.x, Math.min(p.x + p.w - 1, cam.x)); cam.z = Math.max(p.z, Math.min(p.z + p.h - 1, cam.z)); };

    // Unity-style SmoothDamp: zero start velocity (ease-in), decelerates into the target (ease-out).
    function damp(cur, to, vel, smooth, dt) { const w = 2 / smooth, x = w * dt, e = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x), ch = cur - to, tmp = (vel + w * ch) * dt;
      return [to + (ch + tmp) * e, (vel - w * tmp) * e]; }
    function draw(now) { raf = 0; if (dead || !t) return; const F0 = performance.now(), FT = window.MercMap.ft = window.MercMap.ft || { n: 0 }; FT.n++;
      const dt = Math.min(0.05, rig.last ? (now - rig.last) / 1000 : 0.016); rig.last = now;
      if (rig.fly) { const f = rig.fly; f.t = Math.min(1, f.t + dt / f.dur); const k = f.t < 0.5 ? 4 * f.t * f.t * f.t : 1 - Math.pow(-2 * f.t + 2, 3) / 2; // easeInOutCubic
        cam.x = f.x0 + (f.x1 - f.x0) * k; cam.z = f.z0 + (f.z1 - f.z0) * k; if (f.t >= 1) rig.fly = null; }
      [rig.y, rig.vy] = damp(rig.y, refY(), rig.vy, o.heightSmooth, dt);
      rig.zoom += (rig.zoomTo - rig.zoom) * (1 - Math.exp(-dt * 9)); if (Math.abs(rig.zoomTo - rig.zoom) < 0.001) rig.zoom = rig.zoomTo;
      const r = canvas.getBoundingClientRect(), ps = Math.max(1, o.pixelScale), w = Math.max(1, Math.round(r.width / ps)), hh = Math.max(1, Math.round(r.height / ps));
      if (canvas.width !== w || canvas.height !== hh) { canvas.width = w; canvas.height = hh; }
      if (builtScale !== o.heightScale || builtKey !== o.style + o.voxel) build();
      const c = camNow(), mm = mul(persp(o.fov * Math.PI / 180, w / hh, 10, 30000), view(c.eye, c.fw, c.up, c.rt));
      gl.viewport(0, 0, w, hh); const bg = useColor ? deepCol : WATER; const nf = o.night ? [0.3, 0.34, 0.55] : [1, 1, 1]; gl.clearColor(bg[0] * nf[0], bg[1] * nf[1], bg[2] * nf[2], 1); gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT); gl.enable(gl.DEPTH_TEST);
      gl.useProgram(prog); gl.uniformMatrix4fv(uM, false, mm); gl.uniform1f(uNg, o.night ? 1 : 0); gl.uniform2f(uInv, 1 / t.W, 1 / t.H); gl.uniform3f(uWc, bg[0], bg[1], bg[2]); gl.uniform1f(uCt, useColor ? 1 : 0); gl.uniform2f(uCinv, colInv[0], colInv[1]); gl.uniform1f(uRk, o.style === 'voxel' ? 0 : 1); gl.uniform1f(uRs, o.style === 'terrace' ? 0.01 : 0.08);
      gl.activeTexture(gl.TEXTURE0); gl.bindTexture(gl.TEXTURE_2D, rivTex); gl.uniform1i(uRiv, 0);
      gl.activeTexture(gl.TEXTURE1); gl.bindTexture(gl.TEXTURE_2D, colTex || rivTex); gl.uniform1i(uCol, 1);
      gl.activeTexture(gl.TEXTURE2); gl.bindTexture(gl.TEXTURE_2D, natTex || rivTex); gl.uniform1i(uNt, 2);
      gl.activeTexture(gl.TEXTURE3); gl.bindTexture(gl.TEXTURE_2D, dfTex || rivTex); gl.uniform1i(uDf, 3);
      gl.activeTexture(gl.TEXTURE6); gl.bindTexture(gl.TEXTURE_2D, sidTex || rivTex); gl.uniform1i(uSd, 6); gl.uniform1f(uHs, sidTex ? hotSid : 0); gl.uniform2f(uSp, 1 / t.RW, 1 / t.RH);

      const L = liftH(), k = hov.t0 ? Math.min(1, (performance.now() - hov.t0) / LIFT_MS) : 1, ek = k * k * (3 - 2 * k); // smoothstep = ease-in/ease-out
      hov.la = hov.a ? hov.la0 + (L - hov.la0) * ek : 0; hov.lb = hov.lb0 * (1 - ek); if (k >= 1) hov.t0 = 0;
      { const now = performance.now(), q = dim.t0 ? Math.min(1, (now - dim.t0) / DIM_MS) : 1, e = ease(q); dim.v = dim.v0 + (dim.to - dim.v0) * e; if (q >= 1) dim.t0 = 0;
        const qb = br.t0 ? Math.min(1, (now - br.t0) / DIM_MS) : 1, eb = ease(qb); br.va = br.a ? br.va0 + (1 - br.va0) * eb : 0; br.vb = br.vb0 * (1 - eb); if (qb >= 1) br.t0 = 0;
        gl.uniform4f(uBn, br.a, br.va, br.b, br.vb); gl.uniform1f(uDa, dim.v); }
      gl.uniform4f(uNl, hov.a, hov.la, hov.b, hov.lb); gl.uniform1f(uHn, hov.a); { const c = outlineOf(hov.a); gl.uniform3f(uOc, c[0], c[1], c[2]); } gl.uniform1f(uHa, L ? hov.la / L : 0);
      gl.bindBuffer(gl.ARRAY_BUFFER, vbo); gl.enableVertexAttribArray(aP); gl.vertexAttribPointer(aP, 3, gl.FLOAT, false, 24, 0); gl.enableVertexAttribArray(aC); gl.vertexAttribPointer(aC, 3, gl.FLOAT, false, 24, 12);
      const F1 = performance.now(); gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo); gl.drawElements(gl.TRIANGLES, nIdx, gl.UNSIGNED_INT, 0); const F2 = performance.now(); drawOverlay(mm); const F3 = performance.now();
      lastMM = mm; if (o.onFrame) o.onFrame(project); const F4 = performance.now(); report(); const F5 = performance.now();
      const rx = Math.round(cam.x), rz = Math.round(cam.z); if (o.onMove && (rx !== rig.rx || rz !== rig.rz)) { rig.rx = rx; rig.rz = rz; o.onMove(rx - PAD.left, rz - PAD.top); } const F6 = performance.now();
      for (const [k, v] of [['setup', F1 - F0], ['terrain', F2 - F1], ['overlay', F3 - F2], ['onFrame', F4 - F3], ['report', F5 - F4], ['onMove', F6 - F5]]) { FT[k] = (FT[k] || 0) + v; FT[k + 'Max'] = Math.max(FT[k + 'Max'] || 0, v); }
      if (rig.fly || hov.t0 || dim.t0 || br.t0 || Math.abs(rig.y - refY()) > 0.02 || Math.abs(rig.vy) > 0.02 || rig.zoom !== rig.zoomTo) req(); else rig.last = 0; }
    const req = () => { if (!raf) raf = requestAnimationFrame(draw); };

    // Pan: incremental grab. Each move, the cursor's previous and current rays hit the plane at the grabbed height; the camera shifts by the difference.
    // World distance per screen pixel scales with camera distance, so pan speed follows zoom automatically.
    const onPlane = (c, e, y) => { const d = ray(c, e); if (d[1] >= -1e-4) return null; const s = (y - c.eye[1]) / d[1]; return [c.eye[0] + d[0] * s, c.eye[2] + d[2] * s]; };
    // Dev pick: Shift+click reports the image px under the cursor (window.__mercPick + o.onPick) — used to place labels.
    const down = e => { if (o.locked || !t || e.button !== 0) return; downAt = { x: e.clientX, y: e.clientY };
      if (e.shiftKey) { const c = camNow(), p = hit(c, ray(c, e)); if (p) { const ix = Math.round(p[0]), iz = Math.round(p[2]); window.__mercPick = { ix, iz, x: ix - PAD.left, z: iz - PAD.top }; if (o.onPick) o.onPick(window.__mercPick); } e.preventDefault(); return; } rig.fly = null; const c = camNow(); drag = { y: hit(c, ray(c, e))[1], e: { clientX: e.clientX, clientY: e.clientY } }; canvas.setPointerCapture(e.pointerId); canvas.style.cursor = 'grabbing'; e.preventDefault(); };
    const move = e => { if (!drag) return; const c = camNow(), a = onPlane(c, drag.e, drag.y), b = onPlane(c, e, drag.y); drag.e = { clientX: e.clientX, clientY: e.clientY };
      if (!a || !b) return; cam.x += a[0] - b[0]; cam.z += a[1] - b[1]; clamp(); req(); };
    // Cursor readout: terrain point under the pointer (MAP coords) → o.onCursor(x, z); null when the pointer leaves. Re-evaluated after camera moves.
    let ptr = null, curKey = '', curSet = 0, downAt = null;
    // Settlement under the cursor (hit mask) → o.onSettle(name | null); canvas cursor = pointer. Click (press + release < 5 px apart) → o.onSettleClick(name).
    const setAt = p => { if (!p || !t.sidHit || o.locked) return 0; const x = Math.round(p[0]) >> 1, z = Math.round(p[2]) >> 1; return x < 0 || z < 0 || x >= t.RW || z >= t.RH ? 0 : t.sidHit[z * t.RW + x]; };
    // Hovered nation: lifts LIFT world units (≈5 map px; capped below one terrace step so faces never invert) over LIFT_MS with smoothstep easing.
    // Outline color per nation (by name key); others default yellow.
    const OUTLINE = { Vaernebo: '#4fd35a', Rossade: '#4fd35a', Buern: '#4fd35a', Cyfrolaef: '#3a1458', Aerdis: '#2fe0cf', Aldurstein: '#f2b51d', Copari: '#9b4dff', Zukei: '#ff2fd6', Kathaya: '#ff3b30', Miliim: '#ff8a1f', Suorr: '#6e7480' }, OUTLINE_DEFAULT = '#f2d33d';
    const outlineOf = id => { const n = t && t.natById && t.natById[id], k = n && Object.keys(OUTLINE).find(s => n.name.includes(s)), h = (k ? OUTLINE[k] : OUTLINE_DEFAULT).slice(1); return [0, 2, 4].map(i => parseInt(h.slice(i, i + 2), 16) / 255); };
    // Dim: own slow smoothstep (DIM_MS). Focus nation = last hovered nation; stays dimmed over water / no nation; clears when the cursor leaves the map or it's masked.
    // Dim: global amount (on while the cursor is over the map, off on leave / masked) + per-nation brightness in two slots (hovered, previous),
    // all eased with smootherstep over DIM_MS. Over water / no nation every nation is dimmed.
    const DIM_MS = 450, dim = { v: 0, v0: 0, to: 0, t0: 0 }, br = { a: 0, va: 0, va0: 0, b: 0, vb: 0, vb0: 0, t0: 0 };
    const ease = q => q * q * q * (q * (q * 6 - 15) + 10);
    const setBright = id => { if (id === br.a) return; if (id && id === br.b) { const v = br.va; br.b = br.a; br.vb0 = v; br.a = id; br.va0 = br.vb; } else { br.b = br.a; br.vb0 = br.va; br.a = id; br.va0 = 0; } br.t0 = performance.now(); req(); };
    const setDim = to => { if (to === dim.to) return; dim.v0 = dim.v; dim.to = to; dim.t0 = performance.now(); req(); };
    const LIFT = 10, LIFT_MS = 140, hov = { a: 0, la: 0, la0: 0, b: 0, lb: 0, lb0: 0, t0: 0 };
    const liftH = () => LIFT; // world units = map px (no culling, so a lift past a taller neighbor just flips that wall and the gap stays closed)
    const setHover = id => { if (id === hov.a) return;
      if (id && id === hov.b) { const la = hov.la; hov.b = hov.a; hov.lb0 = la; hov.a = id; hov.la0 = hov.lb; } // re-entered the nation still easing down: swap
      else { hov.b = hov.a; hov.lb0 = hov.la; hov.a = id; hov.la0 = 0; }
      hov.t0 = performance.now(); req(); };
    const hoverNation = p => { if (!t.nat || o.locked || !p) return 0; const ix = Math.round(p[0]), iz = Math.round(p[2]); if (ix < 0 || iz < 0 || ix >= t.W || iz >= t.H || t.sea[iz * t.W + ix]) return 0; return t.nat[iz * t.W + ix]; };
    const report = () => { if (!t) return; let hp = null; if (ptr) { const c = camNow(); hp = hit(c, ray(c, ptr)); } { const hn = hoverNation(hp); setHover(hn); setBright(hn); setDim(ptr && !o.locked ? 1 : 0);
        const sh = drag ? curSet : setAt(hp); if (sh !== curSet) { curSet = sh; if (o.onSettle) o.onSettle(sh ? t.setList[sh] : null); } if (!drag) canvas.style.cursor = o.locked ? 'default' : curSet ? 'pointer' : 'grab'; } if (!o.onCursor) return; let k = 'none', x = 0, z = 0; if (ptr) { const p = hp; if (p) { const q = play(t); x = Math.max(0, Math.min(q.w - 1, Math.round(p[0]) - PAD.left)); z = Math.max(0, Math.min(q.h - 1, Math.round(p[2]) - PAD.top)); k = x + ',' + z; } }
      if (k !== curKey) { curKey = k; o.onCursor(k === 'none' ? null : { x, z }); } };
    const hover = e => { ptr = { clientX: e.clientX, clientY: e.clientY }; if (!drag) report(); };
    const leave = () => { ptr = null; report(); };
    const pEl = canvas.parentElement || canvas; // parent: hovering a label / pin keeps tracking the terrain under the cursor
    pEl.addEventListener('pointermove', hover); pEl.addEventListener('pointerleave', leave);
    // Screen position (CSS px, canvas-relative) of an image-px ground point (terrain / water surface height), or null if behind / off-screen.
    let lastMM = null;
    const project = (ix, iz) => { if (!lastMM || !t) return null; const m = lastMM, y = surf(ix, iz) * o.heightScale, w = m[3] * ix + m[7] * y + m[11] * iz + m[15]; if (w <= 1e-3) return null;
      const cx = (m[0] * ix + m[4] * y + m[8] * iz + m[12]) / w, cy = (m[1] * ix + m[5] * y + m[9] * iz + m[13]) / w; if (cx < -1.2 || cx > 1.2 || cy < -1.3 || cy > 1.2) return null;
      return [(cx * 0.5 + 0.5) * canvas.clientWidth, (0.5 - cy * 0.5) * canvas.clientHeight]; }; // layout px (not getBoundingClientRect: the HUD is CSS-scaled to fit, the overlay lives inside that scale)
    const projectY = (ix, iz, y) => { if (!lastMM || !t) return null; const m = lastMM, w = m[3] * ix + m[7] * y + m[11] * iz + m[15]; if (w <= 1e-3) return null; const cx = (m[0] * ix + m[4] * y + m[8] * iz + m[12]) / w, cy = (m[1] * ix + m[5] * y + m[9] * iz + m[13]) / w; if (cx < -1.2 || cx > 1.2 || cy < -1.3 || cy > 1.2) return null; return [(cx * 0.5 + 0.5) * canvas.clientWidth, (0.5 - cy * 0.5) * canvas.clientHeight]; }; // world y given (vehicles, airships)
    const up = e => { if (downAt && Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y) < 5 && curSet && o.onSettleClick) o.onSettleClick(t.setList[curSet]); downAt = null;
      if (!drag) return; drag = null; try { canvas.releasePointerCapture(e.pointerId); } catch (_) {} canvas.style.cursor = o.locked ? 'default' : 'grab'; };
    // Zoom: wheel steps 0.25× between ZOOM_MIN (furthest, = camHeight) and ZOOM_MAX; accumulates trackpad deltas so one notch = one step.
    let wAcc = 0;
    const wheel = e => { if (o.locked || !t) return; e.preventDefault(); wAcc += e.deltaMode === 1 ? e.deltaY * 33 : e.deltaY;
      if (Math.abs(wAcc) < 60) return; const dir = wAcc < 0 ? 1 : -1; wAcc = 0;
      rig.zoomTo = Math.max(o.zoomMin, Math.min(o.zoomMax, Math.round((rig.zoomTo + dir * o.zoomStep) / o.zoomStep) * o.zoomStep)); req(); };
    canvas.addEventListener('pointerdown', down); canvas.addEventListener('pointermove', move); canvas.addEventListener('pointerup', up); canvas.addEventListener('pointercancel', up); const wEl = canvas.parentElement || canvas; wEl.addEventListener('wheel', wheel, { passive: false }); // parent: wheel over map labels still zooms
    const ro = new ResizeObserver(() => req()); ro.observe(canvas);
    canvas.style.cursor = o.locked ? 'default' : 'grab';

    load().then(tt => { if (dead) return; t = tt; let fTick = 0; const fIv = setInterval(() => { if (dead) { clearInterval(fIv); return; } fTick++; if (t && !document.hidden && !drag && ((t.vhVis && o.vehicles !== false) || ((t.fireTorches || t.gwBraziers) && fTick % 3 === 0))) req(); }, 55); /* vehicles ≈ 18 fps while one is on screen; fire frames 6 fps */ { const p = play(t); cam.x = o.startX != null ? o.startX + p.x : p.x + p.w / 2; cam.z = o.startZ != null ? o.startZ + p.z : p.z + p.h / 2; } clamp(); rig.y = refY(); rig.zoom = rig.zoomTo = o.zoom; build(); req(); if (o.onReady) o.onReady(); }, err => o.onError && o.onError(err.message));
    // Glide the look-at point to (x, z) image px. Duration scales with distance (0.6–1.6 s), ease-in-out. Any drag cancels it.
    const flyTo = (x, z) => { if (!t) { o.startX = x; o.startZ = z; return; } const p = play(t), x1 = Math.max(p.x, Math.min(p.x + p.w - 1, x + p.x)), z1 = Math.max(p.z, Math.min(p.z + p.h - 1, z + p.z)), d = Math.hypot(x1 - cam.x, z1 - cam.z);
      rig.fly = { x0: cam.x, z0: cam.z, x1, z1, t: 0, dur: Math.max(0.6, Math.min(1.6, 0.5 + d / 2500)) }; req(); };
    // settle(): finish any glide / zoom / height easing immediately and redraw (snap; also used for screenshots).
    const settle = () => { if (!t) return; if (rig.fly) { cam.x = rig.fly.x1; cam.z = rig.fly.z1; rig.fly = null; } rig.zoom = rig.zoomTo; rig.y = refY(); rig.vy = 0; cancelAnimationFrame(raf); raf = 0; draw(performance.now()); };
    const ctl = {
      flyTo, settle,
      project: (ix, iz) => project(ix, iz), // image px → canvas CSS px (null off screen)
      natHexAt: (ix, iz, id) => { const n = id || (t && t.nat ? t.nat[Math.max(0, Math.min(t.H - 1, Math.round(iz))) * t.W + Math.max(0, Math.min(t.W - 1, Math.round(ix)))] : 0); if (!n || !t || !t.natById || !t.natById[n]) return null; return '#' + outlineOf(n).map(v => Math.round(v * 255).toString(16).padStart(2, '0')).join(''); }, // nation highlight colour (labels match the building tint)
      vehicles: () => (vhSim && vhSim.info ? vhSim.info() : []), // [{ key: 'coach0' | 'train0' | 'ship0', kind, x, z, y, hidden, dest, eta (real s) }] — contract parties (Game HUD tooltips / fly-to)
      projectY: (ix, iz, y) => projectY(ix, iz, y),
      setHot(name) { const id = t && t.setList ? t.setList.indexOf(name) : -1, v = name && id > 0 ? id : 0; if (v !== hotSid) { hotSid = v; const lb = v && t.labels ? t.labels.find(l => l.name === name) : null; hotNat = lb ? (lb.nationId || (t.nat ? t.nat[Math.round(lb.iz) * t.W + Math.round(lb.ix)] : 0) || 0) : 0; req(); } }, // hotNat → building tint = that nation's highlight colour
      set(n) { o = { ...o, ...n }; req(); if (o.locked && drag) drag = null; if (t) report(); canvas.style.cursor = o.locked ? 'default' : 'grab'; req(); },
      center: () => ({ x: cam.x - PAD.left, z: cam.z - PAD.top, zoom: rig.zoomTo }),
      destroy() { if (window.MercMap.view === ctl) window.MercMap.view = null; dead = true; cancelAnimationFrame(raf); ro.disconnect(); canvas.removeEventListener('pointerdown', down); canvas.removeEventListener('pointermove', move); canvas.removeEventListener('pointerup', up); canvas.removeEventListener('pointercancel', up); wEl.removeEventListener('wheel', wheel); pEl.removeEventListener('pointermove', hover); pEl.removeEventListener('pointerleave', leave); },
    };
    window.MercMap.view = ctl; // HUD widgets (ActiveContracts, GuildHomeButton) drive the live map through this
    return ctl;
  }
  // PLACEHOLDER location names until a region map exists (RegionMap: nation/sea id per pixel). Water → sea, land → one of 8 nations on a 4×2 grid.
  // Nation / region under a MAP-coord pixel. Readout text: "Nation (Region)"; no nation (sea etc.) → region only; neither → "Open Sea" / "Unclaimed Land".
  function placeAt(x, z) { const t = terrain; if (!t) return null; const ix = Math.round(x) + PAD.left, iz = Math.round(z) + PAD.top; if (ix < 0 || iz < 0 || ix >= t.W || iz >= t.H) return { nation: null, region: null, regionId: 0, sea: true };
    const i = iz * t.W + ix, n = t.nat && t.nat[i] ? t.natById[t.nat[i]] : null, r = t.reg && t.reg[i] ? t.regById[t.reg[i]] : (t.sea && t.sea[i] && !n ? seaRegionAt(t, ix, iz) : null);
    return { nation: n ? n.name : null, region: r ? r.name : null, regionId: r ? r.id : 0, category: r ? r.category : null, sea: !!t.sea[i] }; }
  // Unnamed open water (no region px): the nearest of the named oceans (SEA_NAMES) — multi-source BFS on an 8 px grid, built once. Never "Open Sea".
  const SEA_NAMES = ['Marric Sea', 'Gledd Sea', 'Halen Ocean'];
  function seaRegionAt(t, ix, iz) { if (!t.seaNear) { const S = 8, w = Math.ceil(t.W / S), h = Math.ceil(t.H / S), M = new Int16Array(w * h).fill(-1), ids = Object.values(t.regById || {}).filter(r => SEA_NAMES.includes(r.name)).map(r => r.id), q = [];
      for (let cz = 0; cz < h; cz++) for (let cx = 0; cx < w; cx++) { const v = t.reg[Math.min(t.H - 1, cz * S + 4) * t.W + Math.min(t.W - 1, cx * S + 4)]; if (ids.includes(v)) { M[cz * w + cx] = v; q.push(cz * w + cx); } }
      for (let k = 0; k < q.length; k++) { const j = q[k], x = j % w, z = (j / w) | 0; for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const xx = x + dx, zz = z + dz; if (xx < 0 || zz < 0 || xx >= w || zz >= h) continue; const j2 = zz * w + xx; if (M[j2] < 0) { M[j2] = M[j]; q.push(j2); } } }
      t.seaNear = { M, w, S }; } const { M, w, S } = t.seaNear, v = M[((iz / S) | 0) * w + ((ix / S) | 0)]; return v >= 0 ? t.regById[v] : null; }
  function regionAt(x, z) { const p = placeAt(x, z); if (!p) return '';
    return p.nation ? (p.region ? p.nation + ' (' + p.region + ')' : p.nation) : (p.region || (p.sea ? 'Halen Ocean' : 'Unclaimed Land')); }
  const GUILD_HOME = [0, 0]; // PLACEHOLDER guild home (image px). 1 px = 1 km.
  // Lat/long readout (MapCoords). Equirectangular on an Earth-sized globe: 1° latitude = KM_PER_DEG km; a degree of longitude shrinks by cos(lat).
  //   KM_PER_DEG = PLANET_KM / 360
  //   lat = LAT0 - (z - z0) / KM_PER_DEG               (+ = N; image rows grow southward)
  //   lon = LON0 + (x - x0) / (KM_PER_DEG · cos(lat))  (+ = E)
  // (x0, z0) = map center, placed at LAT0/LON0: roughly half a Russia south of Russia on Earth (≈45°N, 100°E).
  // Planet size is derived: the map's width spans CONTINENT_SPAN of the way around the planet along the center parallel (LAT0).
  //   PLANET_KM = mapWidthKm / (CONTINENT_SPAN · cos(LAT0))  → 4096 / (1/3 · cos45°) ≈ 17,378 km (Earth ≈ 40,075)
  const LAT0 = 45, LON0 = 100;        // map-center latitude / longitude
  const CONTINENT_SPAN = 1 / 3;       // map width = 1/3 of the planet's circumference → 120° of longitude at the center row
  function toLatLon(x, z) { const t = terrain, p = t ? play(t) : { w: 4096, h: 2160 }, W = p.w, x0 = W / 2, z0 = p.h / 2; // MAP coords; padding excluded
    const PLANET_KM = W / (CONTINENT_SPAN * Math.cos(LAT0 * Math.PI / 180)), KM_PER_DEG = PLANET_KM / 360; // ≈ 48.27 km per degree
    const lat = Math.max(-90, Math.min(90, LAT0 - (z - z0) / KM_PER_DEG)), lon = LON0 + (x - x0) / (KM_PER_DEG * Math.cos(lat * Math.PI / 180));
    const dm = (v, p, n) => { const a = Math.abs(v), d = Math.floor(a), mi = Math.floor((a - d) * 60); return d + '°' + String(mi).padStart(2, '0') + '′' + (v >= 0 ? p : n); };
    return { lat, lon, text: dm(lat, 'N', 'S') + ' ' + dm(lon, 'E', 'W') }; }
  // Biome at a map pixel (same x/z as camera / readout). land = class under the pixel (incl. under rivers), water = water class if any.
  // biome = the class that governs spawning: water class on sea/lake/river pixels, else the land class. Returns null until the map has loaded.
  function biomeAt(x, z) { const t = terrain; if (!t || !t.land) return null; const xi = Math.max(0, Math.min(t.W - 1, Math.round(x) + PAD.left)), zi = Math.max(0, Math.min(t.H - 1, Math.round(z) + PAD.top)), i = zi * t.W + xi;
    const get = (L, layer) => { const c = L.code[i]; if (c === 255) return null; const cl = L.classes.find(k => k.id === c >> 2); return { layer, id: cl.id, name: cl.name, tone: TONES[c & 3], color: cl[TONES[c & 3]] }; };
    const land = get(t.land, 'land'), water = get(t.water, 'water'); return { land, water, biome: water || land, river: !!water && !t.sea[i] }; }
  window.MercMap = { prof: PROF, mount, ensureIcons, load, regionAt, placeAt, toLatLon, biomeAt, PAD, rail: { route: railRoute, stations: () => terrain && terrain.rail ? terrain.rail.stations.map(s => ({ name: s.name, x: s.x - PAD.left, z: s.y - PAD.top })) : [] }, labels: () => terrain ? terrain.labels : [], home: GUILD_HOME, view: null };
  ensureIcons();
})();
