extends Node
## RNG — مولّد أرقام عشوائية مبذور (xorshift32) مكتوب يدويًا.
##
## القاعدة الإلزامية: كل عشوائية في منطق اللعبة تمر من هنا.
## ممنوع استخدام randi()/randf()/randomize() المدمجة في منطق اللعبة.
## البذرة نفسها = نفس تسلسل الأرقام على كل الأجهزة (مهم للأونلاين لاحقًا).

const MASK32: int = 0xFFFFFFFF
const DEFAULT_SEED: int = 0x2545F491

var seed_value: int = DEFAULT_SEED
var _state: int = DEFAULT_SEED
## عدد الاستدعاءات منذ آخر بذر — مفيد للتشخيص ومزامنة الحالة.
var call_count: int = 0


func _ready() -> void:
	seed_rng(DEFAULT_SEED)


## يبذر المولّد. البذرة صفر غير صالحة لـ xorshift فتُستبدل بثابت.
func seed_rng(new_seed: int) -> void:
	seed_value = new_seed
	_state = new_seed & MASK32
	if _state == 0:
		_state = 0x9E3779B9
	call_count = 0
	# تسخين: يشتّت البذور المتقاربة
	for _i in 4:
		next_u32()
	call_count = 0


## xorshift32 — يرجّع عددًا صحيحًا في [0, 2^32).
func next_u32() -> int:
	var x: int = _state
	x ^= (x << 13) & MASK32
	x ^= (x >> 17)
	x ^= (x << 5) & MASK32
	_state = x & MASK32
	call_count += 1
	return _state


## عدد عشري في [0.0, 1.0).
func next_float() -> float:
	return float(next_u32() >> 8) / float(1 << 24)


## عدد صحيح في [lo, hi] (شامل الطرفين).
func range_int(lo: int, hi: int) -> int:
	if hi <= lo:
		return lo
	var span: int = hi - lo + 1
	return lo + int(next_u32() % span)


## عدد عشري في [lo, hi).
func range_float(lo: float, hi: float) -> float:
	return lo + (hi - lo) * next_float()


## يرجّع true باحتمال p (0..1).
func chance(p: float) -> bool:
	return next_float() < p


## يختار عنصرًا عشوائيًا من مصفوفة (null لو فاضية).
func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[range_int(0, arr.size() - 1)]


## خلط Fisher–Yates داخل المصفوفة نفسها.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = range_int(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## لقطة من حالة المولّد (للحفظ/المزامنة).
func get_state() -> Dictionary:
	return {"seed": seed_value, "state": _state, "calls": call_count}


func set_state(s: Dictionary) -> void:
	seed_value = int(s.get("seed", DEFAULT_SEED))
	_state = int(s.get("state", DEFAULT_SEED)) & MASK32
	call_count = int(s.get("calls", 0))
