# Notebook Conventions

Guidelines for creating new LiveBook notebooks in zukunftslabor.

## Directory naming

Each notebook lives in its own directory under `notebooks/`:

```
notebooks/NN_topic_slug/analysis_name.livemd
```

- `NN` — two-digit sequence number
- `topic_slug` — lowercase, underscores, matches the policy area
- One primary `.livemd` per directory (additional notebooks are fine for exploration)
- Numbering gaps are intentional (09 and 11 were cut)

Existing notebooks:

| Directory | Topic | Conclusion |
|-----------|-------|------------|
| `01_grundeinkommen` | UBI financing models — 3 scenarios | Data speaks |
| `02_digitale_souveraenitaet` | Digital readiness gap (citizens vs. state) | Light framing |
| `03_automatisierung_arbeit` | Pre-LLM vs. Post-LLM automation risk | Data speaks |
| `04_wohnen_ungleichheit` | Cantonal rent burden threshold projection | Data speaks |
| `05_forschung_innovation` | R&D spending: who performs, who pays? | Light framing |
| `06_energie_resilienz` | Electricity stress scenarios | Data speaks |
| `07_uebergaenge_weiterbildung` | Training participation vs. automation | Light framing |
| `08_life_science_gesundheit` | Health spending admin cost focus | Data speaks |
| `10_talent_migration` | Immigrant overqualification | Data speaks |
| `12_neutralitaet_verteidigung` | Defense spending vs. priorities | Light framing |

**"Data speaks"** = notebook ends with findings only, no party conclusion.
**"Light framing"** = findings plus brief, natural policy context.

## Section structure

Every notebook should follow this structure:

### 1. Setup cell

```elixir
# Only needed for standalone use (outside attached LiveBook).
# When running via `mise run lab`, all deps are available automatically.
Mix.install([
  {:explorer, "~> 0.11"},
  {:vega_lite, "~> 0.1"},
  {:kino_vega_lite, "~> 0.1"}
])
```

### 2. Fragestellung (research question)

A markdown cell stating:
- The question being investigated
- Category (`datenbriefing`, `langforschung`, or `standpunkt`)
- Evidence level (`stark`, `mittel`, or `schwach`) with justification

### 3. Daten laden (load data)

```elixir
alias Explorer.DataFrame, as: DF
alias Explorer.Series, as: S

df = Zukunftslabor.DataLoader.load("dataset_name")
Zukunftslabor.DataLoader.summary(df)
```

### 4. Analysis sections

One or more sections with:
- Data transformation using Explorer (`DF.filter`, `DF.group_by`, `DF.summarise`, etc.)
- VegaLite chart definitions
- Brief markdown interpretation of findings

### 5. Kernaussage (key finding)

A markdown cell summarizing the main result in 2-3 sentences. This becomes the summary paragraph in the published notiz. Must include **Einschränkungen** (limitations).

### 6. Export cells

```elixir
# Export charts
alias Zukunftslabor.ChartExport

ChartExport.to_svg(chart1, name: "descriptive_chart_name")
ChartExport.to_svg(chart2, name: "another_chart_name")
```

```elixir
# Generate draft
Zukunftslabor.NotizTemplate.generate(
  title: "Title in German",
  description: "SEO meta description.",
  slug: "url-slug-kebab-case",
  category: "datenbriefing",
  evidence: "stark",
  tags: ["tag1", "tag2"],
  charts: ["descriptive_chart_name.svg", "another_chart_name.svg"],
  summary: "Key finding summary paragraph.",
  body: """
  ## Methodik
  ...

  ## Ergebnisse
  ...

  ## Einschränkungen
  ...

  ## Datenquellen
  ...
  """
)
```

## Chart conventions

All charts should use consistent branding:

```elixir
chart =
  Vl.new(width: 720, height: 400, title: "Chart title")
  |> Vl.data_from_values(data)
  |> Vl.mark(:bar, corner_radius_end: 4)
  |> Vl.encode_field(:x, "column", type: :nominal)
  |> Vl.encode_field(:y, "value", type: :quantitative)
  |> Vl.config(font: "Switzer, system-ui, sans-serif", view: [stroke: "transparent"])
```

### Styling rules

| Property | Value |
|----------|-------|
| Width | 720px (default, matches `container--narrow` on site) |
| Font | Switzer, system-ui, sans-serif |
| Colors | Purple `#a855f7`, Blue `#3b82f6`, Teal `#06b6d4`, Green `#10b981`, Orange `#f59e0b`, Red `#ef4444` |
| Bar corners | `corner_radius_end: 4` (rounded top corners) |
| View stroke | `transparent` |
| Background | Transparent (inherits page background) |

### Naming

Chart filenames should be descriptive and use underscores:
- `grundeinkommen_baseline_dezile.svg`
- `automatisierung_pre_post_llm.svg`
- `wohnen_schwelle_prognose.svg`

Avoid generic names like `chart1.svg`.

## Evidence levels

Each notiz is graded by evidence strength. Choose honestly:

| Level | Criteria | Example |
|-------|----------|---------|
| `stark` | Official statistics, large representative samples, peer-reviewed methodology | BFS SILC income data, BFS Strukturerhebung rent data |
| `mittel` | Aggregated public data, model-based estimates, reasonable proxy indicators | OECD automation risk estimates applied to BFS employment |
| `schwach` | Small samples, expert opinion, preliminary or incomplete data | Survey of 200 respondents, single-source estimates |

## Categories

| Category | Use when |
|----------|----------|
| `datenbriefing` | Summarizing existing official statistics with light analysis |
| `langforschung` | Longitudinal trends, cross-country comparisons, deeper modeling |
| `standpunkt` | Policy position argued with supporting evidence |

## Tips

- Use `Zukunftslabor.DataLoader.summary(df)` to inspect data shape and column types
- Keep chart code in separate cells from data transformation for easier iteration
- Test export cells before finishing — the generated draft should render in Zola without warnings
- Manual EU comparison data can be inlined as lists in notebook cells (document the source in a comment)
- Each notebook should produce exactly 4 charts for consistent notiz layout
