class_name WorldView
extends Node3D
## WorldView — جسر بين GameState (بيانات) والعرض (نودات).
## ينشئ/يحذف نودات العرض استجابةً لإشارات GameState، ويدير مجموعة الاختيار (view-only).

signal selection_changed(ids: Array[int])

var views: Dictionary = {}          # id -> Node3D
var selected: Array[int] = []


func attach() -> void:
	if not GameState.entity_spawned.is_connected(_on_spawned):
		GameState.entity_spawned.connect(_on_spawned)
		GameState.entity_removed.connect(_on_removed)
	for id in GameState.entities:
		_on_spawned(id)


func clear() -> void:
	for v in views.values():
		if is_instance_valid(v):
			v.queue_free()
	views.clear()
	selected.clear()
	selection_changed.emit(selected)


func _on_spawned(id: int) -> void:
	if views.has(id):
		return
	var e: SimEntity = GameState.get_entity(id)
	if e == null:
		return
	var v: Node3D
	match e.kind:
		SimEntity.Kind.UNIT:
			v = UnitView.new()
		SimEntity.Kind.BUILDING:
			v = BuildingView.new()
		_:
			v = ResourceView.new()
	v.name = "%s_%d" % [e.def_id, id]
	add_child(v)
	v.setup(e)
	views[id] = v


func _on_removed(id: int) -> void:
	var v = views.get(id)
	if v != null and is_instance_valid(v):
		v.queue_free()
	views.erase(id)
	if selected.has(id):
		selected.erase(id)
		selection_changed.emit(selected)


func get_view(id: int) -> Node3D:
	return views.get(id)


# ------------------------------------------------------------------ الاختيار

func set_selection(ids: Array) -> void:
	for id in selected:
		var v = views.get(id)
		if v != null and is_instance_valid(v) and v.has_method("set_selected"):
			v.set_selected(false)
	selected.clear()
	for id in ids:
		selected.append(int(id))
	for id in selected:
		var v = views.get(id)
		if v != null and is_instance_valid(v) and v.has_method("set_selected"):
			v.set_selected(true)
	selection_changed.emit(selected)


func clear_selection() -> void:
	set_selection([])


func selected_entities() -> Array[SimEntity]:
	var out: Array[SimEntity] = []
	for id in selected:
		var e: SimEntity = GameState.get_entity(id)
		if e != null and e.alive:
			out.append(e)
	return out


func selected_units() -> Array[int]:
	var out: Array[int] = []
	for e in selected_entities():
		if e.is_unit():
			out.append(e.id)
	return out


func selected_building() -> SimEntity:
	for e in selected_entities():
		if e.is_building():
			return e
	return null


func _process(_delta: float) -> void:
	# إزالة الميت من الاختيار
	var changed := false
	for i in range(selected.size() - 1, -1, -1):
		var e: SimEntity = GameState.get_entity(selected[i])
		if e == null or not e.alive:
			selected.remove_at(i)
			changed = true
	if changed:
		selection_changed.emit(selected)
