class_name ViewerTemplate


static func text() -> String:
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
    <div class="section" id="sec-floor">FLOOR</div>
    <div class="slider-wrap" id="floor-wrap">
      <span id="floor-label">ALL</span>
      <input type="range" id="floor-slider" min="0" max="{{SLIDER_MAX}}" value="{{SLIDER_MAX}}" step="1">
    </div>
    <div class="section">SHOW</div>
    <label class="chk-row"><input type="checkbox" id="chk-spawn" checked> Spawn Zones</label>
    <label class="chk-row"><input type="checkbox" id="chk-furn" checked> Furniture</label>
    <label class="chk-row"><input type="checkbox" id="chk-labels" checked> Labels</label>
    <label class="chk-row" id="row-ceil" style="display:none"><input type="checkbox" id="chk-ceil" checked> Ceiling</label>
    <label class="chk-row" id="row-lots" style="display:none"><input type="checkbox" id="chk-lots" checked> Lots</label>
    <label class="chk-row" id="row-cityobj" style="display:none"><input type="checkbox" id="chk-cityobj" checked> Street Objects</label>
    <label class="chk-row" id="row-roofs" style="display:none"><input type="checkbox" id="chk-roofs" checked> Roofs</label>
    <label class="chk-row" id="row-explode"><input type="checkbox" id="chk-explode"{{EXPLODE_ON}}> Explode floors</label>
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
const W=D.width, L=D.length, IS_INT=D.is_interior, IS_CAV=!!D.is_cavern;
const FH=D.floor_height||5, FD=IS_INT?(D.floor_depth||20):0;
const TOP_Y=IS_INT?(D.top_y||3):0, BOT_Y=TOP_Y+FD+1;
const PANEL=160;
const CITY=D.city||null, BLD=D.bld||null, BOWN=D.bld_owner||null;

// floors: floor_num -> elevation in cells above ground
const fEntries=Object.entries(D.floors||{}).map(([k,v])=>[parseInt(k),parseInt(v)]).sort((a,b)=>a[0]-b[0]);
const fNums=fEntries.map(e=>e[0]);
const fElev=Object.fromEntries(fEntries);
const NF=fNums.length;
const UNIT=1.0;

function floorElev(fn){return (fElev[fn]||0)*UNIT;}

// a floor number resolves against the planes of the building that owns the cell, else the map-wide table
const BLDP={};
if(BLD) for(const b of BLD) BLDP[b.id]=b;
function bOwn(gx,gy){return (BOWN&&gx>=0&&gy>=0&&gx<W&&gy<L)?BOWN[gy*W+gx]:-1;}
function fY(fn,gx,gy){
  const b=BLDP[bOwn(gx,gy)];
  if(b!==undefined){const v=b.planes[fn];if(v!==undefined) return v*UNIT;}
  return floorElev(fn);
}
function fH(gx,gy){const b=BLDP[bOwn(gx,gy)];return b!==undefined?b.fh:FH;}
const GY=CITY?floorElev(0):0;

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
function cavTop(){let b=6;for(const v of Object.values(D.cavern_ceiling||{})) if(v>b) b=v; return b+4;}
const totH=IS_INT?(maxElev+FH+4):(IS_CAV?cavTop():10);
const cam=new THREE.PerspectiveCamera(45,(innerWidth-PANEL)/innerHeight,0.1,3000);
const controls=new OrbitControls(cam,renderer.domElement);
function resetCam(){
  cam.position.set(CX+W*0.9,totH*1.1+4,CZ+L*0.9);
  controls.target.set(CX,(IS_INT||IS_CAV)?totH*0.4:1,CZ);
  controls.update();
}
window.resetCam=resetCam;
resetCam();

scene.add(new THREE.AmbientLight(0xffffff,0.9));

