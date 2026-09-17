extends RefCounted
## UnitSystem — يشغّل آلة الحالة لكل وحدة حية في كل فريم.

var fsm: UnitStateMachine = UnitStateMachine.new()


func tick(gs: Node) -> void:
	# ترتيب ثابت بالمعرّف = سلوك حتمي
	var ids: Array = gs.entities.keys()
	ids.sort()
	for id in ids:
		var e: SimEntity = gs.entities[id]
		if not e.is_unit():
			continue
		if not e.alive:
			if e.state != &"dead":
				fsm.change(e, &"dead", gs)
			continue
		fsm.tick_entity(e, gs)
	_separate(gs, ids)


## تباعد بسيط وحتمي بين الوحدات الحية (أفقيًا فقط) حتى لا تتكدس في نقطة واحدة.
func _separate(gs: Node, ids: Array) -> void:
	var units: Array[SimEntity] = []
	for id in ids:
		var e: SimEntity = gs.entities[id]
		if e.is_unit() and e.alive:
			units.append(e)
	var n := units.size()
	for i in n:
		var a := units[i]
		var ra: float = a.unit_def().radius
		for j in range(i + 1, n):
			var b := units[j]
			var rb: float = b.unit_def().radius
			var min_d := (ra + rb) * 0.95
			var dx := b.pos.x - a.pos.x
			var dz := b.pos.z - a.pos.z
			var d2 := dx * dx + dz * dz
			if d2 >= min_d * min_d or d2 < 0.0001:
				if d2 < 0.0001:
					dx = 0.01 * float((a.id % 3) - 1)
					dz = 0.01
					d2 = dx * dx + dz * dz
				else:
					continue
			var d := sqrt(d2)
			var push := (min_d - d) * 0.5
			var nx := dx / d
			var nz := dz / d
			# الوحدة المتوقفة تُزاح أقل حتى لا تنجرف عن موقعها
			var wa := 0.35 if a.state == &"idle" else 0.65
			var wb := 0.35 if b.state == &"idle" else 0.65
			_nudge(gs, a, -nx * push * wa * 2.0, -nz * push * wa * 2.0)
			_nudge(gs, b, nx * push * wb * 2.0, nz * push * wb * 2.0)


func _nudge(gs: Node, e: SimEntity, dx: float, dz: float) -> void:
	var np := Vector3(e.pos.x + dx, e.pos.y, e.pos.z + dz)
	np = gs.map.clamp_world(np)
	if gs.nav.is_walkable(gs.map.world_to_cell(np)):
		e.pos.x = np.x
		e.pos.z = np.z
		e.pos.y = gs.map.height_at_world(np.x, np.z)
