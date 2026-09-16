extends RefCounted
## VictorySystem — شرط الفوز: اللاعب يُقصى عندما تُدمَّر كل مبانيه.

const CHECK_INTERVAL: int = 30


func tick(gs: Node) -> void:
	if gs.tick % CHECK_INTERVAL != 0 or gs.tick == 0:
		return
	var alive_players: Array[int] = []
	for pid in gs.players:
		var p: Dictionary = gs.players[pid]
		if p.eliminated:
			continue
		var buildings: Array = gs.entities_of(pid, SimEntity.Kind.BUILDING)
		if buildings.is_empty():
			p.eliminated = true
			# وحدات اللاعب المقصى تموت
			for u: SimEntity in gs.entities_of(pid, SimEntity.Kind.UNIT):
				gs.kill_entity(u.id)
			continue
		alive_players.append(pid)
	if alive_players.size() <= 1:
		gs.running = false
		gs.winner_id = alive_players[0] if alive_players.size() == 1 else 0
		gs.game_over.emit(gs.winner_id)
