extends RefCounted
## EconomySystem — يزيل نقاط الموارد المستنفدة. (الإيداع نفسه يتم في GatherState عبر gs.add_credits)
## مكان مناسب لاحقًا لأي دخل دوري/صيانة/حدود سكان.


func tick(gs: Node) -> void:
	if gs.tick % 15 != 0:
		return
	var ids: Array = gs.entities.keys()
	ids.sort()
	for id in ids:
		var e: SimEntity = gs.entities[id]
		if e.is_resource() and e.alive and int(e.data.get("amount", 0)) <= 0:
			gs.kill_entity(id)