// groups
const spawnGrp=new THREE.Group(), furnGrp=new THREE.Group(), roofGrp=new THREE.Group();
scene.add(spawnGrp,furnGrp,roofGrp);
const cityGrp=new THREE.Group(), lotGrp=new THREE.Group(), cityObjGrp=new THREE.Group();
scene.add(cityGrp,lotGrp,cityObjGrp);
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
function vm(op){return new THREE.MeshBasicMaterial({vertexColors:true,transparent:op<1,opacity:op,side:THREE.DoubleSide,depthWrite:op>0.5});}
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
  cavF:m(0x9a8f78,.95),cavFE:lm(0x6a6050),
  roof:m(0xc8c8c8,.35),
  roofTile:vm(.92),roofCap:vm(.95),roofCapB:m(0x7a3e22,.95),
  roofFlat:m(0x8c8c84,.90),roofSolid:m(0xa89878,.92),roofSolidE:lm(0x6a5c44),
  roofGab:m(0xd8d4c4,.88),roofAwn:m(0xc0a060,.85),
  roofObjS:m(0x9a9288,.95),roofObjSE:lm(0x585048),
  roofObjW:m(0xa07840,.95),roofObjWE:lm(0x5c4020),
  rock:m(0x6a6058,.45),rockE:lm(0x3a342c),
  water:m(0x2a6ac8,.40),wbed:m(0x10305a,.75),
  pwall:m(0x7c7060,.95),
  entr:m(0x30c060,.55),entrE:lm(0x0c8030),
  stal:m(0x9a9080,.90),
  rubble:m(0x7a6a58,.95),rubbleE:lm(0x3a3028),
  bars:m(0x6c7480,.70),barsE:lm(0x3c4450),
  locked:m(0xc84040,.85),lockedE:lm(0x802020),
  hall:m(0x707a92,.25),
  sMain:m(0x4a4a4a,.95),sSide:m(0x6a6a66,.95),
  sWalk:m(0x9c9c94,.95),sWalkE:lm(0x6e6e66),
  sAly:m(0x7a6a56,.95),sAlyE:lm(0x50443a),
  sLot:m(0xd6c69e,.95),sNat:m(0x5a8a3a,.95),lotL:lm(0xe08020),
  lotF:lm(0xe03030),grass:m(0x6aa83a,.9),spwA:m(0x3058c8,.9),spwB:m(0x38a048,.9),
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

function addRectLine(grp,x,y,z,sx,sz,mat){
  const p=[new THREE.Vector3(x,y,z),new THREE.Vector3(x+sx,y,z),new THREE.Vector3(x+sx,y,z+sz),
    new THREE.Vector3(x,y,z+sz),new THREE.Vector3(x,y,z)];
  const ln=new THREE.Line(new THREE.BufferGeometry().setFromPoints(p),mat);
  grp.add(ln);
  return ln;
}

function addLabel(grp,px,py,pz,sx,sz,text,col,font,cw,chh,extra){
  const cv=document.createElement('canvas');
  cv.width=cw||512;cv.height=chh||64;
  const cc=cv.getContext('2d');
  cc.clearRect(0,0,cv.width,cv.height);
  cc.font=font||'bold 26px monospace';
  cc.fillStyle=col;
  cc.textAlign='center';
  cc.textBaseline='middle';
  cc.fillText(text,cv.width*.5,cv.height*.5);
  const tex=new THREE.CanvasTexture(cv);
  const lmat=new THREE.MeshBasicMaterial({map:tex,transparent:true,side:THREE.DoubleSide,depthWrite:false});
  const plane=new THREE.Mesh(new THREE.PlaneGeometry(sx,sz),lmat);
  plane.rotation.x=-Math.PI*.5;
  plane.position.set(px,py,pz);
  plane.userData.isLabel=true;
  if(extra) Object.assign(plane.userData,extra);
  grp.add(plane);
  allLabMeshes.push(plane);
  return plane;
}

function addPoolWall(gx,gy,dx,dy,y0,y1){
  const h=y1-y0;
  if(h<=0.01) return;
  const g=new THREE.PlaneGeometry(1,h);
  const mesh=new THREE.Mesh(g,M.pwall);
  const ln=new THREE.LineSegments(new THREE.EdgesGeometry(g),M.rockE);
  const cx=dx===0?gx+.5:(dx>0?gx+1:gx);
  const cz=dy===0?gy+.5:(dy>0?gy+1:gy);
  for(const o of [mesh,ln]){
    o.position.set(cx,y0+h*.5,cz);
    if(dx!==0) o.rotation.y=Math.PI/2;
    base.add(o);
  }
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
function tY(gx,gy){return (TH[gx+'_'+gy]||0);}

// cavern lookups: absolute ceiling, pool depth, rock
const CEIL=D.cavern_ceiling||{}, WAT=D.water_cells||{};
const ROCK=new Set((D.rock_cells||[]).map(c=>c[0]+'_'+c[1]));
function maxAdjC(gx,gy){
  let best=null;
  for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){
    const v=CEIL[(gx+dx)+'_'+(gy+dy)];
    if(v!==undefined&&(best===null||v>best)) best=v;
  }
  return best;
}
function drawHanging(obs){
  const low=CEIL[obs.x+'_'+obs.y];
  if(low===undefined) return;
  const h=Math.max(0.5,obs.height||2);
  const cone=new THREE.Mesh(new THREE.ConeGeometry(.3,h,5),M.stal);
  cone.rotation.x=Math.PI;
  cone.position.set(obs.x+.5,low+h*.5,obs.y+.5);
  base.add(cone);
}

