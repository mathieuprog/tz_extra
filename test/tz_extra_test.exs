defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries" do
    assert is_list(TzExtra.countries())
  end

  test "time zones" do
    assert is_list(TzExtra.time_zones())

    assert 2 == TzExtra.time_zones() |> Enum.filter(& &1.name == "Europe/Simferopol") |> Enum.count()
  end
end
