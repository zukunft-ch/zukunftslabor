#!/usr/bin/env python3
"""Fetch datasets from BFS STAT-TAB PxWeb API based on registry.toml."""

import csv
import sys
from pathlib import Path

# pyaxis for px-file parsing (some BFS endpoints return px format)
try:
    import pyaxis
except ImportError:
    pyaxis = None

# Use stdlib tomllib (Python 3.11+)
import tomllib

from common import (
    BFS_PXWEB_BASE,
    PROCESSED_DIR,
    RAW_DIR,
    REGISTRY_PATH,
    ensure_dirs,
    fetch_json,
    pxweb_query,
)


def load_registry() -> dict:
    """Load dataset definitions from registry.toml."""
    with open(REGISTRY_PATH, "rb") as f:
        return tomllib.load(f)


def build_pxweb_query(dataset: dict) -> dict:
    """Build a PxWeb query body from a registry dataset entry.

    The registry entry should have:
      - table: BFS table ID (e.g. "px-x-2004020000_104")
      - dimensions: dict of dimension_code -> list of values (or "*" for all)
    """
    query_items = []
    for code, values in dataset.get("dimensions", {}).items():
        if values == "*":
            # Request all values for this dimension
            query_items.append({
                "code": code,
                "selection": {"filter": "all", "values": ["*"]},
            })
        else:
            query_items.append({
                "code": code,
                "selection": {"filter": "item", "values": values},
            })

    return {
        "query": query_items,
        "response": {"format": "json-stat2"},
    }


def jsonstat2_to_csv(data: dict, output_path: Path):
    """Convert a JSON-stat2 response to a flat CSV file."""
    # JSON-stat2 has a single dataset at the top level
    dims = data.get("dimension", {})
    sizes = data.get("size", [])
    values = data.get("value", [])
    dim_ids = data.get("id", [])

    if not dim_ids or not values:
        print(f"  Warning: empty response, skipping {output_path.name}")
        return

    # Build category labels for each dimension
    dim_labels = {}
    for dim_id in dim_ids:
        dim_info = dims[dim_id]
        cats = dim_info["category"]
        index = cats["index"]
        labels = cats.get("label", {})
        # index can be dict {code: position} or list [code, ...]
        if isinstance(index, dict):
            ordered = sorted(index.items(), key=lambda x: x[1])
            dim_labels[dim_id] = [labels.get(k, k) for k, _ in ordered]
        else:
            dim_labels[dim_id] = [labels.get(k, k) for k in index]

    # Compute strides for index calculation
    strides = []
    stride = 1
    for s in reversed(sizes):
        strides.insert(0, stride)
        stride *= s

    # Write CSV
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        header = [dims[d].get("label", d) for d in dim_ids] + ["value"]
        writer.writerow(header)

        for i, val in enumerate(values):
            row = []
            remaining = i
            for j, dim_id in enumerate(dim_ids):
                idx = remaining // strides[j]
                remaining = remaining % strides[j]
                row.append(dim_labels[dim_id][idx])
            row.append(val)
            writer.writerow(row)

    print(f"  Wrote {len(values)} rows → {output_path}")


def fetch_dataset(name: str, dataset: dict):
    """Fetch a single dataset and convert to CSV."""
    source = dataset.get("source", "bfs")
    table = dataset.get("table", "")

    if source == "bfs":
        # Construct full PxWeb URL
        path = dataset.get("path", "")
        url = f"{BFS_PXWEB_BASE}/{path}/{table}"
        query = build_pxweb_query(dataset)

        print(f"  Fetching {url} ...")
        data = pxweb_query(url, query)

        output = PROCESSED_DIR / f"{name}.csv"
        jsonstat2_to_csv(data, output)

    elif source == "url":
        # Direct CSV/JSON download
        url = dataset["url"]
        suffix = Path(url).suffix or ".csv"
        raw_path = RAW_DIR / f"{name}{suffix}"

        if not raw_path.exists():
            print(f"  Downloading {url} ...")
            import requests
            resp = requests.get(url, timeout=60)
            resp.raise_for_status()
            raw_path.write_bytes(resp.content)
            print(f"  Saved → {raw_path}")
        else:
            print(f"  Cached → {raw_path}")

    else:
        print(f"  Unknown source '{source}' for {name}, skipping")


def main():
    ensure_dirs()
    registry = load_registry()
    datasets = registry.get("datasets", {})

    if not datasets:
        print("No datasets defined in registry.toml")
        sys.exit(1)

    # Allow filtering by name via CLI args
    names = sys.argv[1:] if len(sys.argv) > 1 else list(datasets.keys())

    for name in names:
        if name not in datasets:
            print(f"Unknown dataset: {name}")
            continue
        print(f"\n[{name}]")
        try:
            fetch_dataset(name, datasets[name])
        except Exception as e:
            print(f"  Error: {e}")


if __name__ == "__main__":
    main()
