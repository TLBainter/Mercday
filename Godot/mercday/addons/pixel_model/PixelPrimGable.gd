@tool
class_name PixelPrimGable extends PixelPrim

#Gable roof (MC:1177-1179): ridge along x at cz; end faces inset 1 unit and split as triangles.


func emit(p: PixelPart, model_w: float, b: PixelMeshBuilder) -> void:
	setup(p, model_w, b)
	var zc: float = cz
	face(b, p, "s", 5, quad4(Vector3(x0, y1, zc), Vector3(x0, y0, zs), Vector3(x1, y1, zc), Vector3(x1, y0, zs)), false)
	face(b, p, "n", 4, quad4(Vector3(x1, y1, zc), Vector3(x1, y0, zn), Vector3(x0, y1, zc), Vector3(x0, y0, zn)), false)
	var lx: float = wx(p.x - p.w / 2.0 + 1.0)
	var rx: float = wx(p.x + p.w / 2.0 - 1.0)
	var gzn: float = wz(p.z + p.d / 2.0 - 1.0)
	var gzs: float = wz(p.z - p.d / 2.0 + 1.0)
	face(b, p, "l", 2, quad4(Vector3(lx, y1, zc), Vector3(lx, y0, gzn), Vector3(lx, y1, zc), Vector3(lx, y0, gzs)), true)
	face(b, p, "r", 3, quad4(Vector3(rx, y1, zc), Vector3(rx, y0, gzs), Vector3(rx, y1, zc), Vector3(rx, y0, gzn)), true)
