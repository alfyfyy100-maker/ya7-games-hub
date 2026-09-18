extends Node
## سيناريو: جنود اللاعب خاملون بعيدًا عن مدى الاشتباك، والعدو يهاجم الحصّادة/المبنى.
## المتوقع: يهبّون للدفاع، يقتلون المهاجمين، ويعودون لموقعهم؛ والحصّادة تهرب ثم تعود للجمع.

func _ready() -> void:
	GameState.new_game(4242)
	GameState.start_match()
	GameState.running = false
	var m: MapState = GameState.map
	var base: Vector2i = m.start_cells[1]
	var guards: Array[int] = []
	for i in 3:
		guards.append(GameState.spawn_unit(&"soldier", 1, m.cell_to_world(base + Vector2i(-6 + i, 6))))
	var harv_id := -1
	for e: SimEntity in GameState.entities_of(1, SimEntity.Kind.UNIT):
		if e.def_id == &"harvester":
			harv_id = e.id
	# مهاجمان يقتربان من المصفاة/الحصّادة (بعيدان عن مدى الحرس ~ 16 خلية)
	var attackers: Array[int] = []
	for i in 2:
		var a := GameState.spawn_unit(&"soldier", 2, m.cell_to_world(base + Vector2i(9 + i, -3)))
		attackers.append(a)
	GameState.issue_command(attackers, {"type": "attack", "target": harv_id})
	var guard_pos0: Vector3 = GameState.get_entity(guards[0]).pos
	var reacted_tick := -1
	var fled := false
	for i in 30 * 60:
		GameState.running = true
		GameState._physics_process(0.033)
		GameState.running = false
		var g0 := GameState.get_entity(guards[0])
		if reacted_tick < 0 and g0 != null and g0.state == &"attack":
			reacted_tick = GameState.tick
		var h := GameState.get_entity(harv_id)
		if h != null and h.order.get("flee", false):
			fled = true
		if i % 150 == 0:
			var alive_att := 0
			for a in attackers:
				var e := GameState.get_entity(a)
				if e != null and e.alive: alive_att += 1
			print("t", GameState.tick, " guard0=", g0.state if g0 else "dead", " attackers_alive=", alive_att, " harv=", (h.state if h else "dead"), "/", (h.data.get("gather_phase", "") if h else ""), " harv_hp=", (h.hp if h else 0))
	var g0 := GameState.get_entity(guards[0])
	var back := g0 != null and Locomotion.flat_distance(g0.pos, guard_pos0) < 4.0
	var alive_att := 0
	for a in attackers:
		var e := GameState.get_entity(a)
		if e != null and e.alive: alive_att += 1
	var h := GameState.get_entity(harv_id)
	print("[DefenseTest] reacted_at_tick=", reacted_tick, " attackers_alive=", alive_att, " guard_back_at_post=", back, " harvester_fled=", fled, " harvester_alive=", h != null and h.alive, " harvester_state=", h.state if h else "dead")
	var ok := reacted_tick > 0 and alive_att == 0 and back and h != null and h.alive
	print("[DefenseTest] ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
