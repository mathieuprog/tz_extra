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

    country_time_zone = TzExtra.country_time_zone!("MA", "Africa/Casablanca")

    assert country_time_zone.utc_to_std_offset == 0
    assert country_time_zone.utc_to_dst_offset == 3600

    country_time_zone = TzExtra.country_time_zone!("IE", "Europe/Dublin")

    assert country_time_zone.utc_to_std_offset == 0
    assert country_time_zone.utc_to_dst_offset == 3600
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
    assert "Asia/Bangkok" == TzExtra.canonical_time_zone_id!("Asia/Phnom_Penh")
    assert "Asia/Bangkok" == TzExtra.canonical_time_zone_id!("Asia/Bangkok")

    assert_raise RuntimeError, "time zone identifier \"foo\" not found", fn ->
      TzExtra.canonical_time_zone_id!("foo")
    end
  end

  test "iana_version/0" do
    assert TzExtra.iana_version() == Tz.iana_version()
  end

  test "shifts_clock?/1" do
    assert TzExtra.shifts_clock?("Europe/Brussels")
    assert TzExtra.shifts_clock?("Africa/Casablanca")

    refute TzExtra.shifts_clock?("Asia/Manila")
    refute TzExtra.shifts_clock?("Asia/Tokyo")
  end

  test "next_clock_shift_in_year_span/1 and clock_shift/2" do
    {:ambiguous, first_dt, second_dt} =
      DateTime.new(~D[2018-10-28], ~T[02:00:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    {:backward, dt} =
      TzExtra.next_clock_shift_in_year_span(DateTime.add(first_dt, -1, :day, Tz.TimeZoneDatabase))

    assert DateTime.compare(dt, second_dt) == :eq

    assert TzExtra.clock_shift(first_dt, second_dt) == :backward
    assert TzExtra.clock_shift(first_dt, first_dt) == :no_shift

    {:gap, dt_just_before, dt_just_after} =
      DateTime.new(~D[2019-03-31], ~T[02:30:00], "Europe/Copenhagen", Tz.TimeZoneDatabase)

    {:forward, dt} =
      TzExtra.next_clock_shift_in_year_span(
        DateTime.add(dt_just_before, -1, :day, Tz.TimeZoneDatabase)
      )

    assert DateTime.compare(dt, dt_just_after) == :eq

    assert TzExtra.clock_shift(dt_just_before, dt_just_after) == :forward

    assert_raise RuntimeError, fn ->
      assert TzExtra.clock_shift(dt_just_after, dt_just_before) == :backward
    end

    {:ok, dt} = DateTime.new(~D[2018-10-28], ~T[02:00:00], "Asia/Manila", Tz.TimeZoneDatabase)

    assert :no_shift ==
             TzExtra.next_clock_shift_in_year_span(
               DateTime.add(dt, -1, :day, Tz.TimeZoneDatabase)
             )
  end

  test "time_zone_id_exists?/1" do
    assert TzExtra.time_zone_id_exists?("Europe/Brussels")
    assert TzExtra.time_zone_id_exists?("Europe/Amsterdam")
    refute TzExtra.time_zone_id_exists?("Asia/Amsterdam")
  end

  test "country_code_exists?/1" do
    assert TzExtra.country_code_exists?("BE")
    refute TzExtra.country_code_exists?("XX")
  end

  test "utc_offset_id/2" do
    {:ok, utc1} =
      DateTime.new(~D[2024-12-01], ~T[10:00:00], "Europe/Brussels", Tz.TimeZoneDatabase)

    assert TzExtra.utc_offset_id(utc1) == "UTC+01:00"
    assert TzExtra.utc_offset_id(utc1, :pretty) == "UTC+1"

    {:ok, utc2} =
      DateTime.new(~D[2024-08-01], ~T[10:00:00], "Europe/Brussels", Tz.TimeZoneDatabase)

    assert TzExtra.utc_offset_id(utc2) == "UTC+02:00"
    assert TzExtra.utc_offset_id(utc2, :pretty) == "UTC+2"
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
