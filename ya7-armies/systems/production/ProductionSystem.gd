extends RefCounted
## ProductionSystem — بناء المباني (construction) + قوائم إنتاج الوحدات.
## مبني على البيانات: BuildingData.producible_units يحدد ما ينتجه كل مبنى.


func tick(gs: Node) -> void:
	var ids: Array = gs.entities.keys()
	ids.sort()
	for id in ids:
		var b: SimEntity = gs.entities[id]
		if not b.is_building() or not b.alive:
			continue
		var def := b.building_def()
		if def == null:
			continue
		if not b.data.get("completed", false):
			_tick_construction(b, def)
			continue
		var queue: Array = b.data.queue
		if queue.is_empty():
			continue
		var item: Dictionary = queue[0]
		item.progress = int(item.progress) + 1
		if item.progress >= int(item.total):
			queue.pop_front()
			_spawn_produced(gs, b, def, StringName(String(item.def)))


func _tick_construction(b: SimEntity, def: BuildingData) -> void:
	b.data.construction = int(b.data.construction) + 1
	var t := float(b.data.construction) / float(maxi(def.build_ticks, 1))
	# الصحة تنمو مع التقدّم (كما في RTS الكلاسيكية)
	b.hp = maxf(b.hp, def.max_hp * lerpf(0.1, 1.0, clampf(t, 0.0, 1.0)))
	if b.data.construction >= def.build_ticks:
		b.data.completed = true
		b.hp = maxf(b.hp, def.max_hp)


func _spawn_produced(gs: Node, b: SimEntity, def: BuildingData, unit_def_id: StringName) -> void:
	var origin: Vector2i = b.data.cell
	var rally: Vector3 = b.data.rally
	var spawn_cell: Vector2i = gs.nav.nearest_adjacent_walkable(origin, def.footprint, rally)
	var spawn_pos: Vector3 = gs.map.cell_to_world(spawn_cell)
	var uid: int = gs.spawn_unit(unit_def_id, b.owner_id, spawn_pos)
	if uid < 0:
		return
	var u: SimEntity = gs.get_entity(uid)
	u.facing = atan2(rally.x - spawn_pos.x, rally.z - spawn_pos.z)
	gs.unit_produced.emit(b.id, uid)
	var udef := GameConfig.get_unit_def(unit_def_id)
	if udef != null and udef.can_harvest:
		# الحصّادة الجديدة تبدأ الجمع تلقائيًا
		var res: SimEntity = gs.find_nearest(spawn_pos, func(e: SimEntity) -> bool:
			return e.is_resource() and e.alive and int(e.data.get("amount", 0)) > 0, 1e9)
		if res != null:
			gs.issue_command([uid], {"type": "gather", "target": res.id})
			return
	gs.issue_command([uid], {"type": "move", "pos": rally})
