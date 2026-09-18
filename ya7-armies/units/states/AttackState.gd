extends UnitState
## Attack — يطارد الهدف حتى يدخل المدى ثم يطلق كل fire_cooldown_ticks.


func _init() -> void:
	name = &"attack"


func enter(e: SimEntity, _gs: Node) -> void:
	e.order_dirty = false
	e.target_id = int(e.order.get("target", -1))
	e.path = PackedVector3Array()
	e.path_index = 0


func exit(e: SimEntity, _gs: Node) -> void:
	e.target_id = -1


func tick(e: SimEntity, gs: Node) -> StringName:
	if e.order_dirty:
		e.order_dirty = false
		return state_for_order(e) if not e.order.is_empty() else &"idle"
	var def := e.unit_def()
	var target: SimEntity = gs.get_entity(e.target_id)
	if def == null or target == null or not target.alive:
		return _finish(e)
	if e.cooldown > 0:
		e.cooldown -= 1
	# للمباني تُحسب المسافة إلى حافة البصمة وليس المركز
	var dist := Locomotion.distance_to_entity(e.pos, target)
	if dist <= def.attack_range:
		e.path = PackedVector3Array()
		Locomotion.face_towards(e, target.pos)
		if e.cooldown <= 0:
			gs.apply_damage(target.id, def.damage, e.id)
			e.cooldown = def.fire_cooldown_ticks
			e.last_fire_tick = gs.tick
		return name
	# اشتباك تلقائي: لا ننجرّ بعيدًا عن موقع الحراسة (leash)
	if bool(e.order.get("auto", false)) and e.data.has("guard_pos"):
		var leash := def.aggro_range * 1.6 + 8.0
		if Locomotion.flat_distance(e.pos, e.data.guard_pos) > leash:
			e.resume_order = {}
			e.order = {"type": "move", "pos": e.data.guard_pos, "auto": true}
			return &"move"
	# مطاردة: إعادة حساب المسار دوريًا
	if e.path.is_empty() or (e.state_ticks % GameConfig.REPATH_INTERVAL) == 0:
		Locomotion.request_path(e, gs, target.pos)
	Locomotion.step(e, gs)
	return name


func _finish(e: SimEntity) -> StringName:
	if not e.resume_order.is_empty():
		e.order = e.resume_order
		e.resume_order = {}
		return state_for_order(e)
	e.order = {}
	return &"idle"
