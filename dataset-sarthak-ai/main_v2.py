"""
File: main_v2.py
What does this file do?
    Command-line entrypoint for generating the Nepal-first V2 finance dataset.
Methods/functions this file contains:
    parse_args, main.
Date and Day of last modification:
    2026-05-16, Saturday.
"""

from __future__ import annotations

import argparse

from config_v2 import NepalFinanceConfig
from generators_v2.nepal_finance import write_dataset


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Nepal finance assistant V2 dataset")
    parser.add_argument("--users", type=int, default=500)
    parser.add_argument("--groups", type=int, default=180)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output-dir", type=str, default="output_v2")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = NepalFinanceConfig(
        seed=args.seed,
        num_users=args.users,
        num_groups=args.groups,
        output_dir=args.output_dir,
    )
    counts = write_dataset(config)
    print("Nepal finance V2 dataset generated")
    for name, count in counts.items():
        print(f"  {name}: {count:,} rows")


if __name__ == "__main__":
    main()
