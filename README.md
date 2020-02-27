# TzExtra

`tz_extra` provides a few utilities to work with time zones.

### `TzExtra.time_zones/0`

Returns a list of time zones with useful data such as
* the coordinates of the location
* the country where the time zone is observed
* the UTC and DST offsets

#### Example

```
iex> TzExtra.time_zones() |> Enum.at(200)
```

```
%{
  coordinates: "+513030-0000731",
  country: %{code: "JE", name: "Jersey"},
  dst_offset: 3600,
  name: "Europe/London",
  pretty_dst_offset: "+01:00",
  pretty_utc_offset: "+00:00",
  utc_offset: 0
}
```

If a time zone is observed in multiple countries, the time zone data will be repeated for each country. For example,
Crimea has been a subject of a territorial dispute between Ukraine and Russia:

```
iex> TzExtra.time_zones() |> Enum.filter(& &1.name == "Europe/Simferopol")
```

```
[
  %{
    coordinates: "+4457+03406",
    country: %{code: "RU", name: "Russia"},
    dst_offset: 10800,
    name: "Europe/Simferopol",
    pretty_dst_offset: "+03:00",
    pretty_utc_offset: "+03:00",
    utc_offset: 10800
  },
  %{
    coordinates: "+4457+03406",
    country: %{code: "UA", name: "Ukraine"},
    dst_offset: 10800,
    name: "Europe/Simferopol",
    pretty_dst_offset: "+03:00",
    pretty_utc_offset: "+03:00",
    utc_offset: 10800
  }
]
```

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
    {:tz_extra, "~> 0.1.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/tz_extra](https://hexdocs.pm/tz_extra).
