#!/usr/bin/env bash
# يصدّر نسخة الويب (بدون threads) ويجهّز ملفاتها للاستضافة التي تخدم امتدادات محددة فقط:
# يقسّم index.wasm إلى أجزاء ≤12MB بامتداد .wasm ويعيد تسمية .pck إلى .pck.wasm (انظر shell_artifact.html).
# الاستخدام: ./web/build_web.sh /path/to/godot4.3 out_dir
set -euo pipefail
GODOT="${1:-godot}"; OUT="${2:-export/web}"
mkdir -p "$OUT"
"$GODOT" --headless --path "$(dirname "$0")/.." --export-release "Web" "$OUT/index.html"
cd "$OUT"
rm -f index.part*.wasm
split -b 12000000 -d index.wasm index.part
for f in index.part??; do mv "$f" "$f.wasm"; done
mv index.pck index.pck.wasm
cp "$(dirname "$0")/shell_artifact.html" index.html
echo "done: $(ls)"
