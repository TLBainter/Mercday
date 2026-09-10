class_name HtmlWireframeGenerator


static func save(field: BattlefieldArea, path_stem: String) -> void:
	save_to(field, path_stem + "_3d.html")


#Writes the viewer to an exact path; used for the battle-end re-serialization.
static func save_to(field: BattlefieldArea, path: String) -> void:
	if field == null:
		return
	var html := _build_html(field)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("HtmlWireframeGenerator: could not write %s" % path)
		return
	f.store_string(html)
	f.close()


static func _extract_data(field: BattlefieldArea) -> Dictionary:
	var data: Dictionary = {}
	data["width"] = field.width
	data["length"] = field.length
	data["area_name"] = field.area_name
	data["is_interior"] = field.is_interior_map
	data["floor_height"] = field.interior_floor_height
	data["floor_depth"] = field.interior_floor_depth
	data["top_y"] = field.interior_top_y

	var floors: Dictionary = {}
	for k: Variant in field.interior_floor_elevations.keys():
		floors[str(k as int)] = field.interior_floor_elevations[k]
	data["floors"] = floors

	var th: Dictionary = {}
	for k: Variant in field.terrain_heights.keys():
		var pos := k as Vector2i
		th["%d_%d" % [pos.x, pos.y]] = field.terrain_heights[k]
	data["terrain_heights"] = th

	var obs_list: Array = []
	for obs: Dictionary in field.obstacles:
		var cell := BattlefieldArea.cell_of(obs["pos"])
		var pos := Vector3i(cell.x, cell.y, BattlefieldArea.floor_of(obs["pos"]))
		var d: ObstacleData = obs.get("data") as ObstacleData
		obs_list.append({
			"x": pos.x, "y": pos.y, "floor": pos.z,
			"size": obs.get("size", 1),
			"cell_type": obs.get("cell_type", ""),
			"orient": obs.get("orientation", "v"),
			"size_x": d.size_x if d != null else 1.0,
			"size_y": d.size_y if d != null else 1.0,
			"size_z": d.size_z if d != null else 1.0,
			"pw": obs.get("pw", ceili(d.size_x) if d != null else 1),
			"ph": obs.get("ph", ceili(d.size_y) if d != null else 1),
			"name": d.obstacle_name.to_lower() if d != null else "",
			"type": d.obstacle_type.to_lower() if d != null else "",
			"narrow": d.narrow if d != null else false,
			"broken": obs.get("broken", false) as bool,
		})
	data["obstacles"] = obs_list

	#Exterior buildings key their cells by Vector2i; the viewer draws those on floor 0.
	var bi: Array = []
	for k: Variant in field.building_interiors.keys():
		if k is Vector3i:
			var pos: Vector3i = k
			bi.append([pos.x, pos.y, pos.z])
		elif k is Vector2i:
			var flat: Vector2i = k
			bi.append([flat.x, flat.y, 0])
	data["building_interiors"] = bi

	data["ceiling_cells"] = _triples(field.ceiling_cells)

	data["stairwell_cells"] = _triples(field.stairwell_cells)

	var stc: Array = []
	for k: Variant in field.stair_run_cells.keys():
		var sp := k as Vector3i
		stc.append([sp.x, sp.y, sp.z, field.cell_base_elevation(Vector2i(sp.x, sp.y), sp.z)])
	data["stair_cells"] = stc

	var dls: Array = []
	for k: Variant in field.drop_links.keys():
		var dp := k as Vector3i
		for dl: Dictionary in (field.drop_links[k] as Array):
			var dt: Vector3i = dl["to"] as Vector3i
			dls.append({"x": dp.x, "y": dp.y, "floor": dp.z, "tx": dt.x, "ty": dt.y,
				"paces": int(dl["paces"]), "kind": str(dl["kind"])})
	data["drop_links"] = dls

	var rooms: Array = []
	for entry: Dictionary in field.interior_rooms:
		var rect: Rect2i = entry["rect"] as Rect2i
		rooms.append({
			"x": rect.position.x, "y": rect.position.y,
			"w": rect.size.x, "h": rect.size.y,
			"name": entry["name"], "floor": entry["floor"]
		})
	data["rooms"] = rooms

	var bdata: Array = []
	for b: Dictionary in field.building_data:
		var rect: Rect2i = b["rect"] as Rect2i
		bdata.append({"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y, "name": b.get("name", "")})
	data["buildings"] = bdata

	data["spawn_a"] = _pairs(field.spawn_zone_a)

	data["spawn_b"] = _pairs(field.spawn_zone_b)

	data["jagged_cells"] = _pairs(field.jagged_cells)

	return data


#Vector3i keys of d as [x, y, floor] arrays, in key order.
static func _triples(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		var pos := k as Vector3i
		out.append([pos.x, pos.y, pos.z])
	return out


#Vector2i keys of d as [x, y] arrays, in key order.
static func _pairs(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d.keys():
		var pos := k as Vector2i
		out.append([pos.x, pos.y])
	return out


static func _build_html(field: BattlefieldArea) -> String:
	var data := _extract_data(field)
	var json_str := JSON.stringify(data)
	var title := field.area_name + " - 3D"
	var type_label: String = "INTERIOR" if field.is_interior_map else "EXTERIOR"
	var wh := "%dx%d" % [field.width, field.length]
	var num_floors: int = field.interior_floor_elevations.size()
	var slider_max: String = str(max(1, num_floors - 1)) if field.is_interior_map else "10"

	var html := _html_template()
	html = html.replace("{{SCENE_DATA}}", json_str)
	html = html.replace("{{TITLE}}", title)
	html = html.replace("{{TYPE_LABEL}}", type_label)
	html = html.replace("{{WH}}", wh)
	html = html.replace("{{SLIDER_MAX}}", slider_max)
	return html


static func _html_template() -> String:
	return """<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>{{TITLE}}</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#004e98;overflow:hidden;font-family:Tahoma,'MS Sans Serif',Arial,sans-serif}
canvas{display:block}
#ui{position:fixed;right:0;top:0;bottom:0;width:160px;background:#ece9d8;
  padding:0;display:flex;flex-direction:column;gap:0;color:#000000;font-size:11px;
  border-left:2px solid #7b7b6b}
#ui-title{background:linear-gradient(to right,#0a246a,#3a6abf);color:#ffffff;font-size:11px;
  font-weight:bold;padding:5px 8px;letter-spacing:0.03em;white-space:nowrap;overflow:hidden}
#ui-body{display:flex;flex-direction:column;gap:8px;padding:10px 10px 10px;flex:1}
#info{position:fixed;top:8px;left:8px;background:#ffffe1;border:1px solid #000000;
  color:#000000;font-size:11px;padding:2px 7px;pointer-events:none}
.section{background:linear-gradient(to right,#0a246a,#3a6abf);color:#ffffff;font-size:10px;
  padding:2px 6px;margin:4px -10px 0;letter-spacing:0.06em}
.slider-wrap{display:flex;flex-direction:column;align-items:center;gap:6px}
#floor-label{color:#000000;font-size:12px}
#floor-slider{writing-mode:vertical-lr;direction:rtl;width:20px;height:160px;cursor:pointer;accent-color:#0a246a}
.chk-row{display:flex;gap:6px;align-items:center;cursor:pointer;padding:3px 0}
.chk-row input{accent-color:#0a246a;cursor:pointer}
button{background:#ece9d8;color:#000000;
  border:1px solid #7b7b6b;
  box-shadow:inset 1px 1px 0 #ffffff,inset -1px -1px 0 #aca899;
  padding:4px 8px;cursor:pointer;font-family:Tahoma,Arial,sans-serif;font-size:11px;width:100%}
button:hover{background:#c4def5;box-shadow:inset 1px 1px 0 #d8edff,inset -1px -1px 0 #8ab0d0}
button:active{box-shadow:inset 1px 1px 0 #aca899,inset -1px -1px 0 #ffffff}
</style>
</head>
<body>
<div id="info">{{TYPE_LABEL}} - {{TITLE}} - {{WH}}</div>
<div id="ui">
  <div id="ui-title">Level Viewer</div>
  <div id="ui-body">
    <div class="section">FLOOR</div>
    <div class="slider-wrap">
      <span id="floor-label">ALL</span>
      <input type="range" id="floor-slider" min="0" max="{{SLIDER_MAX}}" value="{{SLIDER_MAX}}" step="1">
    </div>
    <div class="section">SHOW</div>
    <label class="chk-row"><input type="checkbox" id="chk-spawn" checked> Spawn Zones</label>
    <label class="chk-row"><input type="checkbox" id="chk-furn" checked> Furniture</label>
    <label class="chk-row"><input type="checkbox" id="chk-labels" checked> Labels</label>
    <div style="flex:1"></div>
    <button onclick="resetCam()">Reset Camera</button>
  </div>
</div>
<script type="importmap">
{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.158.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.158.0/examples/jsm/"}}
</script>
<script type="module">
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
const D = {{SCENE_DATA}};
const W=D.width, L=D.length, IS_INT=D.is_interior, FH=D.floor_height||5, FD=IS_INT?(D.floor_depth||20):0;
const TOP_Y=IS_INT?(D.top_y||3):0, BLD_X=TOP_Y, FW=W-2-2*TOP_Y, BOT_Y=TOP_Y+FD+1;
const PANEL=160;

// floors: floor_num -> elevation in cells above ground
const fEntries=Object.entries(D.floors||{}).map(([k,v])=>[parseInt(k),parseInt(v)]).sort((a,b)=>a[0]-b[0]);
const fNums=fEntries.map(e=>e[0]);
const fElev=Object.fromEntries(fEntries);
const NF=fNums.length;
const UNIT=1.0;

function floorElev(fn){return (fElev[fn]||0)*UNIT;}

// renderer
let renderer;
try{renderer=new THREE.WebGLRenderer({antialias:true});}
catch(e){
  document.body.innerHTML='<div style="color:#ff8888;font:13px monospace;padding:24px;line-height:1.8">WebGL unavailable.<br>Restart the browser and try again.<br><br>Error: '+e.message+'</div>';
  throw e;
}
renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
renderer.setSize(innerWidth-PANEL,innerHeight);
renderer.setClearColor(0x4a7cbf);
document.body.prepend(renderer.domElement);

const scene=new THREE.Scene();
const CX=W*0.5, CZ=L*0.5;
const maxElev=NF>0?(fElev[fNums[NF-1]]||0)+FH:10;
const totH=IS_INT?(maxElev+FH+4):10;
const cam=new THREE.PerspectiveCamera(45,(innerWidth-PANEL)/innerHeight,0.1,3000);
const controls=new OrbitControls(cam,renderer.domElement);
function resetCam(){
  cam.position.set(CX+W*0.9,totH*1.1+4,CZ+L*0.9);
  controls.target.set(CX,IS_INT?totH*0.4:1,CZ);
  controls.update();
}
window.resetCam=resetCam;
resetCam();

scene.add(new THREE.AmbientLight(0xffffff,0.9));

// groups
const spawnGrp=new THREE.Group(), furnGrp=new THREE.Group();
scene.add(spawnGrp,furnGrp);
const allSpawnMeshes=[];
const hoverMeshes=[];
const fGrps={};
for(const fn of fNums){fGrps[fn]=new THREE.Group();scene.add(fGrps[fn]);}
const base=new THREE.Group();
scene.add(base);

// materials
const allLabMeshes=[];
function m(col,op,ds=true){return new THREE.MeshBasicMaterial({color:col,transparent:op<1,opacity:op,side:ds?THREE.DoubleSide:THREE.FrontSide,depthWrite:op>0.5});}
function lm(col){return new THREE.LineBasicMaterial({color:col});}
const M={
  wall:m(0xd8d4c4,.88),wallE:lm(0x989080),
  floor:m(0x8aa0b4,.45),floorE:lm(0x607890),
  door:m(0xa06830,.88),doorE:lm(0x704820),
  glass:m(0x80b8e0,.55),glassE:lm(0x5090c0),
  glassB:m(0xe05a3c,.45),glassBE:lm(0xa03010),
  dropB:m(0xffcc33,.95),dropW:m(0xff5a3c,.95),
  spawnA:m(0x4878c8,.35),spawnB:m(0x48a040,.35),
  veg:m(0x4a8a1a,.85),vegE:lm(0x2a6808),
  furn:m(0x9a7030,.85),furnE:lm(0x6a4818),
  terr:m(0x8a9870,.8),terrE:lm(0x5a6848),
  stO:m(0xb08858,.9),stOE:lm(0x806030),
  pill:m(0xb0a888,.9),pillE:lm(0x807860),
  tabl:m(0x9a6828,.9),tablE:lm(0x6a4410),
  chair:m(0x8a5820,.85),
  fence:m(0x8a7050,.85),fenceE:lm(0x5a4828),
  outd:m(0x8aaa6a,.22),outdE:lm(0x5a7a3a),
  bldg:m(0xd4d0c4,.18),bldgE:lm(0x9a9888),
  jagg:m(0xa09888,.65),jaggE:lm(0xc0b8a8),
  ground:m(0x6a9a4a,.15),
};

function addBox(grp,x,y,z,sx,sy,sz,fill,edge,ud){
  const g=new THREE.BoxGeometry(sx,sy,sz);
  const mesh=new THREE.Mesh(g,fill);
  mesh.position.set(x+sx*.5,y+sy*.5,z+sz*.5);
  if(ud) Object.assign(mesh.userData,ud);
  grp.add(mesh);
  if(edge){
    const ln=new THREE.LineSegments(new THREE.EdgesGeometry(g),edge);
    ln.position.copy(mesh.position);
    if(ud) Object.assign(ln.userData,ud);
    grp.add(ln);
  }
  return mesh;
}

function addPlane(grp,cx,y,cz,sx,sz,mat,ud){
  const mesh=new THREE.Mesh(new THREE.PlaneGeometry(sx,sz),mat);
  mesh.rotation.x=-Math.PI/2;
  mesh.position.set(cx,y,cz);
  if(ud) Object.assign(mesh.userData,ud);
  grp.add(mesh);
  return mesh;
}

const extGroups={};
function extG(ch){const k=ch.toFixed(4);if(!extGroups[k]){extGroups[k]=new THREE.Group();scene.add(extGroups[k]);}return extGroups[k];}
function mergeGroup(grp){
  const fills=new Map(),lines=new Map(),keep=[];
  for(const o of [...grp.children]){
    if(o.userData.isFurn||o.userData.isSpawn||o.userData.isLabel||o.userData.tag){keep.push(o);continue;}
    if(o.isMesh){
      const k=o.material.uuid;
      if(!fills.has(k))fills.set(k,{mat:o.material,geos:[]});
      const g=o.geometry.clone();o.updateMatrix();g.applyMatrix4(o.matrix);
      fills.get(k).geos.push(g);o.geometry.dispose();
    } else if(o.isLineSegments){
      const k=o.material.uuid;
      if(!lines.has(k))lines.set(k,{mat:o.material,geos:[]});
      const g=o.geometry.clone();o.updateMatrix();g.applyMatrix4(o.matrix);
      lines.get(k).geos.push(g);o.geometry.dispose();
    } else keep.push(o);
  }
  grp.clear();
  for(const o of keep)grp.add(o);
  for(const{mat,geos}of fills.values()){
    if(!geos.length)continue;
    const m=mergeGeometries(geos);geos.forEach(g=>g.dispose());
    if(m)grp.add(new THREE.Mesh(m,mat));
  }
  for(const{mat,geos}of lines.values()){
    if(!geos.length)continue;
    const m=mergeGeometries(geos);geos.forEach(g=>g.dispose());
    if(m)grp.add(new THREE.LineSegments(m,mat));
  }
}

// terrain height lookup
const TH={};
for(const [k,v] of Object.entries(D.terrain_heights||{})) TH[k]=v;
function tY(gx,gy){return (TH[gx+'_'+gy]||0)*3.0;}

// interior scene
if(IS_INT){
  const ceilSet=new Set((D.ceiling_cells||[]).map(c=>c[0]+','+c[1]+','+c[2]));

  const bldInt=new Set((D.building_interiors||[]).map(c=>c[0]+','+c[1]+','+c[2]));
  const stairElev={};
  for(const c of (D.stair_cells||[])) stairElev[c[0]+','+c[1]+','+c[2]]=c[3];
  const stFootprint=new Set(Object.keys(stairElev));

  for(const cell of (D.building_interiors||[])){
    const [gx,gy,fn]=cell;
    if(stFootprint.has(gx+','+gy+','+fn)) continue;
    const ey=floorElev(fn);
    const grp=fGrps[fn]||base;
    addBox(grp,gx,ey-.04,gy,1,.04,1,M.floor,null);
  }

  const wallPosSet=new Set((D.obstacles||[]).filter(o=>o.cell_type==='wall').map(o=>o.x+','+o.y+','+o.floor));

  // stair treads drawn at their interpolated elevation
  for(const c of (D.stair_cells||[])){
    const [gx,gy,fn,ev]=c;
    const prev=stairElev[gx+','+(gy-1)+','+fn];
    const low=(prev===undefined)?ev-0.14:Math.min(ev,prev);
    const th=Math.max(0.14,ev-low);
    addBox(fGrps[fn]||base,gx,ev-th,gy,1,th,1,M.stO,M.stOE);
  }

  // drop link sources: balcony edges and broken shell windows
  for(const dl of (D.drop_links||[])){
    const dey=floorElev(dl.floor);
    const cone=new THREE.Mesh(new THREE.ConeGeometry(.22,.5,4),dl.kind==='window'?M.dropW:M.dropB);
    cone.position.set(dl.x+.5,dey+.35,dl.y+.5);
    cone.userData.tag='drop '+dl.kind+' ('+dl.x+','+dl.y+') F'+dl.floor+' -> ('+dl.tx+','+dl.ty+') F0 paces='+dl.paces;
    (fGrps[dl.floor]||base).add(cone);
    hoverMeshes.push(cone);
  }

  // room labels
  for(const r of (D.rooms||[])){
    const fi=fNums.indexOf(r.floor);
    if(fi<0) continue;
    const ey=floorElev(r.floor);
    const canvas=document.createElement('canvas');
    canvas.width=512;canvas.height=64;
    const ctx=canvas.getContext('2d');
    ctx.clearRect(0,0,512,64);
    ctx.font='bold 26px monospace';
    ctx.fillStyle='rgba(150,150,185,0.9)';
    ctx.textAlign='center';
    ctx.textBaseline='middle';
    ctx.fillText(r.name,256,32);
    const tex=new THREE.CanvasTexture(canvas);
    const lmat=new THREE.MeshBasicMaterial({map:tex,transparent:true,side:THREE.DoubleSide,depthWrite:false});
    const plane=new THREE.Mesh(new THREE.PlaneGeometry(r.w*.85,.55),lmat);
    plane.rotation.x=-Math.PI*.5;
    plane.position.set(r.x+r.w*.5,ey+.1,r.y+r.h*.5);
    const grp=fGrps[r.floor]||base;
    grp.add(plane);
    allLabMeshes.push(plane);
    plane.userData.isLabel=true;
  }
}

// exterior scene
if(!IS_INT){
  addPlane(base,W*.5,.02,L*.5,W,L,M.ground);

  for(const [gx,gy] of (D.jagged_cells||[])){
    addBox(base,gx,.0,gy,1,.3,1,M.jagg,M.jaggE);
  }
  for(const [gx,gy] of (D.building_interiors||[])){
    addBox(base,gx,-.02,gy,1,.04,1,M.floor,M.floorE);
  }
  for(const b of (D.buildings||[])){
    addBox(extG(2.5),b.x,0,b.y,b.w,2.5,b.h,M.bldg,M.bldgE);
  }
  for(const [k,v] of Object.entries(TH)){
    const[sx,sy]=k.split('_').map(Number);
    const h=v*3.0;
    if(Math.abs(h)<.08) continue;
    const yb=h<0?h:0;
    const ch=Math.abs(h);
    addBox(extG(ch),sx,yb,sy,1,ch+.1,1,M.outd,M.outdE);
  }
}

// spawn zones (both)
function drawSpawn(cells,mat){
  for(const [gx,gy] of (cells||[])){
    if(IS_INT){
      // spawn floor is the lowest key in D.floors
      const fn=Object.keys(D.floors||{}).map(Number).sort((a,b)=>a-b)[0]||0;
      const sm=addPlane(fGrps[fn]||base,gx+.5,floorElev(fn)+.05,gy+.5,1,1,mat);
      allSpawnMeshes.push(sm);sm.userData.isSpawn=true;
    } else addPlane(spawnGrp,gx+.5,tY(gx,gy)+.05,gy+.5,1,1,mat);
  }
}
drawSpawn(D.spawn_a,M.spawnA);
drawSpawn(D.spawn_b,M.spawnB);

// obstacles
const stairwellXSet=new Set((D.stairwell_cells||[]).map(c=>c[0]+','+c[2]));
for(const obs of (D.obstacles||[])){
  const{x:gx,y:gy,floor:ofn,cell_type:ct,orient:ori,name:on,type:ot}=obs;
  let grp,bx=gx,bz=gy,by;
  const isFurn=(ot==='furniture');
  if(IS_INT){
    by=floorElev(ofn);
    grp=fGrps[ofn]||base;
  } else {
    by=tY(gx,gy);
    grp=isFurn?furnGrp:base;
  }
  const sz=obs.size_z||1.0;
  const roomH=IS_INT?FH:(sz/3.0)*2.5;
  const wH=IS_INT?FH:roomH;
  const oh=Math.max(0.3,sz*0.5);
  const furnH=Math.min(oh,IS_INT?FH-0.2:1.5);
  const rawX=obs.pw||obs.size_x||1.0,rawY=obs.ph||obs.size_y||1.0;
  const fsx=Math.max(0.2,rawX-0.1);
  const fsy=Math.max(0.2,rawY-0.1);
  const fox=0.05;
  const foy=0.05;
  const DH=Math.min(2,FH*0.7);

  const fud=isFurn?{isFurn:true}:undefined;
  if(ct==='wall'){
    if(IS_INT&&stairwellXSet.has(gx+','+ofn)&&gy>=TOP_Y+1&&gy<=BOT_Y-1) continue;
    const wallH=wH-0.05;
    addBox(grp,bx+.01,by,bz+.01,.98,wallH,.98,M.wall,M.wallE);
  } else if(ct==='window'){
    const brk=!!obs.broken;
    const gM=brk?M.glassB:M.glass, gE=brk?M.glassBE:M.glassE;
    const gud=brk?{tag:'window ('+gx+','+gy+') F'+ofn+' broken'}:null;
    addBox(grp,bx,by,bz,1,wH*.25,1,M.wall,M.wallE);
    addBox(grp,bx,by+wH*.75,bz,1,wH*.25-0.05,1,M.wall,M.wallE);
    const gmesh=(ori==='v')
      ?addBox(grp,bx+.44,by+wH*.25,bz+.05,.12,wH*.5,.9,gM,gE,gud)
      :addBox(grp,bx+.05,by+wH*.25,bz+.44,.9,wH*.5,.12,gM,gE,gud);
    if(brk) hoverMeshes.push(gmesh);
  } else if(ct==='door'){
    addBox(grp,bx,by-.02,bz,1,.04,1,M.floor,null);
    if(ori==='h'){
      addBox(grp,bx+.04,by,bz,.15,DH,1,M.door,M.doorE);
      addBox(grp,bx+.81,by,bz,.15,DH,1,M.door,M.doorE);
      addBox(grp,bx+.04,by+DH,bz,.92,.15,1,M.door,M.doorE);
    } else {
      addBox(grp,bx,by,bz+.04,1,DH,.15,M.door,M.doorE);
      addBox(grp,bx,by,bz+.81,1,DH,.15,M.door,M.doorE);
      addBox(grp,bx,by+DH,bz+.04,1,.15,.92,M.door,M.doorE);
    }
    addBox(grp,bx+.01,by+DH+.15,bz+.01,.98,wH-DH-0.2,.98,M.wall,M.wallE);
  } else if(ct==='stairs'||on.includes('stair')){
    if(!IS_INT){
      const ns=Math.max(2,Math.round(FH));
      const sd=1.0/ns;
      const sh=1.0/ns;
      for(let si=0;si<ns;si++){addBox(grp,bx,by,bz+si*sd,1,(si+1)*sh,sd,M.stO,M.stOE);}
    }
  } else if(on.includes('pillar')){
    addBox(grp,bx+.35,by,bz+.35,.3,roomH,.3,M.pill,M.pillE);
  } else if(on.includes('table')){
    addBox(grp,bx+fox,by,bz+foy,fsx,furnH,fsy,M.tabl,M.tablE,fud);
  } else if(on.includes('bench')||on.includes('stool')||on.includes('chair')){
    addBox(grp,bx+fox,by,bz+foy,fsx,furnH*0.75,fsy,M.chair,null,fud);
  } else if(ct==='fence'){
    if(ori==='v') addBox(grp,bx+.4,by,bz,.2,.6,1,M.fence,M.fenceE);
    else          addBox(grp,bx,by,bz+.4,1,.6,.2,M.fence,M.fenceE);
  } else if(ot==='vegetation'){
    const tg=new THREE.CylinderGeometry(.1,.15,.8,5);
    const tr=new THREE.Mesh(tg,M.veg);
    tr.position.set(bx+.5,by+.4,bz+.5);
    if(isFurn) tr.userData.isFurn=true;
    grp.add(tr);
    const cg=new THREE.SphereGeometry(.45,6,4);
    const cr=new THREE.Mesh(cg,M.veg);
    cr.position.set(bx+.5,by+1.1,bz+.5);
    if(isFurn) cr.userData.isFurn=true;
    grp.add(cr);
  } else if(ot==='terrain'){
    addBox(IS_INT?grp:extG(oh),bx+.1,by,bz+.1,.8,oh,.8,M.terr,M.terrE);
  } else {
    addBox(grp,bx+fox,by,bz+foy,fsx,isFurn?furnH:oh,fsy,M.furn,M.furnE,isFurn?{isFurn:true}:undefined);
  }
  if(on && ct!=='wall' && ct!=='door' && ct!=='fence'){
    const lc=document.createElement('canvas');
    lc.width=256;lc.height=28;
    const lctx=lc.getContext('2d');
    lctx.clearRect(0,0,256,28);
    lctx.font='bold 13px monospace';
    lctx.fillStyle='rgba(255,255,200,0.95)';
    lctx.textAlign='center';
    lctx.textBaseline='middle';
    lctx.fillText(on.replace(/\\b\\w/g,c=>c.toUpperCase()),128,14);
    const ltex=new THREE.CanvasTexture(lc);
    const lp=new THREE.Mesh(new THREE.PlaneGeometry(Math.max(rawX,1)*0.85,0.3),new THREE.MeshBasicMaterial({map:ltex,transparent:true,side:THREE.DoubleSide,depthWrite:false}));
    lp.rotation.x=-Math.PI*.5;
    lp.position.set(bx+rawX*0.5,by+Math.max(oh,0.4)+0.06,bz+rawY*0.5);
    lp.userData.isLabel=true;
    if(isFurn) lp.userData.isFurn=true;
    grp.add(lp);
    allLabMeshes.push(lp);
  }
}
if(IS_INT){for(const fn of fNums)mergeGroup(fGrps[fn]);}
else{mergeGroup(base);mergeGroup(spawnGrp);for(const grp of Object.values(extGroups))mergeGroup(grp);}
// ui
const slider=document.getElementById('floor-slider');
const floorLbl=document.getElementById('floor-label');

let extMaxH=1;
if(!IS_INT){
  for(const v of Object.values(TH)) if(Math.abs(v*3)>extMaxH) extMaxH=Math.abs(v*3);
}

function applySlider(){
  const v=parseInt(slider.value);
  if(IS_INT){
    for(let i=0;i<fNums.length;i++) fGrps[fNums[i]].visible=(i<=v);
    floorLbl.textContent=v>=fNums.length-1?'ALL':'F'+fNums[v];
  } else {
    const cut=v/10*extMaxH;
    for(const[k,grp]of Object.entries(extGroups)){
      grp.visible=(parseFloat(k)<=cut+.01);
    }
    floorLbl.textContent=v>=10?'ALL':cut.toFixed(1)+'u';
  }
}
slider.addEventListener('input',applySlider);

document.getElementById('chk-spawn').addEventListener('change',e=>{
  if(IS_INT){allSpawnMeshes.forEach(m=>m.visible=e.target.checked);}
  else{spawnGrp.visible=e.target.checked;}
});
document.getElementById('chk-furn').addEventListener('change',e=>{
  if(IS_INT){scene.traverse(o=>{if(o.userData.isFurn) o.visible=e.target.checked;});}
  else{furnGrp.visible=e.target.checked;}
});
document.getElementById('chk-labels').addEventListener('change',e=>{
  allLabMeshes.forEach(m=>m.visible=e.target.checked);
});

window.addEventListener('resize',()=>{
  const w=innerWidth-PANEL;
  renderer.setSize(w,innerHeight);
  cam.aspect=w/innerHeight;
  cam.updateProjectionMatrix();
});

const ray=new THREE.Raycaster();
const ptr=new THREE.Vector2();
const infoEl=document.getElementById('info');
const INFO_BASE=infoEl.textContent;
renderer.domElement.addEventListener('pointermove',ev=>{
  if(!hoverMeshes.length) return;
  ptr.x=(ev.clientX/(innerWidth-PANEL))*2-1;
  ptr.y=-(ev.clientY/innerHeight)*2+1;
  ray.setFromCamera(ptr,cam);
  const hit=ray.intersectObjects(hoverMeshes,false)[0];
  infoEl.textContent=hit?(INFO_BASE+'  |  '+hit.object.userData.tag):INFO_BASE;
});

(function animate(){requestAnimationFrame(animate);controls.update();renderer.render(scene,cam);})();
</script>
</body>
</html>"""
