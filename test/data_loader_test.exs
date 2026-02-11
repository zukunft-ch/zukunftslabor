defmodule Zukunftslabor.DataLoaderTest do
  use ExUnit.Case

  alias Zukunftslabor.DataLoader

  test "registry loads successfully" do
    reg = DataLoader.registry()
    assert is_map(reg)
    assert Map.has_key?(reg, "datasets")
  end

  test "list_datasets returns list" do
    # May be empty if no data fetched yet
    result = DataLoader.list_datasets()
    assert is_list(result)
  end
end
