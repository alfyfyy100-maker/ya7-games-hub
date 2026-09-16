class_name UnitStateMachine
extends RefCounted
## UnitStateMachine — يدير حالات الوحدات (بيانات فقط). حالة واحدة نشطة لكل SimEntity.

var states: Dictionary = {}


func _init() -> void:
	_register(preload("res://units/states/IdleState.gd").new())
	_register(preload("res://units/states/MoveState.gd").new())
	_register(preload("res://units/states/AttackState.gd").new())
	_register(preload("res://units/states/GatherState.gd").new())
	_register(preload("res://units/states/DeadState.gd").new())


func _register(s: UnitState) -> void:
	states[s.name] = s


func change(e: SimEntity, new_state: StringName, gs: Node) -> void:
	if not states.has(new_state):
		push_warning("[UnitStateMachine] unknown state %s" % new_state)
		new_state = &"idle"
	var old: UnitState = states.get(e.state)
	if old != null:
		old.exit(e, gs)
	e.state = new_state
	e.state_ticks = 0
	states[new_state].enter(e, gs)


func tick_entity(e: SimEntity, gs: Node) -> void:
	var s: UnitState = states.get(e.state)
	if s == null:
		change(e, &"idle", gs)
		s = states[&"idle"]
	var next: StringName = s.tick(e, gs)
	e.state_ticks += 1
	if next != e.state:
		change(e, next, gs)
