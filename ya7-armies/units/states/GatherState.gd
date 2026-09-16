extends UnitState
## Gather — دورة الحصّادة: إلى المورد → جمع → إلى المصفاة → تفريغ → تكرار.
## المراحل في e.data.gather_phase: to_node / mining / to_refinery / unloading

const REACH_DIST: float = 1.7


func _init() -> void:
	name = &"gather"


func enter(e: SimEntity, gs: Node) -> void:
	e.order_dirty = false
	var target := int(e.order.get("target", -1))
	if target > 0:
		e.data.resource_id = target
	e.path = PackedVector3Array()
	# لو الحمولة ممتلئة نروح للمصفاة مباشرة
	var def := e.unit_def()
	if def != null and e.cargo >= def.cargo_capacity:
		_go_to_refinery(e, gs)
	else:
		_go_to_node(e, gs)


func tick(e: SimEntity, gs: Node) -> StringName:
	if e.order_dirty:
		e.order_dirty = false
		return state_for_order(e) if not e.order.is_empty() else &"idle"
	var def := e.unit_def()
	if def == null:
		return &"idle"
	match String(e.data.get("gather_phase", "to_node")):
		"to_node":
			var node: SimEntity = gs.get_entity(int(e.data.get("resource_id", -1)))
			if node == null or not node.alive:
				if not _retarget_resource(e, gs):
					return _stop(e)
				_go_to_node(e, gs)
				return name
			if _near(e, node):
				e.path = PackedVector3Array()
				Locomotion.face_towards(e, node.pos)
				e.data.gather_phase = "mining"
				e.data.gather_timer = 0
			else:
				if e.path.is_empty():
					_go_to_node(e, gs)
				Locomotion.step(e, gs)
		"mining":
			var node: SimEntity = gs.get_entity(int(e.data.get("resource_id", -1)))
			if node == null or not node.alive or int(node.data.get("amount", 0)) <= 0:
				if e.cargo > 0:
					_go_to_refinery(e, gs)
				elif not _retarget_resource(e, gs):
					return _stop(e)
				else:
					_go_to_node(e, gs)
				return name
			e.data.gather_timer = int(e.data.get("gather_timer", 0)) + 1
			if e.data.gather_timer >= def.gather_ticks_per_unit:
				e.data.gather_timer = 0
				var take := mini(5, mini(def.cargo_capacity - e.cargo, int(node.data.amount)))
				e.cargo += take
				node.data.amount = int(node.data.amount) - take
				node.hp = float(node.data.amount)
			if e.cargo >= def.cargo_capacity:
				_go_to_refinery(e, gs)
		"to_refinery":
			var refinery: SimEntity = gs.get_entity(int(e.data.get("refinery_id", -1)))
			if refinery == null or not refinery.alive:
				if not _go_to_refinery(e, gs):
					return _stop(e)
				return name
			if _near(e, refinery):
				e.path = PackedVector3Array()
				Locomotion.face_towards(e, refinery.pos)
				e.data.gather_phase = "unloading"
				e.data.gather_timer = 0
			else:
				if e.path.is_empty():
					_go_to_refinery(e, gs)
				Locomotion.step(e, gs)
		"unloading":
			e.data.gather_timer = int(e.data.get("gather_timer", 0)) + 1
			if e.data.gather_timer >= def.unload_ticks:
				gs.add_credits(e.owner_id, e.cargo)
				e.cargo = 0
				e.data.gather_timer = 0
				if not _go_to_node(e, gs):
					if not _retarget_resource(e, gs):
						return _stop(e)
					_go_to_node(e, gs)
	return name


func _near(e: SimEntity, target: SimEntity) -> bool:
	# وصلنا لو كنا ملاصقين لحافة البصمة، أو انتهى المسار المطلوب أصلًا إلى الخلية المجاورة
	if Locomotion.distance_to_entity(e.pos, target) <= REACH_DIST:
		return true
	return not e.path.is_empty() and e.path_index >= e.path.size()


func _go_to_node(e: SimEntity, gs: Node) -> bool:
	var node: SimEntity = gs.get_entity(int(e.data.get("resource_id", -1)))
	if node == null or not node.alive:
		return false
	e.data.gather_phase = "to_node"
	var cell: Vector2i = gs.nav.nearest_adjacent_walkable(node.data.cell, node.data.footprint, e.pos)
	return Locomotion.request_path(e, gs, gs.map.cell_to_world(cell))


func _go_to_refinery(e: SimEntity, gs: Node) -> bool:
	var refinery: SimEntity = gs.find_nearest(e.pos, func(o: SimEntity) -> bool:
		if not o.is_building() or not o.alive or o.owner_id != e.owner_id:
			return false
		if not o.data.get("completed", false):
			return false
		var d := o.building_def()
		return d != null and d.is_refinery, 1e9)
	if refinery == null:
		return false
	e.data.refinery_id = refinery.id
	e.data.gather_phase = "to_refinery"
	var cell: Vector2i = gs.nav.nearest_adjacent_walkable(refinery.data.cell, refinery.data.footprint, e.pos)
	return Locomotion.request_path(e, gs, gs.map.cell_to_world(cell))


func _retarget_resource(e: SimEntity, gs: Node) -> bool:
	var node: SimEntity = gs.find_nearest(e.pos, func(o: SimEntity) -> bool:
		return o.is_resource() and o.alive and int(o.data.get("amount", 0)) > 0, 1e9)
	if node == null:
		return false
	e.data.resource_id = node.id
	return true


func _stop(e: SimEntity) -> StringName:
	e.order = {}
	e.data.erase("resource_id")
	e.data.gather_phase = "to_node"
	return &"idle"
