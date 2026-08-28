#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

Entry = tuple[str, str, str | None]


def default_version() -> str:
    return datetime.now().strftime("%Y.%m.%d.%H%M%S")


def iter_dict_entries(path: Path):
    in_entries = False

    with path.open("r", encoding="utf-8") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.rstrip("\n")

            if not in_entries:
                if line.strip() == "...":
                    in_entries = True
                continue

            if not line or line.startswith("#"):
                continue

            fields = line.split("\t")
            if len(fields) < 2:
                raise ValueError(f"{path}:{line_no}: expected text and code columns")

            text = fields[0].strip()
            code = fields[1].strip()
            weight = (
                fields[2].strip() if len(fields) > 2 and fields[2].strip() else None
            )

            if text and code:
                yield text, code, weight


def build_phrase_entries(
    *,
    hokchew_dict_path: Path,
) -> list[Entry]:
    seen: set[tuple[str, str]] = set()
    entries: list[Entry] = []

    for text, code, weight in iter_dict_entries(hokchew_dict_path):
        if len(text) <= 1:
            continue

        phrase_code = code.replace(" ", "+")
        key = (text, phrase_code)
        if key in seen:
            continue

        seen.add(key)
        entries.append((text, phrase_code, weight))

    return entries


def write_dict(
    *,
    output_path: Path,
    template_path: Path,
    version: str,
    entries: list[Entry],
) -> None:
    header = template_path.read_text(encoding="utf-8").format(version=version)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="\n") as out:
        out.write(header)
        if not header.endswith("\n"):
            out.write("\n")

        for text, code, weight in entries:
            out.write(text)
            out.write("\t")
            out.write(code)
            if weight is not None:
                out.write("\t")
                out.write(weight)
            out.write("\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Hokchew phrase reverse lookup dictionary."
    )

    parser.add_argument(
        "--hokchew-dict",
        type=Path,
        default=Path("rime/hokchew.dict.yaml"),
        help="Hokchew dictionary to read pronunciations from.",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("rime/hokchew_phrases.dict.yaml"),
        help="Output Rime dictionary path.",
    )

    parser.add_argument(
        "-t",
        "--template",
        type=Path,
        default=Path("templates/hokchew_phrases.dict.yaml"),
        help="Header template path.",
    )

    parser.add_argument(
        "--version",
        default=default_version(),
        help="Dictionary version. Defaults to current build time.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    entries = build_phrase_entries(
        hokchew_dict_path=args.hokchew_dict,
    )
    write_dict(
        output_path=args.output,
        template_path=args.template,
        version=args.version,
        entries=entries,
    )

    print(f"wrote {len(entries)} entries to {args.output}")


if __name__ == "__main__":
    main()
