extends Node
## يقيس جودة حركة الحصّادة: عدد التفريغات في 60 ثانية وعدد إعادات المسار بسبب "عالق".
func _ready() -> void:
	GameState.new_game(12345)
	GameState.start_match()
	GameState.running = false
	var harv: SimEntity = null
	for e: SimEntity in GameState.entities_of(1, SimEntity.Kind.UNIT):
		if e.def_id == &"harvester": harv = e
	var start_credits := GameState.get_credits(1)
	var repaths := 0
	var last_stuck := 0
	var jitter := 0.0
	var prev := harv.pos
	var prev_dir := Vector3.ZERO
	for i in 1800:
		GameState.running = true; GameState._physics_process(0.033); GameState.running = false
		var st := int(harv.data.get("stuck_ticks", 0))
		if st == 0 and last_stuck > 0: repaths += 1
		last_stuck = st
		var d := harv.pos - prev
		if d.length() > 0.001:
			var dir := d.normalized()
			if prev_dir != Vector3.ZERO and dir.dot(prev_dir) < 0.0: jitter += 1.0
			prev_dir = dir
		prev = harv.pos
	print("[HarvestTrace] deliveries=", (GameState.get_credits(1) - start_credits) / 120, " stuck_resets=", repaths, " direction_reversals=", jitter, " rng_calls=", RNG.call_count)
	get_tree().quit()
