extends UnitState
## Idle — ينتظر أوامر. إن كان مسلحًا يبحث عن أعداء قريبين ويشتبك تلقائيًا.


func _init() -> void:
	name = &"idle"


func enter(e: SimEntity, _gs: Node) -> void:
	e.path = PackedVector3Array()
	e.path_index = 0


func tick(e: SimEntity, gs: Node) -> StringName:
	if e.order_dirty or not e.order.is_empty():
		e.order_dirty = false
		var next := state_for_order(e)
		if next != &"idle":
			return next
		e.order = {}
	var def := e.unit_def()
	if def == null:
		return name
	# حصّادة فارغة بلا أمر: تعود للجمع تلقائيًا إن كان لها مورد سابق
	if def.can_harvest and e.data.has("resource_id"):
		var r: SimEntity = gs.get_entity(int(e.data.resource_id))
		if r != null and r.alive:
			e.order = {"type": "gather", "target": r.id}
			return &"gather"
	if def.has_weapon() and (e.state_ticks % GameConfig.SCAN_INTERVAL) == 0:
		var enemy: SimEntity = gs.find_nearest_enemy(e, def.aggro_range)
		if enemy != null:
			e.order = {"type": "attack", "target": enemy.id, "auto": true}
			return &"attack"
	return name
