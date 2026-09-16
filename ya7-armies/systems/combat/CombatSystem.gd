extends RefCounted
## CombatSystem — أبراج الدفاع التلقائية + تنظيف الجثث/الحطام بعد DEATH_TICKS.
## ضرر الوحدات نفسه يُطبَّق من AttackState عبر gs.apply_damage().


func tick(gs: Node) -> void:
	var ids: Array = gs.entities.keys()
	ids.sort()
	var to_remove: Array[int] = []
	for id in ids:
		var e: SimEntity = gs.entities[id]
		if not e.alive:
			if e.is_resource():
				to_remove.append(id)
				continue
			e.state_ticks += 1
			if e.state_ticks >= GameConfig.DEATH_TICKS:
				to_remove.append(id)
			continue
		if e.is_building():
			_tick_tower(gs, e)
	for id in to_remove:
		gs.remove_entity(id)


func _tick_tower(gs: Node, b: SimEntity) -> void:
	var def := b.building_def()
	if def == null or not def.has_weapon() or not b.data.get("completed", false):
		return
	if b.cooldown > 0:
		b.cooldown -= 1
	var target: SimEntity = gs.get_entity(b.target_id)
	if target == null or not target.alive or Locomotion.distance_to_entity(b.pos, target) > def.attack_range:
		target = null
		b.target_id = -1
		if (gs.tick + b.id) % GameConfig.SCAN_INTERVAL == 0:
			target = gs.find_nearest_enemy(b, def.attack_range)
			if target != null:
				b.target_id = target.id
	if target == null:
		return
	Locomotion.face_towards(b, target.pos)
	if b.cooldown <= 0:
		gs.apply_damage(target.id, def.damage, b.id)
		b.cooldown = def.fire_cooldown_ticks
		b.last_fire_tick = gs.tick
