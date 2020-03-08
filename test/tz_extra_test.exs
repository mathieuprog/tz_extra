defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries" do
    assert is_list(TzExtra.countries())
  end

  test "time zones" do
    assert is_list(TzExtra.time_zones_by_country())

    assert 2 == TzExtra.time_zones_by_country() |> Enum.filter(& &1.time_zone == "Europe/Simferopol") |> Enum.count()
  end
end