// the stair run cells: every floor slab and every city lot cell leaves the level 0 ones open
const stairElev={};
for(const c of (D.stair_cells||[])) stairElev[c[0]+','+c[1]+','+c[2]]=c[3];
const stFootprint=new Set(Object.keys(stairElev));

// interior scene
if(IS_INT){
  for(const cell of (D.building_interiors||[])){
    const [gx,gy,fn]=cell;
    if(stFootprint.has(gx+','+gy+','+fn)) continue;
    const ey=fY(fn,gx,gy);
    const grp=fGrps[fn]||base;
    addBox(grp,gx,ey-.04,gy,1,.04,1,M.floor,null);
  }

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
    const dey=fY(dl.floor,dl.x,dl.y);
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
    const ey=fY(r.floor,r.x,r.y);
    addLabel(fGrps[r.floor]||base,r.x+r.w*.5,ey+.1,r.y+r.h*.5,r.w*.85,.55,
      r.name,'rgba(150,150,185,0.9)');
  }

  // dungeon hall plates
  for(const h of (D.halls||[])){
    const grp=fGrps[h.floor]||base;
    const ey=fY(h.floor,h.x,h.y);
    const pl=addPlane(grp,h.x+h.w*.5,ey+.03,h.y+h.h*.5,h.w,h.h,M.hall);
    if(pl){pl.userData.tag=h.name+' ('+h.x+','+h.y+') F'+h.floor+' '+h.w+'x'+h.h;hoverMeshes.push(pl);}
  }
}

// city surfaces: one flat rect per surface run, sidewalks and alleys raised to the curb
if(CITY){
  const SMAT=[null,M.sMain,M.sSide,M.sWalk,M.sAly,M.sLot,M.sNat];
  for(const r of (CITY.rects||[])){
    const [rx,ry,rw,rh,sf]=r;
    const mat=SMAT[sf];
    if(!mat) continue;
    if(sf===3||sf===4){addBox(cityGrp,rx,GY+.02,ry,rw,.10,rh,mat,sf===3?M.sWalkE:M.sAlyE);continue;}
    if(sf===5){
      // one box per lot cell, at slab height, so a stair down through floor 0 stays open
      for(let ly=ry;ly<ry+rh;ly++) for(let lx=rx;lx<rx+rw;lx++){
        if(stFootprint.has(lx+','+ly+',0')) continue;
        addBox(cityGrp,lx,GY-.04,ly,1,.04,1,mat,null);
      }
      continue;
    }
    addPlane(cityGrp,rx+rw*.5,GY+.02,ry+rh*.5,rw,rh,mat);
  }
  for(const lt of (CITY.lots||[])){
    const [lid,lx,ly,lw,lh,lc,lf]=lt;
    const lotB=(lt.length>8)?lt[8]:-1, lotFail=(lt.length>9)?lt[9]:0;
    addRectLine(lotGrp,lx,GY+.14,ly,lw,lh,lotFail?M.lotF:M.lotL);
    const lotTxt='L'+lid+' '+lc+' '+lf+(lotB>=0?(' B'+lotB):(lotFail?' FAIL':''));
    addLabel(lotGrp,lx+lw*.5,GY+.16,ly+lh*.5,Math.max(lw,4)*.85,.5,lotTxt,lotFail?'rgba(255,170,170,0.95)':'rgba(255,232,170,0.95)');
  }
  mergeGroup(cityGrp);
}

// one label per stamped building
if(BLD){
  for(const b of BLD){
    let top=0;
    for(const k in b.planes){if(b.planes[k]>top) top=b.planes[k];}
    const [bx,bz,bw,bh]=b.rect;
    if(CITY&&b.floors){const topPl=b.planes[b.floors[1]];if(topPl!==undefined) top=topPl;}
    addLabel(base,bx+bw*.5,top+b.fh+1,bz+bh*.5,Math.max(bw,6)*.75,.6,'B'+b.id+' '+b.name,'rgba(255,255,220,0.95)');
  }
}

// roofs: one group per roof level; slopes are custom geometry, flats and blocks are boxes
const ROOFS=D.roofs||null;
const roofGrps={};
const ROOF_EDGES=[[0,-1],[0,1],[-1,0],[1,0]];
let roofsOn=true;

