class_name BuildingView
extends Node3D
## BuildingView — عرض مبنى: نموذج glTF مقاس على البصمة (أو نموذج مؤقت)، بناء تدريجي
## (يرتفع من الأرض)، برج يدور نحو الهدف، علم نقطة التجمع.

var entity_id: int = -1
var body: Node3D
var ring: MeshInstance3D
var rally_marker: Node3D
var visual_height: float = 2.0
var _def: BuildingData
var _turret: Node3D
var _turret_yaw_offset: float = 0.0
var _sink: float = 0.0


func setup(e: SimEntity) -> void:
	entity_id = e.id
	_def = e.building_def()
	var team := GameConfig.team_color(e.owner_id)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	if ModelLibrary.has_model(_def.model_path):
		_setup_model(team)
	else:
		_setup_placeholder(team)
	var r := maxf(_def.footprint.x, _def.footprint.y) * GameConfig.CELL_SIZE * 0.62
	ring = MeshFactory.make_selection_ring(r, Color(1, 1, 1, 0.9))
	ring.visible = false
	add_child(ring)
	# علم نقطة التجمع (يظهر عند الاختيار فقط للمباني المنتِجة)
	rally_marker = Node3D.new()
	MeshFactory.add_part(rally_marker, MeshFactory.box_mesh(Vector3(0.08, 1.6, 0.08)), Color(0.3, 0.3, 0.35), Vector3(0, 0.8, 0))
	MeshFactory.add_part(rally_marker, MeshFactory.box_mesh(Vector3(0.7, 0.4, 0.05)), team, Vector3(0.38, 1.35, 0))
	rally_marker.visible = false
	rally_marker.top_level = true
	add_child(rally_marker)
	position = e.pos


func _setup_model(team: Color) -> void:
	var w := _def.footprint.x * GameConfig.CELL_SIZE * _def.model_fit
	var d := _def.footprint.y * GameConfig.CELL_SIZE * _def.model_fit
	# رصيف خرساني تحت المبنى يوحّد المظهر ويخفي فروق الارتفاع
	var pad := MeshInstance3D.new()
	pad.mesh = MeshFactory.box_mesh(Vector3(_def.footprint.x * GameConfig.CELL_SIZE * 0.98, 0.18, _def.footprint.y * GameConfig.CELL_SIZE * 0.98))
	pad.material_override = MeshFactory.material(Color(0.62, 0.62, 0.64))
	pad.position = Vector3(0, 0.09, 0)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(pad)
	var holder := Node3D.new()
	holder.name = "Model"
	holder.rotation_degrees.y = _def.model_yaw_deg
	holder.position.y = 0.18
	body.add_child(holder)
	var model := ModelLibrary.instantiate(_def.model_path)
	holder.add_child(model)
	# عند تدوير النموذج 90° نبدّل العرض والعمق
	var swap := absf(fmod(_def.model_yaw_deg, 180.0)) > 45.0
	var aabb := ModelLibrary.fit_footprint(model, d if swap else w, w if swap else d)
	ModelLibrary.center_on_ground(model, aabb)
	ModelLibrary.apply_team_look(model, team, _def.team_tint)
	var top_y := 0.18 + aabb.size.y
	var scale_used := model.scale.x
	if ModelLibrary.has_model(_def.top_model_path):
		var top := ModelLibrary.instantiate(_def.top_model_path)
		holder.add_child(top)
		var ta := ModelLibrary.fit_max(top, 0.0, scale_used)
		ModelLibrary.center_on_ground(top, ta)
		top.position.y += aabb.size.y * 0.92
		ModelLibrary.apply_team_look(top, team, _def.team_tint)
		top_y = 0.18 + aabb.size.y * 0.92 + ta.size.y
	if ModelLibrary.has_model(_def.turret_model_path):
		var turret_holder := Node3D.new()
		turret_holder.name = "Turret"
		turret_holder.position = Vector3(0, top_y * 0.97, 0)
		add_child(turret_holder)
		var turret := ModelLibrary.instantiate(_def.turret_model_path)
		turret_holder.add_child(turret)
		var tta := ModelLibrary.fit_max(turret, _def.turret_fit_size)
		ModelLibrary.center_on_ground(turret, tta)
		ModelLibrary.apply_team_look(turret, team, _def.team_tint)
		_turret = turret_holder
		_turret_yaw_offset = deg_to_rad(_def.turret_yaw_deg)
		top_y += tta.size.y
	visual_height = top_y


func _setup_placeholder(team: Color) -> void:
	var mesh_body := MeshFactory.make_building(_def.visual_kind, team, _def.accent_color, _def.footprint, _def.height)
	body.add_child(mesh_body)
	_turret = mesh_body.get_node_or_null("Turret")
	visual_height = _def.height + 0.6


func set_selected(v: bool) -> void:
	ring.visible = v
	rally_marker.visible = v and _def.can_produce()


func _process(delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	position = e.pos
	if not e.alive:
		_sink += delta
		body.position.y = -_sink * 2.0
		body.rotation.z = minf(_sink * 0.8, 0.5)
		if _turret != null:
			_turret.position.y -= delta * 2.0
		ring.visible = false
		rally_marker.visible = false
		return
	# بناء تدريجي: يظهر من تحت الأرض
	var t := 1.0
	if not e.data.get("completed", false):
		t = clampf(float(e.data.get("construction", 0)) / float(maxi(_def.build_ticks, 1)), 0.05, 1.0)
	body.position.y = -(1.0 - t) * (visual_height + 0.5)
	if _turret != null:
		_turret.visible = t >= 0.999
		if e.target_id > 0:
			var target: SimEntity = GameState.get_entity(e.target_id)
			if target != null:
				var to := target.pos - e.pos
				_turret.rotation.y = lerp_angle(_turret.rotation.y, atan2(to.x, to.z) + _turret_yaw_offset, minf(1.0, delta * 8.0))
	if rally_marker.visible:
		rally_marker.global_position = e.data.get("rally", e.pos)
