defmodule Zukunftslabor.MixProject do
  use Mix.Project

  def project do
    [
      app: :zukunftslabor,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:explorer, "~> 0.11"},
      {:vega_lite, "~> 0.1"},
      {:vega_lite_convert, "~> 1.0"},
      {:kino, "~> 0.14"},
      {:kino_vega_lite, "~> 0.1"},
      {:kino_explorer, "~> 0.1"},
      {:jason, "~> 1.4"},
      {:toml, "~> 0.7"},
      {:req, "~> 0.5"}
    ]
  end
end
