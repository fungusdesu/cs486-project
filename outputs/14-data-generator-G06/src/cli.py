from __future__ import annotations

import argparse
import json
from pathlib import Path

from .clean import clean_generated
from .config import load_config
from .generate import generate_dataset
from .load import load_staging
from .validate import validate_dataset


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="G06 Phase 2 synthetic-data generator")
    commands = root.add_subparsers(dest="command", required=True)
    generate = commands.add_parser("generate", help="stream synthetic CSV files")
    generate.add_argument("--config", type=Path)
    generate.add_argument("--seed", type=int)
    generate.add_argument("--users", dest="user_count", type=int)
    generate.add_argument("--spaces", dest="space_count", type=int)
    generate.add_argument("--bookings", dest="booking_count", type=int)
    generate.add_argument("--maintenance", dest="maintenance_count", type=int)
    generate.add_argument("--output", dest="output_dir")
    validate = commands.add_parser("validate", help="validate generated CSV relationships")
    validate.add_argument("--input", type=Path, default=Path("generated"))
    load = commands.add_parser("load", help="bulk-load CSV files into staging tables")
    load.add_argument("--input", type=Path, default=Path("generated"))
    load.add_argument("--server", required=True)
    load.add_argument("--database", required=True)
    load.add_argument("--trust-certificate", action="store_true")
    load.add_argument("--execute", action="store_true")
    clean = commands.add_parser("clean", help="remove generated CSVs and reports")
    clean.add_argument("--input", type=Path, default=Path("generated"))
    clean.add_argument("--yes", action="store_true")
    return root


def main() -> int:
    args = parser().parse_args()
    if args.command == "generate":
        config = load_config(args.config, {"seed": args.seed, "user_count": args.user_count, "space_count": args.space_count, "booking_count": args.booking_count, "maintenance_count": args.maintenance_count, "output_dir": args.output_dir})
        print(json.dumps(generate_dataset(config), indent=2, sort_keys=True))
        return 0
    if args.command == "validate":
        result = validate_dataset(args.input)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0 if result["valid"] else 1
    if args.command == "load":
        load_staging(args.input, args.server, args.database, args.execute, args.trust_certificate)
        return 0
    if args.command == "clean":
        clean_generated(args.input, confirmed=args.yes)
        return 0
    raise AssertionError(f"unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())