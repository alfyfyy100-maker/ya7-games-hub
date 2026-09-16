extends RefCounted
## SimpleAI — خصم بسيط للمرحلة الأولى:
##  - يبقي الحصّادات تجمع.
##  - ينتج جنودًا/رماة من الثكنة عندما تتوفر الموارد.
##  - عندما يجمع جيشًا كافيًا يهاجم مقر اللاعب (attack_move).
##  - يبني مصنع مركبات ثم دبابات عندما يغتني.

const THINK_INTERVAL: int = 45
const ATTACK_GROUP_SIZE: int = 7
## لا يهاجم الخصم قبل هذا الفريم (يعطي اللاعب وقتًا للتجهيز).
const FIRST_ATTACK_TICK: int = 30 * 100


func tick(gs: Node) -> void:
	if gs.tick % THINK_INTERVAL != 0:
		return
	for pid in gs.players:
		var p: Dictionary = gs.players[pid]
		if not p.is_ai or p.eliminated:
			continue
		_think(gs, pid)


func _think(gs: Node, pid: int) -> void:
	var units: Array = gs.entities_of(pid, SimEntity.Kind.UNIT)
	var buildings: Array = gs.entities_of(pid, SimEntity.Kind.BUILDING)
	var credits: int = gs.get_credits(pid)

	var harvesters: Array[SimEntity] = []
	var army: Array[SimEntity] = []
	for u: SimEntity in units:
		var d := u.unit_def()
		if d == null:
			continue
		if d.can_harvest:
			harvesters.append(u)
		elif d.has_weapon():
			army.append(u)

	# 1) الحصّادات الخاملة تعود للجمع
	for h in harvesters:
		if h.state == &"idle" and h.order.is_empty():
			var res: SimEntity = gs.find_nearest(h.pos, func(e: SimEntity) -> bool:
				return e.is_resource() and e.alive and int(e.data.get("amount", 0)) > 0, 1e9)
			if res != null:
				gs.issue_command([h.id], {"type": "gather", "target": res.id})

	# 2) الإنتاج (مبني على البيانات: نختار من producible_units لكل مبنى)
	var barracks: SimEntity = null
	var factory: SimEntity = null
	var hq: SimEntity = null
	for b: SimEntity in buildings:
		var d := b.building_def()
		if d == null or not b.data.get("completed", false):
			continue
		if d.is_hq:
			hq = b
		elif d.id == &"war_factory":
			factory = b
		elif d.producible_units.has(&"soldier"):
			barracks = b

	if harvesters.size() < 2 and hq != null and hq.data.queue.is_empty() and credits >= 350 + 200:
		gs.enqueue_production(hq.id, &"harvester")
		credits = gs.get_credits(pid)

	if factory != null and factory.data.queue.is_empty() and credits >= 400:
		gs.enqueue_production(factory.id, &"tank")
		credits = gs.get_credits(pid)

	if barracks != null and barracks.data.queue.size() < 2 and credits >= 100:
		var choice: StringName = &"archer" if (RNG.chance(0.35) and credits >= 150) else &"soldier"
		gs.enqueue_production(barracks.id, choice)
		credits = gs.get_credits(pid)

	# 3) بناء مصنع مركبات عندما نغتني
	if factory == null and hq != null and credits >= 1000 + 300:
		_try_build_near(gs, pid, &"war_factory", hq)

	# 4) الهجوم
	var idle_army: Array[int] = []
	for u in army:
		if u.state == &"idle" and u.order.is_empty():
			idle_army.append(u.id)
	if idle_army.size() >= ATTACK_GROUP_SIZE and gs.tick >= FIRST_ATTACK_TICK:
		var target: SimEntity = gs.find_enemy_hq(pid)
		if target == null:
			target = gs.find_nearest(hq.pos if hq != null else Vector3.ZERO, func(e: SimEntity) -> bool:
				return e.alive and e.is_building() and e.owner_id != pid and e.owner_id != 0, 1e9)
		if target != null:
			gs.issue_command(idle_army, {"type": "attack_move", "pos": target.pos})


func _try_build_near(gs: Node, pid: int, def_id: StringName, anchor: SimEntity) -> void:
	var def := GameConfig.get_building_def(def_id)
	if def == null:
		return
	var origin_center: Vector2i = gs.map.world_to_cell(anchor.pos)
	# نجرّب مواقع حول المقر بترتيب حتمي (مبذور)
	var candidates: Array = []
	for dy in range(-7, 8):
		for dx in range(-7, 8):
			if absi(dx) < 3 and absi(dy) < 3:
				continue
			candidates.append(origin_center + Vector2i(dx, dy))
	RNG.shuffle(candidates)
	for c in candidates:
		if gs.can_place_building(def_id, c, pid):
			gs.place_building(def_id, c, pid)
			return
