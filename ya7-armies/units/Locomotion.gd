class_name Locomotion
extends RefCounted
## Locomotion — مساعد حركة مشترك بين الحالات (Move/Attack/Gather).
## يعمل على بيانات SimEntity فقط (بدون نودات). كل الحركة بالفريم الثابت.

const ARRIVE_EPS: float = 0.15
## عدد الفريمات بلا تقدم قبل اعتبار الوحدة عالقة.
const STUCK_TICKS: int = 12


## يطلب مسارًا جديدًا إلى نقطة عالمية. يرجّع false لو لم يوجد مسار.
static func request_path(e: SimEntity, gs: Node, target: Vector3) -> bool:
	e.path = gs.nav.find_path_world(e.pos, target)
	e.path_index = 0
	return not e.path.is_empty()


## يتقدم خطوة واحدة على المسار. يرجّع true عند الوصول (أو لا يوجد مسار).
static func step(e: SimEntity, gs: Node) -> bool:
	if e.path.is_empty() or e.path_index >= e.path.size():
		return true
	var def := e.unit_def()
	var remaining := def.speed_per_tick() if def != null else 0.1
	# كشف العالق: نقارن موقع بداية هذا الفريم بموقع بداية الفريم السابق (صافي الحركة بعد التباعد).
	# لو كان صافي التقدم شبه معدوم لعدة فريمات متتالية نعيد المسار مع خطوة جانبية.
	var start := e.pos
	var prev_start: Vector3 = e.data.get("step_prev_start", start)
	var was_stepping: bool = int(e.data.get("step_prev_tick", -2)) == gs.tick - 1
	e.data.step_prev_start = start
	e.data.step_prev_tick = gs.tick
	if was_stepping and flat_distance(prev_start, start) < remaining * 0.2:
		e.data.stuck_ticks = int(e.data.get("stuck_ticks", 0)) + 1
	else:
		e.data.stuck_ticks = 0
	if int(e.data.stuck_ticks) >= STUCK_TICKS:
		e.data.stuck_ticks = 0
		var goal := e.path[e.path.size() - 1]
		var side := 1.0 if RNG.chance(0.5) else -1.0
		var wp0 := e.path[e.path_index]
		var fwd := Vector3(wp0.x - e.pos.x, 0.0, wp0.z - e.pos.z).normalized()
		var sidestep := Vector3(-fwd.z, 0.0, fwd.x) * side * 1.2
		var np: Vector3 = gs.map.clamp_world(e.pos + sidestep)
		if gs.nav.is_walkable(gs.map.world_to_cell(np)):
			e.pos.x = np.x
			e.pos.z = np.z
		request_path(e, gs, goal)
		if e.path.is_empty():
			return true
	while remaining > 0.0 and e.path_index < e.path.size():
		var wp := e.path[e.path_index]
		var to := Vector3(wp.x - e.pos.x, 0.0, wp.z - e.pos.z)
		var dist := to.length()
		if dist <= ARRIVE_EPS:
			e.path_index += 1
			continue
		var move := minf(dist, remaining)
		var dir := to / dist
		e.pos.x += dir.x * move
		e.pos.z += dir.z * move
		e.facing = atan2(dir.x, dir.z)
		remaining -= move
		if move >= dist - ARRIVE_EPS:
			e.path_index += 1
	e.pos.y = gs.map.height_at_world(e.pos.x, e.pos.z)
	return e.path_index >= e.path.size()


static func face_towards(e: SimEntity, target: Vector3) -> void:
	var d := Vector3(target.x - e.pos.x, 0.0, target.z - e.pos.z)
	if d.length_squared() > 0.0001:
		e.facing = atan2(d.x, d.z)


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## المسافة الأفقية من نقطة إلى كيان: للمباني/الموارد تُحسب إلى حافة مستطيل البصمة، للوحدات إلى المركز.
static func distance_to_entity(from: Vector3, target: SimEntity) -> float:
	if target.is_unit():
		return flat_distance(from, target.pos)
	var cell: Vector2i = target.data.get("cell", Vector2i.ZERO)
	var fp: Vector2i = target.data.get("footprint", Vector2i.ONE)
	var min_x := cell.x * GameConfig.CELL_SIZE
	var min_z := cell.y * GameConfig.CELL_SIZE
	var max_x := (cell.x + fp.x) * GameConfig.CELL_SIZE
	var max_z := (cell.y + fp.y) * GameConfig.CELL_SIZE
	var dx := maxf(maxf(min_x - from.x, 0.0), from.x - max_x)
	var dz := maxf(maxf(min_z - from.z, 0.0), from.z - max_z)
	return sqrt(dx * dx + dz * dz)
