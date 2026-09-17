class_name ResourceView
extends Node3D
## ResourceView — حقل نفط: بركة نفط داكنة + براميل تتناقص مع استنزاف الحقل.

const BARREL := "res://assets/models/rgpoly/Barrel_1_A.fbx"
const FALLBACK := "res://assets/models/kenney/tower-defense/detail-crystal-large.glb"

var entity_id: int = -1
var body: Node3D
var _barrels: Array[Node3D] = []


func setup(e: SimEntity) -> void:
	entity_id = e.id
	body = Node3D.new()
	add_child(body)
	position = e.pos
	rotation.y = float(e.id % 7) * 0.9
	# بركة النفط
	var pool := MeshInstance3D.new()
	pool.mesh = MeshFactory.cyl_mesh(1.55, 0.08, 18)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.08, 0.07, 0.09)
	pm.roughness = 0.15
	pm.metallic = 0.4
	pool.material_override = pm
	pool.position = Vector3(0, 0.04, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(pool)
	var rim := MeshInstance3D.new()
	rim.mesh = MeshFactory.cyl_mesh(1.75, 0.06, 18)
	rim.material_override = MeshFactory.material(Color(0.45, 0.36, 0.26))
	rim.position = Vector3(0, 0.02, 0)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(rim)
	if ModelLibrary.has_model(BARREL):
		var slots := [Vector3(0.0, 0, -0.9), Vector3(0.75, 0, -0.55), Vector3(-0.75, 0, -0.55), Vector3(0.45, 0, 0.35), Vector3(-0.45, 0, 0.35), Vector3(0.0, 0, 1.0)]
		for i in slots.size():
			var b := ModelLibrary.instantiate(BARREL)
			body.add_child(b)
			var ba := ModelLibrary.fit_max(b, 0.75)
			ModelLibrary.center_on_ground(b, ba)
			b.position += slots[i] + Vector3(0, 0.06, 0)
			b.rotation.y = float(i) * 1.1
			ModelLibrary.apply_team_look(b, Color(0.1, 0.09, 0.08), 0.7)
			_barrels.append(b)
	elif ModelLibrary.has_model(FALLBACK):
		var model := ModelLibrary.instantiate(FALLBACK)
		body.add_child(model)
		var aabb := ModelLibrary.fit_max(model, 2.1)
		ModelLibrary.center_on_ground(model, aabb)
	else:
		body.add_child(MeshFactory.make_resource())


func _process(_delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	var r := clampf(float(e.data.get("amount", 0)) / maxf(e.max_hp, 1.0), 0.0, 1.0)
	for i in _barrels.size():
		_barrels[i].visible = r > float(i) / float(_barrels.size())
