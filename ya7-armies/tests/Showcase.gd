extends Node
## استعراض كل الوحدات والمباني بنماذجها (للتحقق البصري).
## godot --rendering-driver opengl3 --path . tests/Showcase.tscn -- out_dir

var _main: Node
var _out: String = "/tmp"
var _frame: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_main = load("res://maps/Main.tscn").instantiate()
	_main.randomize_seed = false
	add_child(_main)
	var gs := GameState
	var map: MapState = gs.map
	var base: Vector2i = map.start_cells[GameConfig.PLAYER_ID]
	# مباني إضافية مكتملة
	gs.place_building(&"war_factory", base + Vector2i(3, -6), GameConfig.PLAYER_ID, true)
	gs.place_building(&"defense_tower", base + Vector2i(-4, -6), GameConfig.PLAYER_ID, true)
	gs.place_building(&"defense_tower", base + Vector2i(6, 3), GameConfig.PLAYER_ID, true)
	# وحدات
	var i := 0
	for id in [&"soldier", &"archer", &"engineer", &"tank", &"apc"]:
		var pos := map.cell_to_world(base + Vector2i(-3 + i * 2, 4))
		var uid := gs.spawn_unit(id, GameConfig.PLAYER_ID, pos)
		gs.get_entity(uid).facing = deg_to_rad(20.0 * i)
		i += 1
	# عدو قريب ليتصويب البرج والدبابة عليه
	var enemy_pos := map.cell_to_world(base + Vector2i(8, -4))
	var eid := gs.spawn_unit(&"tank", GameConfig.AI_ID, enemy_pos)
	gs.get_entity(eid).max_hp = 1e6
	gs.get_entity(eid).hp = 1e6
	gs.issue_command([eid], {"type": "stop"})
	_main.camera_rig.focus(map.cell_to_world(base + Vector2i(1, -1)))
	_main.camera_rig.zoom_by(0.75)


func _process(_delta: float) -> void:
	_frame += 1
	# لقطات متتابعة أثناء القتال لالتقاط المقذوفات
	if _frame in [64, 67, 70, 73, 76]:
		get_viewport().get_texture().get_image().save_png(_out.path_join("combat_%d.png" % _frame))
	if _frame == 60:
		get_viewport().get_texture().get_image().save_png(_out.path_join("showcase.png"))
		print("[Showcase] saved tick=", GameState.tick)
		_main.camera_rig.rotate_by(PI * 0.5)
		_main.camera_rig.zoom_by(0.8)
	if _frame == 90:
		get_viewport().get_texture().get_image().save_png(_out.path_join("showcase_2.png"))
		get_tree().quit()
