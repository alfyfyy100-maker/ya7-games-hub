extends Node
## GameState — "حالة اللعبة" الكاملة: كيانات، لاعبون، موارد، أوامر، وخريطة منطقية.
##
## قواعد:
##  - لا يوجد هنا أي نود عرض (Mesh/Animation). العرض يقرأ من هنا فقط عبر الإشارات و get_entity().
##  - المحاكاة تتقدم فريمًا ثابتًا واحدًا في كل _physics_process (tick).
##  - كل التوقيتات بالفريمات. ممنوع OS.get_ticks_msec / Time.* في المنطق.
##  - العشوائية عبر RNG فقط.
##
## لاحقًا للأونلاين: نفس البذرة + نفس تسلسل الأوامر (issue_command بالفريم) = نفس الحالة.

signal entity_spawned(id: int)
signal entity_removed(id: int)
signal entity_died(id: int)
signal credits_changed(player_id: int, credits: int)
signal damage_dealt(target_id: int, amount: float, source_id: int)
signal production_started(building_id: int, unit_def_id: StringName)
signal unit_produced(building_id: int, unit_id: int)
signal building_placed(id: int)
signal game_over(winner_id: int)
signal match_started()

const ProductionSystem := preload("res://systems/production/ProductionSystem.gd")
const UnitSystem := preload("res://systems/simulation/UnitSystem.gd")
const CombatSystem := preload("res://systems/combat/CombatSystem.gd")
const EconomySystem := preload("res://systems/economy/EconomySystem.gd")
const AISystem := preload("res://systems/ai/SimpleAI.gd")
const VictorySystem := preload("res://systems/simulation/VictorySystem.gd")

var tick: int = 0
var running: bool = false
var match_seed: int = 0
var winner_id: int = 0

var entities: Dictionary = {}   # id -> SimEntity
var players: Dictionary = {}    # id -> {credits:int, is_ai:bool, eliminated:bool}
var map: MapState
var nav: NavGrid

var _next_id: int = 1
var _systems: Array = []
## سجل الأوامر بالفريم (للتشخيص والإعادة/الشبكة لاحقًا).
var command_log: Array = []


# ------------------------------------------------------------------ دورة الحياة

func new_game(seed_value: int) -> void:
	reset()
	match_seed = seed_value
	RNG.seed_rng(seed_value)
	map = MapState.new()
	map.generate()
	nav = NavGrid.new()
	nav.build(map)
	players = {
		GameConfig.PLAYER_ID: {"credits": GameConfig.START_CREDITS, "is_ai": false, "eliminated": false},
		GameConfig.AI_ID: {"credits": GameConfig.START_CREDITS, "is_ai": true, "eliminated": false},
	}
	_systems = [
		ProductionSystem.new(),
		UnitSystem.new(),
		CombatSystem.new(),
		EconomySystem.new(),
		AISystem.new(),
		VictorySystem.new(),
	]


## يضع القواعد الابتدائية ويبدأ المحاكاة. يُستدعى بعد أن يربط العرض إشاراته.
func start_match() -> void:
	for cell in map.resource_cells:
		spawn_resource(cell, 3000)
	for pid in players:
		_spawn_start_base(pid, map.start_cells[pid])
	tick = 0
	running = true
	match_started.emit()


func reset() -> void:
	running = false
	winner_id = 0
	tick = 0
	command_log.clear()
	var ids := entities.keys()
	for id in ids:
		remove_entity(id)
	entities.clear()
	_next_id = 1
	_systems.clear()


func _spawn_start_base(pid: int, center: Vector2i) -> void:
	var toward := Vector2(map.width * 0.5 - center.x, map.height * 0.5 - center.y).normalized()
	var side := Vector2(-toward.y, toward.x)
	var hq_id := place_building(&"hq", center - Vector2i(1, 1), pid, true)
	var ref_cell := center + Vector2i((side * 5.0).round())
	place_building(&"refinery", ref_cell - Vector2i(1, 1), pid, true)
	var bar_cell := center - Vector2i((side * 5.0).round())
	place_building(&"barracks", bar_cell - Vector2i(1, 1), pid, true)
	# حصّادة أمام المقر
	var hq := get_entity(hq_id)
	var spawn := map.cell_to_world(nav.nearest_walkable(center + Vector2i((toward * 3.0).round()), 6))
	var harv_id := spawn_unit(&"harvester", pid, spawn)
	if hq != null:
		var h := get_entity(harv_id)
		h.facing = atan2(toward.x, toward.y)
	# الحصّادة تبدأ الجمع تلقائيًا من أقرب مورد
	var res := find_nearest(spawn, func(e: SimEntity) -> bool: return e.is_resource() and e.alive, 1e9)
	if res != null:
		issue_command([harv_id], {"type": "gather", "target": res.id})


