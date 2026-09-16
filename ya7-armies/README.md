# Ya7 Armies — أساس لعبة استراتيجية حربية (Godot 4.x / GDScript / 3D)

لعبة RTS بمنظور علوي بأسلوب **8-Bit Armies** لكن برسوم كرتونية ملوّنة (low-poly + toon shading).
هذا المستودع هو **الأساس (foundation)**: بنية صارمة تفصل المحاكاة عن العرض، جاهزة للتوسع نحو
Android/iOS ثم الأونلاين.

> المحرك: Godot **4.3+** (المشروع مبني ومختبر على 4.3 stable). المعرض: `mobile`.

## التشغيل

- افتح المجلد `ya7-armies/` من Godot 4.3+ ثم Play (المشهد الرئيسي `maps/Main.tscn`).
- اختبار المحاكاة بدون عرض (يتحقق من الحتمية):
  ```
  godot --headless --path . tests/SimTest.tscn
  ```
- لقطات شاشة آلية (Linux + Xvfb):
  ```
  xvfb-run -a godot --rendering-driver opengl3 --path . tests/Screenshot.tscn -- /tmp/shots
  ```

## التحكم

| اللمس | الفأرة/لوحة المفاتيح |
|---|---|
| سحب بإصبع = تحريك الكاميرا (أو مربع تحديد عند تبديل زر «سحب: تحديد») | زر أوسط = تحريك، عجلة = زوم، Tab = تبديل وضع السحب |
| إصبعان: pinch = زوم، تدوير = لفّ الكاميرا | Q/E = لفّ، WASD/الأسهم = تحريك |
| نقرة على وحدة/مبنى مملوك = اختيار | زر يمين = أمر مباشر للوحدات المختارة |
| نقرة على الأرض/عدو/مورد مع وحدات مختارة = تحرك/هجوم/جمع | Esc = إلغاء الأداة أو الاختيار |

## البنية

```
ya7-armies/
├── project.godot
├── autoload/
│   ├── RNG.gd          # xorshift32 مبذور — كل العشوائية تمر هنا
│   ├── GameConfig.gd   # ثوابت + سجل البيانات (يحمّل .tres تلقائيًا)
│   └── GameState.gd    # حالة اللعبة الكاملة + حلقة المحاكاة (فريم ثابت)
├── units/
│   ├── UnitData.gd     # Resource: صحة/سرعة/ضرر/مدى/تكلفة/جمع...
│   ├── data/*.tres     # soldier, archer, engineer, tank, apc, harvester
│   ├── Locomotion.gd   # حركة على المسار (مشتركة بين الحالات)
│   ├── UnitStateMachine.gd
│   ├── states/         # Idle / Move / Attack / Gather / Dead
│   └── UnitView.gd     # عرض الوحدة (يقرأ الحالة فقط)
├── buildings/
│   ├── BuildingData.gd # Resource: بصمة/تكلفة/producible_units/برج...
│   ├── data/*.tres     # hq, refinery, barracks, war_factory, defense_tower
│   └── BuildingView.gd
├── systems/
│   ├── simulation/     # SimEntity, UnitSystem, VictorySystem
│   ├── terrain/        # MapState (heightmap منطقي)
│   ├── pathfinding/    # NavGrid (شبكة غير مرئية، AStarGrid2D)
│   ├── production/     # ProductionSystem (بناء + قوائم إنتاج)
│   ├── combat/         # CombatSystem (أبراج + تنظيف الجثث)
│   ├── economy/        # EconomySystem
│   ├── ai/             # SimpleAI
│   ├── input/          # InputController (لمس أولًا)
│   └── view/           # WorldView, MeshFactory, ResourceView
├── maps/               # Main.tscn, Main.gd, TerrainMesh.gd (ميش الأرض)
├── ui/                 # HUD, WorldOverlay, CameraRig
├── assets/             # shaders (toon/terrain/water), fonts (Cairo, OFL)
└── tests/              # SimTest (headless)، Screenshot (Xvfb)
```

## القواعد الإلزامية (مطبّقة)

1. **العشوائية**: `RNG` autoload (xorshift32 مكتوب يدويًا، مبذور). لا `randi()/randf()` في المنطق.
   نفس البذرة ⇒ نفس الخريطة ونفس المباراة. `tests/SimTest.gd` يتحقق من ذلك بتشغيل مباراتين ومقارنة اللقطتين.
2. **التوقيت بالفريمات**: `GameState._physics_process` يزيد `tick` مرة واحدة كل فريم فيزيائي ثابت
   (`TICK_RATE = 30`). كل المدد (إنتاج، إعادة إطلاق، جمع، موت) أعداد فريمات في ملفات `.tres`.
   لا `OS.get_ticks_msec` ولا `Time.*` داخل المنطق (البذرة الابتدائية فقط تُختار في `Main.gd` خارج المنطق).
