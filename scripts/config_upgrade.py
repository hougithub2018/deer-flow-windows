#!/usr/bin/env python3
"""
config_upgrade.py - Upgrade config.yaml to match config.example.yaml

Cross-platform replacement for config-upgrade.sh.

1. Runs version-specific migrations (value replacements, renames, etc.)
2. Merges missing fields from the example into the user config
3. Backs up config.yaml to config.yaml.bak before modifying.
"""

from __future__ import annotations

import copy
import re
import shutil
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    # Resolve repo root (parent of scripts/ directory)
    repo_root = Path(__file__).resolve().parent.parent
    example_path = repo_root / "config.example.yaml"

    # Resolve config.yaml location: env var > backend/ > repo root
    config_path = None
    env_config = Path(os_environ_get("DEER_FLOW_CONFIG_PATH", "")) if os_environ_get("DEER_FLOW_CONFIG_PATH") else None
    if env_config and env_config.is_file():
        config_path = env_config
    elif (repo_root / "backend" / "config.yaml").is_file():
        config_path = repo_root / "backend" / "config.yaml"
    elif (repo_root / "config.yaml").is_file():
        config_path = repo_root / "config.yaml"

    if not example_path.is_file():
        print(f"config.example.yaml not found at {example_path}", file=sys.stderr)
        return 1

    if config_path is None:
        # No config.yaml found — create from example
        target = repo_root / "config.yaml"
        shutil.copy2(str(example_path), str(target))
        print("config.yaml created. Please review and set your API keys.")
        return 0

    with open(config_path, encoding="utf-8") as f:
        raw_text = f.read()
        user = yaml.safe_load(raw_text) or {}

    with open(example_path, encoding="utf-8") as f:
        example = yaml.safe_load(f) or {}

    user_version = user.get("config_version", 0)
    example_version = example.get("config_version", 0)

    if user_version >= example_version:
        print(f"config.yaml is already up to date (version {user_version}).")
        return 0

    print(f"Upgrading config.yaml: version {user_version} -> {example_version}")
    print()

    # Migrations
    MIGRATIONS = {
        1: {
            "description": "Rename src.* module paths to deerflow.*",
            "replacements": [
                ("src.community.", "deerflow.community."),
                ("src.sandbox.", "deerflow.sandbox."),
                ("src.models.", "deerflow.models."),
                ("src.tools.", "deerflow.tools."),
            ],
        },
    }

    migrated = []
    for version in range(user_version + 1, example_version + 1):
        migration = MIGRATIONS.get(version)
        if not migration:
            continue
        for old, new in migration.get("replacements", []):
            if old in raw_text:
                raw_text = raw_text.replace(old, new)
                migrated.append(f"{old} -> {new}")

    # Re-parse after text migrations
    user = yaml.safe_load(raw_text) or {}

    if migrated:
        print(f"Applied {len(migrated)} migration(s):")
        for m in migrated:
            print(f"  ~ {m}")
        print()

    # Merge missing fields
    added = []

    def merge(target, source, path=""):
        for key, value in source.items():
            key_path = f"{path}.{key}" if path else key
            if key not in target:
                target[key] = copy.deepcopy(value)
                added.append(key_path)
            elif isinstance(value, dict) and isinstance(target[key], dict):
                merge(target[key], value, key_path)

    merge(user, example)

    # Always update config_version
    user["config_version"] = example_version

    # Backup
    backup = config_path.with_suffix(".yaml.bak")
    shutil.copy2(str(config_path), str(backup))
    print(f"Backed up to {backup.name}")

    with open(config_path, "w", encoding="utf-8") as f:
        yaml.dump(user, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    if added:
        print(f"Added {len(added)} new field(s):")
        for a in added:
            print(f"  + {a}")

    if not migrated and not added:
        print("No changes needed (version bumped only).")

    print()
    print(f"config.yaml upgraded to version {example_version}.")
    print("  Please review the changes and set any new required values.")
    return 0


def os_environ_get(key: str, default: str = "") -> str:
    """Helper to avoid importing os at module level (cleaner for scripts)."""
    import os
    return os.environ.get(key, default)


if __name__ == "__main__":
    sys.exit(main())
