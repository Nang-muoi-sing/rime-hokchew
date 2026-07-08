#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import yaml


def read_yaml(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")

    # Some upstream Rime config files contain tabs before comments, e.g.
    #   max_width: 0\t#set 0 to disable max width
    # PyYAML follows YAML strictly and rejects tabs.
    text = text.replace("\t", "    ")

    data = yaml.safe_load(text) or {}

    if not isinstance(data, dict):
        raise RuntimeError(f"{path} must contain a mapping at top level")

    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target_yaml")
    parser.add_argument("preset_yaml")
    parser.add_argument(
        "--set-default",
        metavar="SCHEME_NAME",
        help="Also set style/color_scheme to this scheme.",
    )
    parser.add_argument(
        "--set-dark-default",
        metavar="SCHEME_NAME",
        help="Also set style/color_scheme_dark to this scheme.",
    )
    args = parser.parse_args()

    target_path = Path(args.target_yaml)
    preset_path = Path(args.preset_yaml)

    target = read_yaml(target_path)
    presets = read_yaml(preset_path)

    target.setdefault("preset_color_schemes", {})

    if not isinstance(target["preset_color_schemes"], dict):
        raise RuntimeError(f"{target_path}: preset_color_schemes must be a mapping")

    for name, scheme in presets.items():
        if not isinstance(scheme, dict):
            raise RuntimeError(f"{preset_path}: scheme {name!r} must be a mapping")

        target["preset_color_schemes"][name] = scheme
        print(f"Injected color scheme {name!r} into {target_path}")

    if args.set_default or args.set_dark_default:
        target.setdefault("style", {})

        if not isinstance(target["style"], dict):
            raise RuntimeError(f"{target_path}: style must be a mapping")

    if args.set_default:
        if args.set_default not in presets:
            raise RuntimeError(f"{preset_path} does not contain scheme: {args.set_default}")

        target["style"]["color_scheme"] = args.set_default

    if args.set_dark_default:
        if args.set_dark_default not in presets:
            raise RuntimeError(f"{preset_path} does not contain scheme: {args.set_dark_default}")

        target["style"]["color_scheme_dark"] = args.set_dark_default

    target_path.write_text(
        yaml.safe_dump(
            target,
            allow_unicode=True,
            sort_keys=False,
            width=120,
        ),
        encoding="utf-8",
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
