#!/usr/bin/env python3
"""Cross-platform dependency checker for DeerFlow."""

from __future__ import annotations

import io
import os
import platform
import shutil
import subprocess
import sys
from typing import Optional

# Fix encoding on Windows (GBK console cannot print Unicode symbols like ✓/✗)
if platform.system() == "Windows":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

OK = "  [OK] "
FAIL = "  [FAIL] "
WARN = "  [WARN] "


def run_command(command: list[str]) -> Optional[str]:
    """Run a command and return trimmed stdout, or None on failure."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True, shell=True)
        output = (result.stdout or "").strip()
        if not output:
            output = (result.stderr or "").strip()
        return output or None
    except (OSError, subprocess.CalledProcessError):
        return None


def parse_node_major(version_text: str) -> Optional[int]:
    version = version_text.strip()
    if version.startswith("v"):
        version = version[1:]
    major_str = version.split(".", 1)[0]
    if not major_str.isdigit():
        return None
    return int(major_str)


def main() -> int:
    print("==========================================")
    print("  Checking Required Dependencies")
    print("==========================================")
    print()

    failed = False

    print("Checking Node.js...")
    node_path = shutil.which("node")
    if node_path:
        node_version = run_command(["node", "-v"])
        if node_version:
            major = parse_node_major(node_version)
            if major is not None and major >= 22:
                print(f"{OK}Node.js {node_version.lstrip('v')} (>= 22 required)")
            else:
                print(
                    f"{FAIL}Node.js {node_version.lstrip('v')} found, but version 22+ is required"
                )
                print("    Install from: https://nodejs.org/")
                failed = True
        else:
            print(f"{FAIL}Unable to determine Node.js version")
            print("    Install from: https://nodejs.org/")
            failed = True
    else:
        print(f"{FAIL}Node.js not found (version 22+ required)")
        print("    Install from: https://nodejs.org/")
        failed = True

    print()
    print("Checking pnpm...")
    if shutil.which("pnpm"):
        pnpm_version = run_command(["pnpm", "-v"])
        if pnpm_version:
            print(f"{OK}pnpm {pnpm_version}")
        else:
            print(f"{FAIL}Unable to determine pnpm version")
            failed = True
    else:
        print(f"{FAIL}pnpm not found")
        print("    Install: npm install -g pnpm")
        print("    Or visit: https://pnpm.io/installation")
        failed = True

    print()
    print("Checking uv...")
    if shutil.which("uv"):
        uv_version_text = run_command(["uv", "--version"])
        if uv_version_text:
            # uv --version outputs "uv x.y.z ( ... )" — take the version part only
            uv_version = uv_version_text.split()[0].lstrip("uv").strip() or uv_version_text.split()[-1].rstrip(")")
            print(f"{OK}uv {uv_version}")
        else:
            print(f"{FAIL}Unable to determine uv version")
            failed = True
    else:
        print(f"{FAIL}uv not found")
        print("    Visit the official installation guide for your platform:")
        print("    https://docs.astral.sh/uv/getting-started/installation/")
        failed = True

    print()
    print("Checking nginx...")
    if shutil.which("nginx"):
        nginx_version_text = run_command(["nginx", "-v"])
        if nginx_version_text and "/" in nginx_version_text:
            nginx_version = nginx_version_text.split("/", 1)[1]
            print(f"{OK}nginx {nginx_version}")
        else:
            print(f"{OK}nginx (version unknown)")
    else:
        if platform.system() == "Windows":
            print(f"{WARN}nginx not found (optional on Windows)")
            print("    Windows native mode can run without nginx.")
            print("    Install from: https://nginx.org/en/download.html")
            print("    Or skip nginx and access services directly:")
            print("      Frontend:  http://localhost:3000")
            print("      Gateway:   http://localhost:8001")
            print("      LangGraph: http://localhost:2024")
        else:
            print(f"{FAIL}nginx not found")
            print("    macOS:   brew install nginx")
            print("    Ubuntu:  sudo apt install nginx")
            print("    Or visit: https://nginx.org/en/download.html")
            failed = True

    print()
    if not failed:
        print("==========================================")
        print("  All dependencies are installed!")
        print("==========================================")
        print()
        if platform.system() == "Windows":
            print("You can now run:")
            print("  pwsh scripts/install.ps1    - Install project dependencies")
            print("  pwsh scripts/dev.ps1        - Start development server")
            print("  pwsh scripts/stop.ps1       - Stop all services")
        else:
            print("You can now run:")
            print("  make install  - Install project dependencies")
            print("  make config   - Generate local config files")
            print("  make dev      - Start development server")
            print("  make start    - Start production server")
        return 0

    print("==========================================")
    print("  Some dependencies are missing")
    print("==========================================")
    print()
    print("Please install the missing tools and run 'make check' (or 'python scripts/check.py') again.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
