class_name UnitView
extends Node3D
## UnitView — عرض وحدة. يقرأ SimEntity كل فريم ولا يعدّل الحالة أبدًا.
## يستخدم نموذج glTF (UnitData.model_path) مع أنيميشن إن وُجد، وإلا نموذجًا بلوكيًا مؤقتًا.
## الموقع يُنعَّم بين prev_pos و pos عبر كسر الاستيفاء الفيزيائي.

var entity_id: int = -1
var body: Node3D                # حامل الجسم (اهتزاز/ارتداد)
var ring: MeshInstance3D
var visual_height: float = 1.6
var _def: UnitData
var _turret: TurretPivot
var _legs: Array[Node3D] = []
var _anim: AnimationPlayer
var _anim_current: String = ""
var _anim_t: float = 0.0
var _sink: float = 0.0
var _selected: bool = false
var _owner_id: int = 0
var _cargo_barrels: Array[Node3D] = []


func setup(e: SimEntity) -> void:
	entity_id = e.id
	_def = e.unit_def()
	var team := GameConfig.team_color(e.owner_id)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_owner_id = e.owner_id
	if ModelLibrary.has_model(_def.model_path):
		_setup_model(team)
	else:
		_setup_placeholder(team)
	# قرص فريق تحت الوحدة (قراءة سريعة لِمن يملك الوحدة)
	var disc := MeshInstance3D.new()
	disc.mesh = MeshFactory.cyl_mesh(_def.radius + 0.15, 0.06, 14)
	disc.material_override = MeshFactory.flat_material(Color(team.r, team.g, team.b, 0.85))
	disc.position = Vector3(0, 0.03, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	ring = MeshFactory.make_selection_ring(_def.radius + 0.35, Color(1, 1, 1, 0.9))
	ring.visible = false
	add_child(ring)
	position = e.pos
	rotation.y = e.facing


func _setup_model(team: Color) -> void:
	var model := ModelLibrary.instantiate(ModelLibrary.path_for_team(_def.model_path, _def.model_path_team2, _owner_id))
	var holder := Node3D.new()
	holder.name = "Model"
	holder.rotation_degrees.y = _def.model_yaw_deg
	body.add_child(holder)
	holder.add_child(model)
	var aabb := ModelLibrary.fit_max(model, _def.model_fit_size, _def.scale)
	ModelLibrary.center_on_ground(model, aabb)
	ModelLibrary.apply_team_look(model, team, _def.team_tint)
	visual_height = aabb.size.y
	_anim = ModelLibrary.find_animation_player(model)
	if _def.can_harvest:
		_setup_cargo_barrels(aabb)
	# برج داخلي (عقدة داخل النموذج نفسه)
	var inner := ModelLibrary.find_node_by_suffix(model, _def.turret_node_suffix)
	if inner != null:
		_turret = TurretPivot.new(inner, deg_to_rad(_def.turret_yaw_deg))
	if ModelLibrary.has_model(_def.turret_model_path):
		var turret_holder := Node3D.new()
		turret_holder.name = "Turret"
		turret_holder.position = Vector3(0, aabb.size.y * 0.98, 0)
		body.add_child(turret_holder)
		var turret := ModelLibrary.instantiate(_def.turret_model_path)
		turret_holder.add_child(turret)
		var ta := ModelLibrary.fit_max(turret, _def.turret_fit_size)
		ModelLibrary.center_on_ground(turret, ta)
		ModelLibrary.apply_team_look(turret, team, _def.team_tint)
		_turret = TurretPivot.new(turret_holder, deg_to_rad(_def.turret_yaw_deg))
		visual_height += ta.size.y


## براميل نفط تظهر على صندوق الحصّادة كلما امتلأت الحمولة.
func _setup_cargo_barrels(aabb: AABB) -> void:
	const BARREL := "res://assets/models/rgpoly/Barrel_1_A.fbx"
	if not ModelLibrary.has_model(BARREL):
		return
	var top := aabb.size.y * 0.78
	var slots := [Vector3(-0.3, top, -0.35), Vector3(0.3, top, -0.35), Vector3(-0.3, top, -0.85), Vector3(0.3, top, -0.85)]
	for i in slots.size():
		var b := ModelLibrary.instantiate(BARREL)
		body.add_child(b)
		var ba := ModelLibrary.fit_max(b, 0.42)
		ModelLibrary.center_on_ground(b, ba)
		b.position += slots[i]
		ModelLibrary.apply_team_look(b, Color(0.12, 0.1, 0.08), 0.75)
		b.visible = false
		_cargo_barrels.append(b)


func _setup_placeholder(team: Color) -> void:
	var mesh_body := MeshFactory.make_unit(_def.visual_kind, team, _def.accent_color)
	mesh_body.scale = Vector3.ONE * _def.scale
	body.add_child(mesh_body)
	var t := mesh_body.get_node_or_null("Turret")
	if t != null:
		_turret = TurretPivot.new(t)
	for n in ["LegL", "LegR"]:
		var leg := mesh_body.get_node_or_null(n)
		if leg != null:
			_legs.append(leg)
	visual_height = 1.5 * _def.scale


## موضع الفوهة (للمقذوفات المرئية).
func muzzle_position() -> Vector3:
	if _turret != null and _turret.node != null:
		return _turret.node.global_position + Vector3(0, 0.25, 0)
	return global_position + Vector3(0, visual_height * 0.65, 0)


func set_selected(v: bool) -> void:
	_selected = v
	if ring != null:
		ring.visible = v


func _play(anim_name: String, loop_fallback: String = "") -> void:
	if _anim == null:
		return
	var target := anim_name
	if not _anim.has_animation(target):
		target = loop_fallback
	if target == "" or not _anim.has_animation(target):
		return
	if _anim_current == target:
		return
	_anim_current = target
	_anim.play(target, 0.15)


func _process(delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	var f := Engine.get_physics_interpolation_fraction()
	position = e.prev_pos.lerp(e.pos, f)
	rotation.y = lerp_angle(rotation.y, e.facing, minf(1.0, delta * 14.0))

	if not e.alive:
		ring.visible = false
		if _anim != null and _anim.has_animation("die"):
			_play("die")
			# بعد انتهاء أنيميشن الموت تغوص الجثة
			if not _anim.is_playing():
				_sink += delta
				body.position.y = -_sink * 1.2
		else:
			_sink += delta
			body.position.y = -_sink * 1.2
			body.rotation.x = minf(_sink * 2.0, 1.4)
		return

	_anim_t += delta
	var moving := e.state == &"move" or (e.state == &"attack" and not e.path.is_empty()) \
		or (e.state == &"gather" and not e.path.is_empty())
	# أنيميشن هيكلي (شخصيات Kenney) أو اهتزاز بسيط (مركبات/نماذج مؤقتة)
	if _anim != null:
		if e.state == &"attack" and not moving:
			_play("holding-right-shoot", "idle")
		elif moving:
			_play("sprint" if _def.speed >= 6.0 else "walk", "walk")
		elif e.state == &"gather" and String(e.data.get("gather_phase", "")) in ["mining", "unloading"]:
			_play("pick-up", "idle")
		else:
			_play("idle", "static")
	var bob := 0.0
	if moving and _anim == null:
		bob = absf(sin(_anim_t * 12.0)) * 0.06
		for i in _legs.size():
			_legs[i].rotation.x = sin(_anim_t * 12.0 + (PI if i == 1 else 0.0)) * 0.6
	elif _anim == null:
		for leg in _legs:
			leg.rotation.x = lerpf(leg.rotation.x, 0.0, minf(1.0, delta * 10.0))
	# ارتداد عند الإطلاق ووميض عند الإصابة
	var since_fire := GameState.tick - e.last_fire_tick
	var recoil := 0.0
	if since_fire >= 0 and since_fire < 4:
		recoil = (4 - since_fire) * 0.03
	var since_hit := GameState.tick - e.last_hit_tick
	var flinch := 1.0
	if since_hit >= 0 and since_hit < 3:
		flinch = 0.9
	body.position = Vector3(0, bob, -recoil)
	body.scale = Vector3.ONE * flinch
	if _turret != null:
		var aimed := false
		if e.state == &"attack":
			var t: SimEntity = GameState.get_entity(e.target_id)
			if t != null:
				var to := t.pos - e.pos
				_turret.aim(atan2(to.x, to.z), rotation.y, delta)
				aimed = true
		if not aimed:
			_turret.relax(delta)
	# حصّادة: براميل تظهر تدريجيًا مع الحمولة
	if not _cargo_barrels.is_empty():
		var ratio := float(e.cargo) / float(maxi(_def.cargo_capacity, 1))
		for i in _cargo_barrels.size():
			_cargo_barrels[i].visible = ratio > float(i) / float(_cargo_barrels.size()) + 0.01
	# حصّادة (النموذج المؤقت): صندوق الحمولة يرتفع مع الامتلاء
	if _def.can_harvest and _anim == null and _cargo_barrels.is_empty():
		var cargo_node := body.find_child("Cargo", true, false)
		if cargo_node != null:
			var r := float(e.cargo) / float(maxi(_def.cargo_capacity, 1))
			cargo_node.scale.y = 0.4 + 0.6 * r
