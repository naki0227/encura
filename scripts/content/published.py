#!/usr/bin/env python3
"""List what earlier content migrations already published.

    python scripts/content/published.py [--kind exhibition|daily art|news]

Reads the "-- item:" lines that build_migration.py writes at the top of
every supabase/migrations/*_content_*.sql, newest first.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from content.build_migration import ITEM_MARK  # noqa: E402

MIGRATIONS = Path(__file__).resolve().parents[2] / "supabase" / "migrations"


def published(directory: Path = MIGRATIONS) -> list[tuple[str, str]]:
    items = []
    for path in sorted(directory.glob("*_content_*.sql"), reverse=True):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith(ITEM_MARK):
                kind, _, label = line[len(ITEM_MARK):].partition(" | ")
                items.append((kind, label))
            elif line and not line.startswith("--"):
                break
    return items


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kind")
    args = parser.parse_args()
    for kind, label in published():
        if not args.kind or kind == args.kind:
            print(f"{kind}\t{label}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
