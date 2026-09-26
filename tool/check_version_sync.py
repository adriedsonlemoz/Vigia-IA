#!/usr/bin/env python3
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def fail(message: str) -> None:
    raise SystemExit(f"ERRO DE VERSIONAMENTO: {message}")

pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
match = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$", pubspec, re.M)
if not match:
    fail("version em pubspec.yaml nao encontrada")
version, build_text = match.groups()
build = int(build_text)
full = f"{version}+{build}"

metadata = (root / "lib/core/app_metadata.dart").read_text(encoding="utf-8")
if f"static const String version = '{version}';" not in metadata:
    fail("AppMetadata.version diverge do pubspec")
if f"static const int build = {build};" not in metadata:
    fail("AppMetadata.build diverge do pubspec")

identity = json.loads((root / "app_identity.json").read_text(encoding="utf-8"))
if identity.get("version") != version or identity.get("build") != build:
    fail("app_identity.json diverge do pubspec")

github_manager_path = root / "github-manager.json"
if not github_manager_path.exists():
    fail("github-manager.json ausente")
github_manager = json.loads(github_manager_path.read_text(encoding="utf-8"))
android_manifest = github_manager.get("android") or {}
if github_manager.get("version") != version or github_manager.get("build") != build:
    fail("github-manager.json diverge do pubspec")
if android_manifest.get("versionName") != version or android_manifest.get("versionCode") != build:
    fail("github-manager.json android diverge do pubspec")
if android_manifest.get("applicationId") != identity.get("applicationId"):
    fail("github-manager.json applicationId diverge de app_identity.json")

metadata_test = (root / "test/app_metadata_test.dart").read_text(encoding="utf-8")
if f"expect(AppMetadata.version, '{version}');" not in metadata_test:
    fail("test/app_metadata_test.dart espera uma versao diferente do pubspec")
if f"expect(AppMetadata.build, {build});" not in metadata_test:
    fail("test/app_metadata_test.dart espera um build diferente do pubspec")

release_notes = root / f"RELEASE-{version}.md"
if not release_notes.exists():
    fail(f"notas de release ausentes: {release_notes.name}")

readme = (root / "README.md").read_text(encoding="utf-8")
if f"**Versão atual:** `{full}`" not in readme:
    fail("README nao marca a versao atual")

changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
if f"## {full}" not in changelog:
    fail("CHANGELOG nao possui entrada para a versao atual")

architecture = (root / "ARCHITECTURE.md").read_text(encoding="utf-8")
if f"# Arquitetura — Vigia IA {full}" not in architecture:
    fail("ARCHITECTURE nao marca a versao atual")

app_info = (root / "lib/screens/app_info_screen.dart").read_text(encoding="utf-8") + \
    (root / "lib/screens/app_info_screen_components.dart").read_text(encoding="utf-8")
current_pattern = re.compile(
    rf"_ReleaseCard\(\s*version:\s*'{re.escape(version)}',\s*current:\s*true,",
    re.S,
)
if not current_pattern.search(app_info):
    fail("Tela Mudancas nao marca a versao atual como current")

print(f"Versionamento sincronizado: {full}")
