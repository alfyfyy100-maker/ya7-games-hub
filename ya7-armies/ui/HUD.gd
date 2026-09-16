class_name HUD
extends Control
## HUD — واجهة لمسية متكيّفة (Control + anchors):
##  - شريط علوي: الموارد، الوقت (بالفريمات المحوَّلة)، زر وضع السحب (تحريك/تحديد).
##  - لوحة سفلية سياقية: قائمة إنتاج المبنى المختار (من BuildingData.producible_units)،
##    أو قائمة البناء عند عدم اختيار شيء، أو أوامر الوحدات المختارة.
##  - رسائل عابرة + شاشة نهاية اللعبة.

signal restart_requested()

@export var input_path: NodePath
@export var world_view_path: NodePath

var _input: InputController
var _world: WorldView

var top_bar: PanelContainer
var bottom_panel: PanelContainer
var credits_label: Label
var time_label: Label
var mode_button: Button
var info_label: Label
var actions_box: HBoxContainer
var message_label: Label
var game_over_panel: PanelContainer
var game_over_label: Label

var _message_timer: float = 0.0
var _refresh_timer: float = 0.0
var _seen_building_id: int = -1
var _last_credits: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input = get_node(input_path)
	_world = get_node(world_view_path)
	_build_layout()
	_world.selection_changed.connect(func(_ids: Array[int]) -> void: refresh_actions())
	_input.drag_mode_changed.connect(func(_m: int) -> void: _update_mode_button())
	_input.tool_changed.connect(func(_t: int) -> void: refresh_actions())
	_input.message.connect(show_message)
	GameState.credits_changed.connect(func(pid: int, _c: int) -> void:
		if pid == GameConfig.PLAYER_ID:
			refresh_actions())
	GameState.game_over.connect(_on_game_over)
	GameState.match_started.connect(func() -> void:
		game_over_panel.visible = false
		refresh_actions())
	_update_mode_button()
	refresh_actions()


