# Zukunftslabor — Research Repository

## Overview
Evidence-based research pipeline for **Die Zukunft** policy analysis. Produces data-driven notizen (research notes) for publication on `die-zukunft.ch/zukunftslabor/`.

## Stack
- **Analysis**: Elixir LiveBook (`.livemd`) + Explorer DataFrames + VegaLite
- **Data acquisition**: Python scripts (BFS PxWeb API, OECD SDMX, opendata.swiss)
- **Chart export**: `vega_lite_convert` (Rust-based, no Node dependency)
- **Task runner**: mise

## Key directories

| Path | Purpose |
|------|---------|
| `notebooks/` | LiveBook notebooks organized by topic |
| `lib/zukunftslabor/` | Elixir helpers (data loading, chart export, draft generation) |
| `scripts/` | Python data fetchers |
| `data/registry.toml` | Dataset definitions (tracked) |
| `data/raw/` | Downloaded files (gitignored) |
| `data/processed/` | Cleaned CSVs (gitignored) |
| `output/drafts/` | Generated markdown drafts (gitignored) |
| `output/charts/` | Exported SVG charts (gitignored) |

## Common tasks

```bash
mise run setup     # Install all dependencies
mise run fetch     # Download datasets from BFS/OECD
mise run lab       # Start LiveBook server
mise run test      # Run Elixir tests
mise run publish   # Copy reviewed output → die-zukunft.ch
```

## Data sources
- **BFS STAT-TAB** (PxWeb API): income distribution, social security, employment, housing
- **OECD**: automation risk estimates, international comparisons
- **opendata.swiss**: cantonal datasets
- Datasets defined in `data/registry.toml`, fetched via `scripts/fetch_bfs.py`

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
- Chart colors: Purple `#a855f7`, Blue `#3b82f6`, Teal `#06b6d4`
- Font in charts: Switzer (matches website)
- Chart width: 720px (matches `container--narrow`)

## BFS PxWeb API notes
- Base URL: `https://www.pxweb.bfs.admin.ch/api/v1`
- Requires POST with dimension/value selection queries
- Response format: JSON-stat2
- Public tables are pre-aggregated (no individual records)
- SILC microdata requires formal BFS data request (not used here)