function roofQuad(arr,a,b,c,d){
  arr.push(a[0],a[1],a[2],b[0],b[1],b[2],c[0],c[1],c[2]);
  arr.push(a[0],a[1],a[2],c[0],c[1],c[2],d[0],d[1],d[2]);
}

// every triangle is tinted by the side it faces, so the faces of a hip or gable read apart
function roofShade(arr,col){
  const base=new THREE.Color(col), out=[];
  for(let i=0;i<arr.length;i+=9){
    const ux=arr[i+3]-arr[i],uy=arr[i+4]-arr[i+1],uz=arr[i+5]-arr[i+2];
    const vx=arr[i+6]-arr[i],vy=arr[i+7]-arr[i+1],vz=arr[i+8]-arr[i+2];
    let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;
    const len=Math.hypot(nx,ny,nz)||1;
    if(ny<0){nx=-nx;ny=-ny;nz=-nz;}
    const k=Math.min(1,.62+.38*Math.max(0,(nx*.55+ny*.75+nz*.35)/len));
    for(let j=0;j<3;j++) out.push(base.r*k,base.g*k,base.b*k);
  }
  return out;
}

function roofMesh(grp,arr,mat,tag,col){
  if(!arr.length) return null;
  const g=new THREE.BufferGeometry();
  g.setAttribute('position',new THREE.Float32BufferAttribute(arr,3));
  if(col!==undefined) g.setAttribute('color',new THREE.Float32BufferAttribute(roofShade(arr,col),3));
  const mesh=new THREE.Mesh(g,mat);
  mesh.userData.tag=tag;
  grp.add(mesh);
  hoverMeshes.push(mesh);
  return mesh;
}

function drawRoofPart(r,grp){
  const [rx,rz,rw,rh]=r.rect;
  const PY=r.plane*UNIT;
  const tag='roof '+r.shape+' L'+r.level+(r.bld>=0?' B'+r.bld:'');
  const inP=(cx,cy)=>cx>=0&&cy>=0&&cx<rw&&cy<rh&&r.types[cy*rw+cx]!=='.';
  const vAt=(vx,vy)=>r.vh[vy*(rw+1)+vx]*UNIT;
  const dome=(r.kind==='dome'&&r.dome)?r.dome:null;
  const tile=[],cap=[],gab=[];
  for(let cy=0;cy<rh;cy++) for(let cx=0;cx<rw;cx++){
    const t=r.types[cy*rw+cx];
    if(t==='.') continue;
    const gx=rx+cx, gz=rz+cy;
    const rise=r.rise[cy*rw+cx]*UNIT;
    // a dome cell carries only the flat base slab; the shell itself is one mesh
    if(dome){
      addBox(grp,gx,PY,gz,1,.12,1,M.roofFlat,null);
      continue;
    }
    if(t==='0'){
      addBox(grp,gx,PY,gz,1,.12,1,M.roofFlat,null);
      continue;
    }
    if(t==='3'){
      if(r.kind==='awning'){
        const x0=gx-(inP(cx-1,cy)?0:.3), z0=gz-(inP(cx,cy-1)?0:.3);
        const x1=gx+1+(inP(cx+1,cy)?0:.3), z1=gz+1+(inP(cx,cy+1)?0:.3);
        const y0=PY+r.base*UNIT;
        addBox(grp,x0,y0,z0,x1-x0,Math.max(.04,PY+rise-y0),z1-z0,M.roofAwn,null);
      } else addBox(grp,gx,PY,gz,1,Math.max(.04,rise),1,M.roofSolid,M.roofSolidE);
      continue;
    }
    const h00=vAt(cx,cy),h10=vAt(cx+1,cy),h01=vAt(cx,cy+1),h11=vAt(cx+1,cy+1);
    const p00=[gx,PY+h00,gz],p10=[gx+1,PY+h10,gz],p01=[gx,PY+h01,gz+1],p11=[gx+1,PY+h11,gz+1];
    const arr=(t==='2')?cap:tile;
    // the cell folds along the diagonal that joins its lowest and its highest corner
    if(Math.abs(h10-h01)>Math.abs(h00-h11)) roofQuad(arr,p10,p11,p01,p00);
    else roofQuad(arr,p00,p10,p11,p01);
    const vmax=Math.max(h00,h10,h01,h11);
    if(t==='2'&&rise>vmax+.01) addBox(grp,gx,PY+vmax,gz,1,rise-vmax,1,M.roofCapB,null);
    for(const [ox,oz] of ROOF_EDGES){
      if(inP(cx+ox,cy+oz)) continue;
      let ax,az,bx,bz,ha,hb;
      if(oz<0){ax=gx;az=gz;bx=gx+1;bz=gz;ha=h00;hb=h10;}
      else if(oz>0){ax=gx;az=gz+1;bx=gx+1;bz=gz+1;ha=h01;hb=h11;}
      else if(ox<0){ax=gx;az=gz;bx=gx;bz=gz+1;ha=h00;hb=h01;}
      else {ax=gx+1;az=gz;bx=gx+1;bz=gz+1;ha=h10;hb=h11;}
      if(ha>.005||hb>.005) roofQuad(gab,[ax,PY,az],[bx,PY,bz],[bx,PY+hb,bz],[ax,PY+ha,az]);
      else if(t==='1') roofQuad(tile,[ax,PY,az],[bx,PY,bz],[bx+ox*.3,PY-.075,bz+oz*.3],[ax+ox*.3,PY-.075,az+oz*.3]);
    }
  }
  if(dome) drawDome(grp,dome,PY,tag);
  roofMesh(grp,tile,M.roofTile,tag,0xb4653a);
  roofMesh(grp,cap,M.roofCap,tag,0x7a3e22);
  roofMesh(grp,gab,M.roofGab,tag);
}