func _build_layout() -> void:
	# ---- الشريط العلوي
	top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 56
	add_child(top_bar)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top_bar.add_child(top)
	credits_label = _label("$ 0", 22)
	credits_label.custom_minimum_size.x = 140
	top.add_child(credits_label)
	time_label = _label("00:00", 18)
	top.add_child(time_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	mode_button = _button("سحب: تحريك", Vector2(170, 44))
	mode_button.pressed.connect(_input.toggle_drag_mode)
	top.add_child(mode_button)

	# ---- اللوحة السفلية
	bottom_panel = PanelContainer.new()
	bottom_panel.name = "BottomPanel"
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -118
	add_child(bottom_panel)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom_panel.add_child(bottom)
	info_label = _label("", 16)
	info_label.custom_minimum_size.x = 230
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(info_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	actions_box = HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 8)
	scroll.add_child(actions_box)

	# ---- رسالة عابرة
	message_label = _label("", 20)
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_top = 70
	message_label.offset_bottom = 110
	message_label.offset_left = -300
	message_label.offset_right = 300
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.modulate.a = 0.0
	add_child(message_label)

	# ---- نهاية اللعبة
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_over_panel.offset_left = -180
	game_over_panel.offset_right = 180
	game_over_panel.offset_top = -80
	game_over_panel.offset_bottom = 80
	game_over_panel.visible = false
	add_child(game_over_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vb)
	game_over_label = _label("", 26)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(game_over_label)
	var restart := _button("مباراة جديدة", Vector2(200, 52))
	restart.pressed.connect(func() -> void: restart_requested.emit())
	vb.add_child(restart)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	return b


## هل النقطة فوق عنصر واجهة (لتجاهلها في التحكم بالعالم)؟
func is_point_over_ui(p: Vector2) -> bool:
	for c in [top_bar, bottom_panel, game_over_panel]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false


func show_message(text: String) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	_message_timer = 2.0


func _process(delta: float) -> void:
	credits_label.text = "$ %d" % GameState.get_credits(GameConfig.PLAYER_ID)
	var secs := GameState.tick / GameConfig.TICK_RATE
	time_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	if _message_timer > 0.0:
		_message_timer -= delta
		message_label.modulate.a = clampf(_message_timer, 0.0, 1.0)
	# تحديث دوري خفيف لحالة الأزرار (القائمة/الموارد)
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_refresh_info()


func _update_mode_button() -> void:
	mode_button.text = "سحب: تحريك" if _input.drag_mode == InputController.DragMode.PAN else "سحب: تحديد"


func _clear_actions() -> void:
	for c in actions_box.get_children():
		c.queue_free()


## يبني الأزرار السياقية حسب الاختيار الحالي.
func refresh_actions() -> void:
	_clear_actions()
	var credits := GameState.get_credits(GameConfig.PLAYER_ID)
	var building := _world.selected_building()
	var units := _world.selected_units()

	if _input.tool == InputController.Tool.BUILD or _input.tool == InputController.Tool.RALLY:
		var cancel := _button("إلغاء", Vector2(110, 80))
		cancel.pressed.connect(_input.cancel_tool)
		actions_box.add_child(cancel)
		_refresh_info()
		return

	if building != null:
		var def := building.building_def()
		if def != null and building.data.get("completed", false):
			for uid in def.producible_units:
				var udef := GameConfig.get_unit_def(uid)
				if udef == null:
					continue
				var b := _button("%s\n$%d" % [udef.display_name, udef.cost], Vector2(110, 80))
				b.disabled = credits < udef.cost
				b.pressed.connect(func() -> void:
					if not GameState.enqueue_production(building.id, uid):
						show_message("لا يمكن الإنتاج الآن"))
				actions_box.add_child(b)
			if def.can_produce():
				var rally := _button("نقطة\nالتجمع", Vector2(100, 80))
				rally.pressed.connect(func() -> void:
					_input.set_tool(InputController.Tool.RALLY)
					show_message("انقر على الأرض لتحديد نقطة التجمع"))
				actions_box.add_child(rally)
				var cancel_q := _button("إلغاء\nآخر إنتاج", Vector2(100, 80))
				cancel_q.pressed.connect(func() -> void: GameState.cancel_production(building.id))
				actions_box.add_child(cancel_q)
		_refresh_info()
		return

	if not units.is_empty():
		var stop := _button("توقف", Vector2(100, 80))
		stop.pressed.connect(func() -> void: GameState.issue_command(_world.selected_units(), {"type": "stop"}))
		actions_box.add_child(stop)
		var am := _button("هجوم-تحرك", Vector2(120, 80))
		am.toggle_mode = true
		am.button_pressed = _input.attack_move_mode
		am.toggled.connect(func(on: bool) -> void:
			_input.attack_move_mode = on
			if on:
				show_message("انقر على الأرض للهجوم أثناء التحرك"))
		actions_box.add_child(am)
		_refresh_info()
		return

	# لا شيء مختار: قائمة البناء (مبنية على البيانات)
	for bdef in GameConfig.get_constructible_buildings():
		var b := _button("%s\n$%d" % [bdef.display_name, bdef.cost], Vector2(120, 80))
		b.disabled = credits < bdef.cost
		b.pressed.connect(func() -> void:
			_input.set_tool(InputController.Tool.BUILD, bdef.id)
			show_message("انقر على الأرض لوضع المبنى"))
		actions_box.add_child(b)
	_refresh_info()


func _refresh_info() -> void:
	var building := _world.selected_building()
	var units := _world.selected_units()
	if _input.tool == InputController.Tool.BUILD:
		var d := GameConfig.get_building_def(_input.build_def_id)
		info_label.text = "بناء: %s" % (d.display_name if d != null else "")
		return
	if building != null:
		var def := building.building_def()
		var txt := "%s\n%d / %d" % [def.display_name, int(building.hp), int(building.max_hp)]
		if not building.data.get("completed", false):
			txt += "\n(قيد البناء)"
		else:
			var q: Array = building.data.queue
			if not q.is_empty():
				txt += "\nقائمة الإنتاج: %d" % q.size()
		info_label.text = txt
		return
	if not units.is_empty():
		if units.size() == 1:
			var e: SimEntity = GameState.get_entity(units[0])
			var d := e.unit_def()
			info_label.text = "%s  %d/%d\nانقر الأرض للتحرك، أو عدوًا للهجوم" % [d.display_name, int(e.hp), int(e.max_hp)]
		else:
			info_label.text = "%d وحدات مختارة\nانقر الأرض للتحرك، أو عدوًا للهجوم" % units.size()
		return
	info_label.text = "قائمة البناء\nانقر وحدة/مبنى لاختياره"


func _on_game_over(winner: int) -> void:
	game_over_panel.visible = true
	if winner == GameConfig.PLAYER_ID:
		game_over_label.text = "انتصار! 🎉"
	elif winner == 0:
		game_over_label.text = "تعادل"
	else:
		game_over_label.text = "هزيمة"
