defmodule TzExtra.IanaFileParser do
  @moduledoc false

  import TzExtra.Helper

  def countries() do
    Path.join([Tz.IanaDataDir.dir(), "tzdata#{Tz.iana_version()}", "iso3166.tab"])
    |> file_to_list()
    |> parse_countries()
    |> Enum.sort_by(&normalize_string(&1.name))
  end

  def time_zones_with_country(countries) do
    Path.join([Tz.IanaDataDir.dir(), "tzdata#{Tz.iana_version()}", "zone1970.tab"])
    |> file_to_list()
    |> parse_time_zones_with_country()
    |> Enum.map(fn map ->
      {country_code, map} = pop_in(map, [:country_code])
      country = Enum.find(countries, &(&1.code == country_code))
      Map.put(map, :country, country)
    end)
  end

  def time_zones() do
    for filename <-
          ~w(africa antarctica asia australasia backward etcetera europe northamerica southamerica)s do
      Path.join([Tz.IanaDataDir.dir(), "tzdata#{Tz.iana_version()}", filename])
      |> file_to_list()
      |> parse_time_zones()
    end
    |> List.flatten()
    |> merge_canonical_link_time_zones()
  end

  defp file_to_list(file_path) do
    File.stream!(file_path)
    |> strip_comments()
    |> strip_empty()
    |> trim()
    |> Enum.to_list()
  end

  defp strip_comments(stream) do
    stream
    |> Stream.filter(&(!Regex.match?(~r/^[\s]*#/, &1)))
    |> Stream.map(&Regex.replace(~r/[\s]*#.+/, &1, ""))
  end

  defp strip_empty(stream) do
    Stream.filter(stream, &(!Regex.match?(~r/^[\s]*\n$/, &1)))
  end

  defp trim(stream) do
    Stream.map(stream, &String.trim(&1))
  end

  defp parse_countries([]), do: []

  defp parse_countries([string | tail]) do
    map =
      Enum.zip([
        [:code, :name],
        String.split(string, ~r{\s}, trim: true, parts: 2)
        |> Enum.map(&String.trim(&1))
      ])
      |> Enum.into(%{})

    [map | parse_countries(tail)]
  end

  defp merge_canonical_link_time_zones(time_zones) do
    Enum.reduce(time_zones, %{}, fn
      %{canonical_zone_name: canonical_zone_name, link_zone_name: link_zone_name}, map ->
        link_zone_names = Map.get(map, canonical_zone_name, [])
        Map.put(map, canonical_zone_name, [link_zone_name | link_zone_names])

      %{canonical_zone_name: canonical_zone_name}, map ->
        Map.put_new(map, canonical_zone_name, [])
    end)
  end

  defp parse_time_zones([]), do: []

  defp parse_time_zones([string | tail]) do
    cond do
      String.starts_with?(string, "Link") ->
        [parse_link_string_into_map(string) | parse_time_zones(tail)]

      String.starts_with?(string, "Zone") ->
        [parse_zone_string_into_map(string) | parse_time_zones(tail)]

      true ->
        parse_time_zones(tail)
    end
  end

  defp parse_link_string_into_map(link_string) do
    Enum.zip([
      [:canonical_zone_name, :link_zone_name],
      tl(String.split(link_string, ~r{\s}, trim: true, parts: 3))
      |> Enum.map(&String.trim(&1))
    ])
    |> Enum.into(%{})
  end

  defp parse_zone_string_into_map(zone_string) do
    Enum.zip([
      [:canonical_zone_name],
      tl(String.split(zone_string, ~r{\s}, trim: true, parts: 6))
      |> Enum.map(&String.trim(&1))
    ])
    |> Enum.into(%{})
  end

  defp parse_time_zones_with_country([]), do: []

  defp parse_time_zones_with_country([string | tail]) do
    map =
      Enum.zip([
        [:country_codes, :coordinates, :time_zone, :_],
        String.split(string, ~r{\s}, trim: true, parts: 4)
        |> Enum.map(&String.trim(&1))
      ])
      |> Enum.into(%{})
      |> Map.delete(:_)

    country_codes = String.split(map.country_codes, ",", trim: true)

    for country_code <- country_codes do
      %{
        country_code: country_code,
        coordinates: map.coordinates,
        time_zone: map.time_zone
      }
    end ++
      parse_time_zones_with_country(tail)
  end
end
