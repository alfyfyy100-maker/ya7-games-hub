class_name TurretPivot
extends RefCounted
## TurretPivot — يدير دوران برج حول المحور العمودي العالمي مهما كانت محاور النموذج المستورد
## (FBX بمحور Z للأعلى مثلًا). يعمل على عقدة داخل النموذج أو حامل مستقل.

var node: Node3D
var rest: Basis = Basis.IDENTITY
var axis: Vector3 = Vector3.UP   # المحور العمودي بفضاء الأب
var angle: float = 0.0
var offset: float = 0.0          # إزاحة ثابتة (turret_yaw_deg)
var _ready: bool = false


func _init(n: Node3D, yaw_offset_rad: float = 0.0) -> void:
	node = n
	offset = yaw_offset_rad
	if n != null:
		rest = n.transform.basis


func _ensure_axis() -> void:
	if _ready or node == null or not node.is_inside_tree():
		return
	var parent := node.get_parent() as Node3D
	if parent != null:
		axis = (parent.global_transform.basis.inverse() * Vector3.UP).normalized()
	_ready = true


## يدوّر البرج نحو زاوية عالمية (yaw) نسبةً إلى اتجاه الجسم (body_yaw)، بتنعيم.
func aim(target_yaw: float, body_yaw: float, delta: float, speed: float = 8.0) -> void:
	_ensure_axis()
	if node == null:
		return
	var desired := wrapf(target_yaw - body_yaw + offset, -PI, PI)
	angle = lerp_angle(angle, desired, minf(1.0, delta * speed))
	node.transform.basis = Basis(axis, angle) * rest


func relax(delta: float, speed: float = 4.0) -> void:
	_ensure_axis()
	if node == null:
		return
	angle = lerp_angle(angle, offset, minf(1.0, delta * speed))
	node.transform.basis = Basis(axis, angle) * rest