// truncated ellipsoid shell plus the flat crown disc units stand on, both over the part base slab
function drawDome(grp,d,PY,tag){
  const hy=Math.max(.01,d.h)*UNIT;
  const t0=Math.acos(Math.min(1,Math.max(0,d.plateau/Math.max(.0001,d.h))));
  const shell=new THREE.Mesh(new THREE.SphereGeometry(1,32,16,0,Math.PI*2,t0,Math.PI/2-t0),M.roofSolid);
  shell.scale.set(d.a,hy,d.b);
  shell.position.set(d.cx,PY,d.cy);
  shell.userData.tag=tag;
  grp.add(shell);
  hoverMeshes.push(shell);
  const rr=Math.sin(t0), cy=PY+d.plateau*UNIT;
  const disc=new THREE.Mesh(new THREE.CircleGeometry(1,32),M.roofFlat);
  disc.rotation.x=-Math.PI/2;
  disc.scale.set(Math.max(.05,d.a*rr),Math.max(.05,d.b*rr),1);
  disc.position.set(d.cx,cy+.01,d.cy);
  disc.userData.tag=tag;
  grp.add(disc);
  hoverMeshes.push(disc);
  const pts=[];
  for(let i=0;i<=32;i++){
    const an=i/32*Math.PI*2;
    pts.push(new THREE.Vector3(d.cx+Math.cos(an)*d.a*rr,cy+.015,d.cy+Math.sin(an)*d.b*rr));
  }
  grp.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts),M.roofSolidE));
}

function roofObjBase(o){
  for(const r of (ROOFS||[])){
    if(r.level!==o.floor) continue;
    const [rx,rz,rw,rh]=r.rect;
    const cx=o.x-rx, cy=o.y-rz;
    if(cx<0||cy<0||cx>=rw||cy>=rh) continue;
    if(r.types[cy*rw+cx]==='.') continue;
    return {y:r.plane*UNIT+r.rise[cy*rw+cx]*UNIT, level:r.level};
  }
  return null;
}

if(ROOFS){
  for(const r of ROOFS){
    let g=roofGrps[r.level];
    if(!g){g=new THREE.Group();roofGrps[r.level]=g;scene.add(g);}
    drawRoofPart(r,g);
  }
  for(const o of (D.obstacles||[])){
    if(o.roof_obj!==1) continue;
    const b=roofObjBase(o);
    if(!b) continue;
    let g=roofGrps[b.level];
    if(!g){g=new THREE.Group();roofGrps[b.level]=g;scene.add(g);}
    const wood=(o.name==='dormer');
    const w=Math.max(1,o.pw||1), d=Math.max(1,o.ph||1);
    const h=Math.max(.2,o.height||o.size_z||1);
    addBox(g,o.x+.1,b.y+.1,o.y+.1,w-.2,h,d-.2,
      wood?M.roofObjW:M.roofObjS,wood?M.roofObjWE:M.roofObjSE);
  }
  for(const k in roofGrps) mergeGroup(roofGrps[k]);
}

