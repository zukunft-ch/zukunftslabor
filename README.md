# Zukunftslabor

**Die offene Forschungswerkstatt von [Die Zukunft](https://die-zukunft.ch).** Jede Notiz auf
[die-zukunft.ch/zukunftslabor](https://die-zukunft.ch/zukunftslabor/) lässt sich hier nachrechnen:
Datenquellen, Code, Diagramme. Texte und Daten stehen unter CC BY 4.0, Code unter MIT (siehe `LICENSE.md`).

- **Zitieren:** Die Zukunft, Zukunftslabor (Jahr): «Titel der Notiz». URL der Notiz. CC BY 4.0.
- **Frage vorschlagen:** [Neues Issue «Frage ans Labor»](https://github.com/zukunft-ch/zukunftslabor/issues/new?template=frage-ans-labor.yml)
- **Fehler melden:** [Neues Issue «Korrektur»](https://github.com/zukunft-ch/zukunftslabor/issues/new?template=korrektur.yml). Korrekturen werden auf der Website öffentlich vermerkt.
- **Zukunftsmonitor:** die Indikatoren hinter unseren Zielen, als [monitor.json](https://die-zukunft.ch/zukunftslabor/monitor.json).
- `output/datenbriefings-2026-11/`: Daten (CSV), Diagramm-Spezifikationen (Vega-Lite) und Texte der Notizen vom November 2026; `scripts/render_charts.mjs` rendert die statischen SVG-Fallbacks im Website-Design.

---


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

## Notebooks

10 notebooks covering Swiss policy topics. Each produces 4 charts + a publication-ready draft.

| # | Directory | Topic | Conclusion style |
|---|-----------|-------|-----------------|
| 01 | `01_grundeinkommen` | UBI financing models — 3 scenarios compared | Data speaks |
| 02 | `02_digitale_souveraenitaet` | Digital readiness gap (citizens vs. state) | Light framing |
| 03 | `03_automatisierung_arbeit` | Pre-LLM vs. Post-LLM automation risk | Data speaks |
| 04 | `04_wohnen_ungleichheit` | Cantonal rent burden — when does each cross 30%? | Data speaks |
| 05 | `05_forschung_innovation` | R&D spending — who performs, who pays? | Light framing |
| 06 | `06_energie_resilienz` | Electricity stress scenarios (drought + nuclear exit) | Data speaks |
| 07 | `07_uebergaenge_weiterbildung` | Training participation vs. automation exposure | Light framing |
| 08 | `08_life_science_gesundheit` | Health spending — admin cost waste | Data speaks |
| 10 | `10_talent_migration` | Immigrant overqualification as value loss | Data speaks |
| 12 | `12_neutralitaet_verteidigung` | Defense spending vs. public priorities | Light framing |

## Data sources

Datasets are defined in [`data/registry.toml`](data/registry.toml). Currently registered:

| Dataset | Source | Topic |
|---------|--------|-------|
| `einkommensverteilung_silc` | BFS DAM | Income distribution, Gini, deciles |
| `ikt_egov` | BFS PxWeb | E-government usage |
| `ikt_internetnutzung` | BFS PxWeb | Internet usage by age |
| `erwerbstaetige_sake` | BFS DAM | Employment by sector (SAKE) |
| `mietzinse_kantone` | BFS DAM | Rent prices by canton and room count |
| `forschung_ausgaben` | BFS DAM | R&D expenditure by sector |
| `elektrizitaet_produktion` | BFE OGD | Electricity production by source |
| `energieverbrauch_sektor` | BFE OGD | Energy consumption by sector |
| `gesundheitsausgaben` | BFS DAM | Health expenditure by category |
| `auslaender_aufenthalt` | BFS PxWeb | Foreign population by permit type |
| `wanderungen` | BFS PxWeb | International migration flows |
| `verteidigungsausgaben` | World Bank | Military expenditure (% GDP) |

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
│   ├── 01_grundeinkommen/
│   ├── 02_digitale_souveraenitaet/
│   ├── 03_automatisierung_arbeit/
│   ├── 04_wohnen_ungleichheit/
│   ├── 05_forschung_innovation/
│   ├── 06_energie_resilienz/
│   ├── 07_uebergaenge_weiterbildung/
│   ├── 08_life_science_gesundheit/
│   ├── 10_talent_migration/
│   └── 12_neutralitaet_verteidigung/
├── output/
│   ├── charts/               # exported SVG charts (gitignored)
│   └── drafts/               # generated markdown drafts (gitignored)
├── scripts/
│   ├── common.py             # HTTP caching + BFS API utilities
│   ├── fetch_bfs.py          # main data fetcher (BFS PxWeb + DAM + URL)
│   ├── fetch_oecd.py         # OECD SDMX fetcher
│   └── run_all_notebooks.exs # batch-run all notebooks
├── test/                     # Elixir tests
├── mise.toml                 # tool versions + task definitions
└── mix.exs                   # Elixir project + dependencies
```

## Adding a new analysis

1. Create a directory: `notebooks/NN_your_topic/`
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
