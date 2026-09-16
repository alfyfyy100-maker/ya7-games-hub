class_name UnitView
extends Node3D
## UnitView — عرض وحدة. يقرأ SimEntity كل فريم ولا يعدّل الحالة أبدًا.
## الموقع يُنعَّم بين prev_pos و pos عبر كسر الاستيفاء الفيزيائي.

var entity_id: int = -1
var body: Node3D
var ring: MeshInstance3D
var _def: UnitData
var _turret: Node3D
var _legs: Array[Node3D] = []
var _anim_t: float = 0.0
var _sink: float = 0.0
var _selected: bool = false


func setup(e: SimEntity) -> void:
	entity_id = e.id
	_def = e.unit_def()
	var team := GameConfig.team_color(e.owner_id)
	body = MeshFactory.make_unit(_def.visual_kind, team, _def.accent_color)
	body.scale = Vector3.ONE * _def.scale
	add_child(body)
	_turret = body.get_node_or_null("Turret")
	for n in ["LegL", "LegR"]:
		var leg := body.get_node_or_null(n)
		if leg != null:
			_legs.append(leg)
	ring = MeshFactory.make_selection_ring(_def.radius + 0.35, Color(1, 1, 1, 0.9))
	ring.visible = false
	add_child(ring)
	position = e.pos
	rotation.y = e.facing


func set_selected(v: bool) -> void:
	_selected = v
	if ring != null:
		ring.visible = v


func _process(delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	var f := Engine.get_physics_interpolation_fraction()
	position = e.prev_pos.lerp(e.pos, f)
	rotation.y = lerp_angle(rotation.y, e.facing, minf(1.0, delta * 14.0))

	if not e.alive:
		# موت: يميل ويغوص في الأرض ثم يُحذف من CombatSystem
		_sink += delta
		body.position.y = -_sink * 1.2
		body.rotation.x = minf(_sink * 2.0, 1.4)
		ring.visible = false
		return

	_anim_t += delta
	var moving := e.state == &"move" or (e.state == &"attack" and not e.path.is_empty()) \
		or (e.state == &"gather" and not e.path.is_empty())
	var bob := 0.0
	if moving:
		bob = absf(sin(_anim_t * 12.0)) * 0.08
		for i in _legs.size():
			_legs[i].rotation.x = sin(_anim_t * 12.0 + (PI if i == 1 else 0.0)) * 0.6
	else:
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, minf(1.0, delta * 10.0))
	# ارتداد عند الإطلاق
	var since_fire := GameState.tick - e.last_fire_tick
	var recoil := 0.0
	if since_fire >= 0 and since_fire < 4:
		recoil = (4 - since_fire) * 0.03
	var since_hit := GameState.tick - e.last_hit_tick
	var flinch := 1.0
	if since_hit >= 0 and since_hit < 3:
		flinch = 0.88
	body.position = Vector3(0, bob, -recoil)
	body.scale = Vector3.ONE * _def.scale * flinch
	if _turret != null and e.state == &"attack":
		var t: SimEntity = GameState.get_entity(e.target_id)
		if t != null:
			var to := t.pos - e.pos
			var yaw := atan2(to.x, to.z) - rotation.y
			_turret.rotation.y = lerp_angle(_turret.rotation.y, yaw, minf(1.0, delta * 8.0))
	elif _turret != null:
		_turret.rotation.y = lerp_angle(_turret.rotation.y, 0.0, minf(1.0, delta * 4.0))
	# حصّادة: صندوق الحمولة يرتفع مع الامتلاء
	if _def.can_harvest:
		var cargo_node := body.get_node_or_null("Cargo")
		if cargo_node != null:
			var r := float(e.cargo) / float(maxi(_def.cargo_capacity, 1))
			cargo_node.scale.y = 0.4 + 0.6 * r
