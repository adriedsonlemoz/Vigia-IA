#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
OUT="${1:-$ROOT/../VigiaIA-v${VERSION}-source.zip}"
python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys, zipfile
root=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
exclude_dirs={'.git','.dart_tool','build','.idea','.vscode','__pycache__'}
exclude_files={'android/local.properties'}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(root.rglob('*')):
        rel=p.relative_to(root)
        parts=set(rel.parts)
        if parts & exclude_dirs: continue
        if rel.as_posix() in exclude_files: continue
        if p.is_file(): z.write(p, rel.as_posix())
required={'.github/workflows/android-apk.yml','.gitignore','pubspec.yaml','app_identity.json','README.md','CHANGELOG.md','ARCHITECTURE.md','tool/verify_project.sh','tool/package_source.sh','android/app/src/main/res/mipmap/ic_launcher.xml','android/app/src/main/res/values/styles.xml','android/app/src/main/res/values-night/styles.xml','android/app/src/main/res/drawable/launch_background.xml'}
with zipfile.ZipFile(out) as z:
    names=set(z.namelist())
missing=sorted(required-names)
if missing:
    raise SystemExit('ERRO: ZIP sem arquivos obrigatorios: '+', '.join(missing))
print(out)
PY
