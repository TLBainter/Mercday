@tool
class_name PixelPrimBox extends PixelPrim

#Box (MC:1175-1176): top, front, left and right; no back and no bottom.


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	face(b, p, "top", 0, quad4(Vector3(x0, y1, zn), Vector3(x0, y1, zs), Vector3(x1, y1, zn), Vector3(x1, y1, zs)), false)
	face(b, p, "front", 1, quad4(Vector3(x0, y1, zs), Vector3(x0, y0, zs), Vector3(x1, y1, zs), Vector3(x1, y0, zs)), false)
	face(b, p, "left", 2, quad4(Vector3(x0, y1, zn), Vector3(x0, y0, zn), Vector3(x0, y1, zs), Vector3(x0, y0, zs)), false)
	face(b, p, "right", 3, quad4(Vector3(x1, y1, zs), Vector3(x1, y0, zs), Vector3(x1, y1, zn), Vector3(x1, y0, zn)), false)
