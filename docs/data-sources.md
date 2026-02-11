# Data Sources

How to register, fetch, and process datasets in zukunftslabor.

## Registry format

All datasets are declared in [`data/registry.toml`](../data/registry.toml). Each entry lives under `[datasets.<name>]`:

```toml
[datasets.my_dataset]
description = "What this dataset contains"
source = "bfs-dam"                          # bfs-pxweb | bfs-dam | url
url = "https://dam-api.bfs.admin.ch/..."    # for bfs-dam and url sources
format = "csv"                              # csv | xlsx (for bfs-dam/url)
note = "Any context for future reference"
processed_as = "my_dataset.csv"             # output filename in data/processed/
```

The dataset name (`my_dataset`) is used as the key everywhere — in `DataLoader.load("my_dataset")`, in fetch commands, and in processor function names.

## Source types

### `bfs-pxweb` — BFS STAT-TAB API

For datasets from [BFS STAT-TAB](https://www.pxweb.bfs.admin.ch/). Uses the PxWeb API with POST queries.

```toml
[datasets.ikt_egov]
description = "E-Government usage"
source = "bfs-pxweb"
table = "px-x-1604000000_103"
processed_as = "ikt_egov.csv"

[datasets.ikt_egov.dimensions]
"Online-Dienste in Zusammenhang mit den Behörden" = ["IGV12", "IGOV12IFCH"]
"Geschlecht" = ["0"]                # 0 = total
"Altersklasse" = ["0"]              # 0 = total
"Jahr" = ["2025", "2023", "2021"]
"Absolut / relativ" = ["1"]         # 1 = percentage
"Resultat" = ["0"]
```

**Finding the table ID:** Navigate to the table on [pxweb.bfs.admin.ch](https://www.pxweb.bfs.admin.ch/), the table ID is in the URL (e.g., `px-x-1604000000_103`).

**Finding dimension values:** The fetch script queries the table metadata first. Check the raw JSON in `data/raw/` or use the PxWeb web interface to explore available dimension values.

### `bfs-dam` — BFS direct download

For files hosted on the BFS DAM (Digital Asset Management) platform. Supports CSV and Excel.

```toml
[datasets.mietzinse_kantone]
description = "Rent prices by canton"
source = "bfs-dam"
url = "https://dam-api.bfs.admin.ch/hub/api/dam/assets/33947475/master"
format = "xlsx"
processed_as = "mietzinse_kantone.csv"
```

**Finding the URL:** On [bfs.admin.ch](https://www.bfs.admin.ch/), find the dataset page and look for the download link. The DAM URL contains an asset ID number.

### `url` — Arbitrary download

For any dataset available via direct URL (OECD, opendata.swiss, etc.):

```toml
[datasets.some_data]
description = "Description"
source = "url"
url = "https://example.com/data.csv"
format = "csv"
processed_as = "some_data.csv"
```

## Adding a custom processor

If your dataset needs transformation beyond a simple download (e.g., Excel with multiple sheets, pivoting, filtering), add a processor function in `scripts/fetch_bfs.py`:

```python
def process_my_dataset(raw_path: Path, out_path: Path):
    """Convert raw download to clean CSV."""
    import openpyxl
    wb = openpyxl.load_workbook(raw_path)

    rows = []
    for sheet_name in wb.sheetnames:
        ws = wb[sheet_name]
        # ... extract and reshape data ...
        rows.append({"year": sheet_name, "value": ...})

    df = pd.DataFrame(rows)
    df.to_csv(out_path, index=False)
```

The fetch script calls processors by convention: a dataset named `my_dataset` looks for `process_my_dataset()`. If no processor exists, the raw file is copied as-is to `data/processed/`.

Existing processors:

| Function | What it does |
|----------|-------------|
| `process_einkommensverteilung()` | Excel sheets (one per year) to flat CSV with decile shares + Gini + median |
| `process_sake()` | Raw SAKE CSV to clean sector-level employment with NOGA labels |
| `process_mietzinse()` | Excel sheets (one per year) to flat CSV with canton x rooms x price |

## Cache behavior

Downloaded files are stored in `data/raw/` with hash-based filenames (12 chars of SHA-256 of the URL). Files are considered fresh for 24 hours (`CACHE_MAX_AGE = 86400` in `scripts/common.py`).

- Re-running `mise run fetch` within 24h skips downloads and only re-processes
- To force re-download, delete the relevant file in `data/raw/` or clear the entire directory
- `data/raw/` and `data/processed/` are gitignored — every clone starts fresh

## Column naming conventions

Processed CSVs should use consistent column names:

- Lowercase with underscores: `income_share`, `rent_price`, `year`
- German column names are fine (the data is Swiss): `kanton`, `zimmerzahl`, `preis`
- Include a `year` or `jahr` column for time series
- Use standard BFS canton abbreviations where applicable (`ZH`, `BE`, `LU`, etc.)
- Numeric values should be plain numbers (no formatting, no units in the value)

## Fetching a single dataset

```bash
# All datasets
mise run fetch

# One specific dataset
.venv/bin/python scripts/fetch_bfs.py einkommensverteilung_silc
```
