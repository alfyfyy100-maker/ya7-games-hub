class_name ModelLibrary
extends RefCounted
## ModelLibrary — تحميل نماذج glTF (Kenney CC0) وتجهيزها للعرض:
## قياس تلقائي (fit)، تمركز، تلوين فريق (tint) بمواد مشتركة (cache) لتقليل draw calls،
## وضبط الأنيميشن للتكرار. لا يلمس حالة اللعبة.

static var _scenes: Dictionary = {}     # path -> PackedScene
static var _materials: Dictionary = {}  # key -> Material (مشتركة بين كل النسخ)

const LOOPING_ANIMS: Array[String] = ["idle", "walk", "sprint", "holding-right-shoot", "holding-both-shoot", "static"]


static func has_model(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


static func instantiate(path: String) -> Node3D:
	if path == "":
		return null
	var ps: PackedScene = _scenes.get(path)
	if ps == null:
		if not ResourceLoader.exists(path):
			push_warning("[ModelLibrary] missing model %s" % path)
			return null
		ps = load(path)
		if ps == null:
			return null
		_scenes[path] = ps
	var inst := ps.instantiate()
	if inst is Node3D:
		return inst
	push_warning("[ModelLibrary] %s is not a Node3D scene" % path)
	inst.free()
	return null


## تحويل نود نسبةً إلى جذر (يعمل قبل الإضافة للشجرة).
static func relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## AABB مدمج لكل الميشات في فضاء الجذر.
static func local_aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var a: AABB = relative_transform(m, root) * m.get_aabb()
		if first:
			box = a
			first = false
		else:
			box = box.merge(a)
	return box


## يقيس النموذج بحيث يصبح أكبر بعد له = target (0 = بدون تغيير)، ويرجّع الـ AABB بعد القياس.
static func fit_max(root: Node3D, target: float, extra_scale: float = 1.0) -> AABB:
	var a := local_aabb(root)
	var s := extra_scale
	var m := maxf(a.size.x, maxf(a.size.y, a.size.z))
	if target > 0.0 and m > 0.0001:
		s *= target / m
	root.scale = Vector3.ONE * s
	return AABB(a.position * s, a.size * s)


## يقيس النموذج ليملأ مستطيلًا أرضيًا (عرض × عمق) دون تجاوزه.
static func fit_footprint(root: Node3D, width: float, depth: float, extra_scale: float = 1.0) -> AABB:
	var a := local_aabb(root)
	var s := extra_scale
	if a.size.x > 0.0001 and a.size.z > 0.0001:
		s *= minf(width / a.size.x, depth / a.size.z)
	root.scale = Vector3.ONE * s
	return AABB(a.position * s, a.size * s)


## يضع النموذج بحيث يكون مركزه الأرضي عند (0, 0, 0) وقاعدته على y = 0.
static func center_on_ground(root: Node3D, scaled_aabb: AABB) -> void:
	root.position = -Vector3(scaled_aabb.position.x + scaled_aabb.size.x * 0.5, scaled_aabb.position.y, scaled_aabb.position.z + scaled_aabb.size.z * 0.5)


## يلوّن كل مواد النموذج نحو لون الفريق (مواد مشتركة عبر cache) ويطبق مظهرًا كرتونيًا.
static func apply_team_look(root: Node3D, team: Color, strength: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(i)
			if src == null:
				continue
			m.set_surface_override_material(i, _styled_material(src, team, strength))


static func _styled_material(src: Material, team: Color, strength: float) -> Material:
	var key := "%d_%d_%.2f" % [src.get_instance_id(), team.to_rgba32(), strength]
	if _materials.has(key):
		return _materials[key]
	var out: Material = src
	if src is BaseMaterial3D:
		var dup := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
		dup.albedo_color = (src as BaseMaterial3D).albedo_color.lerp(team, strength)
		dup.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		dup.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		dup.roughness = 1.0
		dup.metallic = 0.0
		out = dup
	_materials[key] = out
	return out


## يختار مسار النموذج حسب الفريق (نموذج بديل للفريق 2 إن وُجد).
static func path_for_team(base: String, team2: String, owner_id: int) -> String:
	if owner_id == GameConfig.AI_ID and has_model(team2):
		return team2
	return base


## يبحث عن أول عقدة Node3D ينتهي اسمها باللاحقة (للأبراج الداخلية مثل "_T").
static func find_node_by_suffix(root: Node, suffix: String) -> Node3D:
	if suffix == "":
		return null
	for n in root.find_children("*", "Node3D", true, false):
		if String(n.name).ends_with(suffix):
			return n
	return null


static func find_animation_player(root: Node) -> AnimationPlayer:
	for n in root.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		for name in LOOPING_ANIMS:
			if ap.has_animation(name):
				ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		return ap
	return null