// exterior scene
if(!IS_INT&&!IS_CAV&&!CITY){
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
    const h=v;
    if(Math.abs(h)<.08) continue;
    const yb=h<0?h:0;
    const ch=Math.abs(h);
    addBox(extG(ch),sx,yb,sy,1,ch+.1,1,M.outd,M.outdE);
  }
}

// cavern scene
if(IS_CAV){
  const entSet=new Set((D.entrance_cells||[]).map(c=>c[0]+'_'+c[1]));
  const wallSet=new Set((D.obstacles||[]).filter(o=>o.cell_type==='wall').map(o=>o.x+'_'+o.y));
  for(const k of Object.keys(CEIL)){
    if(ROCK.has(k)) continue;
    const[gx,gy]=k.split('_').map(Number);
    const fy=tY(gx,gy);
    const ent=entSet.has(k);
    const wd=WAT[k];
    const wet=wd!==undefined;
    addBox(base,gx,fy-.08,gy,1,.08,1,wet?M.wbed:(ent?M.entr:M.cavF),ent?M.entrE:M.cavFE);
    const cy=CEIL[k];
    if(cy>fy+.05) addPlane(roofGrp,gx+.5,cy,gy+.5,1,1,M.roof);
    if(wet){
      const sy=fy+wd;
      addPlane(base,gx+.5,sy+.06,gy+.5,1,1,M.water);
      for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
        const nk=(gx+dx)+'_'+(gy+dy);
        if(WAT[nk]!==undefined) continue;
        const dry=CEIL[nk]!==undefined&&!ROCK.has(nk);
        addPoolWall(gx,gy,dx,dy,fy,dry?Math.max(sy,tY(gx+dx,gy+dy)):sy);
      }
    }
  }
  for(const [gx,gy] of (D.rock_cells||[])){
    if(!wallSet.has(gx+'_'+gy)) continue;
    const top=maxAdjC(gx,gy);
    addBox(base,gx,0,gy,1,(top===null?2:top),1,M.rock,M.rockE);
  }
  for(const ch of (D.cavern_chambers||[])){
    addLabel(base,ch.x+ch.w*.5,(ch.level+ch.peak_clearance)+.6,ch.y+ch.h*.5,Math.max(ch.w,4)*.85,.6,
      ch.flooded?(ch.name+' d='+ch.depth):ch.name,'rgba(240,236,190,0.95)');
  }
}

// spawn zones (both)
function drawSpawn(cells,mat){
  for(const [gx,gy] of (cells||[])){
    if(CITY){
      // a city spawn zone lies on floor 0 over ground the buildings do not own
      if(bOwn(gx,gy)>=0) continue;
      const cm=addPlane(fGrps[0]||base,gx+.5,fY(0,gx,gy)+.05,gy+.5,1,1,mat);
      allSpawnMeshes.push(cm);cm.userData.isSpawn=true;
    } else if(IS_INT){
      // spawn floor is the lowest key in D.floors
      const fn=Object.keys(D.floors||{}).map(Number).sort((a,b)=>a-b)[0]||0;
      const sm=addPlane(fGrps[fn]||base,gx+.5,fY(fn,gx,gy)+.05,gy+.5,1,1,mat);
      allSpawnMeshes.push(sm);sm.userData.isSpawn=true;
    } else addPlane(spawnGrp,gx+.5,tY(gx,gy)+.05,gy+.5,1,1,mat);
  }
}
drawSpawn(D.spawn_a,M.spawnA);
drawSpawn(D.spawn_b,M.spawnB);

// one marker per team at the city spawn centre
if(CITY){
  const SPW=CITY.spawn||{};
  for(const [spKey,spMat] of [['a',M.spwA],['b',M.spwB]]){
    const spC=SPW[spKey];
    if(!spC) continue;
    const spMk=new THREE.Mesh(new THREE.ConeGeometry(.38,1.3,4),spMat);
    spMk.position.set(spC[0]+.5,fY(0,spC[0],spC[1])+.65,spC[1]+.5);
    spMk.userData.isSpawn=true;
    const spSide=(spKey==='a')?SPW.side_a:SPW.side_b, spOut=(spKey==='a')?SPW.outdoor_a:SPW.outdoor_b;
    spMk.userData.tag='spawn '+spKey.toUpperCase()+' ('+spC[0]+','+spC[1]+') side='+spSide+' outdoor='+spOut;
    (fGrps[0]||base).add(spMk);
    allSpawnMeshes.push(spMk);hoverMeshes.push(spMk);
  }
}

// obstacles
// keyed by the owning building on a city map, so one building's stairwell never opens another's wall
const stairwellXSet=new Set((D.stairwell_cells||[]).map(c=>c[0]+','+c[2]+','+(CITY?bOwn(c[0],c[1]):-1)));

