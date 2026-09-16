class_name MapState
extends RefCounted
## MapState — الخريطة المنطقية: خريطة ارتفاعات (heightmap) + مواقع البداية + الموارد.
## هذه بيانات فقط. العرض (الميش) في res://maps/TerrainMesh.gd يقرأ منها.
## كل العشوائية هنا تمر عبر RNG (xorshift32 مبذور).

var width: int = GameConfig.MAP_W       # خلايا
var height: int = GameConfig.MAP_H
## ارتفاعات الرؤوس: (width+1) x (height+1)
var heights: PackedFloat32Array = PackedFloat32Array()
var start_cells: Dictionary = {}       # player_id -> Vector2i (مركز القاعدة)
var resource_cells: Array[Vector2i] = []
## ديكور يعيق الحركة (أشجار/صخور): [{cell: Vector2i, kind: int}]
var decor: Array[Dictionary] = []

enum DecorKind { TREE, ROCKS }
const DECOR_TREES: int = 55
const DECOR_ROCKS: int = 18

const BASE_FLAT_RADIUS: float = 9.0
const BASE_FLAT_HEIGHT: float = 0.35
const NOISE_AMP_1: float = 2.6
const NOISE_AMP_2: float = 0.8
const LATTICE_1: int = 8
const LATTICE_2: int = 4


func generate() -> void:
	var vw := width + 1
	var vh := height + 1
	heights.resize(vw * vh)

	# مواقع البداية: اللاعب أسفل-يسار، الخصم أعلى-يمين
	start_cells = {
		GameConfig.PLAYER_ID: Vector2i(10, height - 11),
		GameConfig.AI_ID: Vector2i(width - 11, 10),
	}

	# طبقتا ضجيج قيمي (value noise) ناعم — تلال خفيفة بدون حواف
	var lat1 := _make_lattice(LATTICE_1)
	var lat2 := _make_lattice(LATTICE_2)
	for vy in vh:
		for vx in vw:
			var n1 := _sample_lattice(lat1, LATTICE_1, vx, vy)
			var n2 := _sample_lattice(lat2, LATTICE_2, vx, vy)
			var h := n1 * NOISE_AMP_1 + n2 * NOISE_AMP_2
			# حوض ماء في المنتصف تقريبًا (بحيرة) — عبر تخفيض ناعم
			var cx := float(width) * 0.5
			var cy := float(height) * 0.5
			var d := Vector2(vx - cx, vy - cy).length()
			var lake := smoothstep(11.0, 5.0, d) # 1 في المركز، 0 بعيدًا
			h = lerpf(h, -1.6, lake * 0.9)
			heights[vy * vw + vx] = h

	# تسطيح مناطق القواعد + ممر طبيعي بينهما
	for pid in start_cells:
		_flatten_disc(start_cells[pid], BASE_FLAT_RADIUS, BASE_FLAT_HEIGHT)
	_flatten_corridor(start_cells[GameConfig.PLAYER_ID], start_cells[GameConfig.AI_ID], 3.0, 0.3)

	# الموارد: قرب كل قاعدة + منتصف الخريطة
	resource_cells.clear()
	for pid in start_cells:
		var c: Vector2i = start_cells[pid]
		var towards_center := Vector2(width * 0.5 - c.x, height * 0.5 - c.y).normalized()
		var side := Vector2(-towards_center.y, towards_center.x)
		var r1 := c + Vector2i((towards_center * 6.0 + side * 3.0).round())
		var r2 := c + Vector2i((towards_center * 6.0 - side * 3.0).round())
		resource_cells.append(_clamp_cell(r1))
		resource_cells.append(_clamp_cell(r2))
	# موارد وسطية عشوائية (مبذورة) على أطراف البحيرة
	for _i in 3:
		var ang := RNG.range_float(0.0, TAU)
		var dist := RNG.range_float(12.0, 15.0)
		var cell := Vector2i(int(round(width * 0.5 + cos(ang) * dist)), int(round(height * 0.5 + sin(ang) * dist)))
		cell = _clamp_cell(cell)
		_flatten_disc(cell, 2.5, maxf(cell_center_height(cell), 0.2))
		resource_cells.append(cell)

	_generate_decor()


## أشجار وصخور (مبذورة) بعيدًا عن القواعد والموارد والممر.
func _generate_decor() -> void:
	decor.clear()
	var pa := Vector2(start_cells[GameConfig.PLAYER_ID])
	var pb := Vector2(start_cells[GameConfig.AI_ID])
	var seg := pb - pa
	var used: Dictionary = {}
	var trees := 0
	var rocks := 0
	for _attempt in 900:
		if trees >= DECOR_TREES and rocks >= DECOR_ROCKS:
			break
		var c := Vector2i(RNG.range_int(1, width - 2), RNG.range_int(1, height - 2))
		if used.has(c) or not is_terrain_walkable(c):
			continue
		if cell_center_height(c) < GameConfig.WATER_LEVEL + 0.5:
			continue
		var ok := true
		for pid in start_cells:
			if Vector2(c - start_cells[pid]).length() < BASE_FLAT_RADIUS + 2.0:
				ok = false
		for r in resource_cells:
			if Vector2(c - r).length() < 2.5:
				ok = false
		var t := clampf((Vector2(c) - pa).dot(seg) / seg.length_squared(), 0.0, 1.0)
		if (pa + seg * t - Vector2(c)).length() < 4.0:
			ok = false
		if not ok:
			continue
		var kind := DecorKind.TREE if trees < DECOR_TREES and (rocks >= DECOR_ROCKS or RNG.chance(0.75)) else DecorKind.ROCKS
		if kind == DecorKind.TREE:
			trees += 1
		else:
			rocks += 1
		used[c] = true
		decor.append({"cell": c, "kind": kind})


