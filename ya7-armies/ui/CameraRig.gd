class_name CameraRig
extends Node3D
## CameraRig — كاميرا Orthogonal بزاوية ميل ثابتة (≈40°). اللاعب يحرّك الـ rig، يزوم، ويلفّ حول المحور العمودي.
## الهيكل: CameraRig (yaw) → Pivot (pitch ثابت) → Camera3D (orthogonal).

@export var pitch_degrees: float = 40.0
@export var initial_yaw_degrees: float = 45.0
@export var min_zoom: float = 12.0
@export var max_zoom: float = 44.0
@export var zoom: float = 26.0
@export var camera_distance: float = 90.0

@onready var pivot: Node3D = $Pivot
@onready var camera: Camera3D = $Pivot/Camera3D

var _map: MapState


func _ready() -> void:
	pivot.rotation_degrees.x = -pitch_degrees
	rotation_degrees.y = initial_yaw_degrees
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, camera_distance)
	camera.near = 0.5
	camera.far = camera_distance * 2.5
	camera.size = zoom


func set_map(map: MapState) -> void:
	_map = map


func focus(world_pos: Vector3) -> void:
	position = world_pos
	_clamp()


## تحريك الـ rig بحيث تبقى النقطة الأرضية تحت الإصبع ثابتة (سحب طبيعي).
func pan_screen(from_px: Vector2, to_px: Vector2) -> void:
	var a := screen_to_plane(from_px, position.y)
	var b := screen_to_plane(to_px, position.y)
	position -= Vector3(b.x - a.x, 0.0, b.z - a.z)
	_clamp()


func pan_local(dir: Vector2, amount: float) -> void:
	# dir.x يمين/يسار الشاشة، dir.y أعلى/أسفل الشاشة — بالنسبة لدوران الكاميرا
	var right := global_transform.basis.x
	var forward := -global_transform.basis.z
	var d := (right * dir.x + forward * dir.y)
	d.y = 0.0
	position += d.normalized() * amount if d.length() > 0.0 else Vector3.ZERO
	_clamp()


func zoom_by(factor: float, anchor_px: Vector2 = Vector2(-1, -1)) -> void:
	var before := Vector3.ZERO
	var use_anchor := anchor_px.x >= 0.0
	if use_anchor:
		before = screen_to_plane(anchor_px, position.y)
	zoom = clampf(zoom * factor, min_zoom, max_zoom)
	camera.size = zoom
	if use_anchor:
		var after := screen_to_plane(anchor_px, position.y)
		position -= Vector3(after.x - before.x, 0.0, after.z - before.z)
	_clamp()


func rotate_by(radians: float) -> void:
	rotation.y += radians


func _clamp() -> void:
	if _map == null:
		return
	var s := _map.world_size()
	position.x = clampf(position.x, 0.0, s.x)
	position.z = clampf(position.z, 0.0, s.y)
	position.y = _map.height_at_world(position.x, position.z) if _map != null else 0.0


## تقاطع شعاع الشاشة مع مستوى أفقي y = plane_y.
func screen_to_plane(screen_pos: Vector2, plane_y: float) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, plane_y)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		return Vector3(origin.x, plane_y, origin.z)
	return hit


## تقاطع شعاع الشاشة مع سطح الأرض الفعلي (heightmap) — مسير خطوي ثم تدقيق.
func screen_to_ground(screen_pos: Vector2) -> Vector3:
	if _map == null:
		return screen_to_plane(screen_pos, 0.0)
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var t := 0.0
	var step := 1.0
	var last_above := true
	var prev_t := 0.0
	var max_t := camera_distance * 2.5
	while t < max_t:
		var p := origin + dir * t
		var above := p.y > _map.height_at_world(p.x, p.z)
		if last_above and not above:
			# تدقيق بالتنصيف
			var lo := prev_t
			var hi := t
			for _i in 8:
				var mid := (lo + hi) * 0.5
				var pm := origin + dir * mid
				if pm.y > _map.height_at_world(pm.x, pm.z):
					lo = mid
				else:
					hi = mid
			var r := origin + dir * ((lo + hi) * 0.5)
			return _map.snap_to_ground(_map.clamp_world(r))
		last_above = above
		prev_t = t
		t += step
	return screen_to_plane(screen_pos, 0.0)


## عدد البكسلات لكل وحدة عالم (للاختيار بالحجم الظاهري).
func pixels_per_unit() -> float:
	var vp := get_viewport().get_visible_rect().size
	return vp.y / camera.size
