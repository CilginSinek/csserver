#!/usr/bin/env python3
"""Remove files ignored by this project's .gitignore."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
IGNORED_DIRS = {"data", "logs", "run", "runtime", "downloads", "server",
                "__pycache__", ".pytest_cache", ".venv", "venv"}
IGNORED_SUFFIXES = {".pyc", ".pyo", ".pyd", ".amxx", ".amx", ".o"}
IGNORED_NAMES = {".DS_Store", "Thumbs.db"}


def in_git_repo():
    return subprocess.run(
        ["git", "rev-parse", "--is-inside-work-tree"], cwd=ROOT,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0


def fallback_candidates():
    candidates = set()
    for path in ROOT.iterdir():
        if path.name.startswith(".env") and path.name != ".env.example":
            candidates.add(path)
        if path.is_dir() and path.name in IGNORED_DIRS:
            candidates.add(path)

    for current, dirs, files in os.walk(ROOT, topdown=True, followlinks=False):
        directory = Path(current)
        dirs[:] = [name for name in dirs if name != ".git"]
        for name in list(dirs):
            path = directory / name
            if name in IGNORED_DIRS:
                candidates.add(path)
                dirs.remove(name)
        for name in files:
            path = directory / name
            if name in IGNORED_NAMES or path.suffix in IGNORED_SUFFIXES:
                candidates.add(path)
    return sorted(candidates, key=lambda path: (len(path.parts), str(path)))


def main():
    parser = argparse.ArgumentParser(description="Remove .gitignore-excluded local files")
    parser.add_argument("--dry-run", action="store_true", help="show deletions without removing them")
    args = parser.parse_args()

    if in_git_repo():
        command = ["git", "clean", "-Xdf"]
        if args.dry_run:
            command.insert(2, "-n")
        return subprocess.run(command, cwd=ROOT).returncode

    candidates = fallback_candidates()
    for path in candidates:
        print(("would remove " if args.dry_run else "remove ") + str(path.relative_to(ROOT)))
        if args.dry_run:
            continue
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
