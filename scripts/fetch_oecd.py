#!/usr/bin/env python3
"""Fetch datasets from OECD.Stat / OECD Data Explorer API."""

import csv
import sys
from pathlib import Path

import tomllib

from common import PROCESSED_DIR, RAW_DIR, ensure_dirs, fetch_json, REGISTRY_PATH

OECD_BASE = "https://sdmx.oecd.org/public/rest"


def load_registry() -> dict:
    with open(REGISTRY_PATH, "rb") as f:
        return tomllib.load(f)


def fetch_oecd_dataset(name: str, dataset: dict):
    """Fetch an OECD dataset via SDMX JSON API."""
    dataflow = dataset["dataflow"]
    filter_expr = dataset.get("filter", "all")
    params = dataset.get("params", {})

    url = f"{OECD_BASE}/data/{dataflow}/{filter_expr}"
    print(f"  Fetching {url} ...")

    data = fetch_json(url + "?" + "&".join(f"{k}={v}" for k, v in params.items())
                      if params else url)

    # SDMX JSON structure → flat CSV
    output = PROCESSED_DIR / f"{name}.csv"

    datasets = data.get("dataSets", [])
    if not datasets:
        print(f"  Warning: empty response for {name}")
        return

    structure = data.get("structure", {})
    dimensions = structure.get("dimensions", {}).get("observation", [])

    # Write raw JSON for inspection
    import json
    raw_path = RAW_DIR / f"{name}_oecd.json"
    raw_path.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(f"  Raw JSON → {raw_path}")
    print(f"  Note: SDMX→CSV conversion is dataset-specific; inspect raw JSON to refine.")


def main():
    ensure_dirs()
    registry = load_registry()
    datasets = {k: v for k, v in registry.get("datasets", {}).items()
                if v.get("source") == "oecd"}

    if not datasets:
        print("No OECD datasets in registry.toml")
        return

    names = sys.argv[1:] if len(sys.argv) > 1 else list(datasets.keys())

    for name in names:
        if name not in datasets:
            print(f"Unknown dataset: {name}")
            continue
        print(f"\n[{name}]")
        try:
            fetch_oecd_dataset(name, datasets[name])
        except Exception as e:
            print(f"  Error: {e}")


if __name__ == "__main__":
    main()
