class_name CombatFX
extends Node3D
## CombatFX — مؤثرات قتال (عرض فقط): مقذوفات مرئية، وميض فوهة، وارتطام.
## تُشتق من إشارة GameState.damage_dealt ولا تؤثر على الحالة إطلاقًا (الضرر طُبّق أصلًا).

const MAX_ACTIVE: int = 96
const SHELL_SPEED: float = 26.0
const TRACER_SPEED: float = 55.0

var _world: WorldView
var _shots: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _shell_mesh: SphereMesh
var _tracer_mesh: BoxMesh
var _flash_mesh: SphereMesh
var _mat_shell: StandardMaterial3D
var _mat_tracer: StandardMaterial3D
var _mat_flash: StandardMaterial3D
var _mat_impact: StandardMaterial3D


func _ready() -> void:
	_shell_mesh = SphereMesh.new()
	_shell_mesh.radius = 0.13
	_shell_mesh.height = 0.26
	_shell_mesh.radial_segments = 8
	_shell_mesh.rings = 4
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3(0.07, 0.07, 0.8)
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 0.5
	_flash_mesh.height = 1.0
	_flash_mesh.radial_segments = 8
	_flash_mesh.rings = 4
	_mat_shell = MeshFactory.flat_material(Color(0.15, 0.15, 0.15))
	_mat_tracer = MeshFactory.flat_material(Color(1.0, 0.9, 0.35))
	_mat_flash = MeshFactory.flat_material(Color(1.0, 0.75, 0.2, 0.9))
	_mat_impact = MeshFactory.flat_material(Color(1.0, 0.45, 0.15, 0.8))


func setup(world: WorldView) -> void:
	_world = world
	if not GameState.damage_dealt.is_connected(_on_damage):
		GameState.damage_dealt.connect(_on_damage)


func _on_damage(target_id: int, _amount: float, source_id: int) -> void:
	if _shots.size() >= MAX_ACTIVE:
		return
	var s: SimEntity = GameState.get_entity(source_id)
	var t: SimEntity = GameState.get_entity(target_id)
	if s == null or t == null:
		return
	var sv = _world.get_view(source_id)
	var tv = _world.get_view(target_id)
	var from: Vector3 = s.pos + Vector3(0, 0.9, 0)
	if sv != null and sv.has_method("muzzle_position"):
		from = sv.muzzle_position()
	var to_h := 0.8
	if tv != null and "visual_height" in tv:
		to_h = maxf(0.5, tv.visual_height * 0.5)
	var to: Vector3 = t.pos + Vector3(0, to_h, 0)
	var heavy := s.is_building()
	if s.is_unit():
		var d := s.unit_def()
		heavy = d != null and d.category == UnitData.Category.VEHICLE
	# وميض الفوهة
	_spawn_impact(from, 0.35 if heavy else 0.2, 0.08, _mat_flash)
	# المقذوف
	var mi := MeshInstance3D.new()
	mi.mesh = _shell_mesh if heavy else _tracer_mesh
	mi.material_override = _mat_shell if heavy else _mat_tracer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = from
	if not heavy:
		mi.look_at(to, Vector3.UP)
	var dist := from.distance_to(to)
	var speed := SHELL_SPEED if heavy else TRACER_SPEED
	_shots.append({"node": mi, "from": from, "to": to, "t": 0.0, "dur": maxf(dist / speed, 0.04), "heavy": heavy})


func _spawn_impact(pos: Vector3, size: float, dur: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _flash_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.4
	_impacts.append({"node": mi, "t": 0.0, "dur": dur, "size": size})


func _process(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var s := _shots[i]
		s.t = float(s.t) + delta
		var k := clampf(float(s.t) / float(s.dur), 0.0, 1.0)
		var n: MeshInstance3D = s.node
		var p: Vector3 = (s.from as Vector3).lerp(s.to, k)
		if s.heavy:
			p.y += sin(k * PI) * 0.6  # قوس بسيط للقذائف الثقيلة
		n.global_position = p
		if k >= 1.0:
			_spawn_impact(s.to, 1.1 if s.heavy else 0.45, 0.22 if s.heavy else 0.12, _mat_impact)
			n.queue_free()
			_shots.remove_at(i)
	for i in range(_impacts.size() - 1, -1, -1):
		var im := _impacts[i]
		im.t = float(im.t) + delta
		var k := clampf(float(im.t) / float(im.dur), 0.0, 1.0)
		var n: MeshInstance3D = im.node
		n.scale = Vector3.ONE * float(im.size) * (0.4 + 0.8 * k)
		if k >= 1.0:
			n.queue_free()
			_impacts.remove_at(i)
