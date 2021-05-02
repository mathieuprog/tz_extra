# TzExtra

`tz_extra` provides a few utilities to work with time zones:

* [`TzExtra.countries_time_zones/1`](#`TzExtra.countries_time_zones/1`): returns a list of time zone data by country
* [`TzExtra.time_zone_identifiers/1`](#`TzExtra.time_zone_identifiers/1`): returns a list of time zone identifiers
* [`TzExtra.civil_time_zone_identifiers/1`](#`TzExtra.civil_time_zone_identifiers/1`): returns a list of time zone identifiers that are tied to a country
* [`TzExtra.countries/0`](#`TzExtra.countries/0`): returns a list of ISO country codes with their English name
* [`TzExtra.Changeset.validate_time_zone/3`](#`TzExtra.Changeset.validate_time_zone/3`): an Ecto Changeset validator, validating that the user input is a valid time zone
* [`TzExtra.Changeset.validate_civil_time_zone/3`](#`TzExtra.Changeset.validate_civil_time_zone/3`): an Ecto Changeset validator, validating that the user input is a valid civil time zone
* [`TzExtra.Changeset.validate_iso_country_code/3`](#`TzExtra.Changeset.validate_iso_country_code/3`): an Ecto Changeset validator, validating that the user input is a valid ISO country code

### `TzExtra.countries_time_zones/1`

Returns a list of time zone data by country. The data includes:
* the country and time zone;
* the current UTC and DST offsets observed;
* the links (other city names) linking to the time zone;
* the zone abbreviation;
* the coordinates.

#### Example

```elixir
iex> TzExtra.countries_time_zones() |> Enum.at(5)
```

```elixir
%{
  coordinates: "+0627+00324",
  country: %{code: "AO", name: "Angola"},
  dst_offset: 3600,
  dst_zone_abbr: "WAT",
  pretty_dst_offset: "+01:00",
  pretty_utc_offset: "+01:00",
  time_zone: "Africa/Lagos",
  time_zone_links: [
    "Africa/Bangui", "Africa/Brazzaville", "Africa/Douala",
    "Africa/Kinshasa", "Africa/Libreville", "Africa/Luanda",
    "Africa/Malabo", "Africa/Niamey", "Africa/Porto-Novo"
  ],
  utc_offset: 3600,
  zone_abbr: "WAT"
}
```

Note that a time zone may be observed by multiple countries. For example, the tz database version `2019c` lists 10
countries observing the time zone `Africa/Lagos`; this will result in 10 map entries for that time zone.

You may pass the `:prepend_utc` option set to `true`, in order to add the UTC time zone to the list; the following map is then added:

```elixir
%{
  coordinates: nil,
  country: nil,
  dst_offset: 0,
  dst_zone_abbr: "UTC",
  pretty_dst_offset: "+00:00",
  pretty_utc_offset: "+00:00",
  time_zone: "UTC",
  time_zone_links: [],
  utc_offset: 0,
  zone_abbr: "UTC"
}
```

### `TzExtra.time_zone_identifiers/1`

```elixir
iex> TzExtra.time_zone_identifiers() |> Enum.take(5)
```

```elixir
[
  "Africa/Abidjan", 
  "Africa/Accra", 
  "Africa/Algiers", 
  "Africa/Bissau",
  "Africa/Cairo"
]
```

This function can take an option `:include_alias` (by default set to `false`). By default, only canonical time zones are returned. Set this option to `true` to include time zone aliases (also called links).

### `TzExtra.civil_time_zone_identifiers/1`

```elixir
iex> TzExtra.civil_time_zone_identifiers()
```

This function returns only the time zone identifiers attached to a country. It takes two options:
* `:include_alias` (by default set to `false`)
  By default, only canonical time zones are returned. Set this option to `false` to include time zone aliases (also called links).
* `:prepend_utc` (by default set to `false`)
  Add the UTC time zone as the first element of the time zone list.

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

### `TzExtra.Changeset.validate_time_zone/3`

```elixir
import TzExtra.Changeset

changeset
|> validate_time_zone(:time_zone)
```

You may pass the option `:include_alias` as described above, as well as the `:message` option to customize the error message.

### `TzExtra.Changeset.validate_civil_time_zone/3`

```elixir
import TzExtra.Changeset

changeset
|> validate_civil_time_zone(:time_zone)
```

You may pass the options `:include_alias` and `:prepend_utc` as described above, as well as the `:message` option to customize the error message.

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

`TzExtra.UpdatePeriodically` also triggers `tz`'s time zone recompilation; so you don't need to add
`Tz.UpdatePeriodically` if you added `TzExtra.UpdatePeriodically` in your supervisor.

Lastly, add the http client `mint` and ssl certificate store `castore` into your `mix.exs` file:

```elixir
defp deps do
  [
    {:castore, "~> 0.1.10"},
    {:mint, "~> 1.2"},
    {:tz_extra, "~> 0.16.0"}
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
    {:tz_extra, "~> 0.16.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/tz_extra](https://hexdocs.pm/tz_extra).
