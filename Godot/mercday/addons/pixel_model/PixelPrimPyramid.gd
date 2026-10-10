@tool
class_name PixelPrimPyramid extends PixelPrim

#Pyramid (MC:1187-1188): four triangle faces with the apex used twice per face.


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	var a: Vector3 = Vector3(cx, y1, cz)
	face(b, p, "s", 5, quad4(a, Vector3(x0, y0, zs), a, Vector3(x1, y0, zs)), true)
	face(b, p, "n", 4, quad4(a, Vector3(x1, y0, zn), a, Vector3(x0, y0, zn)), true)
	face(b, p, "l", 2, quad4(a, Vector3(x0, y0, zn), a, Vector3(x0, y0, zs)), true)
	face(b, p, "r", 3, quad4(a, Vector3(x1, y0, zs), a, Vector3(x1, y0, zn)), true)
