extends Node
## GameConfig — ثوابت اللعبة + سجلّ البيانات (Registry) للوحدات والمباني.
##
## كل الوحدات والمباني تُعرَّف بملفات .tres داخل:
##   res://units/data/      (UnitData)
##   res://buildings/data/  (BuildingData)
## يكفي إضافة ملف .tres جديد ليظهر تلقائيًا في اللعبة — بدون تعديل كود المحرك.

## معدل المحاكاة الثابت (فريم/ثانية). كل التوقيتات تُحسب بالفريمات وليس بالوقت الحقيقي.
const TICK_RATE: int = 30

## حجم الخلية المنطقية بوحدات العالم (الشبكة غير مرئية للاعب).
const CELL_SIZE: float = 2.0
const MAP_W: int = 48
const MAP_H: int = 48

## مستوى الماء (ارتفاع). الخلايا تحته غير صالحة للمشي/البناء.
const WATER_LEVEL: float = -0.7
## أقصى فرق ارتفاع بين زوايا خلية واحدة لتبقى صالحة للمشي/البناء.
const MAX_SLOPE: float = 1.25

const START_CREDITS: int = 1500
const PLAYER_ID: int = 1
const AI_ID: int = 2

## عدد الفريمات التي تبقى فيها الجثة/الحطام قبل الحذف.
const DEATH_TICKS: int = 45
## كل كم فريم تبحث الوحدة عن أهداف تلقائيًا.
const SCAN_INTERVAL: int = 8
## كل كم فريم يعاد حساب المسار عند مطاردة هدف متحرك.
const REPATH_INTERVAL: int = 15

const TEAM_COLORS: Dictionary = {
	1: Color(0.27, 0.56, 1.0),   # اللاعب — أزرق
	2: Color(1.0, 0.36, 0.30),   # الخصم — أحمر
}

var unit_defs: Dictionary = {}       # StringName -> UnitData
var building_defs: Dictionary = {}   # StringName -> BuildingData


func _ready() -> void:
	Engine.physics_ticks_per_second = TICK_RATE
	_load_defs("res://units/data", unit_defs)
	_load_defs("res://buildings/data", building_defs)
	print("[GameConfig] loaded %d unit defs, %d building defs" % [unit_defs.size(), building_defs.size()])


## يحمّل كل ملفات .tres من مجلد (يتعامل مع .remap في النسخ المصدَّرة).
func _load_defs(dir_path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[GameConfig] cannot open %s" % dir_path)
		return
	var files := dir.get_files()
	var names: Array[String] = []
	for f in files:
		var name := f
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			if not names.has(name):
				names.append(name)
	names.sort()  # ترتيب ثابت = سلوك حتمي
	for name in names:
		var res: Resource = ResourceLoader.load(dir_path.path_join(name))
		if res == null:
			push_warning("[GameConfig] failed to load %s" % name)
			continue
		if not ("id" in res):
			push_warning("[GameConfig] %s has no id" % name)
			continue
		var id: StringName = res.id
		if String(id).is_empty():
			push_warning("[GameConfig] %s has empty id" % name)
			continue
		into[id] = res


func get_unit_def(id: StringName) -> UnitData:
	return unit_defs.get(id) as UnitData


func get_building_def(id: StringName) -> BuildingData:
	return building_defs.get(id) as BuildingData


## المباني التي يمكن للاعب إنشاؤها من قائمة البناء (مرتبة حسب build_order).
func get_constructible_buildings() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for def: BuildingData in building_defs.values():
		if def.constructible:
			out.append(def)
	out.sort_custom(func(a: BuildingData, b: BuildingData) -> bool: return a.build_order < b.build_order)
	return out


func seconds_to_ticks(seconds: float) -> int:
	return int(round(seconds * TICK_RATE))


func team_color(player_id: int) -> Color:
	return TEAM_COLORS.get(player_id, Color.WHITE)