func _physics_process(_delta: float) -> void:
	if not running:
		return
	tick += 1
	for e: SimEntity in entities.values():
		e.prev_pos = e.pos
	for s in _systems:
		s.tick(self)


# ------------------------------------------------------------------ كيانات

func get_entity(id: int) -> SimEntity:
	return entities.get(id)


func _alloc_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func spawn_unit(def_id: StringName, owner_id: int, pos: Vector3) -> int:
	var def := GameConfig.get_unit_def(def_id)
	if def == null:
		push_error("[GameState] unknown unit def %s" % def_id)
		return -1
	var e := SimEntity.new()
	e.id = _alloc_id()
	e.kind = SimEntity.Kind.UNIT
	e.def_id = def_id
	e.owner_id = owner_id
	e.pos = map.snap_to_ground(pos)
	e.prev_pos = e.pos
	e.max_hp = def.max_hp
	e.hp = def.max_hp
	e.state = &"idle"
	entities[e.id] = e
	entity_spawned.emit(e.id)
	return e.id


func spawn_resource(cell: Vector2i, amount: int) -> int:
	var e := SimEntity.new()
	e.id = _alloc_id()
	e.kind = SimEntity.Kind.RESOURCE
	e.def_id = &"oil"
	e.owner_id = 0
	e.pos = map.cell_to_world(cell)
	e.prev_pos = e.pos
	e.max_hp = float(amount)
	e.hp = float(amount)
	e.data = {"amount": amount, "cell": cell, "footprint": Vector2i(1, 1)}
	entities[e.id] = e
	nav.occupy([cell], e.id)
	entity_spawned.emit(e.id)
	return e.id


## هل يمكن وضع مبنى في هذه الخلية (الزاوية العلوية اليسرى للبصمة)؟
func can_place_building(def_id: StringName, origin: Vector2i, owner_id: int, ignore_distance: bool = false) -> bool:
	var def := GameConfig.get_building_def(def_id)
	if def == null:
		return false
	for c in NavGrid.footprint_cells(origin, def.footprint):
		if not nav.is_free_for_building(c):
			return false
	# لا نسمح بإغلاق الحلقة المحيطة بالكامل (يجب وجود مخرج واحد على الأقل)
	var has_exit := false
	for c in NavGrid.ring_cells(origin, def.footprint):
		if nav.is_walkable(c):
			has_exit = true
			break
	if not has_exit:
		return false
	if ignore_distance or def.max_build_distance <= 0:
		return true
	var center := map.cell_to_world(origin) + Vector3(def.footprint.x - 1, 0, def.footprint.y - 1) * GameConfig.CELL_SIZE * 0.5
	var limit := float(def.max_build_distance) * GameConfig.CELL_SIZE
	for e: SimEntity in entities.values():
		if e.is_building() and e.alive and e.owner_id == owner_id:
			if e.pos.distance_to(center) <= limit:
				return true
	return false


## يضع مبنى ويخصم التكلفة (إلا لو كان مبنى ابتدائيًا مكتملًا).
func place_building(def_id: StringName, origin: Vector2i, owner_id: int, completed: bool = false) -> int:
	var def := GameConfig.get_building_def(def_id)
	if def == null:
		return -1
	if not can_place_building(def_id, origin, owner_id, completed):
		return -1
	if not completed and not try_spend(owner_id, def.cost):
		return -1
	var e := SimEntity.new()
	e.id = _alloc_id()
	e.kind = SimEntity.Kind.BUILDING
	e.def_id = def_id
	e.owner_id = owner_id
	var cells := NavGrid.footprint_cells(origin, def.footprint)
	var center := Vector3.ZERO
	for c in cells:
		center += map.cell_to_world(c)
	center /= cells.size()
	e.pos = map.snap_to_ground(center)
	e.prev_pos = e.pos
	e.max_hp = def.max_hp
	e.hp = def.max_hp if completed else def.max_hp * 0.1
	e.state = &"idle"
	var rally_cell := origin + Vector2i(def.footprint.x / 2, def.footprint.y) + def.default_rally_offset - Vector2i(0, 1)
	rally_cell = nav.nearest_walkable(rally_cell, 6)
	e.data = {
		"cell": origin,
		"footprint": def.footprint,
		"queue": [],
		"rally": map.cell_to_world(rally_cell),
		"construction": def.build_ticks if completed else 0,
		"completed": completed,
	}
	entities[e.id] = e
	nav.occupy(cells, e.id)
	entity_spawned.emit(e.id)
	building_placed.emit(e.id)
	return e.id


