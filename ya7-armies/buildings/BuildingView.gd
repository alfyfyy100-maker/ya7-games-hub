class_name BuildingView
extends Node3D
## BuildingView — عرض مبنى: بناء تدريجي (يرتفع من الأرض)، برج يدور نحو الهدف، علم نقطة التجمع.

var entity_id: int = -1
var body: Node3D
var ring: MeshInstance3D
var rally_marker: Node3D
var _def: BuildingData
var _turret: Node3D
var _sink: float = 0.0


func setup(e: SimEntity) -> void:
	entity_id = e.id
	_def = e.building_def()
	var team := GameConfig.team_color(e.owner_id)
	body = MeshFactory.make_building(_def.visual_kind, team, _def.accent_color, _def.footprint, _def.height)
	add_child(body)
	_turret = body.get_node_or_null("Turret")
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
		ring.visible = false
		rally_marker.visible = false
		return
	# بناء تدريجي: يظهر من تحت الأرض
	var t := 1.0
	if not e.data.get("completed", false):
		t = clampf(float(e.data.get("construction", 0)) / float(maxi(_def.build_ticks, 1)), 0.05, 1.0)
	body.position.y = -(1.0 - t) * (_def.height + 0.5)
	if _turret != null:
		if e.target_id > 0:
			var target: SimEntity = GameState.get_entity(e.target_id)
			if target != null:
				var to := target.pos - e.pos
				_turret.rotation.y = lerp_angle(_turret.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
	if rally_marker.visible:
		rally_marker.global_position = e.data.get("rally", e.pos)