// the stairwell wall band: the owning building's rect on a city map, the map-wide scalars elsewhere
function inStairBand(gx,gy){
  if(CITY){
    const sb=BLDP[bOwn(gx,gy)];
    if(sb===undefined) return false;
    return gy>=sb.rect[1]+1&&gy<=sb.rect[1]+sb.rect[3]-2;
  }
  return gy>=TOP_Y+1&&gy<=BOT_Y-1;
}
for(const obs of (D.obstacles||[])){
  const{x:gx,y:gy,floor:ofn,cell_type:ct,orient:ori,name:on,type:ot}=obs;
  if(obs.roof_obj===1) continue;
  if(IS_CAV){
    if(ct==='wall') continue;
    if(obs.hanging){drawHanging(obs);continue;}
  }
  let grp,bx=gx,bz=gy,by;
  const isFurn=(ot==='furniture');
  if(IS_INT){
    by=fY(ofn,gx,gy);
    grp=fGrps[ofn]||base;
  } else {
    by=tY(gx,gy);
    grp=isFurn?furnGrp:base;
  }
  const cityTag=obs.ct||'';
  const cityBlk=(obs.blk===1);
  if(cityTag!==''&&cityTag!=='nature') grp=cityObjGrp;
  const cFH=fH(gx,gy);
  const sz=obs.size_z||1.0;
  const roomH=IS_INT?cFH:sz;
  const wH=IS_INT?cFH:roomH;
  const oh=Math.max(0.3,sz);
  const furnH=Math.min(oh,IS_INT?cFH-0.2:1.5);
  const rawX=obs.pw||obs.size_x||1.0,rawY=obs.ph||obs.size_y||1.0;
  const fsx=Math.max(0.2,rawX-0.1);
  const fsy=Math.max(0.2,rawY-0.1);
  const fox=0.05;
  const foy=0.05;
  const DH=Math.min(2,cFH*0.7);

  const fud=isFurn?{isFurn:true}:undefined;
  if(ct==='wall'){
    if(IS_INT&&stairwellXSet.has(gx+','+ofn+','+(CITY?bOwn(gx,gy):-1))&&inStairBand(gx,gy)) continue;
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
    const isBar=!!obs.bars;
    const dM=obs.locked?M.locked:(isBar?M.bars:M.door);
    const dE=obs.locked?M.lockedE:(isBar?M.barsE:M.doorE);
    addBox(grp,bx,by-.02,bz,1,.04,1,M.floor,null);
    if(ori==='h'){
      addBox(grp,bx+.04,by,bz,.15,DH,1,dM,dE);
      addBox(grp,bx+.81,by,bz,.15,DH,1,dM,dE);
      addBox(grp,bx+.04,by+DH,bz,.92,.15,1,dM,dE);
      if(isBar){for(let bi=1;bi<5;bi++) addBox(grp,bx+.04+bi*.18,by,bz+.4,.07,DH,.2,dM,dE);}
    } else {
      addBox(grp,bx,by,bz+.04,1,DH,.15,dM,dE);
      addBox(grp,bx,by,bz+.81,1,DH,.15,dM,dE);
      addBox(grp,bx,by+DH,bz+.04,1,.15,.92,dM,dE);
      if(isBar){for(let bi=1;bi<5;bi++) addBox(grp,bx+.4,by,bz+.04+bi*.18,.2,DH,.07,dM,dE);}
    }
    if(obs.locked){
      const lk=addBox(grp,bx+.4,by+DH*.5,bz+.4,.2,.2,.2,M.locked,M.lockedE);
      lk.userData.tag='locked bars ('+gx+','+gy+') F'+ofn+' lock '+obs.lock_d;
      hoverMeshes.push(lk);
    }
    addBox(grp,bx+.01,by+DH+.15,bz+.01,.98,wH-DH-0.2,.98,M.wall,M.wallE);
  } else if(cityTag==='nature'&&!cityBlk){
    addPlane(grp,bx+.5,by+.05,bz+.5,1,1,M.grass);
  } else if(cityTag==='lamp'){
    addBox(grp,bx+.42,by,bz+.42,.15,sz,.15,M.furn,M.furnE);
    addBox(grp,bx+.34,by+sz,bz+.34,.32,.22,.32,M.furn,M.furnE);
  } else if(cityTag!==''&&cityTag!=='nature'){
    addBox(grp,bx,by,bz,rawX,sz,rawY,M.furn,M.furnE);
  } else if(ct==='stairs'||on.includes('stair')){
    if(!IS_INT){
      const ns=Math.max(2,Math.round(cFH));
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
    if(IS_CAV&&obs.rubble) addBox(base,bx,by,bz,1,Math.max(.3,(obs.height||oh)),1,M.rubble,M.rubbleE);
    else if(IS_CAV) addBox(base,bx+.1,by,bz+.1,.8,Math.max(.3,(obs.height||oh)),.8,M.terr,M.terrE);
    else addBox(IS_INT?grp:extG(oh),bx+.1,by,bz+.1,.8,oh,.8,M.terr,M.terrE);
  } else {
    addBox(grp,bx+fox,by,bz+foy,fsx,isFurn?furnH:oh,fsy,M.furn,M.furnE,isFurn?{isFurn:true}:undefined);
  }
  if(on && ct!=='wall' && ct!=='door' && ct!=='fence' && cityTag!=='nature'){
    addLabel(grp,bx+rawX*0.5,by+Math.max(oh,0.4)+0.06,bz+rawY*0.5,Math.max(rawX,1)*0.85,0.3,
      on.replace(/\\b\\w/g,c=>c.toUpperCase()),'rgba(255,255,200,0.95)','bold 13px monospace',256,28,
      isFurn?{isFurn:true}:undefined);
  }
}
if(IS_INT){for(const fn of fNums)mergeGroup(fGrps[fn]);}
else{mergeGroup(base);mergeGroup(spawnGrp);for(const grp of Object.values(extGroups))mergeGroup(grp);}
if(IS_CAV) mergeGroup(roofGrp);
if(CITY) mergeGroup(cityObjGrp);
// ui
const slider=document.getElementById('floor-slider');
const floorLbl=document.getElementById('floor-label');
if(IS_CAV){
  document.getElementById('sec-floor').style.display='none';
  document.getElementById('floor-wrap').style.display='none';
  document.getElementById('row-ceil').style.display='flex';
  document.getElementById('chk-ceil').addEventListener('change',e=>{roofGrp.visible=e.target.checked;});
}
if(CITY){
  document.getElementById('row-lots').style.display='flex';
  document.getElementById('chk-lots').addEventListener('change',e=>{lotGrp.visible=e.target.checked;});
  document.getElementById('row-cityobj').style.display='flex';
  document.getElementById('chk-cityobj').addEventListener('change',e=>{cityObjGrp.visible=e.target.checked;});
}
if(ROOFS){
  document.getElementById('row-roofs').style.display='flex';
  document.getElementById('chk-roofs').addEventListener('change',e=>{roofsOn=e.target.checked;applySlider();});
}

let extMaxH=1;
if(!IS_INT){
  for(const v of Object.values(TH)) if(Math.abs(v)>extMaxH) extMaxH=Math.abs(v);
}

// a roof level follows the floor below it; with the slider at its top every roof shows
function applyRoofVis(v){
  const atMax=(v>=fNums.length-1);
  for(const k in roofGrps){
    const fi=fNums.indexOf(parseInt(k)-1);
    roofGrps[k].visible=roofsOn&&(atMax||(fi>=0&&fi+1<=v));
  }
}

function applySlider(){
  const v=parseInt(slider.value);
  if(ROOFS) applyRoofVis(v);
  if(IS_INT){
    for(let i=0;i<fNums.length;i++) fGrps[fNums[i]].visible=(i<=v);
    floorLbl.textContent=v>=fNums.length-1?('ALL ('+fNums.length+' floors)'):('F'+fNums[v]);
  } else {
    const cut=v/10*extMaxH;
    for(const[k,grp]of Object.entries(extGroups)){
      grp.visible=(parseFloat(k)<=cut+.01);
    }
    floorLbl.textContent=v>=10?'ALL':cut.toFixed(1)+'u';
  }
}
slider.addEventListener('input',applySlider);

const expChk=document.getElementById('chk-explode');
const expRow=document.getElementById('row-explode');
function applyExplode(){
  const on=expChk.checked;
  for(let i=0;i<fNums.length;i++){
    const g=fGrps[fNums[i]];
    if(g) g.position.y=on?i*FH*1.5:0;
  }
  for(const k in roofGrps){
    roofGrps[k].position.y=on?(fNums.indexOf(parseInt(k)-1)+1)*FH*1.5:0;
  }
}
if(IS_INT){expChk.addEventListener('change',applyExplode);applyExplode();applySlider();}
else{expRow.style.display='none';}

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
