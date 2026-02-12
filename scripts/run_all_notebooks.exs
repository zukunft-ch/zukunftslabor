# Run all notebook analyses and export charts + drafts.
# Usage: mix run scripts/run_all_notebooks.exs
#
# Parses .livemd files, extracts Elixir code blocks,
# skips Mix.install blocks, and evaluates them in sequence.
# Each notebook runs in its own Code.eval_string context
# so variable names don't clash across notebooks.

defmodule NotebookRunner do
  @prelude """
  require Explorer.DataFrame
  alias Explorer.DataFrame, as: DF
  alias Explorer.Series
  alias VegaLite, as: Vl
  """

  def run(path) do
    dir = Path.basename(Path.dirname(path))

    IO.puts("\n========================================")
    IO.puts("  #{dir}")
    IO.puts("========================================\n")

    content = File.read!(path)

    blocks =
      Regex.scan(~r/```elixir\n(.*?)```/s, content, capture: :all_but_first)
      |> Enum.map(&hd/1)
      |> Enum.reject(&String.starts_with?(&1, "Mix.install"))

    code = @prelude <> "\n\n" <> Enum.join(blocks, "\n\n")

    try do
      Code.eval_string(code)
      IO.puts("\n  >> #{dir} complete\n")
    rescue
      e ->
        IO.puts("\n  !! #{dir} FAILED: #{Exception.message(e)}\n")
        IO.puts("  #{Exception.format(:error, e, __STACKTRACE__)}")
    end
  end
end

notebooks = [
  "notebooks/01_grundeinkommen/einkommensverteilung.livemd",
  "notebooks/02_digitale_souveraenitaet/digitale_souveraenitaet_offener_staat.livemd",
  "notebooks/03_automatisierung_arbeit/automatisierungsrisiko.livemd",
  "notebooks/04_wohnen_ungleichheit/mietbelastung.livemd",
  "notebooks/05_forschung_innovation/forschung_ausgaben.livemd",
  "notebooks/06_energie_resilienz/energiemix.livemd",
  "notebooks/07_uebergaenge_weiterbildung/weiterbildung.livemd",
  "notebooks/08_life_science_gesundheit/gesundheitskosten.livemd",
  "notebooks/10_talent_migration/zuwanderung_qualifikation.livemd",
  "notebooks/12_neutralitaet_verteidigung/verteidigungsausgaben.livemd"
]

IO.puts("Zukunftslabor — Running #{length(notebooks)} notebooks")
IO.puts("Output: output/charts/*.svg + output/drafts/*.md\n")

# Ensure output directories exist
File.mkdir_p!(Zukunftslabor.charts_dir())
File.mkdir_p!(Zukunftslabor.drafts_dir())

# Check data availability
available = Zukunftslabor.DataLoader.list_datasets()
IO.puts("Available datasets: #{length(available)}")
IO.puts("  #{Enum.join(available, ", ")}\n")

# Run each notebook
results =
  Enum.map(notebooks, fn path ->
    {time_us, _} = :timer.tc(fn -> NotebookRunner.run(path) end)
    dir = Path.basename(Path.dirname(path))
    IO.puts("  (#{Float.round(time_us / 1_000_000, 1)}s)")
    {dir, time_us}
  end)

# Summary
IO.puts("\n========================================")
IO.puts("  Summary")
IO.puts("========================================\n")

charts = Path.wildcard(Path.join(Zukunftslabor.charts_dir(), "*.svg"))
drafts = Path.wildcard(Path.join(Zukunftslabor.drafts_dir(), "*.md"))

IO.puts("Charts: #{length(charts)} SVGs")
IO.puts("Drafts: #{length(drafts)} markdown files")

total_s = Enum.map(results, fn {_, us} -> us end) |> Enum.sum() |> div(1_000_000)
IO.puts("Total:  #{total_s}s")
