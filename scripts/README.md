# Scripts

Python data fetchers and an Elixir batch runner. Usually invoked via `mise run` tasks rather than directly.

## Files

| Script | Language | Description |
|--------|----------|-------------|
| `fetch_bfs.py` | Python | Main data fetcher. Reads `data/registry.toml`, downloads from BFS PxWeb/DAM APIs, runs dataset-specific processors to produce clean CSVs. |
| `fetch_oecd.py` | Python | OECD SDMX API fetcher. Downloads JSON for OECD datasets. Currently minimal — CSV conversion is dataset-specific. |
| `common.py` | Python | Shared utilities: HTTP caching (24h), BFS PxWeb API helpers, directory constants. |
| `run_all_notebooks.exs` | Elixir | Batch-runs all 4 notebook analyses without opening LiveBook. Produces all charts + drafts in one pass. |

## Running individually

Python scripts require the project's virtual environment:

```bash
# Single dataset
.venv/bin/python scripts/fetch_bfs.py mietzinse_kantone

# All datasets
.venv/bin/python scripts/fetch_bfs.py

# Batch notebook run (requires Elixir deps installed)
elixir scripts/run_all_notebooks.exs
```

## Python dependencies

Defined in `requirements.txt`:
- `requests` — HTTP client
- `pyaxis` — PxWeb JSON-stat2 parsing
- `openpyxl` — Excel file processing
