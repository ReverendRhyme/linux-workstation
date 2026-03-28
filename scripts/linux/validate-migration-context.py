#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import sys


REQUIRED_FILES = {
    "machine-profile.json",
    "software-map.json",
    "paths.json",
    "deployment.seed.env",
    "summary.md",
}


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def require_keys(data, keys, file_name):
    missing = [k for k in keys if k not in data]
    if missing:
        raise ValueError(f"{file_name} missing keys: {', '.join(missing)}")


def validate_context(context_dir: Path):
    if not context_dir.is_dir():
        raise ValueError(f"Context directory not found: {context_dir}")

    existing = {p.name for p in context_dir.iterdir() if p.is_file()}
    missing_files = sorted(REQUIRED_FILES - existing)
    if missing_files:
        raise ValueError("Missing required files: " + ", ".join(missing_files))

    machine = load_json(context_dir / "machine-profile.json")
    require_keys(machine, ["generated_at", "machine_id", "sanitized", "os", "cpu", "memory_gb", "storage"], "machine-profile.json")

    software = load_json(context_dir / "software-map.json")
    require_keys(software, ["generated_at", "apps"], "software-map.json")
    for i, app in enumerate(software.get("apps", []), start=1):
        require_keys(app, ["name", "linux_target", "install_method"], f"software-map.json app[{i}]")

    paths = load_json(context_dir / "paths.json")
    require_keys(paths, ["generated_at", "backup_root", "steam_libraries", "browser_profiles", "dev_paths"], "paths.json")

    seed_lines = (context_dir / "deployment.seed.env").read_text(encoding="utf-8").splitlines()
    seed = {}
    for line in seed_lines:
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        seed[k.strip()] = v.strip()

    for req in ["DEPLOY_PROFILE", "INSTALL_MODE", "MOUNT_GAMES", "MOUNT_STORAGE", "MOUNT_BACKUPS", "USE_FUSION360", "ENABLE_CLOUD_SETUP"]:
        if req not in seed:
            raise ValueError(f"deployment.seed.env missing key: {req}")


def validate_all_contexts(context_root: Path):
    if not context_root.is_dir():
        raise ValueError(f"Context root not found: {context_root}")

    context_dirs = sorted(
        [
            p
            for p in context_root.iterdir()
            if p.is_dir() and (p / "machine-profile.json").is_file()
        ]
    )

    if not context_dirs:
        raise ValueError(f"No context directories found under: {context_root}")

    failures = []
    for context_dir in context_dirs:
        try:
            validate_context(context_dir)
            print(f"[+] Migration context valid: {context_dir}")
        except Exception as exc:
            failures.append((context_dir, str(exc)))

    if failures:
        for context_dir, reason in failures:
            print(f"[ERROR] {context_dir}: {reason}", file=sys.stderr)
        raise ValueError(f"{len(failures)} context validation failure(s)")

    print(f"[+] Validated {len(context_dirs)} context directory(s)")


def main():
    parser = argparse.ArgumentParser(description="Validate migration context files")
    parser.add_argument("--context-dir", help="Migration context directory")
    parser.add_argument(
        "--all-contexts",
        action="store_true",
        help="Validate all context directories under --context-root",
    )
    parser.add_argument(
        "--context-root",
        default="migration/context",
        help="Root directory containing context subdirectories (default: migration/context)",
    )
    args = parser.parse_args()

    try:
        if args.all_contexts:
            validate_all_contexts(Path(args.context_root))
        else:
            if not args.context_dir:
                raise ValueError("--context-dir is required unless --all-contexts is set")
            validate_context(Path(args.context_dir))
            print(f"[+] Migration context valid: {args.context_dir}")
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
