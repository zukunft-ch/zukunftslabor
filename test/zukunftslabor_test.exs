defmodule ZukunftslaborTest do
  use ExUnit.Case

  test "data directories are configured" do
    assert Zukunftslabor.data_dir() |> String.ends_with?("data")
    assert Zukunftslabor.raw_dir() |> String.ends_with?("raw")
    assert Zukunftslabor.processed_dir() |> String.ends_with?("processed")
  end

  test "output directories are configured" do
    assert Zukunftslabor.drafts_dir() |> String.ends_with?("drafts")
    assert Zukunftslabor.charts_dir() |> String.ends_with?("charts")
  end
end
