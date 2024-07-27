defmodule TzExtraTest do
  use ExUnit.Case
  doctest TzExtra

  test "countries/0" do
    assert is_list(TzExtra.countries())
  end

  test "countries_time_zones/1" do
    assert is_list(TzExtra.countries_time_zones())

    assert 2 ==
             TzExtra.countries_time_zones()
             |> Enum.filter(&(&1.time_zone_id == "Europe/Simferopol"))
             |> Enum.count()

    refute TzExtra.countries_time_zones() |> Enum.any?(&(&1.time_zone_id == "Etc/UTC"))
  end

  test "time_zone_ids/1" do
    assert is_list(TzExtra.time_zone_ids())

    refute TzExtra.civil_time_zone_ids() |> Enum.any?(&(&1 == "Etc/UTC"))

    assert TzExtra.civil_time_zone_ids(include_aliases: true)
           |> Enum.any?(&(&1 == "America/Guadeloupe"))

    refute TzExtra.civil_time_zone_ids(include_aliases: false)
           |> Enum.any?(&(&1 == "America/Guadeloupe"))

    refute TzExtra.civil_time_zone_ids() |> Enum.any?(&(&1 == "America/Guadeloupe"))

    assert TzExtra.time_zone_ids(include_aliases: true)
           |> Enum.any?(&(&1 == "America/Guadeloupe"))

    refute TzExtra.time_zone_ids(include_aliases: false)
           |> Enum.any?(&(&1 == "America/Guadeloupe"))

    refute TzExtra.time_zone_ids() |> Enum.any?(&(&1 == "America/Guadeloupe"))
  end

  test "canonical_time_zone_id/1" do
    assert "Asia/Bangkok" == TzExtra.canonical_time_zone_id("Asia/Phnom_Penh")
    assert "Asia/Bangkok" == TzExtra.canonical_time_zone_id("Asia/Bangkok")

    assert_raise RuntimeError, "time zone identifier \"foo\" not found", fn ->
      TzExtra.canonical_time_zone_id("foo")
    end
  end

  test "iana_version/0" do
    assert TzExtra.iana_version() == Tz.iana_version()
  end

  test "time_zone_id_exists?/1" do
    assert TzExtra.time_zone_id_exists?("Europe/Brussels")
    assert TzExtra.time_zone_id_exists?("Europe/Amsterdam")
    refute TzExtra.time_zone_id_exists?("Asia/Amsterdam")
  end

  test "earliest_datetime/2 and latest_datetime/2" do
    {:ambiguous, first_dt, second_dt} =
      DateTime.new(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    earliest_datetime =
      TzExtra.earliest_datetime!(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen")

    latest_datetime = TzExtra.latest_datetime!(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen")
    assert DateTime.compare(earliest_datetime, first_dt) == :eq
    assert DateTime.compare(latest_datetime, second_dt) == :eq

    {:gap, just_before, just_after} =
      DateTime.new(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    earliest_datetime =
      TzExtra.earliest_datetime!(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen")

    latest_datetime = TzExtra.latest_datetime!(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen")
    assert DateTime.compare(earliest_datetime, just_before) == :eq
    assert DateTime.compare(latest_datetime, just_after) == :eq
  end
end
