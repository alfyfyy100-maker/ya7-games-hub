extends Node3D
## TerrainMesh — العرض البصري للأرض: ميش واحد مستمر من خريطة الارتفاعات + سطح ماء.
## لا يوجد أي منطق لعبة هنا؛ الشبكة المنطقية (NavGrid) غير مرئية.

const TERRAIN_SHADER: Shader = preload("res://assets/shaders/terrain.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")

var _ground: MeshInstance3D
var _water: MeshInstance3D


func build(map: MapState) -> void:
	for c in get_children():
		c.queue_free()
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = _build_ground_mesh(map)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	_ground.material_override = mat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)

	_water = MeshInstance3D.new()
	_water.name = "Water"
	var plane := PlaneMesh.new()
	var size := map.world_size()
	plane.size = size
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	_water.mesh = plane
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	_water.material_override = wmat
	_water.position = Vector3(size.x * 0.5, GameConfig.WATER_LEVEL + 0.12, size.y * 0.5)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


func _build_ground_mesh(map: MapState) -> ArrayMesh:
	var vw := map.width + 1
	var vh := map.height + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vy in vh:
		for vx in vw:
			var h := map.vertex_height(vx, vy)
			var slope := _vertex_slope(map, vx, vy)
			st.set_color(_color_for(h, slope))
			st.set_uv(Vector2(float(vx) / vw, float(vy) / vh))
			st.add_vertex(Vector3(vx * GameConfig.CELL_SIZE, h, vy * GameConfig.CELL_SIZE))
	for y in map.height:
		for x in map.width:
			var i := y * vw + x
			# نقسم المربع على القطر الأقصر لتلال أنعم
			var h00 := map.vertex_height(x, y)
			var h10 := map.vertex_height(x + 1, y)
			var h01 := map.vertex_height(x, y + 1)
			var h11 := map.vertex_height(x + 1, y + 1)
			# ملاحظة: Godot يعتبر الوجه الأمامي بترتيب clockwise
			if absf(h00 - h11) <= absf(h10 - h01):
				st.add_index(i); st.add_index(i + 1); st.add_index(i + vw)
				st.add_index(i + 1); st.add_index(i + vw + 1); st.add_index(i + vw)
			else:
				st.add_index(i); st.add_index(i + vw + 1); st.add_index(i + vw)
				st.add_index(i); st.add_index(i + 1); st.add_index(i + vw + 1)
	st.generate_normals()
	return st.commit()


func _vertex_slope(map: MapState, vx: int, vy: int) -> float:
	var dx := map.vertex_height(vx + 1, vy) - map.vertex_height(vx - 1, vy)
	var dz := map.vertex_height(vx, vy + 1) - map.vertex_height(vx, vy - 1)
	return Vector2(dx, dz).length() / (2.0 * GameConfig.CELL_SIZE)


## ألوان الأرض بانتقال تدريجي: قاع → رمل → عشب → عشب فاتح على المرتفعات، وصخر على المنحدرات.
func _color_for(h: float, slope: float) -> Color:
	var seabed := Color(0.28, 0.42, 0.48)
	var sand := Color(0.9, 0.82, 0.55)
	var grass := Color(0.42, 0.74, 0.33)
	var grass_hi := Color(0.62, 0.82, 0.4)
	var rock := Color(0.58, 0.5, 0.42)
	var w := GameConfig.WATER_LEVEL
	var c := seabed.lerp(sand, smoothstep(w - 0.6, w + 0.05, h))
	c = c.lerp(grass, smoothstep(w + 0.15, w + 0.75, h))
	c = c.lerp(grass_hi, smoothstep(1.4, 2.8, h))
	c = c.lerp(rock, smoothstep(0.35, 0.7, slope))
	return c
