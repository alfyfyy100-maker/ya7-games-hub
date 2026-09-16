class_name UnitState
extends RefCounted
## UnitState — الصنف الأساسي لحالات آلة الحالة (Idle, Move, Attack, Gather, Dead).
## كل حالة تعمل على SimEntity (بيانات) ولا تلمس أي نود عرض.
## tick() يرجّع اسم الحالة التالية (أو نفس الاسم للبقاء).

var name: StringName = &"base"


func enter(_e: SimEntity, _gs: Node) -> void:
	pass


func exit(_e: SimEntity, _gs: Node) -> void:
	pass


func tick(_e: SimEntity, _gs: Node) -> StringName:
	return name


## يحوّل الأمر الحالي إلى الحالة المناسبة (مشترك بين Idle وغيرها).
static func state_for_order(e: SimEntity) -> StringName:
	match String(e.order.get("type", "")):
		"move", "attack_move":
			return &"move"
		"attack":
			return &"attack"
		"gather":
			return &"gather"
	return &"idle"
