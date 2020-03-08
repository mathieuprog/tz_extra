# TzExtra

`tz_extra` provides a few utilities to work with time zones.

### `TzExtra.time_zones_by_country/0`

Returns a list of time zone data by country. The data includes:
* the country and time zone;
* the current UTC and DST offsets observed;
* the links (other city names) linking to the time zone;
* the zone abbreviation;
* the coordinates.

#### Example

```
iex> TzExtra.time_zones_by_country() |> Enum.at(5)
```

```
%{
  coordinates: "+0627+00324",
  country: %{code: "AO", name: "Angola"},
  dst_offset: 3600,
  dst_zone_abbr: "WAT",
  links: [
    "Bangui", "Brazzaville", "Douala",
    "Kinshasa", "Libreville", "Luanda",
    "Malabo", "Niamey", "Porto-Novo"
  ],
  pretty_dst_offset: "+01:00",
  pretty_utc_offset: "+01:00",
  time_zone: "Africa/Lagos",
  utc_offset: 3600,
  zone_abbr: "WAT"
}
```

Note that a time zone may be observed by multiple countries. For example, the tz database version `2019c` lists 10
countries observing the time zone `Africa/Lagos`; this will result in 10 map entries for that time zone.

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

## Installation

Add `tz_extra` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:tz_extra, "~> 0.2.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/tz_extra](https://hexdocs.pm/tz_extra).
