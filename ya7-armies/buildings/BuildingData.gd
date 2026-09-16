class_name BuildingData
extends Resource
## BuildingData — تعريف مبنى (resource-driven).
## قائمة producible_units تحدد ماذا ينتج هذا المبنى — نظام الإنتاج مبني على البيانات.

enum VisualKind { HQ, BARRACKS, WAR_FACTORY, REFINERY, TOWER }

@export var id: StringName = &""
@export var display_name: String = "Building"
@export var visual_kind: VisualKind = VisualKind.BARRACKS

@export_group("Stats")
@export var max_hp: float = 1000.0
## أبعاد المبنى بالخلايا المنطقية.
@export var footprint: Vector2i = Vector2i(2, 2)

@export_group("Construction")
## هل يظهر في قائمة البناء للاعب؟
@export var constructible: bool = true
@export var build_order: int = 10
@export var cost: int = 500
@export var build_ticks: int = 300
## أقصى مسافة (بالخلايا) عن أقرب مبنى مملوك للسماح بالبناء. 0 = بلا قيد.
@export var max_build_distance: int = 8

@export_group("Production")
## معرّفات الوحدات التي ينتجها هذا المبنى (UnitData.id).
@export var producible_units: Array[StringName] = []
## إزاحة نقطة التجمع الافتراضية من مركز المبنى (بالخلايا).
@export var default_rally_offset: Vector2i = Vector2i(0, 3)

@export_group("Roles")
@export var is_hq: bool = false
@export var is_refinery: bool = false

@export_group("Defense (tower)")
@export var damage: float = 0.0
@export var attack_range: float = 0.0
@export var fire_cooldown_ticks: int = 30

@export_group("Look")
@export var accent_color: Color = Color(0.9, 0.9, 0.9)
@export var height: float = 2.0


func can_produce() -> bool:
	return not producible_units.is_empty()


func has_weapon() -> bool:
	return damage > 0.0 and attack_range > 0.0
