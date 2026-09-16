class_name SimEntity
extends RefCounted
## SimEntity — بيانات كيان في "حالة اللعبة" (بدون أي عرض/نودات).
## كل شيء هنا قابل للتسلسل (to_dict/from_dict) للحفظ والمزامنة الشبكية لاحقًا.

enum Kind { UNIT, BUILDING, RESOURCE }

var id: int = 0
var kind: int = Kind.UNIT
var def_id: StringName = &""
var owner_id: int = 0          # 0 = محايد (موارد)

var pos: Vector3 = Vector3.ZERO       # موقع منطقي في العالم
var prev_pos: Vector3 = Vector3.ZERO  # موقع الفريم السابق (للعرض المُنعَّم فقط)
var facing: float = 0.0               # الاتجاه (yaw) بالراديان

var hp: float = 100.0
var max_hp: float = 100.0
var alive: bool = true

## آلة الحالة (للوحدات): idle / move / attack / gather / dead
var state: StringName = &"idle"
var state_ticks: int = 0

## الأمر الحالي: {type: "move"|"attack"|"attack_move"|"gather"|"stop", pos: Vector3, target: int}
var order: Dictionary = {}
var order_dirty: bool = false
## أمر يُستأنف بعد انتهاء اشتباك تلقائي (مثلاً attack_move).
var resume_order: Dictionary = {}

var target_id: int = -1
var path: PackedVector3Array = PackedVector3Array()
var path_index: int = 0
var cooldown: int = 0
## آخر فريم أطلقت فيه (للعرض: ارتداد/وميض).
var last_fire_tick: int = -1000
var last_hit_tick: int = -1000

var cargo: int = 0

## بيانات خاصة بالنوع:
## مبنى: cell:Vector2i, footprint:Vector2i, queue:Array, rally:Vector3, construction:int, completed:bool
## مورد: amount:int
## وحدة حصّادة: gather_phase:String, resource_id:int, refinery_id:int
var data: Dictionary = {}


func is_unit() -> bool:
	return kind == Kind.UNIT


func is_building() -> bool:
	return kind == Kind.BUILDING


func is_resource() -> bool:
	return kind == Kind.RESOURCE


func unit_def() -> UnitData:
	return GameConfig.get_unit_def(def_id) if kind == Kind.UNIT else null


func building_def() -> BuildingData:
	return GameConfig.get_building_def(def_id) if kind == Kind.BUILDING else null


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


func set_order(new_order: Dictionary) -> void:
	order = new_order.duplicate()
	resume_order = {}
	order_dirty = true


func to_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "def": String(def_id), "owner": owner_id,
		"pos": [pos.x, pos.y, pos.z], "facing": facing,
		"hp": hp, "max_hp": max_hp, "alive": alive,
		"state": String(state), "state_ticks": state_ticks,
		"order": order.duplicate(true), "resume_order": resume_order.duplicate(true),
		"target": target_id, "cooldown": cooldown, "cargo": cargo,
		"data": data.duplicate(true),
	}


static func from_dict(d: Dictionary) -> SimEntity:
	var e := SimEntity.new()
	e.id = int(d.get("id", 0))
	e.kind = int(d.get("kind", Kind.UNIT))
	e.def_id = StringName(String(d.get("def", "")))
	e.owner_id = int(d.get("owner", 0))
	var p: Array = d.get("pos", [0, 0, 0])
	e.pos = Vector3(p[0], p[1], p[2])
	e.prev_pos = e.pos
	e.facing = float(d.get("facing", 0.0))
	e.hp = float(d.get("hp", 100.0))
	e.max_hp = float(d.get("max_hp", 100.0))
	e.alive = bool(d.get("alive", true))
	e.state = StringName(String(d.get("state", "idle")))
	e.state_ticks = int(d.get("state_ticks", 0))
	e.order = d.get("order", {})
	e.resume_order = d.get("resume_order", {})
	e.target_id = int(d.get("target", -1))
	e.cooldown = int(d.get("cooldown", 0))
	e.cargo = int(d.get("cargo", 0))
	e.data = d.get("data", {})
	return e
