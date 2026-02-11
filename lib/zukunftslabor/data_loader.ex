defmodule Zukunftslabor.DataLoader do
  @moduledoc """
  Load CSV and JSON data into Explorer DataFrames.
  """

  alias Explorer.DataFrame
  alias Explorer.Series

  @doc """
  Load a CSV file from the processed data directory by dataset name.

      iex> df = Zukunftslabor.DataLoader.load("einkommensverteilung_silc")
  """
  def load(name) when is_binary(name) do
    path = Path.join(Zukunftslabor.processed_dir(), "#{name}.csv")
    DataFrame.from_csv!(path)
  end

  @doc """
  Load a CSV from an arbitrary path.
  """
  def load_csv(path) do
    DataFrame.from_csv!(path)
  end

  @doc """
  Load a JSON file into a DataFrame.
  """
  def load_json(path) do
    DataFrame.from_ndjson!(path)
  end

  @doc """
  List available processed datasets.
  """
  def list_datasets do
    Zukunftslabor.processed_dir()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".csv"))
    |> Enum.map(&String.trim_trailing(&1, ".csv"))
    |> Enum.sort()
  end

  @doc """
  Load the dataset registry (TOML) and return as a map.
  """
  def registry do
    path = Path.join(Zukunftslabor.data_dir(), "registry.toml")
    {:ok, data} = Toml.decode_file(path)
    data
  end

  @doc """
  Quick summary of a DataFrame: shape, column types, first few rows.
  """
  def summary(df) do
    IO.puts("Shape: #{DataFrame.n_rows(df)} rows x #{DataFrame.n_columns(df)} columns")
    IO.puts("Columns:")

    for name <- DataFrame.names(df) do
      series = df[name]
      IO.puts("  #{name}: #{Series.dtype(series)}")
    end

    IO.puts("\nFirst 5 rows:")
    DataFrame.head(df, 5) |> DataFrame.print()
  end
end
