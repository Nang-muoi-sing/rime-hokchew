#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import yaml


def split_dict(path: Path) -> tuple[str, str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    in_meta = False

    for index, line in enumerate(lines):
        if line.strip() == "---":
            in_meta = True
            continue

        if in_meta and line.strip() == "...":
            return "".join(lines[: index + 1]), "".join(lines[index + 1 :])

    raise ValueError(f"{path}: failed to find dictionary metadata block")


def read_source_version(header: str, path: Path) -> str:
    lines = header.splitlines()

    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == "---")
        end = next(
            i
            for i, line in enumerate(lines[start + 1 :], start + 1)
            if line.strip() == "..."
        )
    except StopIteration:
        raise ValueError(f"{path}: failed to find dictionary metadata block") from None

    data: Any = yaml.safe_load("\n".join(lines[start + 1 : end])) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected mapping in dictionary metadata")

    version = data.get("version")
    if version is None:
        raise ValueError(f"{path}: source dictionary metadata is missing version")

    return str(version)


def read_template(template_path: Path, *, version: str) -> str:
    template = template_path.read_text(encoding="utf-8")
    return template.format(version=version)


def write_pinyin_dict(
    *,
    input_path: Path,
    output_path: Path,
    template_path: Path,
    version: str | None,
) -> None:
    source_header, entries = split_dict(input_path)
    output_version = version or read_source_version(source_header, input_path)
    header = read_template(template_path, version=output_version)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="\n") as out:
        out.write(header)
        if not header.endswith("\n"):
            out.write("\n")
        out.write(entries.lstrip("\n"))

    print(f"wrote pinyin dictionary to {output_path}")
    print(f"source: {input_path}")
    print(f"version: {output_version}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Hokchew reverse lookup pinyin dictionary from luna_pinyin."
    )

    parser.add_argument(
        "-i",
        "--input",
        type=Path,
        default=Path("data/rime-luna-pinyin/luna_pinyin.dict.yaml"),
        help="Input luna_pinyin dictionary path.",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("rime/hokchew_pinyin.dict.yaml"),
        help="Output Rime dictionary path.",
    )

    parser.add_argument(
        "-t",
        "--template",
        type=Path,
        default=Path("templates/hokchew_pinyin.dict.yaml"),
        help="Header template path.",
    )

    parser.add_argument(
        "--version",
        help="Dictionary version. Defaults to the source luna_pinyin version.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    write_pinyin_dict(
        input_path=args.input,
        output_path=args.output,
        template_path=args.template,
        version=args.version,
    )


if __name__ == "__main__":
    main()
