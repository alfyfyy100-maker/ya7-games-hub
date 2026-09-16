extends UnitState
## Dead — تبقى الجثة DEATH_TICKS فريمًا ثم يُحذف الكيان (الحذف في CombatSystem).


func _init() -> void:
	name = &"dead"


func enter(e: SimEntity, _gs: Node) -> void:
	e.alive = false
	e.order = {}
	e.path = PackedVector3Array()
	e.target_id = -1


func tick(_e: SimEntity, _gs: Node) -> StringName:
	return name
