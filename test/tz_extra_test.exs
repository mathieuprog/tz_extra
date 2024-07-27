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

  test "utc_datetime_range/3" do
    range =
      TzExtra.utc_datetime_range(~U[2024-07-27 13:00:00Z], ~U[2024-07-27 17:00:00Z], 30 * 60)

    assert length(range) == 9
  end

  test "round_datetime/3" do
    rounded_datetime = TzExtra.round_datetime(~U[2024-07-27 13:23:00Z], 30 * 60, :floor)
    assert DateTime.compare(rounded_datetime, ~U[2024-07-27 13:00:00Z]) == :eq

    rounded_datetime = TzExtra.round_datetime(~U[2024-07-27 13:23:00Z], 30 * 60, :ceil)
    assert DateTime.compare(rounded_datetime, ~U[2024-07-27 13:30:00Z]) == :eq
  end

  test "new_resolved_datetime!/4" do
    {:ambiguous, first_dt, second_dt} =
      DateTime.new(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    dt =
      TzExtra.new_resolved_datetime!(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen",
        ambiguous: :first,
        gap: :just_before
      )

    assert DateTime.compare(dt, first_dt) == :eq

    dt =
      TzExtra.new_resolved_datetime!(~D[2018-10-28], ~T[02:30:00], "Europe/Copenhagen",
        ambiguous: :second,
        gap: :just_before
      )

    assert DateTime.compare(dt, second_dt) == :eq

    {:gap, just_before, just_after} =
      DateTime.new(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    dt =
      TzExtra.new_resolved_datetime!(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen",
        ambiguous: :first,
        gap: :just_before
      )

    assert DateTime.compare(dt, just_before) == :eq

    dt =
      TzExtra.new_resolved_datetime!(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen",
        ambiguous: :first,
        gap: :just_after
      )

    assert DateTime.compare(dt, just_after) == :eq
  end
end
