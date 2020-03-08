defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries" do
    assert is_list(TzExtra.countries())
  end

  test "time zones" do
    assert is_list(TzExtra.countries_time_zones())

    assert 2 == TzExtra.countries_time_zones() |> Enum.filter(& &1.time_zone == "Europe/Simferopol") |> Enum.count()
  end
end
