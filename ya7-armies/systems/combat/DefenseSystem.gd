extends RefCounted
## DefenseSystem — ذكاء دفاعي للوحدات (حتمي، داخل المحاكاة):
##  - الوحدة المُهاجَمة تردّ على مهاجمها إن كانت خاملة أو تشتبك تلقائيًا مع هدف أبعد.
##  - عند مهاجمة مبنى/وحدة، الوحدات المسلحة الخاملة ضمن نصف قطر الدفاع تهبّ للرد.
##  - الحصّادة المُهاجَمة تهرب إلى أقرب مبنى مملوك ثم تعود للجمع تلقائيًا.
##  - الأوامر اليدوية للاعب لها الأولوية دائمًا (لا نلمس وحدة لها أمر غير تلقائي).

const DEFENSE_RADIUS: float = 30.0
const FLEE_COOLDOWN: int = 90
const MAX_RESPONDERS: int = 8


func tick(gs: Node) -> void:
	if gs.threat_events.is_empty():
		return
	var events: Array = gs.threat_events.duplicate()
	gs.threat_events.clear()
	for ev in events:
		var target: SimEntity = gs.get_entity(int(ev.target))
		var source: SimEntity = gs.get_entity(int(ev.source))
		if target == null or source == null or not source.alive:
			continue
		_react_victim(gs, target, source)
		_alert_defenders(gs, target, source)


static func is_auto_engaged(e: SimEntity) -> bool:
	return e.order.is_empty() or bool(e.order.get("auto", false))


func _react_victim(gs: Node, victim: SimEntity, attacker: SimEntity) -> void:
	if not victim.is_unit() or not victim.alive:
		return
	var def := victim.unit_def()
	if def == null:
		return
	if def.can_harvest and not def.has_weapon():
		_flee(gs, victim, attacker)
		return
	if not def.has_weapon() or not is_auto_engaged(victim):
		return
	# نردّ على المهاجم إن لم نكن نشتبك أصلًا مع هدف أقرب منه
	var current: SimEntity = gs.get_entity(victim.target_id)
	if current != null and current.alive and current.id != attacker.id:
		if victim.pos.distance_squared_to(current.pos) <= victim.pos.distance_squared_to(attacker.pos):
			return
	_engage(victim, attacker)


func _alert_defenders(gs: Node, victim: SimEntity, attacker: SimEntity) -> void:
	var responders := 0
	var ids: Array = gs.entities.keys()
	ids.sort()
	# الأقرب أولًا
	var candidates: Array[SimEntity] = []
	for id in ids:
		var u: SimEntity = gs.entities[id]
		if not u.is_unit() or not u.alive or u.owner_id != victim.owner_id or u.id == victim.id:
			continue
		var d := u.unit_def()
		if d == null or not d.has_weapon():
			continue
		if not is_auto_engaged(u):
			continue
		if u.state != &"idle" and u.state != &"move":
			continue
		if Locomotion.flat_distance(u.pos, victim.pos) > DEFENSE_RADIUS:
			continue
		candidates.append(u)
	candidates.sort_custom(func(a: SimEntity, b: SimEntity) -> bool:
		var da := a.pos.distance_squared_to(attacker.pos)
		var db := b.pos.distance_squared_to(attacker.pos)
		return da < db if da != db else a.id < b.id)
	for u in candidates:
		if responders >= MAX_RESPONDERS:
			break
		_engage(u, attacker)
		responders += 1


func _engage(u: SimEntity, attacker: SimEntity) -> void:
	if not u.data.has("guard_pos"):
		u.data.guard_pos = u.pos
	u.set_order({"type": "attack", "target": attacker.id, "auto": true})


func _flee(gs: Node, h: SimEntity, attacker: SimEntity) -> void:
	var last := int(h.data.get("flee_tick", -1000))
	if gs.tick - last < FLEE_COOLDOWN:
		return
	var refuge: SimEntity = gs.find_nearest(h.pos, func(o: SimEntity) -> bool:
		return o.is_building() and o.alive and o.owner_id == h.owner_id, 1e9)
	if refuge == null:
		return
	# لا نهرب إن كان الملاذ أقرب للمهاجم مما نحن عليه
	if refuge.pos.distance_squared_to(attacker.pos) < h.pos.distance_squared_to(attacker.pos) * 0.5:
		return
	h.data.flee_tick = gs.tick
	var cell: Vector2i = gs.nav.nearest_adjacent_walkable(refuge.data.cell, refuge.data.footprint, h.pos)
	# نحفظ المورد كي تعود للجمع تلقائيًا عند الهدوء (IdleState يستأنف الجمع)
	h.set_order({"type": "move", "pos": gs.map.cell_to_world(cell), "auto": true, "flee": true})
