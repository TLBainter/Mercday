@tool
class_name MapConst extends RefCounted
#Every map constant the bake steps and the runtime read; values from plan section 7 and the budgets in section 8.
#Units: image px on the 5696x2960 source, map px = image px - (PAD_L, PAD_T), 1 map px = 1 km = 1 world unit.

const PAD_L: int = 800
const PAD_T: int = 500
const PAD_R: int = 800
const PAD_B: int = 300
const IMG_W: int = 5696
const IMG_H: int = 2960
const PLAY_W: int = 4096
const PLAY_H: int = 2160
const PLAY_RECT: Rect2i = Rect2i(800, 500, 4096, 2160)
const WORLD_PER_PX: float = 1.0

const BLOCK_PX: int = 2
const CHUNK_BLOCKS: int = 128
const CHUNK_PX: int = 256
const CHUNKS_X: int = 23
const CHUNKS_Y: int = 12
const BLOCKS_X: int = 2848
const BLOCKS_Y: int = 1480

const SEA_GRAY: int = 77
const TERRACE: float = 10.5 / 255.0
const WATER_H: float = 77.0 / 255.0
const SEA_BED: float = WATER_H - 0.06
const HEIGHT_SCALE: float = 160.0
const TR_CARVE: float = 0.15
const POND: float = 0.3
#Level codes in block_level: 0 sea bed, 1 water, 2 the 8 terrace river floor, 3 shore, n >= 4 is (n + 5) terraces.
const LEVEL_SEA: int = 0
const LEVEL_WATER: int = 1
const LEVEL_RIVER_FLOOR: int = 2
const LEVEL_SHORE: int = 3
const LEVEL_TERRACE_OFFSET: int = 5
const RIVER_FLOOR_TERRACES: int = 8
const LEVEL_COUNT: int = 20
const POND_BIT := 128

const FACE_TOP: float = 1.0
const FACE_S: float = 0.62
const FACE_W: float = 0.78
const FACE_E: float = 0.50
const FACE_N: float = 0.45
const WATER_SIDE: float = 0.8
const OFF_MAP_FRAME: float = 20000.0
const FAR_PLANE: float = 30000.0
const DEEP_SEA: Color = Color("#263e62")

const RENDER_SIZE: Vector2i = Vector2i(640, 322)
const BAND_SIZE: Vector2i = Vector2i(1280, 644)
const GRID: int = 4
const CAM_BLUR: int = 24
const CAM_BLUR_PASSES: int = 3
const CAM_HEIGHT: float = 520.0
const CAM_PITCH_DEG: float = 55.0
const CAM_FOV: float = 40.0
const CAM_SMOOTH_S: float = 0.9
const ZOOM_MIN: float = 1.0
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.25
const ZOOM_DEFAULT: float = 1.5
const ZOOM_RATE: float = 9.0
const ZOOM_SNAP: float = 0.001
const WHEEL_STEP_ACCUM: float = 60.0
#Fly duration is clamp(FLY_BASE_S + dist / FLY_PX_PER_S, FLY_MIN_S, FLY_MAX_S), eased in-out cubic.
const FLY_BASE_S: float = 0.5
const FLY_PX_PER_S: float = 2500.0
const FLY_MIN_S: float = 0.6
const FLY_MAX_S: float = 1.6

const LIFT: float = 10.0
const LIFT_MS: int = 140
const DIM: float = 0.25
const DIM_MS: int = 450
const ISLET_MIN_BLOCKS: int = 400
const ISLET_FRAC: float = 0.03
const DF_CLAMP: int = 16
#Rim core is 1 - smoothstep(RIM_CORE_LO, RIM_CORE_HI, d); glow is exp(-RIM_GLOW_K * d); d in field texels (2 map px).
const RIM_CORE_LO: float = 0.3
const RIM_CORE_HI: float = 1.0
const RIM_GLOW_K: float = 0.9
#Rim on side faces is RIM_SIDE_BASE + RIM_SIDE_SHADE * face shade.
const RIM_SIDE_BASE: float = 0.55
const RIM_SIDE_SHADE: float = 0.45
const SETTLEMENT_TINT: Color = Color("#f28c28")
const SETTLEMENT_TINT_MIX: float = 0.42
const SETTLEMENT_TINT_GAIN: float = 1.12
const POPUP_MS: int = 160

const TEXEL_K: float = 1.4
const TEXEL_KY: float = 1.6
const LATHE_SEGMENTS: int = 12

const NIGHT_MUL: Vector3 = Vector3(0.30, 0.34, 0.55)
const NIGHT_DIRTY_STEP: float = 1.0 / 64.0
#Rim and glow colours per nation live in MapNations.
const GLOW_CRATER_PX: float = 260.0
const LIGHT_ALPHA_MIN: float = 0.5
const FIRE_FRAMES: int = 4
const FIRE_W: int = 5
const FIRE_H: int = 8
const FIRE_FPS: int = 6
#Full night from NIGHT_START_MIN to NIGHT_END_MIN (minute of day) with linear ramps of NIGHT_RAMP_MIN either side.
const NIGHT_START_MIN: int = 21 * 60
const NIGHT_END_MIN: int = 5 * 60
const NIGHT_RAMP_MIN: int = 120

const MODE_FOOT: int = 1
const MODE_CARAVAN: int = 2
const MODE_TRAIN: int = 4
const CURVE_BAKE_INTERVAL: float = 4.0
const ROUTE_PAIR_RADIUS: float = 520.0
const ROUTE_PAIR_COUNT: int = 2

const LABEL_LEAD: int = 10
const LABEL_TITLE: int = 20
const LABEL_REGION_SEA: int = 14
const LABEL_REGION_RIVER: int = 9
const LABEL_REGION_OTHER: int = 11
const LABEL_POI: int = 10
const LABEL_POI_HOVER: int = 13
const LABEL_REGION_HOVER_ADD: int = 4
const TOOLTIP_TOP_MIN: int = 84

const LAT0_DEG: float = 45.0
const LON0_DEG: float = 100.0
const PLANET_FRACTION: float = 1.0 / 3.0
const TERRAIN_CHUNK_VERTS: int = 60000
const PROPS_CHUNK_VERTS: int = 40000
const GROUND_CHUNK_VERTS: int = 500000
const STRUCT_CHUNK_VERTS: int = 20000
const TERRAIN_TOTAL_VERTS: int = 2000000
const BAKED_CAP_BYTES: int = 268435456
const DRAW_CALLS_MAX: int = 120
const CENSUS_TOLERANCE: float = 0.05
