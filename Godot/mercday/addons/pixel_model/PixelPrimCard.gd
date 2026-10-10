@tool
class_name PixelPrimCard extends PixelPrim

#Card (MC:1173): one upright front quad through the part centre.


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	face(b, p, "front", 0, quad4(Vector3(x0, y1, cz), Vector3(x0, y0, cz), Vector3(x1, y1, cz), Vector3(x1, y0, cz)), false)
