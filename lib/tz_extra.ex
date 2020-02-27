defmodule TzExtra do
  require TzExtra.FileParser.CountryParser
  require TzExtra.FileParser.ZoneParser
  require TzExtra.FileParser.ZoneRuleParser
  import TzExtra.Helper

  alias TzExtra.FileParser.CountryParser
  alias TzExtra.FileParser.ZoneParser
  alias TzExtra.FileParser.ZoneRuleParser

  tz_data_dir = Path.join(:code.priv_dir(:tz), Tz.version())

  countries = CountryParser.parse(Path.join(tz_data_dir, "iso3166.tab"))
  time_zones_with_country = ZoneParser.parse(Path.join(tz_data_dir, "zone1970.tab"), countries)
  time_zones_with_country = [%{coordinates: nil, country: nil, name: "Etc/UTC", short_name: "UTC"} | time_zones_with_country]

  time_zones_with_country =
    Enum.map(time_zones_with_country, fn time_zone ->
      {:ok, periods} = Tz.periods(time_zone.name)

      utc_offset = find_latest_utc_offset_for_periods(periods)
      dst_offset = utc_offset + find_latest_std_offset_for_periods(periods)

      time_zone
      |> Map.put(:utc_offset, utc_offset)
      |> Map.put(:dst_offset, dst_offset)
      |> Map.put(:pretty_utc_offset, offset_to_string(utc_offset))
      |> Map.put(:pretty_dst_offset, offset_to_string(dst_offset))
      |> Map.put(:zone_abbr, find_zone_abbr_for_periods(periods))
      |> Map.put(:dst_zone_abbr, find_dst_zone_abbr_for_periods(periods))
    end)

  all_time_zones =
    for filename <- ~w(africa antarctica asia australasia backward etcetera europe northamerica southamerica)s do
      ZoneRuleParser.parse(Path.join(tz_data_dir, filename))
    end
    |> List.flatten()
    |> Enum.filter(fn
      %{record_type: :link, canonical_zone_name: "Etc/GMT"} ->
        false
      %{record_type: :link, canonical_zone_name: "Etc/UTC"} ->
        false
      %{name: name} ->
        !String.contains?(name, "GMT") && String.contains?(name, "/")
      _ ->
        true
    end)

  time_zones =
    Enum.map(all_time_zones, fn
      %{record_type: :link} = time_zone ->
        filtered_time_zones_with_country = Enum.filter(time_zones_with_country, & &1.name == time_zone.link_zone_name)

        if Enum.count(filtered_time_zones_with_country) == 0 do
          filtered_time_zones_with_country = Enum.filter(time_zones_with_country, & &1.name == time_zone.canonical_zone_name)

          if Enum.count(filtered_time_zones_with_country) == 0 do
            raise "missing time zone in zone1970.tab file: #{time_zone.canonical_zone_name}"
          end

          for filtered_time_zone_with_country <- filtered_time_zones_with_country do
            filtered_time_zone_with_country
            |> Map.put(:name, time_zone.link_zone_name)
            |> Map.put(:short_name, String.split(time_zone.link_zone_name, "/") |> List.last())
            |> Map.put(:link, time_zone.canonical_zone_name)
          end
        else
          filtered_time_zones_with_country
        end
      time_zone ->
        filtered_time_zones_with_country = Enum.filter(time_zones_with_country, & &1.name == time_zone.name)

        if Enum.count(filtered_time_zones_with_country) == 0 do
          raise "missing time zone in zone1970.tab file: #{time_zone.name}"
        end

        for filtered_time_zone_with_country <- filtered_time_zones_with_country do
          filtered_time_zone_with_country
          |> Map.put(:link, nil)
        end
    end)
    |> List.flatten()
    |> Enum.filter(& &1 != nil)
    |> Enum.sort_by(&{&1.country && &1.country.name, &1.utc_offset, &1.name})

  time_zones_without_links = Enum.filter(time_zones, & &1.link == nil)

  def time_zones(opts \\ [])

  def time_zones(with_links: false) do
    unquote(Macro.escape(time_zones_without_links))
  end

  def time_zones(_) do
    unquote(Macro.escape(time_zones))
  end

  def countries() do
    unquote(Macro.escape(countries))
  end
end
