class_name NavGrid
extends RefCounted
## NavGrid — الشبكة المنطقية غير المرئية للـ pathfinding وصلاحية البناء.
## تعتمد على AStarGrid2D (حتمي). المباني والموارد تحجز خلايا.

var map: MapState
var astar: AStarGrid2D = AStarGrid2D.new()
## Vector2i -> entity id (خلايا محجوزة بمباني/موارد)
var occupied: Dictionary = {}


func build(m: MapState) -> void:
	map = m
	occupied.clear()
	astar.region = Rect2i(0, 0, m.width, m.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.jumping_enabled = false
	astar.update()
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, not m.is_terrain_walkable(c))
	# الديكور (أشجار/صخور) يحجز خلاياه
	for d in m.decor:
		var c: Vector2i = d.cell
		occupied[c] = -1
		astar.set_point_solid(c, true)


func is_walkable(cell: Vector2i) -> bool:
	if not map.in_bounds(cell):
		return false
	return not astar.is_point_solid(cell)


func is_free_for_building(cell: Vector2i) -> bool:
	if not map.in_bounds(cell):
		return false
	if occupied.has(cell):
		return false
	return map.is_terrain_walkable(cell)


func occupy(cells: Array[Vector2i], entity_id: int) -> void:
	for c in cells:
		if map.in_bounds(c):
			occupied[c] = entity_id
			astar.set_point_solid(c, true)


func release(cells: Array[Vector2i]) -> void:
	for c in cells:
		if occupied.has(c):
			occupied.erase(c)
		if map.in_bounds(c):
			astar.set_point_solid(c, not map.is_terrain_walkable(c))


static func footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			out.append(origin + Vector2i(x, y))
	return out


## الخلايا المحيطة بمستطيل (حلقة واحدة حوله).
static func ring_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(-1, footprint.y + 1):
		for x in range(-1, footprint.x + 1):
			if x == -1 or y == -1 or x == footprint.x or y == footprint.y:
				out.append(origin + Vector2i(x, y))
	return out


## أقرب خلية صالحة للمشي حول خلية (بحث حلزوني حتى radius).
func nearest_walkable(cell: Vector2i, radius: int = 6) -> Vector2i:
	if is_walkable(cell):
		return cell
	for r in range(1, radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if is_walkable(c):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return cell


## أقرب خلية صالحة للمشي من الحلقة المحيطة بمبنى/مورد، بالنسبة لنقطة.
func nearest_adjacent_walkable(origin: Vector2i, footprint: Vector2i, from_world: Vector3) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e18
	for c in ring_cells(origin, footprint):
		if is_walkable(c):
			var d := map.cell_to_world(c).distance_squared_to(from_world)
			if d < best_d:
				best_d = d
				best = c
	if best.x < 0:
		return nearest_walkable(origin, 8)
	return best


## مسار عالمي (نقاط على سطح الأرض) من موقع إلى موقع. يرجّع مصفوفة فارغة إن لم يوجد.
func find_path_world(from_world: Vector3, to_world: Vector3) -> PackedVector3Array:
	var a := map.world_to_cell(from_world)
	var b := map.world_to_cell(to_world)
	a = nearest_walkable(a, 4)
	b = nearest_walkable(b, 8)
	var out := PackedVector3Array()
	if not map.in_bounds(a) or not map.in_bounds(b):
		return out
	var cells := astar.get_id_path(a, b)
	if cells.is_empty():
		return out
	# نتخطى الخلية الأولى (موقعنا الحالي) ونستبدل الأخيرة بالوجهة الدقيقة
	for i in range(1, cells.size()):
		out.append(map.cell_to_world(cells[i]))
	if cells.size() == 1:
		out.append(map.cell_to_world(cells[0]))
	var last := out.size() - 1
	var exact := map.snap_to_ground(to_world)
	if map.world_to_cell(exact) == b:
		out[last] = exact
	return out
