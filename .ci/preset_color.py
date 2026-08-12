#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections.abc import MutableMapping
from pathlib import Path

from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap


def rime_yaml() -> YAML:
    yaml = YAML(typ="rt")
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)
    yaml.width = 120
    return yaml


def read_yaml(path: Path, yaml: YAML) -> MutableMapping:
    text = path.read_text(encoding="utf-8")

    # Some upstream Rime config files contain tabs before comments, e.g.
    #   max_width: 0\t#set 0 to disable max width
    # ruamel.yaml follows YAML strictly and rejects tabs.
    text = text.replace("\t", "    ")

    data = yaml.load(text) or CommentedMap()

    if not isinstance(data, MutableMapping):
        raise RuntimeError(f"{path} must contain a mapping at top level")

    return data


def ensure_mapping(data: MutableMapping, key: str, path: Path) -> MutableMapping:
    if key not in data or data[key] is None:
        data[key] = CommentedMap()

    value = data[key]
    if not isinstance(value, MutableMapping):
        raise RuntimeError(f"{path}: {key} must be a mapping")

    return value


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

    yaml = rime_yaml()
    target = read_yaml(target_path, yaml)
    presets = read_yaml(preset_path, yaml)

    preset_color_schemes = ensure_mapping(target, "preset_color_schemes", target_path)

    for name, scheme in presets.items():
        if not isinstance(scheme, MutableMapping):
            raise RuntimeError(f"{preset_path}: scheme {name!r} must be a mapping")

        preset_color_schemes[name] = scheme
        print(f"Injected color scheme {name!r} into {target_path}")

    if args.set_default or args.set_dark_default:
        style = ensure_mapping(target, "style", target_path)

        if args.set_default:
            if args.set_default not in presets:
                raise RuntimeError(
                    f"{preset_path} does not contain scheme: {args.set_default}"
                )

            style["color_scheme"] = args.set_default

        if args.set_dark_default:
            if args.set_dark_default not in presets:
                raise RuntimeError(
                    f"{preset_path} does not contain scheme: {args.set_dark_default}"
                )

            style["color_scheme_dark"] = args.set_dark_default

    with target_path.open("w", encoding="utf-8") as target_file:
        yaml.dump(target, target_file)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
