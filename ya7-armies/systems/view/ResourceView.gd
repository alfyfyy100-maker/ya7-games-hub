class_name ResourceView
extends Node3D
## ResourceView — عنقود بلّورات (نموذج Kenney أو نموذج مؤقت) يصغر مع استنزاف المورد.

const MODEL_PATH := "res://assets/models/kenney/tower-defense/detail-crystal-large.glb"

var entity_id: int = -1
var body: Node3D


func setup(e: SimEntity) -> void:
	entity_id = e.id
	body = Node3D.new()
	add_child(body)
	if ModelLibrary.has_model(MODEL_PATH):
		var model := ModelLibrary.instantiate(MODEL_PATH)
		body.add_child(model)
		var aabb := ModelLibrary.fit_max(model, 2.1)
		ModelLibrary.center_on_ground(model, aabb)
		ModelLibrary.apply_team_look(model, Color.WHITE, 0.0)
	else:
		body.add_child(MeshFactory.make_resource())
	position = e.pos
	rotation.y = float(e.id % 7) * 0.9


func _process(_delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	var r := float(e.data.get("amount", 0)) / maxf(e.max_hp, 1.0)
	body.scale = Vector3.ONE * lerpf(0.45, 1.0, clampf(r, 0.0, 1.0))
