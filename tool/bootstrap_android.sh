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
cp "$ROOT/tool/android/CompassStreamHandler.kt" "$KOTLIN_DIR/CompassStreamHandler.kt"
cp "$ROOT/tool/android/AlertAudioPlayer.kt" "$KOTLIN_DIR/AlertAudioPlayer.kt"
cp "$ROOT/tool/android/AudioResourceCatalog.kt" "$KOTLIN_DIR/AudioResourceCatalog.kt"
cp "$ROOT/tool/android/MonitorSystemUi.kt" "$KOTLIN_DIR/MonitorSystemUi.kt"
cp "$ROOT/tool/android/MonitoringForegroundService.kt" "$KOTLIN_DIR/MonitoringForegroundService.kt"
cp "$ROOT/tool/android/MonitorRecoveryReceiver.kt" "$KOTLIN_DIR/MonitorRecoveryReceiver.kt"

# Áudios personalizados opcionais. Eles ficam fora de android/ para sobreviver
# à recriação completa feita por este bootstrap.
CUSTOM_AUDIO_DIR="$ROOT/custom_audio"
RAW_DIR="$ROOT/android/app/src/main/res/raw"
if [[ -d "$CUSTOM_AUDIO_DIR" ]]; then
  mkdir -p "$RAW_DIR"
  declare -A AUDIO_SLOTS=()
  shopt -s nullglob
  for AUDIO_FILE in "$CUSTOM_AUDIO_DIR"/*.wav "$CUSTOM_AUDIO_DIR"/*.mp3 "$CUSTOM_AUDIO_DIR"/*.ogg "$CUSTOM_AUDIO_DIR"/*.m4a "$CUSTOM_AUDIO_DIR"/*.aac; do
    BASENAME="$(basename "$AUDIO_FILE")"
    STEM="${BASENAME%.*}"
    if [[ ! "$STEM" =~ ^[a-z0-9_]+$ ]]; then
      echo "Nome de áudio inválido para Android: $BASENAME" >&2
      exit 1
    fi
    if [[ -n "${AUDIO_SLOTS[$STEM]:-}" ]]; then
      echo "Mais de um arquivo para o slot de áudio '$STEM'. Use apenas uma extensão." >&2
      exit 1
    fi
    AUDIO_SLOTS[$STEM]="$BASENAME"
    cp "$AUDIO_FILE" "$RAW_DIR/$BASENAME"
  done
  shopt -u nullglob
fi

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

signing_block = r'''    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val keyAliasValue = System.getenv("ANDROID_KEY_ALIAS")
            val keyPasswordValue = System.getenv("ANDROID_KEY_PASSWORD")

            if (keystorePath.isNullOrBlank() || keystorePassword.isNullOrBlank() ||
                keyAliasValue.isNullOrBlank() || keyPasswordValue.isNullOrBlank()) {
                throw GradleException("Secrets de assinatura release ausentes. Configure ANDROID_KEYSTORE_BASE64/PASSWORD/ALIAS/KEY_PASSWORD no GitHub.")
            }

            storeFile = rootProject.file(keystorePath)
            storePassword = keystorePassword
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

'''
multi_apk_block = r'''    // No CI otimizado, uma unica tarefa Gradle gera o APK universal e os tres APKs por ABI.
    // Builds locais continuam com o comportamento padrao do Flutter.
    val multiApkCi = providers.environmentVariable("VIGIAIA_CI_MULTI_APK").orNull == "1"
    if (multiApkCi) {
        splits {
            abi {
                isEnable = true
                reset()
                include("armeabi-v7a", "arm64-v8a", "x86_64")
                isUniversalApk = true
            }
        }
    }

'''
if 'VIGIAIA_CI_MULTI_APK' not in text:
    marker = '    signingConfigs {\n'
    if marker not in text:
        marker = '    buildTypes {\n'
    if marker not in text:
        raise SystemExit('Bloco Android nao encontrado para configurar APKs multiplos')
    text = text.replace(marker, multi_apk_block + marker, 1)

if 'signingConfigs {\n        create("release")' not in text:
    marker = '    buildTypes {\n'
    if marker not in text:
        raise SystemExit('Bloco buildTypes nao encontrado para assinatura release')
    text = text.replace(marker, signing_block + marker, 1)
text = text.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
if 'signingConfig = signingConfigs.getByName("release")' not in text:
    raise SystemExit('Nao foi possivel aplicar signingConfig release')
if 'signingConfigs.getByName("debug")' in text:
    raise SystemExit('Assinatura debug ainda presente no release')
path.write_text(text)
PY

cat >> android/gradle.properties <<'EOF'
org.gradle.caching=true
org.gradle.parallel=true
EOF

echo "Android recriado pelo template atual do Flutter com minSdk 29, servico de monitoramento, build otimizado e assinatura release permanente."
