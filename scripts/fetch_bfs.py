#!/usr/bin/env python3
"""Fetch datasets from BFS based on registry.toml.

Handles three source types:
  - bfs-pxweb: BFS STAT-TAB PxWeb API (POST with dimension query → JSON-stat2)
  - bfs-dam:   BFS DAM API direct download (CSV or XLSX)
  - url:       Arbitrary URL download
"""

import csv
import json
import sys
from pathlib import Path

import tomllib

from common import (
    BFS_PXWEB_BASE,
    PROCESSED_DIR,
    RAW_DIR,
    REGISTRY_PATH,
    ensure_dirs,
    pxweb_query,
)


def load_registry() -> dict:
    with open(REGISTRY_PATH, "rb") as f:
        return tomllib.load(f)


# ── BFS PxWeb API ────────────────────────────────────────────────────


def build_pxweb_query(dataset: dict) -> dict:
    query_items = []
    for code, values in dataset.get("dimensions", {}).items():
        if values == "*":
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
    dims = data.get("dimension", {})
    sizes = data.get("size", [])
    values = data.get("value", [])
    dim_ids = data.get("id", [])

    if not dim_ids or not values:
        print(f"  Warning: empty response, skipping {output_path.name}")
        return

    dim_labels = {}
    for dim_id in dim_ids:
        cats = dims[dim_id]["category"]
        index = cats["index"]
        labels = cats.get("label", {})
        if isinstance(index, dict):
            ordered = sorted(index.items(), key=lambda x: x[1])
            dim_labels[dim_id] = [labels.get(k, k) for k, _ in ordered]
        else:
            dim_labels[dim_id] = [labels.get(k, k) for k in index]

    strides = []
    stride = 1
    for s in reversed(sizes):
        strides.insert(0, stride)
        stride *= s

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


def fetch_pxweb(name: str, dataset: dict):
    table = dataset["table"]
    url = f"{BFS_PXWEB_BASE}/de/{table}/{table}.px"
    query = build_pxweb_query(dataset)

    print(f"  POST {url}")
    data = pxweb_query(url, query)

    raw_path = RAW_DIR / f"{name}.json"
    raw_path.write_text(json.dumps(data, ensure_ascii=False, indent=2))

    output = PROCESSED_DIR / f"{dataset.get('processed_as', name + '.csv')}"
    jsonstat2_to_csv(data, output)


# ── BFS DAM API / URL downloads ─────────────────────────────────────


def fetch_download(name: str, dataset: dict):
    import requests

    url = dataset["url"]
    fmt = dataset.get("format", "csv")
    raw_path = RAW_DIR / f"{name}.{fmt}"

    if not raw_path.exists():
        print(f"  GET {url}")
        resp = requests.get(url, headers={"User-Agent": "Zukunftslabor/0.1"}, timeout=60)
        resp.raise_for_status()
        raw_path.write_bytes(resp.content)
        print(f"  Saved → {raw_path} ({len(resp.content)} bytes)")
    else:
        print(f"  Cached → {raw_path}")

    # Auto-process based on format + name
    processed_name = dataset.get("processed_as", f"{name}.csv")
    output = PROCESSED_DIR / processed_name

    if name == "erwerbstaetige_sake":
        process_sake(raw_path, output)
    elif name == "einkommensverteilung_silc":
        process_einkommensverteilung(raw_path, output)
    elif name == "mietzinse_kantone":
        process_mietzinse(raw_path, output)
    else:
        print(f"  Note: no auto-processor for '{name}', raw file saved only")


# ── Dataset-specific processors ──────────────────────────────────────


