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
    elif name == "forschung_ausgaben":
        process_forschung_ausgaben(raw_path, output)
    elif name == "energieverbrauch_sektor":
        process_energieverbrauch(raw_path, output)
    elif name == "elektrizitaet_produktion":
        process_elektrizitaet(raw_path, output)
    elif name == "gesundheitsausgaben":
        process_gesundheitsausgaben(raw_path, output)
    elif name == "wanderungen":
        process_wanderungen(raw_path, output)
    elif name == "verteidigungsausgaben":
        process_verteidigungsausgaben(raw_path, output)
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


def process_forschung_ausgaben(raw_path: Path, output: Path):
    """Process BFS R&D expenditure XLSX → sector × year CSV.

    Format: single sheet, years as columns (row 4), sector labels in col A,
    values in subsequent columns. Wide → long transformation.
    """
    import openpyxl

    wb = openpyxl.load_workbook(raw_path, data_only=True)
    ws = wb.active
    rows = []

    # Find year row (row with numeric years in columns B+)
    year_row = None
    years_by_col = {}
    for r in range(1, 10):
        for c in range(2, ws.max_column + 1):
            v = ws.cell(row=r, column=c).value
            if v and isinstance(v, (int, float)) and 1990 <= int(v) <= 2030:
                year_row = r
                break
        if year_row:
            break

    if year_row is None:
        print(f"  Warning: no year row found → {output}")
        return

    for c in range(2, ws.max_column + 1):
        v = ws.cell(row=year_row, column=c).value
        if v and isinstance(v, (int, float)) and 1990 <= int(v) <= 2030:
            years_by_col[c] = int(v)

    # Scan sector rows below the year row
    for r in range(year_row + 1, ws.max_row + 1):
        label = ws.cell(row=r, column=1).value
        if not label or not isinstance(label, str):
            continue
        label = label.strip()
        if not label or label.startswith("[") or label.startswith("("):
            continue

        has_data = False
        for c, year in years_by_col.items():
            val = ws.cell(row=r, column=c).value
            if val and isinstance(val, (int, float)) and float(val) > 0:
                has_data = True
                rows.append({
                    "Jahr": year,
                    "Sektor": label,
                    "Ausgaben_Mio_CHF": round(float(val), 1),
                })

    rows.sort(key=lambda x: (-x["Jahr"], -x["Ausgaben_Mio_CHF"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Sektor", "Ausgaben_Mio_CHF"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        years = sorted(set(r["Jahr"] for r in rows))
        print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


def process_energieverbrauch(raw_path: Path, output: Path):
    """Process BFE energy balance CSV → sector × year CSV.

    Source: BFE OGD Gesamtenergiebilanz (long format: Jahr, Rubrik, Energietraeger, TJ).
    Filters to Endverbrauch rows and aggregates TJ across all Energietraeger per sector per year.
    """
    sector_map = {
        "Endverbrauch - Industrie": "Industrie",
        "Endverbrauch - Verkehr": "Verkehr",
        "Endverbrauch - Haushalte": "Haushalte",
        "Endverbrauch - Dienstleistungen": "Dienstleistungen",
        "Endverbrauch - Statistische Differenz inkl. Landwirtschaft": "Stat. Differenz inkl. Landwirtschaft",
        "Endverbrauch - Total": "Total",
    }

    # Aggregate TJ per sector per year
    from collections import defaultdict
    totals = defaultdict(lambda: defaultdict(float))

    with open(raw_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rubrik = row["Rubrik"].strip().strip('"')
            if rubrik not in sector_map:
                continue
            sector = sector_map[rubrik]
            year = int(row["Jahr"])
            val = row["TJ"]
            if val and val != "NA":
                totals[year][sector] += float(val)

    rows = []
    for year, sectors in totals.items():
        for sector, tj in sectors.items():
            rows.append({
                "Jahr": year,
                "Sektor": sector,
                "Verbrauch_TJ": round(tj),
            })

    rows.sort(key=lambda x: (-x["Jahr"], -x["Verbrauch_TJ"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Sektor", "Verbrauch_TJ"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        years = sorted(set(r["Jahr"] for r in rows))
        print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


def process_elektrizitaet(raw_path: Path, output: Path):
    """Process BFE electricity balance CSV → long format (Jahr, Quelle, GWh).

    Source: BFE OGD Elektrizitätsbilanz (wide format: one row per year, columns per source).
    Pivots to long format for easier chart generation with VegaLite.
    """
    col_map = {
        "Erzeugung_laufwerk_GWh": "Laufkraftwerke",
        "Erzeugung_speicherwerk_GWh": "Speicherkraftwerke",
        "Erzeugung_kernkraftwerk_GWh": "Kernkraftwerke",
        "Erzeugung_photovoltaik_GWh": "Photovoltaik",
        "Erzeugung_wind_GWh": "Wind",
        "Erzeugung_andere_erneuerbare_abfaelle_GWh": "Andere Erneuerbare + Abfälle",
        "Erzeugung_andere_fossil_GWh": "Fossile Erzeugung",
        "Einfuhr_GWh": "Import",
        "Ausfuhr_GWh": "Export",
        "Endverbrauch_GWh": "Endverbrauch",
        "Landesverbrauch_GWh": "Landesverbrauch",
        "Verluste_GWh": "Verluste",
        "Verbrauch_speicherpumpen_GWh": "Speicherpumpen",
    }

    rows = []
    with open(raw_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            year = int(row["Jahr"])
            for col, label in col_map.items():
                val = row.get(col, "")
                if val and val != "NA":
                    rows.append({
                        "Jahr": year,
                        "Quelle": label,
                        "GWh": round(float(val)),
                    })

    rows.sort(key=lambda x: (-x["Jahr"], -x["GWh"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Quelle", "GWh"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        years = sorted(set(r["Jahr"] for r in rows))
        print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


def process_gesundheitsausgaben(raw_path: Path, output: Path):
    """Process BFS healthcare expenditure XLSX → category × year CSV.

    Format: first sheet "In Millionen Franken", years as columns (row 4, cols C+),
    category codes in col A, names in col B, values across year columns.
    """
    import openpyxl

    wb = openpyxl.load_workbook(raw_path, data_only=True)
    ws = wb.worksheets[0]  # "In Millionen Franken"
    rows = []

    # Find year row (row 4 typically, with years in cols C+)
    years_by_col = {}
    for r in range(1, 10):
        for c in range(3, ws.max_column + 1):
            v = ws.cell(row=r, column=c).value
            if v and isinstance(v, (int, float)) and 1990 <= int(v) <= 2030:
                if r not in [rr for rr in years_by_col.values()]:
                    years_by_col[c] = int(v)
        if years_by_col:
            break

    if not years_by_col:
        print(f"  Warning: no year columns found → {output}")
        return

    # Scan data rows: col A = code, col B = category name
    for r in range(5, ws.max_row + 1):
        code = ws.cell(row=r, column=1).value
        name = ws.cell(row=r, column=2).value
        # Use name if available, fall back to code
        label = str(name).strip() if name and str(name).strip() else (str(code).strip() if code else "")
        if not label:
            continue

        for c, year in years_by_col.items():
            val = ws.cell(row=r, column=c).value
            if val and isinstance(val, (int, float)) and float(val) > 0:
                rows.append({
                    "Jahr": year,
                    "Kategorie": label,
                    "Ausgaben_Mio_CHF": round(float(val), 1),
                })

    rows.sort(key=lambda x: (-x["Jahr"], -x["Ausgaben_Mio_CHF"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Kategorie", "Ausgaben_Mio_CHF"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        years = sorted(set(r["Jahr"] for r in rows))
        print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


def process_wanderungen(raw_path: Path, output: Path):
    """Process BFS migration flows XLSX → flat CSV with type, nationality, year.

    Format: sheets for immigration, emigration, migration balance.
    Years as columns (row 3), nationality/demographic labels in col A.
    Data is in French (from opendata.swiss).
    """
    import openpyxl

    wb = openpyxl.load_workbook(raw_path, data_only=True)
    rows = []

    # Map sheet names to migration types
    type_map = {
        "immigration": "Einwanderung",
        "émigration": "Auswanderung",
        "solde migratoire": "Saldo",
    }

    # Map French labels to German
    label_map = {
        "Total": "Total",
        "Suisses": "Schweizer",
        "Étrangers": "Ausländer",
        "Hommes": None,  # Skip gendered breakdowns
        "Femmes": None,
        "Âge": None,  # Skip age header
    }

    for ws in wb.worksheets:
        title = ws.title.strip().lower()
        typ = type_map.get(title)
        if not typ:
            continue

        # Find year row
        years_by_col = {}
        for r in range(1, 6):
            for c in range(2, ws.max_column + 1):
                v = ws.cell(row=r, column=c).value
                if v and isinstance(v, (int, float)) and 1990 <= int(v) <= 2030:
                    years_by_col[c] = int(v)
            if years_by_col:
                break

        if not years_by_col:
            continue

        # Extract key aggregate rows (Total, Suisses, Étrangers, and nationality groups)
        for r in range(4, ws.max_row + 1):
            label = ws.cell(row=r, column=1).value
            if not label or not isinstance(label, str):
                continue
            label = label.strip()
            if not label:
                continue
            # Skip age breakdowns and gendered rows
            if label in ("Hommes", "Femmes", "Âge") or "ans" in label:
                continue

            for c, year in years_by_col.items():
                val = ws.cell(row=r, column=c).value
                if val and isinstance(val, (int, float)):
                    rows.append({
                        "Jahr": year,
                        "Nationalitaet": label,
                        "Typ": typ,
                        "Personen": round(float(val)),
                    })

    rows.sort(key=lambda x: (-x["Jahr"], x["Typ"], -abs(x["Personen"])))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Jahr", "Nationalitaet", "Typ", "Personen"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        years = sorted(set(r["Jahr"] for r in rows))
        print(f"  Processed {len(rows)} rows, years {years[0]}–{years[-1]} → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


def process_verteidigungsausgaben(raw_path: Path, output: Path):
    """Process World Bank military spending JSON → flat CSV."""
    with open(raw_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    rows = []
    # World Bank API v2 JSON: [metadata, records]
    records = data[1] if isinstance(data, list) and len(data) > 1 else []
    for rec in records:
        val = rec.get("value")
        if val is None:
            continue
        rows.append({
            "Land": rec["country"]["value"],
            "Code": rec["countryiso3code"],
            "Jahr": int(rec["date"]),
            "Anteil_BIP_Prozent": round(float(val), 3),
        })

    rows.sort(key=lambda x: (x["Land"], -x["Jahr"]))

    with open(output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["Land", "Code", "Jahr", "Anteil_BIP_Prozent"])
        writer.writeheader()
        writer.writerows(rows)

    if rows:
        countries = sorted(set(r["Land"] for r in rows))
        print(f"  Processed {len(rows)} rows, {len(countries)} countries → {output}")
    else:
        print(f"  Warning: no data rows extracted → {output}")


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
