# Pipeline

The zukunftslabor pipeline turns Swiss federal data into publication-ready research notes (notizen) for die-zukunft.ch. Five stages, two languages (Python for fetching, Elixir for analysis).

## Overview

```
1. Registry        2. Fetch          3. Notebook         4. Export         5. Publish
registry.toml  ──▶  data/raw/    ──▶  LiveBook       ──▶  output/     ──▶  die-zukunft.ch
(definitions)      (cached files)    (analysis)         (charts+drafts)   (website)
```

## 1. Registry

All datasets are declared in [`data/registry.toml`](../data/registry.toml). Each entry specifies a source type, where to fetch from, and what the processed output should be named. See [data-sources.md](data-sources.md) for the full format.

Three source types are supported:

| Type | How it works |
|------|-------------|
| `bfs-pxweb` | POST query to BFS STAT-TAB PxWeb API, returns JSON-stat2 |
| `bfs-dam` | Direct download from BFS DAM (CSV or Excel) |
| `url` | Arbitrary URL download |

## 2. Fetch

`mise run fetch` runs `scripts/fetch_bfs.py`, which:

1. Reads `data/registry.toml`
2. Downloads each dataset to `data/raw/` (hash-based cache filenames)
3. Runs dataset-specific processors to produce clean CSVs in `data/processed/`

Downloaded files are cached for 24 hours. Re-running `fetch` within that window skips the download and only re-processes if needed.

You can also fetch a single dataset:

```bash
.venv/bin/python scripts/fetch_bfs.py einkommensverteilung_silc
```

### Processors

Some datasets (especially Excel files) need custom processing. Processors live in `fetch_bfs.py` as functions named `process_<dataset_name>()`:

- `process_einkommensverteilung()` — Excel sheets per year to flat CSV with deciles + Gini
- `process_sake()` — raw SAKE CSV to sector-level employment
- `process_mietzinse()` — Excel sheets per year to flat CSV with canton x rooms x price

PxWeb datasets are converted automatically from JSON-stat2 to CSV (no custom processor needed unless you want to reshape the data).

## 3. Notebook

Analysis happens in LiveBook notebooks under `notebooks/`. LiveBook runs attached to the project's Erlang node, so all modules from `lib/` are available without `Mix.install`.

Key Elixir modules available in notebooks:

| Module | Purpose |
|--------|---------|
| `Zukunftslabor.DataLoader` | Load processed CSVs into Explorer DataFrames |
| `Zukunftslabor.ChartExport` | Export VegaLite charts to SVG/PNG |
| `Zukunftslabor.NotizTemplate` | Generate markdown drafts with TOML frontmatter |

Typical notebook flow:

```elixir
# Load data
df = Zukunftslabor.DataLoader.load("mietzinse_kantone")

# Transform with Explorer
filtered = df |> DF.filter(rooms == "3 Zimmer") |> DF.sort_by(desc: price)

# Build chart
chart = Vl.new() |> Vl.data_from_values(filtered) |> ... |> ChartExport.style()

# Export
ChartExport.to_svg(chart, name: "mieten_kantone")
```

See [notebooks.md](notebooks.md) for conventions on structuring new notebooks.

## 4. Export

Each notebook ends with export cells that:

1. Call `ChartExport.to_svg(chart, name: "filename")` for each chart
2. Call `NotizTemplate.generate(title: ..., slug: ..., ...)` to produce a markdown draft

Output lands in:
- `output/charts/*.svg` — ready-to-publish chart files
- `output/drafts/*.md` — German draft with TOML frontmatter

You can also batch-export all notebooks without opening LiveBook:

```bash
elixir scripts/run_all_notebooks.exs
```

### Notiz draft format

Generated drafts follow this structure:

```toml
+++
title = "Einkommensverteilung und Grundeinkommen"
description = "Meta description for SEO."
slug = "einkommensverteilung-grundeinkommen"
date = 2026-02-11
template = "notiz.html"

[extra]
category = "datenbriefing"
evidence = "stark"
tags = ["grundeinkommen", "einkommensverteilung"]
charts = ["einkommensverteilung_dezile.svg", "einkommensverteilung_vergleich.svg"]
+++

Summary paragraph — the key finding in 2-3 sentences.

<!-- more -->

## Methodik
...

## Ergebnisse
...

## Datenquellen
...
```

**Categories:**
- `datenbriefing` — data-driven summary of existing statistics
- `langforschung` — longitudinal or comparative research
- `standpunkt` — policy position backed by evidence

**Evidence levels:**
- `stark` — official statistics, large samples, peer-reviewed
- `mittel` — aggregated data, model estimates, reasonable proxies
- `schwach` — small samples, expert opinion, preliminary data

## 5. Publish

After human review and creating FR/IT/EN language variants:

```bash
mise run publish
```

This copies:
- `output/charts/*.svg` → `die-zukunft.ch/static/zukunftslabor/charts/`
- `output/drafts/*.md` → `die-zukunft.ch/content/zukunftslabor/notizen/`

Then run `zola build` in the die-zukunft.ch repo to verify the pages render correctly.

### Language variants

The generated draft is German only. Before publishing, create:
- `slug.fr.md` — French translation
- `slug.it.md` — Italian translation
- `slug.en.md` — English translation (optional)

These go in the same content directory. Each variant has its own frontmatter with translated title, description, and body, but the same slug, category, evidence, and chart references.
