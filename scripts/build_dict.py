#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from datetime import datetime
from pathlib import Path
from typing import Iterable

import yaml

TEXT_FIELD = "word__text"
CODE_FIELD = "yngping"


def default_version() -> str:
    return datetime.now().strftime("%Y.%m.%d.%H%M%S")


def normalize_text(value: str) -> str:
    return value.strip().replace("*", "")


def normalize_code(value: str) -> str:
    return " ".join(value.strip().lower().split())


def read_header(template_path: Path, *, version: str) -> str:
    template = template_path.read_text(encoding="utf-8")
    return template.format(version=version)


def iter_entries(tsv_paths: Iterable[Path]):
    for tsv_path in tsv_paths:
        with tsv_path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f, delimiter="\t")

            if reader.fieldnames is None:
                raise ValueError(f"{tsv_path}: missing header row")

            missing = {TEXT_FIELD, CODE_FIELD} - set(reader.fieldnames)
            if missing:
                missing_cols = ", ".join(sorted(missing))
                raise ValueError(
                    f"{tsv_path}: missing required columns: {missing_cols}"
                )

            for line_no, row in enumerate(reader, start=2):
                text = normalize_text(row.get(TEXT_FIELD, ""))
                code = normalize_code(row.get(CODE_FIELD, ""))

                if not text or not code:
                    continue

                if "\t" in text or "\n" in text:
                    raise ValueError(f"{tsv_path}:{line_no}: invalid text: {text!r}")

                if "\t" in code or "\n" in code:
                    raise ValueError(f"{tsv_path}:{line_no}: invalid code: {code!r}")

                yield text, code


def load_weights(path: Path | None) -> dict[tuple[str, str], int]:
    if path is None or not path.exists():
        return {}

    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected mapping: text -> code -> weight")

    weights: dict[tuple[str, str], int] = {}

    for raw_text, raw_code_map in data.items():
        text = normalize_text(str(raw_text))

        if not isinstance(raw_code_map, dict):
            raise ValueError(f"{path}: invalid weight entry for {raw_text!r}")

        for raw_code, raw_weight in raw_code_map.items():
            code = normalize_code(str(raw_code))

            try:
                weight = int(raw_weight)
            except (TypeError, ValueError):
                raise ValueError(
                    f"{path}: invalid weight for {text!r} / {code!r}: {raw_weight!r}"
                ) from None

            weights[(text, code)] = weight

    return weights


def write_dict(
    *,
    input_paths: list[Path],
    output_path: Path,
    template_path: Path,
    weights_path: Path | None,
    version: str,
    dedupe: bool,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    header = read_header(template_path, version=version)
    weights = load_weights(weights_path)

    seen: set[tuple[str, str]] = set()
    written = 0
    weighted = 0
    skipped_duplicates = 0

    with output_path.open("w", encoding="utf-8", newline="\n") as out:
        out.write(header)
        if not header.endswith("\n"):
            out.write("\n")

        for text, code in iter_entries(input_paths):
            key = (text, code)

            if dedupe and key in seen:
                skipped_duplicates += 1
                continue

            seen.add(key)

            out.write(text)
            out.write("\t")
            out.write(code)

            weight = weights.get(key)
            if weight is not None:
                out.write("\t")
                out.write(str(weight))
                weighted += 1

            out.write("\n")
            written += 1

    print(f"wrote {written} entries to {output_path}")
    print(f"applied {weighted} weights")
    if weights_path is not None:
        unused = len(weights) - weighted
        print(f"unused weights: {unused}")
    if dedupe:
        print(f"skipped {skipped_duplicates} duplicate entries")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build Rime dict.yaml from TSV and optional weights.yaml."
    )

    parser.add_argument(
        "-i",
        "--input",
        nargs="+",
        type=Path,
        required=True,
        help="Input TSV file(s). Required columns: word__text, yngping.",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("rime/hokchoew.dict.yaml"),
        help="Output Rime dictionary path.",
    )

    parser.add_argument(
        "-t",
        "--template",
        type=Path,
        default=Path("templates/hokchew.dict.yaml"),
        help="Header template path.",
    )

    parser.add_argument(
        "--weights",
        type=Path,
        default=Path("data/weights.yaml"),
        help="YAML file containing text -> code -> weight.",
    )

    parser.add_argument(
        "--version",
        default=default_version(),
        help="Dictionary version. Defaults to current build time.",
    )

    parser.add_argument(
        "--no-dedupe",
        action="store_true",
        help="Do not remove duplicate text+code entries.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    write_dict(
        input_paths=args.input,
        output_path=args.output,
        template_path=args.template,
        weights_path=args.weights,
        version=args.version,
        dedupe=not args.no_dedupe,
    )


if __name__ == "__main__":
    main()
