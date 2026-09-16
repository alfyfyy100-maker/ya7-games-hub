extends RefCounted
## UnitSystem — يشغّل آلة الحالة لكل وحدة حية في كل فريم.

var fsm: UnitStateMachine = UnitStateMachine.new()


func tick(gs: Node) -> void:
	# ترتيب ثابت بالمعرّف = سلوك حتمي
	var ids: Array = gs.entities.keys()
	ids.sort()
	for id in ids:
		var e: SimEntity = gs.entities[id]
		if not e.is_unit():
			continue
		if not e.alive:
			if e.state != &"dead":
				fsm.change(e, &"dead", gs)
			continue
		fsm.tick_entity(e, gs)
