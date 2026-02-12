defmodule Mix.Tasks.Zukunftslabor.ExportAll do
  @moduledoc """
  Headless evaluation of all notebooks to export charts (SVG + JSON) and drafts.

  Usage:
      mix zukunftslabor.export_all
  """

  use Mix.Task

  @shortdoc "Export all notebooks headlessly → SVG + JSON + drafts"

  @notebooks [
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

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    # Define Kino stubs so Kino.Markdown.new() calls become no-ops
    # (Kino is a LiveBook-only dependency, not available in Mix)
    unless Code.ensure_loaded?(Kino.Markdown) do
      defmodule Kino.Markdown do
        def new(_text), do: :ok
      end
    end

    results =
      Enum.map(@notebooks, fn path ->
        Mix.shell().info("\n#{IO.ANSI.cyan()}▸ #{path}#{IO.ANSI.reset()}")

        case eval_notebook(path) do
          :ok ->
            Mix.shell().info("  #{IO.ANSI.green()}✓ done#{IO.ANSI.reset()}")
            {:ok, path}

          {:error, reason} ->
            Mix.shell().error("  ✗ #{inspect(reason)}")
            {:error, path, reason}
        end
      end)

    ok = Enum.count(results, &match?({:ok, _}, &1))
    fail = Enum.count(results, &match?({:error, _, _}, &1))

    Mix.shell().info("\n#{ok}/#{ok + fail} notebooks exported.")

    if fail > 0 do
      Mix.shell().error("Failed:")

      for {:error, path, reason} <- results do
        Mix.shell().error("  #{path}: #{inspect(reason)}")
      end
    end
  end

  defp eval_notebook(path) do
    content = File.read!(path)
    cells = extract_elixir_cells(content)

    # Concatenate all cells into one script with a shared preamble
    # that sets up the aliases used across all notebooks.
    preamble = """
    alias Explorer.DataFrame, as: DF
    alias Explorer.Series
    alias VegaLite, as: Vl
    import Explorer.Series, only: [col: 1]
    require Explorer.DataFrame
    """

    script = preamble <> "\n" <> Enum.join(cells, "\n\n")

    try do
      Code.eval_string(script, [], file: path, line: 1)
      :ok
    rescue
      e ->
        {:error, Exception.message(e)}
    catch
      kind, reason ->
        {:error, "#{kind}: #{inspect(reason)}"}
    end
  end

  defp extract_elixir_cells(content) do
    regex = ~r/```elixir\n(.*?)```/s

    Regex.scan(regex, content, capture: :all_but_first)
    |> Enum.map(fn [code] -> code end)
    |> Enum.reject(&skip_cell?/1)
  end

  defp skip_cell?(code) do
    # Skip Mix.install (LiveBook dependency setup — already loaded in Mix project)
    String.contains?(code, "Mix.install")
  end
end
