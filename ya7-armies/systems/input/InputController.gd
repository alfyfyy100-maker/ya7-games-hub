class_name InputController
extends Node
## InputController — تحكم موحّد لمس/فأرة (اللمس أولًا):
##  - إصبع واحد: سحب = تحريك الكاميرا (وضع PAN) أو مربع تحديد (وضع SELECT) — التبديل من HUD.
##  - نقرة: اختيار وحدة/مبنى مملوك، أو إصدار أمر (تحرك/هجوم/جمع) للوحدات المختارة.
##  - إصبعان: pinch = زوم، تدوير = لفّ الكاميرا، سحب = تحريك.
##  - فأرة إضافيًا: زر يمين = أمر، عجلة = زوم، زر أوسط = تحريك، Q/E لفّ، WASD تحريك.
## كل الأوامر تمر عبر GameState.issue_command — لا يلمس هذا السكربت الحالة مباشرة.

enum DragMode { PAN, SELECT }
enum Tool { NONE, RALLY, BUILD }

signal drag_mode_changed(mode: int)
signal tool_changed(tool: int)
signal message(text: String)

const TAP_MOVE_THRESHOLD_PX: float = 14.0
const PICK_EXTRA_PX: float = 12.0

@export var camera_rig_path: NodePath
@export var world_view_path: NodePath
@export var hud_path: NodePath
@export var overlay_path: NodePath

var drag_mode: int = DragMode.PAN
var tool: int = Tool.NONE
var attack_move_mode: bool = false
var build_def_id: StringName = &""

var _rig: CameraRig
var _world: WorldView
var _hud: HUD
var _overlay: Control

var _touches: Dictionary = {}     # index -> Vector2 (الموقع الحالي)
var _primary: int = -1
var _primary_start: Vector2 = Vector2.ZERO
var _primary_last: Vector2 = Vector2.ZERO
var _primary_moved: bool = false
var _primary_over_ui: bool = false
var _box_active: bool = false
var _pinch_active: bool = false
var _pinch_dist: float = 0.0
var _pinch_angle: float = 0.0
var _pinch_center: Vector2 = Vector2.ZERO
var _middle_drag: bool = false
var _last_pointer: Vector2 = Vector2.ZERO

var _ghost: Node3D
var _ghost_cell: Vector2i = Vector2i(-1, -1)
var _ghost_valid: bool = false


func _ready() -> void:
	_rig = get_node(camera_rig_path)
	_world = get_node(world_view_path)
	_hud = get_node(hud_path)
	_overlay = get_node(overlay_path)


func set_drag_mode(mode: int) -> void:
	drag_mode = mode
	drag_mode_changed.emit(mode)


func toggle_drag_mode() -> void:
	set_drag_mode(DragMode.SELECT if drag_mode == DragMode.PAN else DragMode.PAN)


func set_tool(new_tool: int, def_id: StringName = &"") -> void:
	tool = new_tool
	build_def_id = def_id
	_update_ghost_visibility()
	tool_changed.emit(new_tool)


func cancel_tool() -> void:
	set_tool(Tool.NONE)


