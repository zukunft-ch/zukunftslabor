defmodule Mix.Tasks.Zukunftslabor.Export do
  @moduledoc """
  Export a LiveBook notebook to a notiz draft with charts.

  Usage:
      mix zukunftslabor.export notebooks/01_grundeinkommen/einkommensverteilung.livemd

  This evaluates the notebook, captures VegaLite chart outputs,
  exports them as SVGs, and generates a markdown draft.

  Note: For now, use LiveBook's interactive export. This task is a
  placeholder for future headless evaluation.
  """

  use Mix.Task

  @shortdoc "Export notebook → draft + charts"

  @impl Mix.Task
  def run(args) do
    case args do
      [path] ->
        if File.exists?(path) do
          Mix.shell().info("Notebook: #{path}")
          Mix.shell().info("")
          Mix.shell().info("Headless notebook evaluation is not yet implemented.")
          Mix.shell().info("For now, use LiveBook's interactive export:")
          Mix.shell().info("  1. Open the notebook in LiveBook")
          Mix.shell().info("  2. Run all cells")
          Mix.shell().info("  3. Use the export helpers in the notebook's final cell")
          Mix.shell().info("")
          Mix.shell().info("The notebook's export cell calls:")
          Mix.shell().info("  Zukunftslabor.ChartExport.to_svg/2")
          Mix.shell().info("  Zukunftslabor.NotizTemplate.generate/1")
        else
          Mix.shell().error("File not found: #{path}")
          exit({:shutdown, 1})
        end

      _ ->
        Mix.shell().error("Usage: mix zukunftslabor.export <notebook_path>")
        exit({:shutdown, 1})
    end
  end
end
