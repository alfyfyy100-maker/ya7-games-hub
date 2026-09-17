extends Node3D
## DecorView — أشجار وصخور من MapState.decor عبر MultiMesh (draw call واحد لكل ميش).
## عرض فقط؛ الحجز المنطقي للخلايا في NavGrid.

const MODELS: Dictionary = {
	MapState.DecorKind.TREE: {"path": "res://assets/models/rgpoly/PineTree_1_A.fbx", "fit": 3.4},
	MapState.DecorKind.ROCKS: {"path": "res://assets/models/rgpoly/Bags_3_A.fbx", "fit": 2.0},
}


func build(map: MapState) -> void:
	for c in get_children():
		c.queue_free()
	for kind in MODELS:
		var cells: Array[Vector2i] = []
		for d in map.decor:
			if int(d.kind) == kind:
				cells.append(d.cell)
		if cells.is_empty():
			continue
		var info: Dictionary = MODELS[kind]
		if ModelLibrary.has_model(info.path):
			_build_multimesh(map, cells, info.path, float(info.fit))
		else:
			_build_placeholder(map, cells, kind)


func _build_multimesh(map: MapState, cells: Array[Vector2i], path: String, fit: float) -> void:
	var proto := ModelLibrary.instantiate(path)
	var aabb := ModelLibrary.fit_max(proto, fit)
	ModelLibrary.center_on_ground(proto, aabb)
	ModelLibrary.apply_team_look(proto, Color.WHITE, 0.0)
	# لكل ميش داخل النموذج ننشئ MultiMesh بنفس التحويل النسبي
	for mi in proto.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var rel := ModelLibrary.relative_transform(m, proto) 
		rel = proto.transform * rel
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m.mesh
		mm.instance_count = cells.size()
		for i in cells.size():
			var c := cells[i]
			var yaw := float((c.x * 7 + c.y * 13) % 360) * TAU / 360.0
			var s := 0.85 + float((c.x * 3 + c.y * 5) % 10) * 0.03
			var base := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * s), map.cell_to_world(c))
			mm.set_instance_transform(i, base * rel)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		for si in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(si)
			if mat != null and si == 0:
				mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	proto.free()


func _build_placeholder(map: MapState, cells: Array[Vector2i], kind: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshFactory.cone_mesh(0.9, 2.2, 7) if kind == MapState.DecorKind.TREE else MeshFactory.box_mesh(Vector3(1.2, 0.7, 1.0))
	mm.instance_count = cells.size()
	for i in cells.size():
		var p := map.cell_to_world(cells[i])
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p + Vector3(0, 1.1 if kind == MapState.DecorKind.TREE else 0.35, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MeshFactory.material(Color(0.3, 0.6, 0.3) if kind == MapState.DecorKind.TREE else Color(0.55, 0.5, 0.45))
	add_child(mmi)