func remove_entity(id: int) -> void:
	var e: SimEntity = entities.get(id)
	if e == null:
		return
	if e.is_building() or e.is_resource():
		nav.release(NavGrid.footprint_cells(e.data.get("cell", Vector2i.ZERO), e.data.get("footprint", Vector2i.ONE)))
	entities.erase(id)
	entity_removed.emit(id)


## يعلّم الكيان ميتًا (تحرير الخلايا فورًا؛ الحذف الفعلي بعد DEATH_TICKS من CombatSystem).
func kill_entity(id: int) -> void:
	var e := get_entity(id)
	if e == null or not e.alive:
		return
	e.alive = false
	e.hp = 0.0
	e.state = &"dead"
	e.state_ticks = 0
	e.order = {}
	e.path = PackedVector3Array()
	if e.is_building() or e.is_resource():
		nav.release(NavGrid.footprint_cells(e.data.get("cell", Vector2i.ZERO), e.data.get("footprint", Vector2i.ONE)))
	entity_died.emit(id)


func apply_damage(target_id: int, amount: float, source_id: int) -> void:
	var t := get_entity(target_id)
	if t == null or not t.alive or t.is_resource():
		return
	t.hp -= amount
	t.last_hit_tick = tick
	damage_dealt.emit(target_id, amount, source_id)
	if t.hp <= 0.0:
		kill_entity(target_id)


# ------------------------------------------------------------------ اقتصاد

func get_credits(player_id: int) -> int:
	return int(players.get(player_id, {}).get("credits", 0))


func try_spend(player_id: int, amount: int) -> bool:
	if not players.has(player_id):
		return false
	if players[player_id].credits < amount:
		return false
	players[player_id].credits -= amount
	credits_changed.emit(player_id, players[player_id].credits)
	return true


func add_credits(player_id: int, amount: int) -> void:
	if not players.has(player_id):
		return
	players[player_id].credits += amount
	credits_changed.emit(player_id, players[player_id].credits)


# ------------------------------------------------------------------ أوامر

## الواجهة الوحيدة لإصدار الأوامر (لاعب أو AI أو شبكة لاحقًا).
## cmd: {type: "move"|"attack"|"attack_move"|"gather"|"stop", pos: Vector3, target: int}
func issue_command(ids: Array, cmd: Dictionary) -> void:
	command_log.append({"tick": tick, "ids": ids.duplicate(), "cmd": cmd.duplicate()})
	var moving_ids: Array[int] = []
	for id in ids:
		var e := get_entity(id)
		if e == null or not e.alive or not e.is_unit():
			continue
		match String(cmd.get("type", "")):
			"stop":
				e.set_order({})
			"move", "attack_move":
				# أمر يدوي للحصّادة يلغي عودتها التلقائية للجمع (تطيع اللاعب)
				e.data.erase("resource_id")
				moving_ids.append(id)
			"attack":
				var def := e.unit_def()
				if def != null and def.has_weapon():
					e.set_order(cmd)
				else:
					# وحدة بلا سلاح تتحرك للهدف بدلًا من الهجوم
					var t := get_entity(int(cmd.get("target", -1)))
					if t != null:
						e.set_order({"type": "move", "pos": t.pos})
			"gather":
				var def := e.unit_def()
				if def != null and def.can_harvest:
					e.set_order(cmd)
				else:
					var t := get_entity(int(cmd.get("target", -1)))
					if t != null:
						e.set_order({"type": "move", "pos": t.pos})
	# توزيع تشكيلي بسيط لأوامر الحركة الجماعية (كل وحدة تحصل على إزاحة)
	if not moving_ids.is_empty():
		var base_pos: Vector3 = cmd.get("pos", Vector3.ZERO)
		var n := moving_ids.size()
		var cols := int(ceil(sqrt(float(n))))
		var spacing := GameConfig.CELL_SIZE * 0.9
		for i in n:
			var e := get_entity(moving_ids[i])
			var col := i % cols
			var row := i / cols
			var off := Vector3((col - (cols - 1) * 0.5) * spacing, 0.0, (row - (cols - 1) * 0.5) * spacing)
			var p := map.clamp_world(base_pos + off)
			var c := nav.nearest_walkable(map.world_to_cell(p), 5)
			var final_pos := map.cell_to_world(c) if n > 1 else map.snap_to_ground(p)
			var o := cmd.duplicate()
			o["pos"] = final_pos
			e.set_order(o)


