# TzExtra

`tz_extra` provides a few utilities to work with time zones.

### `TzExtra.countries_time_zones/1`

Returns a list of time zone data by country. The data includes:
* the country and time zone;
* the current UTC and DST offsets observed;
* the links (other city names) linking to the time zone;
* the zone abbreviation;
* the coordinates.

#### Example

```
iex> TzExtra.countries_time_zones() |> Enum.at(5)
```

```
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

You may pass the `:with_utc` option set to `true`, in order to add the UTC time zone to the list; the following map is then added:

```
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

```
iex> TzExtra.time_zone_identifiers() |> Enum.take(5)
```

```
[
  "Africa/Abidjan",
  "Africa/Accra",
  "Africa/Algiers",
  "Africa/Bissau",
  "Africa/Cairo"
]
```

This function takes two options:

* `:exclude_non_civil` (by default `true`)  
  By default, only time zones attached to countries are returned. Set this option to `false` to include time zones that aren't not tied to a particular country.

* `:exclude_alias` (by default `true`)  
  By default, only canonical time zones are returned. Set this option to `false` to include time zone aliases (also called links).

### `TzExtra.countries/0`

```
iex> TzExtra.countries() |> Enum.take(5)
```

```
[
  %{code: "AF", name: "Afghanistan"},
  %{code: "AL", name: "Albania"},
  %{code: "DZ", name: "Algeria"},
  %{code: "AD", name: "Andorra"},
  %{code: "AO", name: "Angola"}
]
```

### Automatic time zone data updates

`tz_extra` can watch for IANA time zone database updates and automatically recompile the time zone data.

To enable automatic updates, add `TzExtra.UpdatePeriodically` as a child in your supervisor:

```
{TzExtra.UpdatePeriodically, []}
```

`TzExtra.UpdatePeriodically` also triggers `tz`'s time zone recompilation; so you don't need to add
`Tz.UpdatePeriodically` if you added `TzExtra.UpdatePeriodically` in your supervisor.

Lastly, add the http client `mint` and ssl certificate store `castore` into your `mix.exs` file:

```
defp deps do
  [
    {:castore, "~> 0.1.10"},
    {:mint, "~> 1.2"},
    {:tz_extra, "~> 0.15.0"}
  ]
end
```

### Dump JSON data for JavaScript

Dump time zone data into JSON files for JavaScript clients. The JSON files are written into `tz_extra`'s `priv` folder.

```
iex> TzExtra.JsonDumper.dump_countries_time_zones()
```

```
iex> TzExtra.JsonDumper.dump_countries()
```

## Installation

Add `tz_extra` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:tz_extra, "~> 0.15.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/tz_extra](https://hexdocs.pm/tz_extra).
