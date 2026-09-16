extends Node
## يلتقط لقطات شاشة من المشهد الرئيسي للتحقق البصري (تشغيل عبر Xvfb + OpenGL).
## godot --rendering-driver opengl3 --path . tests/Screenshot.tscn -- out_dir
## المراحل مبنية على فريمات المحاكاة (GameState.tick) وليس على fps الجهاز.

var _main: Node
var _out: String = "/tmp"
var _stage: int = 0
var _pending_shot: String = ""
var _shot_delay: int = 0
var _barracks_id: int = -1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = load("res://maps/Main.tscn").instantiate()
	_main.randomize_seed = false
	add_child(_main)


func _process(_delta: float) -> void:
	if _pending_shot != "":
		_shot_delay -= 1
		if _shot_delay <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_out.path_join(_pending_shot))
			print("[Screenshot] saved ", _pending_shot, " tick=", GameState.tick)
			_pending_shot = ""
			if _stage >= 99:
				get_tree().quit()
		return
	var t := GameState.tick
	match _stage:
		0:
			if t >= 10:
				_stage = 1
				_request("shot_start.png")
		1:
			for e: SimEntity in GameState.entities_of(GameConfig.PLAYER_ID, SimEntity.Kind.BUILDING):
				if e.def_id == &"barracks":
					_barracks_id = e.id
			GameState.enqueue_production(_barracks_id, &"soldier")
			GameState.enqueue_production(_barracks_id, &"archer")
			_main.world_view.set_selection([_barracks_id])
			_stage = 2
		2:
			if t >= 70:
				_stage = 3
				_request("shot_producing.png")
		3:
			if t >= 300:
				# الجندي والرامي خرجا: نختارهم ونرسلهم لمهاجمة مقر الخصم
				var ids: Array[int] = []
				for u: SimEntity in GameState.entities_of(GameConfig.PLAYER_ID, SimEntity.Kind.UNIT):
					if not u.unit_def().can_harvest:
						ids.append(u.id)
				_main.world_view.set_selection(ids)
				var hq: SimEntity = GameState.find_enemy_hq(GameConfig.PLAYER_ID)
				GameState.issue_command(ids, {"type": "attack_move", "pos": hq.pos})
				_main.camera_rig.zoom_by(0.65)
				_main.camera_rig.rotate_by(0.6)
				_stage = 4
				_request("shot_zoom_rotate.png")
		4:
			if t >= 900:
				var hq: SimEntity = GameState.find_enemy_hq(GameConfig.PLAYER_ID)
				_main.camera_rig.focus(hq.pos)
				_main.camera_rig.zoom_by(1.2)
				_stage = 5
				_request("shot_enemy_base.png")
		5:
			if t >= 1500:
				# لقطة للقتال قرب قاعدة الخصم (أو أينما وصل الجنود)
				var units := GameState.entities_of(GameConfig.PLAYER_ID, SimEntity.Kind.UNIT)
				for u: SimEntity in units:
					if not u.unit_def().can_harvest:
						_main.camera_rig.focus(u.pos)
						break
				_stage = 99
				_request("shot_combat.png")


func _request(name: String) -> void:
	_pending_shot = name
	_shot_delay = 2
