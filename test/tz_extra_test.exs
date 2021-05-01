defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries/0" do
    assert is_list(TzExtra.countries())
  end

  test "countries_time_zones/1" do
    assert is_list(TzExtra.countries_time_zones())

    assert 2 == TzExtra.countries_time_zones() |> Enum.filter(& &1.time_zone == "Europe/Simferopol") |> Enum.count()
  end

  test "time_zone_identifiers/1" do
    assert is_list(TzExtra.time_zone_identifiers())
  end
end
