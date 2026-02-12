defmodule Zukunftslabor.ChartExport do
  @moduledoc """
  Export VegaLite charts to SVG using vega_lite_convert (Rust-based, no Node).
  """

  alias VegaLite, as: Vl

  @default_width 720

  @doc """
  Export a VegaLite spec to SVG file.

  Options:
    - `:width` - chart width in px (default: 720, matches container--narrow)
    - `:name` - output filename without extension (required)

  Returns the output path.
  """
  def to_svg(%Vl{} = chart, opts) do
    name = Keyword.fetch!(opts, :name)
    width = Keyword.get(opts, :width, @default_width)

    chart = chart |> Vl.config(width: width)
    svg = VegaLite.Convert.to_svg(chart)

    dir = Zukunftslabor.charts_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{name}.svg")
    File.write!(path, svg)

    IO.puts("Chart exported → #{path}")
    path
  end

  @doc """
  Export a VegaLite spec to PNG file.
  """
  def to_png(%Vl{} = chart, opts) do
    name = Keyword.fetch!(opts, :name)
    width = Keyword.get(opts, :width, @default_width)
    scale = Keyword.get(opts, :scale, 2)

    chart = chart |> Vl.config(width: width)
    png = VegaLite.Convert.to_png(chart, scale: scale)

    dir = Zukunftslabor.charts_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{name}.png")
    File.write!(path, png)

    IO.puts("Chart exported → #{path}")
    path
  end

  @doc """
  Export a VegaLite spec to JSON file for client-side rendering.

  Options:
    - `:name` - output filename without extension (required)

  Returns the output path.
  """
  def to_json(%Vl{} = chart, opts) do
    name = Keyword.fetch!(opts, :name)

    spec = chart |> VegaLite.to_spec()
    json = Jason.encode!(spec, pretty: true)

    dir = Zukunftslabor.charts_dir()
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{name}.json")
    File.write!(path, json)

    IO.puts("Chart spec exported → #{path}")
    path
  end

  @doc """
  Apply standard zukunftslabor chart styling.
  Uses brand colors and Switzer font.
  """
  def style(%Vl{} = chart) do
    chart
    |> Vl.config(
      font: "Switzer, system-ui, sans-serif",
      axis: [
        label_font_size: 12,
        title_font_size: 13,
        grid: true,
        grid_opacity: 0.15
      ],
      view: [stroke: "transparent"],
      range: [
        category: ["#a855f7", "#3b82f6", "#06b6d4", "#10b981", "#f59e0b", "#ef4444"]
      ]
    )
  end
end
