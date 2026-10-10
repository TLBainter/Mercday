class_name FloorGeo
extends RefCounted

#Floor geometry of one planned building, shared by every BuildingLayouts pass.
var front: String = "W"
var bld_x: int = 0
var top_y: int = 0
var floor_w: int = 0
var floor_d: int = 0
var ix0: int = 0
var ix1: int = 0
var iy0: int = 0
var iy1: int = 0
var ux0: int = 0
var ux1: int = 0
var band_x0: int = -1
var rows: Vector2i = Vector2i.ZERO
var top_floor: int = 0
var ent_row: int = 0
var street: int = 0
var t0: int = 0
var t1: int = 0
var s_size: int = 0
var used: Dictionary = {}
var t_door: int = -1