3. **فصل الحالة عن العرض**:
   - الحالة: `GameState` + `SimEntity` (بيانات فقط، قابلة للتسلسل عبر `to_dict/from_dict` و`snapshot()`).
   - العرض: `WorldView` ينشئ `UnitView/BuildingView/ResourceView` استجابةً لإشارات `entity_spawned/removed`،
     وكل view يقرأ `GameState.get_entity(id)` كل فريم ويستوفي الموقع بين `prev_pos` و`pos`.
   - الأوامر تدخل من مكان واحد فقط: `GameState.issue_command(ids, cmd)` (اللاعب، الـ AI، ولاحقًا الشبكة).
     وتُسجَّل مع رقم الفريم في `command_log` (أساس lockstep/replay).
4. **آلة حالة للوحدات**: `units/states/*` — كل حالة صنف مستقل يعمل على `SimEntity`.

## الأرض

- **بصريًا**: ميش واحد مستمر (`maps/TerrainMesh.gd`) من خريطة ارتفاعات ناعمة (ضجيج قيمي بطبقتين عبر RNG)،
  ألوان رؤوس تتدرج (قاع → رمل → عشب → عشب فاتح، صخر على المنحدرات) بلا خطوط حادة، + سطح ماء.
- **منطقيًا**: `NavGrid` شبكة 48×48 غير مرئية (خلية = 2 وحدات) للمسارات وصلاحية البناء
  (ماء/انحدار/خلايا محجوزة). اللاعب لا يراها.

## نظام الإنتاج (مبني على البيانات)

كل `BuildingData.tres` يحدد `producible_units` (قائمة معرّفات `UnitData.id`):

| المبنى | ينتج |
|---|---|
| المقر الرئيسي | حصّادة |
| ثكنة | جندي، رامي، مهندس |
| مصنع مركبات | دبابة، مدرّعة، حصّادة |
| مصفاة | — (نقطة تفريغ الحصّادات) |
| برج دفاعي | — (يدافع تلقائيًا) |

عند اختيار مبنى تظهر أزراره من هذه القائمة؛ التكلفة تُخصم فورًا، شريط تقدّم فوق المبنى،
والوحدة تخرج عند أقرب خلية للـ rally point (قابل للتحديد بزر «نقطة التجمع»).

### إضافة وحدة/مبنى جديد
1. انسخ ملف `.tres` في `units/data/` أو `buildings/data/` وعدّل القيم (لا حاجة لتعديل الكود).
2. لإظهار الوحدة في مبنى: أضف معرّفها إلى `producible_units` في ملف المبنى.
3. الشكل: اختر `visual_kind` موجودًا، أو أضف فرعًا جديدًا في `MeshFactory.make_unit/make_building`
   (لاحقًا: استبدله بـ `PackedScene` من ملفات glTF).

## الموبايل

- المعرض `mobile`، بدون ظلال ديناميكية، مواد مشتركة (cache في `MeshFactory`)، أرض بميش واحد،
  الأشرطة والمربعات تُرسم في Control واحد (`WorldOverlay`).
- الواجهة Control + anchors مع `stretch: canvas_items / expand` وتوجيه `sensor_landscape`.
- `emulate_touch_from_mouse = true`: كل منطق التحكم مكتوب لأحداث اللمس، والفأرة تحاكيها.
- للتصدير: أضف export preset لـ Android/iOS من محرر Godot (Project → Export). لا يوجد اعتماد على
  أي إضافة خارجية.

## الأونلاين لاحقًا (جاهزية)

- المحاكاة حتمية (بذرة + أوامر مؤرخة بالفريم) ⇒ يمكن تطبيق **lockstep** بإرسال الأوامر فقط،
  أو **server-authoritative** بإرسال `GameState.snapshot()`.
- ملاحظة: الحتمية عبر الأجهزة المختلفة تتطلب لاحقًا مراجعة العمليات العشرية (أو التحول لأعداد ثابتة النقطة)؛
  البنية الحالية تحصر كل الحسابات في `systems/` و`units/states/` مما يسهّل ذلك.

## الخطوات التالية المقترحة
- تفادي التصادم بين الوحدات (steering/separation) وتجميع تشكيلي أفضل.
- Fog of war، minimap، أصوات، مؤثرات إطلاق/انفجار.
- استبدال placeholders بنماذج glTF كرتونية.
- حدود سكانية، تكنولوجيا، أنواع موارد إضافية.
