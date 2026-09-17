extends Node
func _ready() -> void:
	GameState.new_game(777)
	GameState.start_match()
	GameState.running = false
	var m: MapState = GameState.map
	var base: Vector2i = m.start_cells[1]
	var tower := GameState.place_building(&"defense_tower", base + Vector2i(5, 0), 1, true)
	var tank := GameState.spawn_unit(&"tank", 1, m.cell_to_world(base + Vector2i(0, 5)))
	var enemy := GameState.spawn_unit(&"soldier", 2, m.cell_to_world(base + Vector2i(7, 1)))
	var enemy2 := GameState.spawn_unit(&"soldier", 2, m.cell_to_world(base + Vector2i(1, 8)))
	GameState.issue_command([enemy, enemy2], {"type": "stop"})
	var hits := {}
	GameState.damage_dealt.connect(func(t, a, s): hits[s] = hits.get(s, 0) + 1)
	for i in 300:
		GameState.running = true; GameState._physics_process(0.033); GameState.running = false
		if i % 60 == 0:
			var e1 := GameState.get_entity(enemy); var e2 := GameState.get_entity(enemy2); var tk := GameState.get_entity(tank)
			print("t", GameState.tick, " enemy1 hp=", e1.hp if e1 else -1, " enemy2 hp=", e2.hp if e2 else -1, " tank state=", tk.state, " target=", tk.target_id, " tower target=", GameState.get_entity(tower).target_id)
	print("shots by source: ", hits, " (tower id=", tower, ", tank id=", tank, ")")
	get_tree().quit()
