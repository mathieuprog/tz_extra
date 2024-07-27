# TzExtra

`tz_extra` provides a few utilities to work with time zones. It uses [`Tz`](https://github.com/mathieuprog/tz) under the hood, which brings time zone support for Elixir.

* [`TzExtra.countries_time_zones/0`](#tzextracountries_time_zones0): returns a list of time zone data by country
* [`TzExtra.CountryTimeZone.for_country_code/1`](#tzextracountrytimezonefor_country_code1): returns a list of time zone data for a given country
* [`TzExtra.CountryTimeZone.for_time_zone/1`](#tzextracountrytimezonefor_time_zone1): returns a list of time zone data for a time zone
* [`TzExtra.time_zone_ids/1`](#tzextratime_zone_ids1): returns a list of time zone identifiers
* [`TzExtra.civil_time_zone_ids/1`](#tzextracivil_time_zone_ids1): returns a list of time zone identifiers that are tied to a country
* [`TzExtra.countries/0`](#tzextracountries0): returns a list of ISO country codes with their English name
* [`TzExtra.get_canonical_time_zone_id/1`](#tzextraget_canonical_time_zone_id1): returns the canonical time zone identifier for the given time zone identifier
* [`TzExtra.Changeset.validate_time_zone_id/3`](#tzextraChangesetvalidate_time_zone_id3): an Ecto Changeset validator, validating that the user input is a valid time zone
* [`TzExtra.Changeset.validate_civil_time_zone_id/3`](#tzextraChangesetvalidate_civil_time_zone_id3): an Ecto Changeset validator, validating that the user input is a valid civil time zone
* [`TzExtra.Changeset.validate_iso_country_code/3`](#tzextraChangesetvalidate_iso_country_code3): an Ecto Changeset validator, validating that the user input is a valid ISO country code

### `TzExtra.countries_time_zones/0`

Returns a list of time zone data by country.

#### Example

```elixir
iex> TzExtra.countries_time_zones() |> Enum.find(& &1.country.code == "BE")
```

```elixir
%{
  time_zone_id: "Europe/Brussels",
  time_zone_alias_ids: ["Europe/Amsterdam", "Europe/Luxembourg"],

  country: %{code: "BE", name: "Belgium", local_names: ["België", "Belgique"]},
  coordinates: "+5050+00420",

  zone_abbr: "CET",
  dst_zone_abbr: "CEST",

  utc_to_std_offset: 3600,
  utc_to_dst_offset: 7200,
  utc_to_std_offset_id: "UTC+01:00",
  utc_to_dst_offset_id: "UTC+02:00",
  pretty_utc_to_std_offset_id: "UTC+1",
  pretty_utc_to_dst_offset_id: "UTC+2"
}
```

Note that a time zone may be observed by multiple countries. For example, the tz database version `2024a` lists 10
countries observing the time zone `"Africa/Lagos"`; this will result in 10 map entries for that time zone.

### `TzExtra.CountryTimeZone.for_country_code/1`

Returns a list of time zone data for the given country code (string or atom).

### `TzExtra.CountryTimeZone.for_time_zone/1`

Returns a list of time zone data for the given time zone.

You may also call `TzExtra.country_time_zone/1` which takes a country code or a time zone as argument.

### `TzExtra.time_zone_ids/1`

```elixir
iex> TzExtra.time_zone_ids() |> Enum.take(5)
```

```elixir
[
  "Africa/Abidjan",
  "Africa/Algiers",
  "Africa/Bissau",
  "Africa/Cairo",
  "Africa/Casablanca"
]
```

This function can take an option `:include_aliases` (by default set to `false`) to include time zone aliases. By default, only canonical time zones are returned. Set this option to `true` to include time zone aliases.

### `TzExtra.civil_time_zone_ids/1`

```elixir
iex> TzExtra.civil_time_zone_ids()
```

This function returns only the time zone identifiers attached to a country. It takes two options:
* `:include_aliases` (by default set to `false`)
  By default, only canonical time zones are returned. Set this option to `false` to include time zone aliases.

### `TzExtra.countries/0`

```elixir
iex> TzExtra.countries() |> Enum.take(5)
```

```elixir
[
  %{code: "AF", name: "Afghanistan"},
  %{code: "AL", name: "Albania"},
  %{code: "DZ", name: "Algeria"},
  %{code: "AD", name: "Andorra"},
  %{code: "AO", name: "Angola"}
]
```

### `TzExtra.get_canonical_time_zone_id/1`

Returns the canonical time zone identifier for the given time zone identifier.

If you pass a canonical time zone identifier, the same identifier will be returned.

```elixir
iex> TzExtra.get_canonical_time_zone_id("Asia/Phnom_Penh")
```

```elixir
"Asia/Bangkok"
```

```elixir
iex> TzExtra.get_canonical_time_zone_id("Asia/Bangkok")
```

```elixir
"Asia/Bangkok"
```

### `TzExtra.Changeset.validate_time_zone_id/3`

```elixir
import TzExtra.Changeset

changeset
|> validate_time_zone_id(:time_zone_id)
```

You may pass the option `:allow_alias` to allow time zone aliases, as well as the `:message` option to customize the error message.

### `TzExtra.Changeset.validate_civil_time_zone_id/3`

```elixir
import TzExtra.Changeset

changeset
|> validate_civil_time_zone_id(:time_zone_id)
```

You may pass the option `:allow_alias` to allow time zone aliases, as well as the `:message` option to customize the error message.

### `TzExtra.Changeset.validate_iso_country_code/3`

```elixir
import TzExtra.Changeset

changeset
|> validate_iso_country_code(:country_code)
```

You may pass the `:message` option to customize the error message.

### Automatic time zone data updates

`tz_extra` can watch for IANA time zone database updates and automatically recompile the time zone data.

To enable automatic updates, add `TzExtra.UpdatePeriodically` as a child in your supervisor:

```elixir
{TzExtra.UpdatePeriodically, []}
```

You may pass the option `:interval_in_days` in order to configure the frequency of the task.

```elixir
{TzExtra.UpdatePeriodically, [interval_in_days: 5]}
```

`TzExtra.UpdatePeriodically` also triggers `tz`'s time zone recompilation; so you don't need to add
`Tz.UpdatePeriodically` if you added `TzExtra.UpdatePeriodically` in your supervisor.

Lastly, if you did not configure a custom http client for `tz`, add the default http client `mint` and ssl certificate store `castore` into your `mix.exs` file:

```elixir
defp deps do
  [
    {:castore, "~> 1.0"},
    {:mint, "~> 1.6"},
    {:tz_extra, "~> 0.30.0"}
  ]
end
```

### Dump JSON data for JavaScript

Dump time zone data into JSON files for JavaScript clients. The JSON files are written into `tz_extra`'s `priv` folder.

```elixir
iex> TzExtra.JsonDumper.dump_countries_time_zones()
```

```elixir
iex> TzExtra.JsonDumper.dump_countries()
```

## Installation

Add `tz_extra` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:tz_extra, "~> 0.30.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/tz_extra](https://hexdocs.pm/tz_extra).
