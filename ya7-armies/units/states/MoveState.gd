extends UnitState
## Move — يتبع مسارًا إلى order.pos. في attack_move يشتبك مع الأعداء أثناء الطريق.


func _init() -> void:
	name = &"move"


func enter(e: SimEntity, gs: Node) -> void:
	e.order_dirty = false
	var target: Vector3 = e.order.get("pos", e.pos)
	if not Locomotion.request_path(e, gs, target):
		e.order = {}


func tick(e: SimEntity, gs: Node) -> StringName:
	if e.order_dirty:
		e.order_dirty = false
		return state_for_order(e) if not e.order.is_empty() else &"idle"
	if e.order.is_empty():
		return &"idle"
	if String(e.order.get("type", "")) == "attack_move":
		var def := e.unit_def()
		if def != null and def.has_weapon() and (e.state_ticks % GameConfig.SCAN_INTERVAL) == 0:
			var enemy: SimEntity = gs.find_nearest_enemy(e, def.aggro_range)
			if enemy != null:
				e.resume_order = e.order.duplicate()
				e.order = {"type": "attack", "target": enemy.id, "auto": true}
				return &"attack"
	if Locomotion.step(e, gs):
		e.order = {}
		return &"idle"
	return name
