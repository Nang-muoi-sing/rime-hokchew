#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import yaml


def parse_rime_dict(path: Path) -> dict[str, dict[str, int]]:
    weights: dict[str, dict[str, int]] = {}
    in_entries = False

    with path.open("r", encoding="utf-8-sig") as f:
        for line_no, raw_line in enumerate(f, start=1):
            line = raw_line.rstrip("\n")

            if not in_entries:
                if line.strip() == "...":
                    in_entries = True
                continue

            line = line.strip()
            if not line or line.startswith("#"):
                continue

            parts = line.split("\t")

            # Rime dict line:
            # text<TAB>code
            # text<TAB>code<TAB>weight
            if len(parts) < 2:
                continue

            text = parts[0].strip()
            code = " ".join(parts[1].strip().split())

            if len(parts) < 3:
                continue

            weight_raw = parts[2].strip()
            if not weight_raw:
                continue

            try:
                weight = int(weight_raw)
            except ValueError:
                raise ValueError(
                    f"{path}:{line_no}: invalid weight {weight_raw!r}"
                ) from None

            weights.setdefault(text, {})[code] = weight

    return weights


def write_weights_yaml(weights: dict[str, dict[str, int]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write("# Extracted from old Rime dict. Maintain this file by hand.\n")
        yaml.safe_dump(
            weights,
            f,
            allow_unicode=True,
            sort_keys=False,
            default_flow_style=False,
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract explicit weights from old Rime dict.yaml."
    )

    parser.add_argument(
        "input",
        type=Path,
        help="Old Rime dict.yaml file.",
    )

    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("data/weights.yaml"),
        help="Output weights YAML.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    weights = parse_rime_dict(args.input)
    write_weights_yaml(weights, args.output)

    count = sum(len(codes) for codes in weights.values())
    print(f"extracted {count} weights to {args.output}")


if __name__ == "__main__":
    main()
