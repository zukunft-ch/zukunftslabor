# Zukunftslabor — Research Repository

## Overview
Evidence-based research pipeline for **Die Zukunft** policy analysis. Produces data-driven notizen (research notes) for publication on `die-zukunft.ch/zukunftslabor/`.

## Stack
- **Analysis**: Elixir LiveBook (`.livemd`) + Explorer DataFrames + VegaLite
- **Data acquisition**: Python scripts (BFS PxWeb API, BFS DAM, BFE OGD, World Bank)
- **Chart export**: `vega_lite_convert` (Rust-based, no Node dependency)
- **Task runner**: mise

## Key directories

| Path | Purpose |
|------|---------|
| `notebooks/` | LiveBook notebooks organized by topic (10 notebooks) |
| `lib/zukunftslabor/` | Elixir helpers (data loading, chart export, draft generation) |
| `scripts/` | Python data fetchers |
| `data/registry.toml` | Dataset definitions (tracked) |
| `data/raw/` | Downloaded files (gitignored) |
| `data/processed/` | Cleaned CSVs (gitignored) |
| `output/drafts/` | Generated markdown drafts (gitignored) |
| `output/charts/` | Exported SVG charts (gitignored) |

## Notebooks

| # | Directory | Topic | Slug |
|---|-----------|-------|------|
| 01 | `01_grundeinkommen` | UBI financing models (3 scenarios) | `grundeinkommen-finanzierungsmodelle` |
| 02 | `02_digitale_souveraenitaet` | Digital readiness gap | `digitale-souveraenitaet-luecke` |
| 03 | `03_automatisierung_arbeit` | Pre/Post-LLM automation risk | `automatisierungsrisiko-branchen` |
| 04 | `04_wohnen_ungleichheit` | Cantonal rent burden projection | `mietbelastung-kantonale-prognose` |
| 05 | `05_forschung_innovation` | R&D: who performs, who pays | `forschung-wer-forscht-wer-zahlt` |
| 06 | `06_energie_resilienz` | Electricity stress scenarios | `energieresilienz-stressszenarien` |
| 07 | `07_uebergaenge_weiterbildung` | Training vs. automation exposure | `weiterbildung-teilnahme-luecken` |
| 08 | `08_life_science_gesundheit` | Health admin cost focus | `gesundheitskosten-verwaltung-fokus` |
| 10 | `10_talent_migration` | Immigrant overqualification | `talent-ueberqualifikation` |
| 12 | `12_neutralitaet_verteidigung` | Defense spending vs. priorities | `verteidigung-ausgaben-prioritaeten` |

Gaps in numbering (09, 11) are intentional — those notebooks were cut/merged.

## Common tasks

```bash
mise run setup     # Install all dependencies
mise run fetch     # Download datasets from BFS/BFE/World Bank
mise run lab       # Start LiveBook server
mise run test      # Run Elixir tests
mise run publish   # Copy reviewed output → die-zukunft.ch
```

## Data sources

12 datasets in `data/registry.toml`:

| Dataset | Source | Used by |
|---------|--------|---------|
| `einkommensverteilung_silc` | BFS DAM | NB01 |
| `ikt_egov` | BFS PxWeb | NB02 |
| `ikt_internetnutzung` | BFS PxWeb | NB02 |
| `erwerbstaetige_sake` | BFS DAM | NB03, NB07 |
| `mietzinse_kantone` | BFS DAM | NB04 |
| `forschung_ausgaben` | BFS DAM | NB05 |
| `elektrizitaet_produktion` | BFE OGD | NB06 |
| `energieverbrauch_sektor` | BFE OGD | NB06 |
| `gesundheitsausgaben` | BFS DAM | NB08 |
| `auslaender_aufenthalt` | BFS PxWeb | NB10 |
| `wanderungen` | BFS PxWeb | NB10 |
| `verteidigungsausgaben` | World Bank | NB12 |

## Publishing pipeline
1. Run notebook in LiveBook → interactive analysis
2. Export: charts → SVG, draft → markdown with TOML frontmatter
3. Human review + create FR/IT/EN language variants
4. `mise run publish` → copies to `die-zukunft.ch`
5. `zola build` in site repo to verify

## Notiz frontmatter format
Drafts must match the `notiz.html` template in `die-zukunft.ch`:
```toml
+++
title = "..."
description = "..."
slug = "..."
date = YYYY-MM-DD
template = "notiz.html"

[extra]
category = "datenbriefing"  # or: langforschung, standpunkt
evidence = "stark"          # or: mittel, schwach
tags = ["tag1", "tag2"]
charts = ["chart1.svg"]     # optional
+++
```

## Brand & tone
- Pragmatic, evidence-based, Swiss-serious
- No "free money" framing for UBI — use "stability", "foundation"
- No sci-fi vibes — measurable claims backed by data
- Chart style is NOT set per spec: the site applies one house style (Alpenglühen palette, mono axes, Swiss highlight) via `die-zukunft.ch/themes/avenir/static/js/dz-charts.js`; static SVG fallbacks come from `scripts/render_charts.mjs` using the same file. Specs only need data, encodings and a German title.
- Every published note carries `[extra.review]` and `[[extra.changelog]]` (see the site's `.claude/rules/technical.md`).

## BFS PxWeb API notes
- Base URL: `https://www.pxweb.bfs.admin.ch/api/v1`
- Requires POST with dimension/value selection queries
- Response format: JSON-stat2
- Public tables are pre-aggregated (no individual records)
- SILC microdata requires formal BFS data request (not used here)

## BFE OGD notes
- Base URL: `https://www.uvek-gis.admin.ch/BFE/ogd/`
- Direct CSV downloads (no API authentication needed)
- Electricity: wide format (one row per year, columns per source)
- Energy balance: long format (Jahr × Rubrik × Energietraeger → TJ)
