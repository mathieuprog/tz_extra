defmodule TzExtra.ChangesetTest do
  use ExUnit.Case

  import Ecto.Changeset
  import TzExtra.Changeset

  test "valid canonical time zone" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "Etc/UTC"}, [:time_zone])
      |> validate_time_zone_identifier(:time_zone)

    assert changeset.valid?
    assert validations(changeset) == [time_zone: :time_zone_identifier]
    assert changeset.errors == []
  end

  test "valid alias time zone" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "America/Guadeloupe"}, [:time_zone])
      |> validate_time_zone_identifier(:time_zone, allow_alias: true)

    assert changeset.valid?
    assert validations(changeset) == [time_zone: :time_zone_identifier]
    assert changeset.errors == []
  end

  test "invalid canonical time zone" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "America/Guadeloupe"}, [:time_zone])
      |> validate_time_zone_identifier(:time_zone)

    refute changeset.valid?
    assert validations(changeset) == [time_zone: :time_zone_identifier]

    assert changeset.errors == [
             time_zone: {"is not a valid time zone", [validation: :time_zone_identifier]}
           ]
  end

  test "invalid time zone with custom message" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "Europe/Foo"}, [:time_zone])
      |> validate_time_zone_identifier(:time_zone, message: "foo")

    refute changeset.valid?
    assert validations(changeset) == [time_zone: :time_zone_identifier]
    assert changeset.errors == [time_zone: {"foo", [validation: :time_zone_identifier]}]
  end

  test "valid civil time zone" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "Europe/London"}, [:time_zone])
      |> validate_civil_time_zone_identifier(:time_zone)

    assert changeset.valid?
    assert validations(changeset) == [time_zone: :civil_time_zone_identifier]
    assert changeset.errors == []
  end

  test "invalid civil time zone" do
    data = %{time_zone: ""}
    types = %{time_zone: :string}

    changeset =
      cast({data, types}, %{time_zone: "Etc/UTC"}, [:time_zone])
      |> validate_civil_time_zone_identifier(:time_zone)

    refute changeset.valid?
    assert validations(changeset) == [time_zone: :civil_time_zone_identifier]

    assert changeset.errors == [
             time_zone: {"is not a valid time zone", [validation: :civil_time_zone_identifier]}
           ]
  end

  test "valid iso country code" do
    data = %{country_code: ""}
    types = %{country_code: :string}

    changeset =
      cast({data, types}, %{country_code: "BE"}, [:country_code])
      |> validate_iso_country_code(:country_code)

    assert changeset.valid?
    assert validations(changeset) == [country_code: :iso_country_code]
  end

  test "invalid iso country code" do
    data = %{country_code: ""}
    types = %{country_code: :string}

    changeset =
      cast({data, types}, %{country_code: "BEL"}, [:country_code])
      |> validate_iso_country_code(:country_code)

    refute changeset.valid?
    assert validations(changeset) == [country_code: :iso_country_code]

    assert changeset.errors == [
             country_code: {"is not a valid country code", [validation: :iso_country_code]}
           ]
  end
end
