#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from ruamel.yaml import YAML


def iter_recipe_files(source_dir: Path):
    for path in sorted(source_dir.rglob("*")):
        if path.is_file():
            yield path


def copy_file(source_path: Path, target_path: Path) -> None:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, target_path)


def write_schema_without_style(source_path: Path, target_path: Path) -> bool:
    yaml = YAML()
    yaml.preserve_quotes = True

    with source_path.open("r", encoding="utf-8") as f:
        data = yaml.load(f)

    removed_style = False
    if isinstance(data, dict) and "style" in data:
        del data["style"]
        removed_style = True

    target_path.parent.mkdir(parents=True, exist_ok=True)
    with target_path.open("w", encoding="utf-8", newline="\n") as f:
        yaml.dump(data, f)

    return removed_style


def build_bim(*, source_dir: Path, output_dir: Path) -> None:
    copied = 0
    stripped = 0

    if not source_dir.is_dir():
        raise ValueError(f"source directory not found: {source_dir}")

    for source_path in iter_recipe_files(source_dir):
        relative_path = source_path.relative_to(source_dir)
        target_path = output_dir / relative_path

        if source_path.name.endswith(".schema.yaml"):
            if write_schema_without_style(source_path, target_path):
                stripped += 1
        else:
            copy_file(source_path, target_path)

        copied += 1

    print(f"copied {copied} files from {source_dir} to {output_dir}")
    print(f"stripped style from {stripped} schema files")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build BIM recipe files from the Rime recipe directory."
    )

    parser.add_argument(
        "-s",
        "--source",
        type=Path,
        default=Path("rime"),
        help="Source Rime recipe directory.",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("bim"),
        help="Output BIM recipe directory.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    build_bim(source_dir=args.source, output_dir=args.output)


if __name__ == "__main__":
    main()
