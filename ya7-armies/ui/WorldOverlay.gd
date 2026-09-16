class_name WorldOverlay
extends Control
## WorldOverlay — رسم ثنائي الأبعاد فوق العالم: أشرطة صحة/تقدّم، مربع التحديد، علامات الأوامر.
## نود واحد يرسم كل شيء = draw call واحد تقريبًا. لا يغيّر الحالة.

@export var camera_rig_path: NodePath
@export var world_view_path: NodePath

var _rig: CameraRig
var _world: WorldView
var _box: Rect2 = Rect2()
var _markers: Array = []   # [{pos:Vector3, color:Color, t:float}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig = get_node(camera_rig_path)
	_world = get_node(world_view_path)


func set_selection_box(r: Rect2) -> void:
	_box = r


func get_selection_box() -> Rect2:
	return _box


func flash_marker(pos: Vector3, color: Color) -> void:
	_markers.append({"pos": pos, "color": color, "t": 0.0})


func _process(delta: float) -> void:
	for m: Dictionary in _markers:
		m.t = float(m.t) + delta
	_markers = _markers.filter(func(m: Dictionary) -> bool: return m.t < 0.6)
	queue_redraw()


func _draw() -> void:
	if _rig == null or GameState.map == null:
		return
	var cam := _rig.camera
	var vp := get_viewport_rect()
	var selected := _world.selected
	for e: SimEntity in GameState.entities.values():
		if not e.alive:
			continue
		var is_sel := selected.has(e.id)
		var show_hp := is_sel or (e.hp < e.max_hp and not e.is_resource())
		var show_prod := false
		var prod_ratio := 0.0
		if e.is_building():
			if not e.data.get("completed", false):
				var def := e.building_def()
				show_prod = true
				prod_ratio = float(e.data.get("construction", 0)) / float(maxi(def.build_ticks, 1))
			elif not (e.data.queue as Array).is_empty():
				var item: Dictionary = e.data.queue[0]
				show_prod = true
				prod_ratio = float(item.progress) / float(maxi(int(item.total), 1))
		if not show_hp and not show_prod:
			continue
		var top := 1.6
		var width := 34.0
		if e.is_building():
			var def := e.building_def()
			top = def.height + 0.9
			width = 60.0
		elif e.is_resource():
			top = 1.8
		var sp := cam.unproject_position(e.pos + Vector3(0, top, 0))
		if cam.is_position_behind(e.pos) or not vp.grow(60).has_point(sp):
			continue
		var x := sp.x - width * 0.5
		var y := sp.y
		if show_hp:
			var ratio := e.hp_ratio() if not e.is_resource() else float(e.data.get("amount", 0)) / maxf(e.max_hp, 1.0)
			var col := Color(0.35, 0.9, 0.35)
			if e.owner_id != GameConfig.PLAYER_ID and e.owner_id != 0:
				col = Color(1.0, 0.35, 0.3)
			elif e.is_resource():
				col = Color(1.0, 0.8, 0.25)
			draw_rect(Rect2(x - 1, y - 1, width + 2, 7), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(x, y, width * ratio, 5), col)
			y += 8
		if show_prod:
			draw_rect(Rect2(x - 1, y - 1, width + 2, 7), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(x, y, width * clampf(prod_ratio, 0.0, 1.0), 5), Color(1.0, 0.85, 0.2))
	# مربع التحديد
	if _box.size.length() > 2.0:
		draw_rect(_box, Color(0.4, 0.8, 1.0, 0.18), true)
		draw_rect(_box, Color(0.5, 0.9, 1.0, 0.9), false, 2.0)
	# علامات الأوامر (حلقة تتلاشى)
	for m: Dictionary in _markers:
		var mpos: Vector3 = m.pos
		var mt: float = m.t
		var mcol: Color = m.color
		var sp := cam.unproject_position(mpos)
		var a: float = 1.0 - mt / 0.6
		draw_arc(sp, 10.0 + mt * 30.0, 0.0, TAU, 20, Color(mcol.r, mcol.g, mcol.b, a), 2.0)
