class_name MeshFactory
extends RefCounted
## MeshFactory — يبني نماذج placeholder بلوكية (low-poly) بألوان كرتونية.
## المواد والميشات مُخزّنة مؤقتًا (cache) لتقليل draw calls/الذاكرة على الموبايل.

static var _toon_shader: Shader = preload("res://assets/shaders/toon.gdshader")
static var _materials: Dictionary = {}   # Color -> ShaderMaterial
static var _meshes: Dictionary = {}      # String key -> Mesh


static func material(color: Color) -> ShaderMaterial:
	var key := color.to_rgba32()
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = _toon_shader
	m.set_shader_parameter("albedo", color)
	_materials[key] = m
	return m


static func box_mesh(size: Vector3) -> BoxMesh:
	var key := "box_%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func cyl_mesh(radius: float, height: float, sides: int = 10) -> CylinderMesh:
	var key := "cyl_%s_%s_%d" % [radius, height, sides]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	_meshes[key] = m
	return m


static func cone_mesh(radius: float, height: float, sides: int = 8) -> CylinderMesh:
	var key := "cone_%s_%s_%d" % [radius, height, sides]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	_meshes[key] = m
	return m


static func prism_mesh(size: Vector3) -> PrismMesh:
	var key := "prism_%s" % size
	if _meshes.has(key):
		return _meshes[key]
	var m := PrismMesh.new()
	m.size = size
	_meshes[key] = m
	return m


static func ring_mesh(radius: float) -> TorusMesh:
	var key := "ring_%s" % radius
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = radius
	m.outer_radius = radius + 0.12
	m.rings = 24
	m.ring_segments = 6
	_meshes[key] = m
	return m


static func add_part(parent: Node3D, mesh: Mesh, color: Color, offset: Vector3, rot_deg: Vector3 = Vector3.ZERO, part_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color)
	mi.position = offset
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if part_name != "":
		mi.name = part_name
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ الوحدات

## يبني جسم وحدة. يرجّع Node3D فيه الأجزاء؛ الجزء "Turret" (إن وُجد) يدور نحو الهدف.
static func make_unit(kind: int, team: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	var dark := team.darkened(0.35)
	var skin := Color(0.98, 0.83, 0.68)
	match kind:
		UnitData.VisualKind.SOLDIER, UnitData.VisualKind.ARCHER, UnitData.VisualKind.ENGINEER:
			# مشاة: جذع + رأس + خوذة + سلاح
			add_part(root, box_mesh(Vector3(0.5, 0.55, 0.32)), team, Vector3(0, 0.62, 0))
			add_part(root, box_mesh(Vector3(0.18, 0.35, 0.18)), dark, Vector3(-0.17, 0.18, 0), Vector3.ZERO, "LegL")
			add_part(root, box_mesh(Vector3(0.18, 0.35, 0.18)), dark, Vector3(0.17, 0.18, 0), Vector3.ZERO, "LegR")
			add_part(root, box_mesh(Vector3(0.36, 0.34, 0.34)), skin, Vector3(0, 1.08, 0))
			add_part(root, box_mesh(Vector3(0.44, 0.16, 0.42)), accent, Vector3(0, 1.3, 0))
			if kind == UnitData.VisualKind.ARCHER:
				add_part(root, box_mesh(Vector3(0.06, 0.9, 0.06)), Color(0.45, 0.28, 0.15), Vector3(0.34, 0.7, 0.1), Vector3(0, 0, 8))
			elif kind == UnitData.VisualKind.ENGINEER:
				add_part(root, box_mesh(Vector3(0.12, 0.12, 0.5)), Color(0.55, 0.55, 0.6), Vector3(0.34, 0.6, 0.15))
			else:
				add_part(root, box_mesh(Vector3(0.1, 0.1, 0.6)), Color(0.25, 0.25, 0.3), Vector3(0.32, 0.65, 0.25))
		UnitData.VisualKind.TANK:
			add_part(root, box_mesh(Vector3(1.4, 0.5, 1.8)), team, Vector3(0, 0.45, 0))
			add_part(root, box_mesh(Vector3(0.35, 0.3, 1.9)), dark, Vector3(-0.72, 0.28, 0))
			add_part(root, box_mesh(Vector3(0.35, 0.3, 1.9)), dark, Vector3(0.72, 0.28, 0))
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 0.75, -0.1)
			root.add_child(turret)
			add_part(turret, cyl_mesh(0.5, 0.35, 10), accent, Vector3.ZERO)
			add_part(turret, box_mesh(Vector3(0.16, 0.16, 1.4)), dark, Vector3(0, 0.05, 0.9))
		UnitData.VisualKind.APC:
			add_part(root, box_mesh(Vector3(1.2, 0.6, 1.7)), team, Vector3(0, 0.55, 0))
			add_part(root, box_mesh(Vector3(0.9, 0.35, 0.9)), accent, Vector3(0, 1.0, -0.2))
			for x in [-0.6, 0.6]:
				for z in [-0.55, 0.55]:
					add_part(root, cyl_mesh(0.28, 0.25, 8), Color(0.15, 0.15, 0.18), Vector3(x, 0.28, z), Vector3(0, 0, 90))
		UnitData.VisualKind.HARVESTER:
			add_part(root, box_mesh(Vector3(1.3, 0.55, 1.6)), team, Vector3(0, 0.5, 0.1))
			add_part(root, box_mesh(Vector3(1.1, 0.5, 0.7)), accent, Vector3(0, 1.0, -0.3), Vector3.ZERO, "Cargo")
			add_part(root, box_mesh(Vector3(0.7, 0.45, 0.5)), dark, Vector3(0, 0.95, 0.5))
			add_part(root, box_mesh(Vector3(1.4, 0.25, 0.5)), Color(0.3, 0.3, 0.35), Vector3(0, 0.35, 1.0))
			for x in [-0.6, 0.6]:
				for z in [-0.5, 0.5]:
					add_part(root, cyl_mesh(0.3, 0.3, 8), Color(0.15, 0.15, 0.18), Vector3(x, 0.3, z), Vector3(0, 0, 90))
	return root


