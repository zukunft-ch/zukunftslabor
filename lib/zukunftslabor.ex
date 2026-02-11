defmodule Zukunftslabor do
  @moduledoc """
  Research toolkit for evidence-based policy analysis.
  """

  @data_dir Path.join(File.cwd!(), "data")
  @output_dir Path.join(File.cwd!(), "output")

  def data_dir, do: @data_dir
  def raw_dir, do: Path.join(@data_dir, "raw")
  def processed_dir, do: Path.join(@data_dir, "processed")
  def output_dir, do: @output_dir
  def drafts_dir, do: Path.join(@output_dir, "drafts")
  def charts_dir, do: Path.join(@output_dir, "charts")
end