func _make_lattice(step: int) -> PackedFloat32Array:
	var lw := width / step + 2
	var lh := height / step + 2
	var lat := PackedFloat32Array()
	lat.resize(lw * lh)
	for i in lat.size():
		lat[i] = RNG.range_float(-1.0, 1.0)
	return lat


func _sample_lattice(lat: PackedFloat32Array, step: int, vx: int, vy: int) -> float:
	var lw := width / step + 2
	var fx := float(vx) / step
	var fy := float(vy) / step
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - x0)
	var ty := smoothstep(0.0, 1.0, fy - y0)
	var a := lat[y0 * lw + x0]
	var b := lat[y0 * lw + x0 + 1]
	var c := lat[(y0 + 1) * lw + x0]
	var d := lat[(y0 + 1) * lw + x0 + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _flatten_disc(center: Vector2i, radius: float, target_h: float) -> void:
	var vw := width + 1
	for vy in height + 1:
		for vx in vw:
			var d := Vector2(vx - center.x - 0.5, vy - center.y - 0.5).length()
			if d < radius + 3.0:
				var w := 1.0 - smoothstep(radius - 2.0, radius + 3.0, d)
				var i := vy * vw + vx
				heights[i] = lerpf(heights[i], target_h, w)


func _flatten_corridor(a: Vector2i, b: Vector2i, half_width: float, target_h: float) -> void:
	var vw := width + 1
	var pa := Vector2(a) + Vector2(0.5, 0.5)
	var pb := Vector2(b) + Vector2(0.5, 0.5)
	var seg := pb - pa
	var seg_len2 := seg.length_squared()
	for vy in height + 1:
		for vx in vw:
			var p := Vector2(vx, vy)
			var t := clampf((p - pa).dot(seg) / seg_len2, 0.0, 1.0)
			var d := (pa + seg * t - p).length()
			var w := 1.0 - smoothstep(half_width, half_width + 3.0, d)
			var i := vy * vw + vx
			# نرفع فقط ما هو تحت الهدف (نضمن يابسة) ونخفف الأعلى
			heights[i] = lerpf(heights[i], target_h, w * 0.85)


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 1, width - 2), clampi(c.y, 1, height - 2))


# ------------------------------------------------------------------ استعلامات

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func vertex_height(vx: int, vy: int) -> float:
	vx = clampi(vx, 0, width)
	vy = clampi(vy, 0, height)
	return heights[vy * (width + 1) + vx]


## ارتفاع الأرض عند نقطة عالمية (bilinear).
func height_at_world(x: float, z: float) -> float:
	var fx := x / GameConfig.CELL_SIZE
	var fz := z / GameConfig.CELL_SIZE
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var a := vertex_height(x0, z0)
	var b := vertex_height(x0 + 1, z0)
	var c := vertex_height(x0, z0 + 1)
	var d := vertex_height(x0 + 1, z0 + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func cell_center_height(cell: Vector2i) -> float:
	return height_at_world((cell.x + 0.5) * GameConfig.CELL_SIZE, (cell.y + 0.5) * GameConfig.CELL_SIZE)


func cell_to_world(cell: Vector2i) -> Vector3:
	var x := (cell.x + 0.5) * GameConfig.CELL_SIZE
	var z := (cell.y + 0.5) * GameConfig.CELL_SIZE
	return Vector3(x, height_at_world(x, z), z)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / GameConfig.CELL_SIZE)), int(floor(p.z / GameConfig.CELL_SIZE)))


## يُسقط نقطة على سطح الأرض (يصحح y).
func snap_to_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at_world(p.x, p.z), p.z)


func cell_slope(cell: Vector2i) -> float:
	var h0 := vertex_height(cell.x, cell.y)
	var h1 := vertex_height(cell.x + 1, cell.y)
	var h2 := vertex_height(cell.x, cell.y + 1)
	var h3 := vertex_height(cell.x + 1, cell.y + 1)
	return maxf(maxf(h0, h1), maxf(h2, h3)) - minf(minf(h0, h1), minf(h2, h3))


func is_water_cell(cell: Vector2i) -> bool:
	var h0 := vertex_height(cell.x, cell.y)
	var h1 := vertex_height(cell.x + 1, cell.y)
	var h2 := vertex_height(cell.x, cell.y + 1)
	var h3 := vertex_height(cell.x + 1, cell.y + 1)
	return minf(minf(h0, h1), minf(h2, h3)) < GameConfig.WATER_LEVEL


## خلية صالحة للمشي بحسب التضاريس فقط (بدون احتساب المباني).
func is_terrain_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	if is_water_cell(cell):
		return false
	return cell_slope(cell) <= GameConfig.MAX_SLOPE


func world_size() -> Vector2:
	return Vector2(width * GameConfig.CELL_SIZE, height * GameConfig.CELL_SIZE)


func clamp_world(p: Vector3, margin: float = 1.0) -> Vector3:
	var s := world_size()
	return Vector3(clampf(p.x, margin, s.x - margin), p.y, clampf(p.z, margin, s.y - margin))
