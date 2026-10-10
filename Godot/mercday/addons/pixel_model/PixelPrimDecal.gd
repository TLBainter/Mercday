@tool
class_name PixelPrimDecal extends PixelPrim

#Decal (MC:1174): one top quad just above the kit ground, ignoring the part y and h.

const LIFT: float = 0.08


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	var pts: Array[Vector3] = quad4(Vector3(x0, LIFT, zn), Vector3(x0, LIFT, zs), Vector3(x1, LIFT, zn), Vector3(x1, LIFT, zs))
	face(b, p, "top", 0, pts, false)
