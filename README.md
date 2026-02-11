# Zukunftslabor

Evidence-based research pipeline for [Die Zukunft](https://die-zukunft.ch) policy analysis. Fetches Swiss federal data, runs analysis in LiveBook notebooks, and produces publication-ready charts and markdown drafts for the party website.

## Prerequisites

- [mise](https://mise.jdx.dev/) (installs Erlang, Elixir, Python automatically)
- [LiveBook](https://livebook.dev/) (`mix escript.install hex livebook`)

Tool versions are pinned in `mise.toml`:

| Tool | Version |
|------|---------|
| Erlang | 27.3.4.6 |
| Elixir | 1.19.5-otp-27 |
| Python | 3.13 |

## Quick start

```bash
git clone https://github.com/zukunft-ch/zukunftslabor.git
cd zukunftslabor
mise run setup    # install Elixir deps + Python venv
mise run fetch    # download datasets from BFS
mise run lab      # open LiveBook at http://localhost:8080
```

## Pipeline

```
registry.toml          data/raw/           data/processed/
 (definitions) ──fetch──▶ (cached) ──process──▶ (clean CSVs)
                                                    │
                                                    ▼
                                              notebooks/
                                           (LiveBook analysis)
                                                    │
                                          ┌─────────┴─────────┐
                                          ▼                   ▼
                                   output/charts/      output/drafts/
                                    (SVG files)        (markdown + TOML)
                                          │                   │
                                          └─────────┬─────────┘
                                                    │ publish
                                                    ▼
                                            die-zukunft.ch
```

See [docs/pipeline.md](docs/pipeline.md) for the full pipeline reference.

## Tasks

All tasks are defined in `mise.toml` and run via `mise run <task>`.

| Task | Description |
|------|-------------|
| `setup` | Install Elixir deps + create Python venv |
| `fetch` | Download all datasets defined in `data/registry.toml` |
| `lab` | Start LiveBook attached to the project's Erlang node |
| `export` | Export a notebook to draft + charts (placeholder) |
| `publish` | Copy `output/` to `die-zukunft.ch` repo |
| `test` | Run Elixir tests (`mix test`) |

## Data sources

Datasets are defined in [`data/registry.toml`](data/registry.toml). Currently registered:

| Dataset | Source | Topic |
|---------|--------|-------|
| `einkommensverteilung_silc` | BFS DAM | Income distribution, Gini, deciles |
| `ikt_egov` | BFS PxWeb | E-government usage 2014-2025 |
| `erwerbstaetige_sake` | BFS DAM | Employment by sector (SAKE) |
| `mietzinse_kantone` | BFS DAM | Rent prices by canton and room count |

See [docs/data-sources.md](docs/data-sources.md) for how to add new datasets.

## Project structure

```
zukunftslabor/
├── data/
│   ├── registry.toml        # dataset definitions (tracked)
│   ├── raw/                  # cached downloads (gitignored)
│   └── processed/            # cleaned CSVs (gitignored)
├── lib/
│   └── zukunftslabor/
│       ├── data_loader.ex    # load CSVs into Explorer DataFrames
│       ├── chart_export.ex   # VegaLite → SVG/PNG export
│       └── notiz_template.ex # generate markdown drafts with TOML frontmatter
├── notebooks/
│   ├── 01_grundeinkommen/    # income distribution + UBI simulation
│   ├── 02_digitale_souveraenitaet/  # e-gov usage + e-ID
│   ├── 03_automatisierung_arbeit/   # automation risk by sector
│   └── 04_wohnen_ungleichheit/      # rent burden by income group
├── output/
│   ├── charts/               # exported SVG charts (gitignored)
│   └── drafts/               # generated markdown drafts (gitignored)
├── scripts/
│   ├── common.py             # HTTP caching + BFS API utilities
│   ├── fetch_bfs.py          # main data fetcher (BFS PxWeb + DAM)
│   ├── fetch_oecd.py         # OECD SDMX fetcher
│   └── run_all_notebooks.exs # batch-run all notebooks
├── test/                     # Elixir tests
├── mise.toml                 # tool versions + task definitions
└── mix.exs                   # Elixir project + dependencies
```

## Adding a new analysis

1. Create a directory: `notebooks/05_your_topic/`
2. Register datasets in `data/registry.toml` and run `mise run fetch`
3. Create a `.livemd` notebook following the [notebook conventions](docs/notebooks.md)
4. Run analysis in LiveBook (`mise run lab`)
5. Export charts and draft via the export cells in your notebook
6. Review output in `output/drafts/` and `output/charts/`

## Publishing to die-zukunft.ch

After reviewing drafts and creating FR/IT/EN translations:

```bash
mise run publish   # copies output/ → die-zukunft.ch
```

This copies SVGs to `die-zukunft.ch/static/zukunftslabor/charts/` and drafts to `die-zukunft.ch/content/zukunftslabor/notizen/`. Run `zola build` in the site repo to verify.

The draft frontmatter format is documented in [docs/pipeline.md](docs/pipeline.md#notiz-draft-format).

## Related repos

| Repo | Purpose |
|------|---------|
| [die-zukunft.ch](https://github.com/zukunft-ch/die-zukunft.ch) | Zola website (publishes notizen) |
| [avenir](https://github.com/zukunft-ch/avenir) | Zola theme (contains `notiz.html` template) |
| [assets](https://github.com/zukunft-ch/assets) | Favicons + OG images |