## يضيف وحدة لقائمة إنتاج مبنى. التكلفة تُخصم فورًا.
func enqueue_production(building_id: int, unit_def_id: StringName) -> bool:
	var b := get_entity(building_id)
	if b == null or not b.is_building() or not b.alive or not b.data.get("completed", false):
		return false
	var bdef := b.building_def()
	var udef := GameConfig.get_unit_def(unit_def_id)
	if bdef == null or udef == null:
		return false
	if not bdef.producible_units.has(unit_def_id):
		return false
	var queue: Array = b.data.queue
	if queue.size() >= 5:
		return false
	if not try_spend(b.owner_id, udef.cost):
		return false
	queue.append({"def": unit_def_id, "progress": 0, "total": udef.build_ticks})
	production_started.emit(building_id, unit_def_id)
	return true


## يلغي آخر عنصر في القائمة ويعيد تكلفته.
func cancel_production(building_id: int) -> void:
	var b := get_entity(building_id)
	if b == null or not b.is_building():
		return
	var queue: Array = b.data.queue
	if queue.is_empty():
		return
	var item: Dictionary = queue.pop_back()
	var udef := GameConfig.get_unit_def(item.def)
	if udef != null:
		add_credits(b.owner_id, udef.cost)


func set_rally_point(building_id: int, pos: Vector3) -> void:
	var b := get_entity(building_id)
	if b == null or not b.is_building():
		return
	var c := nav.nearest_walkable(map.world_to_cell(map.clamp_world(pos)), 6)
	b.data.rally = map.cell_to_world(c)


# ------------------------------------------------------------------ استعلامات

func entities_of(owner_id: int, kind: int = -1, alive_only: bool = true) -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for e: SimEntity in entities.values():
		if e.owner_id != owner_id:
			continue
		if kind >= 0 and e.kind != kind:
			continue
		if alive_only and not e.alive:
			continue
		out.append(e)
	return out


## أقرب كيان يحقق الشرط ضمن مسافة. filter: Callable(SimEntity) -> bool
func find_nearest(pos: Vector3, filter: Callable, max_dist: float) -> SimEntity:
	var best: SimEntity = null
	var best_d := max_dist * max_dist
	for e: SimEntity in entities.values():
		if not filter.call(e):
			continue
		var d := e.pos.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func is_enemy(a: SimEntity, b: SimEntity) -> bool:
	return a.owner_id != b.owner_id and a.owner_id != 0 and b.owner_id != 0


func find_nearest_enemy(e: SimEntity, max_dist: float) -> SimEntity:
	return find_nearest(e.pos, func(o: SimEntity) -> bool:
		return o.alive and not o.is_resource() and is_enemy(e, o), max_dist)


func find_enemy_hq(owner_id: int) -> SimEntity:
	for e: SimEntity in entities.values():
		if e.is_building() and e.alive and e.owner_id != owner_id and e.owner_id != 0:
			var def := e.building_def()
			if def != null and def.is_hq:
				return e
	return null


## لقطة كاملة للحالة (حفظ/شبكة).
func snapshot() -> Dictionary:
	var ents: Array = []
	for e: SimEntity in entities.values():
		ents.append(e.to_dict())
	return {
		"tick": tick, "seed": match_seed, "rng": RNG.get_state(),
		"players": players.duplicate(true), "entities": ents, "next_id": _next_id,
	}