# ------------------------------------------------------------------ الإدخال

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMagnifyGesture:
		_rig.zoom_by(1.0 / event.factor, event.position)
	elif event is InputEventPanGesture:
		_rig.pan_local(Vector2(-event.delta.x, event.delta.y), 0.6)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_last_pointer = event.position
		if _middle_drag:
			_rig.pan_screen(event.position - event.relative, event.position)
		elif tool == Tool.BUILD:
			_update_ghost(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if tool != Tool.NONE:
				cancel_tool()
			else:
				_world.clear_selection()
		elif event.keycode == KEY_TAB:
			toggle_drag_mode()


func _on_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		_touches[ev.index] = ev.position
		_last_pointer = ev.position
		if _touches.size() == 1:
			_primary = ev.index
			_primary_start = ev.position
			_primary_last = ev.position
			_primary_moved = false
			_primary_over_ui = _hud.is_point_over_ui(ev.position)
			_box_active = false
		elif _touches.size() == 2:
			# إصبع ثانٍ: نلغي التحديد/السحب الأحادي ونبدأ pinch
			_end_box(false)
			_primary = -1
			_pinch_active = true
			var pts := _touches.values()
			_pinch_dist = pts[0].distance_to(pts[1])
			_pinch_angle = (pts[1] - pts[0]).angle()
			_pinch_center = (pts[0] + pts[1]) * 0.5
	else:
		if ev.index == _primary:
			if _box_active:
				_end_box(true)
			elif not _primary_moved and not _primary_over_ui:
				_on_tap(ev.position)
			_primary = -1
		_touches.erase(ev.index)
		if _touches.size() < 2:
			_pinch_active = false


func _on_drag(ev: InputEventScreenDrag) -> void:
	_touches[ev.index] = ev.position
	_last_pointer = ev.position
	if _pinch_active and _touches.size() >= 2:
		var pts := _touches.values()
		var dist: float = pts[0].distance_to(pts[1])
		var ang: float = (pts[1] - pts[0]).angle()
		var center: Vector2 = (pts[0] + pts[1]) * 0.5
		if _pinch_dist > 1.0:
			_rig.zoom_by(_pinch_dist / maxf(dist, 1.0), center)
		_rig.rotate_by(-wrapf(ang - _pinch_angle, -PI, PI))
		_rig.pan_screen(_pinch_center, center)
		_pinch_dist = dist
		_pinch_angle = ang
		_pinch_center = center
		return
	if ev.index != _primary or _primary_over_ui:
		return
	if not _primary_moved and ev.position.distance_to(_primary_start) > TAP_MOVE_THRESHOLD_PX:
		_primary_moved = true
		if drag_mode == DragMode.SELECT and tool == Tool.NONE:
			_box_active = true
	if _box_active:
		_overlay.set_selection_box(Rect2(_primary_start, ev.position - _primary_start).abs())
	elif _primary_moved:
		if tool == Tool.BUILD:
			_update_ghost(ev.position)
		_rig.pan_screen(_primary_last, ev.position)
	_primary_last = ev.position


func _on_mouse_button(ev: InputEventMouseButton) -> void:
	match ev.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if ev.pressed:
				_rig.zoom_by(0.9, ev.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if ev.pressed:
				_rig.zoom_by(1.1, ev.position)
		MOUSE_BUTTON_MIDDLE:
			_middle_drag = ev.pressed
		MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				if tool != Tool.NONE:
					cancel_tool()
				elif not _hud.is_point_over_ui(ev.position):
					_command_at(ev.position)


func _process(delta: float) -> void:
	# لوحة مفاتيح اختيارية (ليست الطريقة الوحيدة للتحكم)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if dir != Vector2.ZERO:
		_rig.pan_local(dir, delta * _rig.zoom * 1.2)
	if Input.is_key_pressed(KEY_Q):
		_rig.rotate_by(delta * 1.5)
	if Input.is_key_pressed(KEY_E):
		_rig.rotate_by(-delta * 1.5)
	if tool == Tool.BUILD and _ghost != null:
		_update_ghost(_last_pointer)


# ------------------------------------------------------------------ النقر والأوامر

func _on_tap(screen_pos: Vector2) -> void:
	match tool:
		Tool.BUILD:
			_try_place_building(screen_pos)
			return
		Tool.RALLY:
			var b := _world.selected_building()
			if b != null:
				GameState.set_rally_point(b.id, _rig.screen_to_ground(screen_pos))
			cancel_tool()
			return
	var hit := pick_entity(screen_pos)
	if hit != null and hit.owner_id == GameConfig.PLAYER_ID:
		_world.set_selection([hit.id])
		return
	var units := _world.selected_units()
	if not units.is_empty():
		_command_at(screen_pos, hit)
		return
	_world.clear_selection()


func _command_at(screen_pos: Vector2, hit: SimEntity = null) -> void:
	var units := _world.selected_units()
	if units.is_empty():
		return
	if hit == null:
		hit = pick_entity(screen_pos)
	if hit != null and hit.alive:
		if hit.is_resource():
			GameState.issue_command(units, {"type": "gather", "target": hit.id})
			return
		if GameState.is_enemy(hit, GameState.get_entity(units[0])):
			GameState.issue_command(units, {"type": "attack", "target": hit.id})
			return
	var ground := _rig.screen_to_ground(screen_pos)
	var type := "attack_move" if attack_move_mode else "move"
	GameState.issue_command(units, {"type": type, "pos": ground})
	attack_move_mode = false
	_overlay.flash_marker(ground, Color(0.4, 1.0, 0.4) if type == "move" else Color(1.0, 0.4, 0.3))


## يختار الكيان الأقرب لموضع الشاشة (بالحجم الظاهري على الشاشة).
func pick_entity(screen_pos: Vector2) -> SimEntity:
	var cam := _rig.camera
	var ppu := _rig.pixels_per_unit()
	var best: SimEntity = null
	var best_d := 1e9
	for e: SimEntity in GameState.entities.values():
		if not e.alive:
			continue
		var r := 0.6
		var h := 0.8
		if e.is_unit():
			var d := e.unit_def()
			if d != null:
				r = d.radius + 0.4
		elif e.is_building():
			var fp: Vector2i = e.data.get("footprint", Vector2i.ONE)
			r = maxf(fp.x, fp.y) * GameConfig.CELL_SIZE * 0.55
			h = 1.2
		var sp := cam.unproject_position(e.pos + Vector3(0, h, 0))
		var d_px := sp.distance_to(screen_pos)
		var limit := r * ppu + PICK_EXTRA_PX
		if d_px <= limit and d_px < best_d:
			# الوحدات لها أولوية على المباني عند التداخل
			if best != null and best.is_unit() and e.is_building():
				continue
			best_d = d_px
			best = e
	return best


func _end_box(apply: bool) -> void:
	if not _box_active:
		return
	_box_active = false
	var rect: Rect2 = _overlay.get_selection_box()
	_overlay.set_selection_box(Rect2())
	if not apply:
		return
	var ids: Array[int] = []
	var cam := _rig.camera
	for e: SimEntity in GameState.entities.values():
		if not e.alive or not e.is_unit() or e.owner_id != GameConfig.PLAYER_ID:
			continue
		var sp := cam.unproject_position(e.pos + Vector3(0, 0.6, 0))
		if rect.has_point(sp):
			ids.append(e.id)
	if ids.is_empty():
		# مربع صغير جدًا يُعامل كنقرة
		if rect.size.length() < TAP_MOVE_THRESHOLD_PX * 2.0:
			_on_tap(rect.position + rect.size * 0.5)
		else:
			_world.clear_selection()
	else:
		_world.set_selection(ids)


# ------------------------------------------------------------------ البناء (ghost)

func _update_ghost_visibility() -> void:
	if tool != Tool.BUILD:
		if _ghost != null:
			_ghost.queue_free()
			_ghost = null
		return
	var def := GameConfig.get_building_def(build_def_id)
	if def == null:
		return
	if _ghost != null:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost.name = "BuildGhost"
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.box_mesh(Vector3(def.footprint.x * GameConfig.CELL_SIZE, def.height, def.footprint.y * GameConfig.CELL_SIZE))
	mi.position = Vector3(0, def.height * 0.5, 0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 1.0, 0.4, 0.45)
	mi.material_override = m
	mi.name = "Box"
	_ghost.add_child(mi)
	_world.add_child(_ghost)
	_update_ghost(_last_pointer)


func _update_ghost(screen_pos: Vector2) -> void:
	if _ghost == null:
		return
	var def := GameConfig.get_building_def(build_def_id)
	if def == null:
		return
	var ground := _rig.screen_to_ground(screen_pos)
	var cell := GameState.map.world_to_cell(ground) - Vector2i(def.footprint.x / 2, def.footprint.y / 2)
	_ghost_cell = cell
	_ghost_valid = GameState.can_place_building(build_def_id, cell, GameConfig.PLAYER_ID)
	var center := GameState.map.cell_to_world(cell) + Vector3(def.footprint.x - 1, 0, def.footprint.y - 1) * GameConfig.CELL_SIZE * 0.5
	_ghost.position = GameState.map.snap_to_ground(center)
	var mi: MeshInstance3D = _ghost.get_node("Box")
	(mi.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.45) if _ghost_valid else Color(1.0, 0.3, 0.3, 0.45)


func _try_place_building(screen_pos: Vector2) -> void:
	_update_ghost(screen_pos)
	var def := GameConfig.get_building_def(build_def_id)
	if def == null:
		cancel_tool()
		return
	if not _ghost_valid:
		message.emit("موقع غير صالح للبناء")
		return
	if GameState.get_credits(GameConfig.PLAYER_ID) < def.cost:
		message.emit("موارد غير كافية")
		return
	var id := GameState.place_building(build_def_id, _ghost_cell, GameConfig.PLAYER_ID)
	if id > 0:
		cancel_tool()
	else:
		message.emit("تعذّر البناء هنا")
