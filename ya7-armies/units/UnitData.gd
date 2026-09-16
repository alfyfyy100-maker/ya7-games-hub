class_name UnitData
extends Resource
## UnitData — تعريف وحدة (resource-driven). كل القيم هنا وليس في الكود.
## أضف ملف .tres جديد في res://units/data/ لإضافة وحدة جديدة.

enum Category { INFANTRY, VEHICLE, HARVESTER }
enum VisualKind { SOLDIER, ARCHER, ENGINEER, TANK, HARVESTER, APC }

@export var id: StringName = &""
@export var display_name: String = "Unit"
@export var category: Category = Category.INFANTRY
@export var visual_kind: VisualKind = VisualKind.SOLDIER

@export_group("Stats")
@export var max_hp: float = 100.0
## سرعة بوحدات العالم/ثانية (تُحوَّل إلى مسافة/فريم في المحاكاة).
@export var speed: float = 6.0
## نصف قطر الوحدة (للاختيار والتباعد البصري).
@export var radius: float = 0.5

@export_group("Combat")
@export var damage: float = 0.0
## المدى بوحدات العالم. 0 = لا سلاح.
@export var attack_range: float = 0.0
## زمن إعادة الإطلاق بالفريمات.
@export var fire_cooldown_ticks: int = 30
## مدى الاشتباك التلقائي (كم تبعد الوحدة لتبحث عن أهداف بنفسها).
@export var aggro_range: float = 10.0

@export_group("Production")
@export var cost: int = 100
@export var build_ticks: int = 150

@export_group("Harvesting")
@export var can_harvest: bool = false
@export var cargo_capacity: int = 100
## فريمات لجمع وحدة مورد واحدة.
@export var gather_ticks_per_unit: int = 2
@export var unload_ticks: int = 30

@export_group("Look")
@export var accent_color: Color = Color(0.95, 0.85, 0.3)
@export var scale: float = 1.0


func has_weapon() -> bool:
	return damage > 0.0 and attack_range > 0.0


func speed_per_tick() -> float:
	return speed / float(GameConfig.TICK_RATE)
