defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries/0" do
    assert is_list(TzExtra.countries())
  end

  test "countries_time_zones/1" do
    assert is_list(TzExtra.countries_time_zones())

    assert 2 == TzExtra.countries_time_zones() |> Enum.filter(& &1.time_zone == "Europe/Simferopol") |> Enum.count()

    assert TzExtra.countries_time_zones(prepend_utc: true) |> Enum.any?(& &1.time_zone == "Etc/UTC")
    refute TzExtra.countries_time_zones(prepend_utc: false) |> Enum.any?(& &1.time_zone == "Etc/UTC")
    refute TzExtra.countries_time_zones() |> Enum.any?(& &1.time_zone == "Etc/UTC")
  end

  test "time_zone_identifiers/1" do
    assert is_list(TzExtra.time_zone_identifiers())

    assert TzExtra.civil_time_zone_identifiers(prepend_utc: true) |> Enum.any?(& &1 == "Etc/UTC")
    refute TzExtra.civil_time_zone_identifiers(prepend_utc: false) |> Enum.any?(& &1 == "Etc/UTC")
    refute TzExtra.civil_time_zone_identifiers() |> Enum.any?(& &1 == "Etc/UTC")

    assert TzExtra.civil_time_zone_identifiers(include_alias: true) |> Enum.any?(& &1 == "America/Guadeloupe")
    refute TzExtra.civil_time_zone_identifiers(include_alias: false) |> Enum.any?(& &1 == "America/Guadeloupe")
    refute TzExtra.civil_time_zone_identifiers() |> Enum.any?(& &1 == "America/Guadeloupe")

    assert TzExtra.time_zone_identifiers(include_alias: true) |> Enum.any?(& &1 == "America/Guadeloupe")
    refute TzExtra.time_zone_identifiers(include_alias: false) |> Enum.any?(& &1 == "America/Guadeloupe")
    refute TzExtra.time_zone_identifiers() |> Enum.any?(& &1 == "America/Guadeloupe")
  end
end