# ------------------------------------------------------------------ المباني

static func make_building(kind: int, team: Color, accent: Color, footprint: Vector2i, height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	var w := footprint.x * GameConfig.CELL_SIZE * 0.82
	var d := footprint.y * GameConfig.CELL_SIZE * 0.82
	var dark := team.darkened(0.35)
	var roof := accent
	var wall := Color(0.93, 0.9, 0.82)
	# قاعدة/رصيف
	add_part(root, box_mesh(Vector3(w + 0.5, 0.18, d + 0.5)), Color(0.6, 0.6, 0.62), Vector3(0, 0.09, 0))
	match kind:
		BuildingData.VisualKind.HQ:
			add_part(root, box_mesh(Vector3(w, height * 0.55, d)), wall, Vector3(0, height * 0.275 + 0.15, 0))
			add_part(root, box_mesh(Vector3(w * 0.6, height * 0.45, d * 0.6)), team, Vector3(0, height * 0.55 + height * 0.225 + 0.15, 0))
			add_part(root, box_mesh(Vector3(w * 0.66, 0.25, d * 0.66)), roof, Vector3(0, height + 0.25, 0))
			add_part(root, box_mesh(Vector3(0.12, 1.6, 0.12)), Color(0.3, 0.3, 0.35), Vector3(w * 0.25, height + 1.0, -d * 0.25))
			add_part(root, box_mesh(Vector3(0.7, 0.45, 0.05)), team, Vector3(w * 0.25 + 0.4, height + 1.55, -d * 0.25))
		BuildingData.VisualKind.BARRACKS:
			add_part(root, box_mesh(Vector3(w, height * 0.75, d)), wall, Vector3(0, height * 0.375 + 0.15, 0))
			add_part(root, prism_mesh(Vector3(w + 0.3, height * 0.45, d + 0.3)), roof, Vector3(0, height * 0.75 + height * 0.225 + 0.15, 0))
			add_part(root, box_mesh(Vector3(0.9, 1.1, 0.15)), dark, Vector3(0, 0.7, d * 0.5))
		BuildingData.VisualKind.WAR_FACTORY:
			add_part(root, box_mesh(Vector3(w, height * 0.7, d)), Color(0.72, 0.74, 0.78), Vector3(0, height * 0.35 + 0.15, 0))
			add_part(root, box_mesh(Vector3(w * 0.95, 0.35, d * 0.95)), team, Vector3(0, height * 0.7 + 0.3, 0))
			add_part(root, cyl_mesh(0.35, height * 0.9, 8), dark, Vector3(-w * 0.35, height * 0.7 + 0.5, -d * 0.3))
			add_part(root, box_mesh(Vector3(w * 0.5, height * 0.5, 0.15)), roof, Vector3(0, height * 0.35, d * 0.5))
		BuildingData.VisualKind.REFINERY:
			add_part(root, box_mesh(Vector3(w * 0.55, height * 0.6, d)), wall, Vector3(-w * 0.2, height * 0.3 + 0.15, 0))
			add_part(root, cyl_mesh(d * 0.3, height, 12), roof, Vector3(w * 0.28, height * 0.5 + 0.15, 0))
			add_part(root, cyl_mesh(d * 0.32, 0.2, 12), team, Vector3(w * 0.28, height + 0.2, 0))
			add_part(root, box_mesh(Vector3(w * 0.5, 0.25, d * 0.5)), team, Vector3(-w * 0.2, height * 0.6 + 0.3, 0))
		BuildingData.VisualKind.TOWER:
			add_part(root, cyl_mesh(0.7, height * 0.7, 8), Color(0.62, 0.62, 0.66), Vector3(0, height * 0.35 + 0.15, 0))
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, height * 0.7 + 0.35, 0)
			root.add_child(turret)
			add_part(turret, box_mesh(Vector3(0.9, 0.5, 0.9)), team, Vector3.ZERO)
			add_part(turret, box_mesh(Vector3(0.14, 0.14, 1.2)), Color(0.2, 0.2, 0.25), Vector3(0, 0.05, 0.7))
			add_part(root, cone_mesh(0.75, 0.5, 8), roof, Vector3(0, height * 0.7 + 0.15, 0))
	return root


## نقطة موارد: عنقود بلّورات ذهبية.
static func make_resource() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	var gold := Color(1.0, 0.82, 0.25)
	var gold2 := Color(1.0, 0.68, 0.15)
	add_part(root, prism_mesh(Vector3(0.7, 1.4, 0.7)), gold, Vector3(0, 0.7, 0), Vector3(0, 20, 0))
	add_part(root, prism_mesh(Vector3(0.5, 1.0, 0.5)), gold2, Vector3(0.55, 0.5, 0.2), Vector3(0, -30, 12))
	add_part(root, prism_mesh(Vector3(0.45, 0.8, 0.45)), gold2, Vector3(-0.5, 0.4, -0.3), Vector3(0, 60, -10))
	add_part(root, prism_mesh(Vector3(0.4, 0.7, 0.4)), gold, Vector3(0.1, 0.35, -0.6), Vector3(0, 95, 8))
	return root


static func make_selection_ring(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ring_mesh(radius)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.position = Vector3(0, 0.08, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
