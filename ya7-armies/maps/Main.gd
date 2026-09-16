extends Node3D
## Main — يجمع الطبقات: المحاكاة (GameState) ← العرض (Terrain/WorldView) ← التحكم (Input/HUD).

## بذرة ثابتة افتراضيًا (مباراة قابلة للتكرار). عند تفعيل randomize_seed تؤخذ من ساعة النظام
## — خارج منطق اللعبة تمامًا؛ المنطق نفسه يرى فقط البذرة.
@export var match_seed: int = 12345
@export var randomize_seed: bool = true

@onready var terrain: Node3D = $Terrain
@onready var decor: Node3D = $Decor
@onready var world_view: WorldView = $WorldView
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HUD = $UI/HUD
@onready var overlay: WorldOverlay = $UI/Overlay


func _ready() -> void:
	# إضاءة مسطحة من زاوية ثابتة بدون ظلال ديناميكية (toon)
	$Sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	hud.restart_requested.connect(func() -> void:
		if randomize_seed:
			match_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
		start_match(match_seed))
	if randomize_seed:
		match_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	start_match(match_seed)


func start_match(seed_value: int) -> void:
	world_view.clear()
	GameState.new_game(seed_value)
	terrain.build(GameState.map)
	decor.build(GameState.map)
	camera_rig.set_map(GameState.map)
	world_view.attach()
	GameState.start_match()
	var hq_cell: Vector2i = GameState.map.start_cells[GameConfig.PLAYER_ID]
	camera_rig.focus(GameState.map.cell_to_world(hq_cell))
	print("[Main] match started, seed=%d" % seed_value)
