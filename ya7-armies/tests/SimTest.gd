extends Node
## اختبار headless للمحاكاة: يشغّل مباراة بدون عرض لعدد فريمات ثم يطبع ملخصًا.
## تشغيل: godot --headless --path . tests/SimTest.tscn

const TICKS: int = 30 * 60  # دقيقة لعب


func _ready() -> void:
	GameState.new_game(12345)
	GameState.start_match()
	# نوقف التقدم التلقائي ونتحكم يدويًا لضمان الحتمية داخل الاختبار
	GameState.running = false
	var snap_a := _run(TICKS)
	# نعيد نفس البذرة ونتأكد أن النتيجة متطابقة (حتمية)
	GameState.new_game(12345)
	GameState.start_match()
	GameState.running = false
	var snap_b := _run(TICKS)
	print("[SimTest] deterministic: ", snap_a == snap_b)
	print("[SimTest] summary: ", snap_a)
	get_tree().quit(0 if snap_a == snap_b else 1)


func _run(n: int) -> Dictionary:
	# نطلب إنتاج جندي من ثكنة اللاعب ونرسله للهجوم عند خروجه
	var barracks_id := -1
	for e: SimEntity in GameState.entities_of(GameConfig.PLAYER_ID, SimEntity.Kind.BUILDING):
		if e.def_id == &"barracks":
			barracks_id = e.id
	assert(barracks_id > 0)
	assert(GameState.enqueue_production(barracks_id, &"soldier"))
	var produced: Array[int] = []
	GameState.unit_produced.connect(func(_b: int, u: int) -> void: produced.append(u))
	for i in n:
		GameState.running = true
		GameState._physics_process(1.0 / GameConfig.TICK_RATE)
		GameState.running = false
		if i == 200 and not produced.is_empty():
			var hq := GameState.find_enemy_hq(GameConfig.PLAYER_ID)
			GameState.issue_command(produced, {"type": "attack_move", "pos": hq.pos})
	var units_p := GameState.entities_of(GameConfig.PLAYER_ID, SimEntity.Kind.UNIT)
	var units_ai := GameState.entities_of(GameConfig.AI_ID, SimEntity.Kind.UNIT)
	var states := {}
	for u in units_p + units_ai:
		states[u.id] = String(u.state)
	var soldier_pos := Vector3.ZERO
	if not produced.is_empty() and GameState.get_entity(produced[0]) != null:
		soldier_pos = GameState.get_entity(produced[0]).pos
	return {
		"tick": GameState.tick,
		"credits_player": GameState.get_credits(GameConfig.PLAYER_ID),
		"credits_ai": GameState.get_credits(GameConfig.AI_ID),
		"units_player": units_p.size(),
		"units_ai": units_ai.size(),
		"produced": produced.size(),
		"soldier_pos": soldier_pos,
		"states": states,
		"rng_calls": RNG.call_count,
		"cmds": GameState.command_log.size(),
	}
