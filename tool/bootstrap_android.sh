#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter nao encontrado no PATH." >&2
  exit 1
fi

MANIFEST_SOURCE="$ROOT/tool/AndroidManifest.xml"
if [[ ! -f "$MANIFEST_SOURCE" ]]; then
  echo "Manifesto base nao encontrado: $MANIFEST_SOURCE" >&2
  exit 1
fi

rm -rf android
flutter create --empty --platforms=android --org com.vigiaia --project-name vigiaia .

# Defesa adicional para templates que ainda gerem o teste de contador.
# So removemos o arquivo quando ele for claramente o exemplo padrao com MyApp,
# preservando um eventual widget_test.dart real criado pelo projeto no futuro.
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm -f test/widget_test.dart
fi

cp "$MANIFEST_SOURCE" android/app/src/main/AndroidManifest.xml

rm -rf android/app/src/main/kotlin/*
KOTLIN_DIR="android/app/src/main/kotlin/com/vigiaia/app"
mkdir -p "$KOTLIN_DIR"
cp "$ROOT/tool/android/MainActivity.kt" "$KOTLIN_DIR/MainActivity.kt"
cp "$ROOT/tool/android/MonitoringForegroundService.kt" "$KOTLIN_DIR/MonitoringForegroundService.kt"
cp "$ROOT/tool/android/MonitorRecoveryReceiver.kt" "$KOTLIN_DIR/MonitorRecoveryReceiver.kt"

BUILD_FILE="android/app/build.gradle.kts"
python3 - "$BUILD_FILE" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 29', text)
text = re.sub(r'namespace\s*=\s*"[^"]+"', 'namespace = "com.vigiaia.app"', text)
text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.vigiaia.app"', text)
if 'minSdk = 29' not in text:
    raise SystemExit('Nao foi possivel ajustar minSdk para 29')
if 'namespace = "com.vigiaia.app"' not in text or 'applicationId = "com.vigiaia.app"' not in text:
    raise SystemExit('Nao foi possivel aplicar a identidade Android vigiaia')
path.write_text(text)
PY

echo "Android recriado pelo template atual do Flutter com minSdk 29 e servico de monitoramento."