def process_sake(raw_path: Path, output: Path):
    """Process SAKE employment CSV → clean sector-level CSV."""
    noga_labels = {
        "A": "Land- und Forstwirtschaft",
        "B-C": "Verarbeitendes Gewerbe, Bergbau",
        "D": "Energieversorgung",
        "E": "Wasserversorgung, Entsorgung",
        "F": "Baugewerbe",
        "G": "Handel, Reparatur",
        "H": "Verkehr, Lagerei",
        "I": "Gastgewerbe, Beherbergung",
        "J": "Information, Kommunikation",
        "K": "Finanz-, Versicherungsdienstl.",
        "L": "Grundstücks-, Wohnungswesen",
        "M": "Freiberufliche, wiss. Dienstl.",
        "N": "Sonstige wirtsch. Dienstl.",
        "O": "Öffentliche Verwaltung",
        "P": "Erziehung und Unterricht",
        "Q": "Gesundheits-, Sozialwesen",
        "R": "Kunst, Unterhaltung, Erholung",
        "S": "Sonstige Dienstleistungen",
        "T": "Private Haushalte",
        "Total": "Total",
    }

    rows = []
    with open(raw_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if (
                row["FREQ"] in ("A", "Y")
                and row["INDICATORS_DE"] in ("WIRTSCHAFTSABSCHNITT", "TOTAL")
                and row["GENDER_DE"] == "Total"
                and row["VALUE"]
            ):
                code = row["DETAILS_DE"]
                label = noga_labels.get(code, code)
                rows.append({
                    "Sektor": code,
                    "Bezeichnung": label,
                    "Erwerbstaetige": round(float(row["VALUE"])),
                    "Jahr": int(row["PERIOD"]),
                })

    rows.sort(key=lambda x: (-x["Jahr"], -x["Erwerbstaetige"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Sektor", "Bezeichnung", "Erwerbstaetige", "Jahr"])
        writer.writeheader()
        writer.writerows(rows)

    latest_year = max(r["Jahr"] for r in rows)
    latest = [r for r in rows if r["Jahr"] == latest_year]
    print(f"  Processed {len(rows)} rows ({len(set(r['Jahr'] for r in rows))} years) → {output}")
    print(f"  Latest year: {latest_year}, {len(latest)} sectors")


def process_einkommensverteilung(raw_path: Path, output: Path):
    """Process BFS income distribution XLSX → decile shares + Gini + median."""
    import openpyxl

    wb = openpyxl.load_workbook(raw_path, data_only=True)
    rows = []

    for year_name in wb.sheetnames:
        ws = wb[year_name]
        year = int(year_name)

        # Row 8: Mean (col F), Row 9: Median (col F), Row 13: Gini (col F)
        for row_num, label in [(8, "Mittelwert_CHF_Monat"), (9, "Median_CHF_Monat")]:
            val = ws.cell(row=row_num, column=6).value
            if val:
                rows.append({"Jahr": year, "Kennzahl": label, "Wert": round(float(val))})

        gini = ws.cell(row=13, column=6).value
        if gini:
            rows.append({"Jahr": year, "Kennzahl": "Gini_Koeffizient", "Wert": round(float(gini), 4)})

        # Rows 16-25: Decile income shares (col F = Verfügbar)
        for d in range(10):
            val = ws.cell(row=16 + d, column=6).value
            if val:
                rows.append({"Jahr": year, "Kennzahl": f"Dezil_{d + 1}_Anteil_Prozent", "Wert": round(float(val), 2)})

    rows.sort(key=lambda x: (-x["Jahr"], x["Kennzahl"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Kennzahl", "Wert"])
        writer.writeheader()
        writer.writerows(rows)

    years = sorted(set(r["Jahr"] for r in rows))
    print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")


def process_mietzinse(raw_path: Path, output: Path):
    """Process BFS rent prices XLSX → flat CSV with canton, rooms, price, year."""
    import openpyxl

    wb = openpyxl.load_workbook(raw_path, data_only=True)
    room_cols = {
        "Total": 2, "1 Zimmer": 4, "2 Zimmer": 6, "3 Zimmer": 8,
        "4 Zimmer": 10, "5 Zimmer": 12, "6+ Zimmer": 14,
    }

    rows = []
    for year_name in wb.sheetnames:
        ws = wb[year_name]
        year = int(year_name)

        # Find data start (row with "Schweiz")
        start_row = 6
        for r in range(4, 10):
            val = ws.cell(row=r, column=1).value
            if val and "Schweiz" in str(val):
                start_row = r
                break

        for r in range(start_row, start_row + 28):
            canton = ws.cell(row=r, column=1).value
            if not canton or not isinstance(canton, str) or canton.startswith("["):
                continue
            canton = canton.strip()
            if not canton:
                continue

            for room_name, col in room_cols.items():
                val = ws.cell(row=r, column=col).value
                if val and isinstance(val, (int, float)):
                    rows.append({
                        "Kanton": canton,
                        "Zimmerzahl": room_name,
                        "Miete_CHF": int(val),
                        "Jahr": year,
                    })

    rows.sort(key=lambda x: (-x["Jahr"], x["Kanton"], x["Zimmerzahl"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Kanton", "Zimmerzahl", "Miete_CHF", "Jahr"])
        writer.writeheader()
        writer.writerows(rows)

    years = sorted(set(r["Jahr"] for r in rows))
    print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")


# ── Main ─────────────────────────────────────────────────────────────


def fetch_dataset(name: str, dataset: dict):
    source = dataset.get("source", "")

    if source == "bfs-pxweb":
        fetch_pxweb(name, dataset)
    elif source in ("bfs-dam", "url"):
        fetch_download(name, dataset)
    else:
        print(f"  Unknown source '{source}', skipping")


def main():
    ensure_dirs()
    registry = load_registry()
    datasets = registry.get("datasets", {})

    if not datasets:
        print("No datasets defined in registry.toml")
        sys.exit(1)

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
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()
