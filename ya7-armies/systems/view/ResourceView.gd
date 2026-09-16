class_name ResourceView
extends Node3D
## ResourceView — عنقود بلّورات يصغر مع استنزاف المورد.

var entity_id: int = -1
var body: Node3D


func setup(e: SimEntity) -> void:
	entity_id = e.id
	body = MeshFactory.make_resource()
	add_child(body)
	position = e.pos
	rotation.y = float(e.id % 7) * 0.9


func _process(_delta: float) -> void:
	var e: SimEntity = GameState.get_entity(entity_id)
	if e == null:
		queue_free()
		return
	var r := float(e.data.get("amount", 0)) / maxf(e.max_hp, 1.0)
	body.scale = Vector3.ONE * lerpf(0.45, 1.0, clampf(r, 0.0, 1.0))
