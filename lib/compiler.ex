defmodule TzExtra.Compiler do
  @moduledoc false

  require TzExtra.IanaFileParser
  import TzExtra.Helper

  alias TzExtra.IanaFileParser

  def compile() do
    countries = IanaFileParser.countries()

    time_zones =
      IanaFileParser.time_zones_with_country(countries)
      |> add_links()
      |> List.insert_at(0, %{coordinates: nil, country: nil, time_zone: "UTC", links: []})
      |> add_offset_data()
      |> Enum.sort_by(&{&1.country && &1.country.name, &1.utc_offset, &1.time_zone})

    contents = [
      quote do
        def time_zones_by_country() do
          unquote(Macro.escape(time_zones))
        end

        def countries() do
          unquote(Macro.escape(countries))
        end
      end
    ]

    module = :"Elixir.TzExtra"
    Module.create(module, contents, Macro.Env.location(__ENV__))
    :code.purge(module)
  end

  defp add_offset_data(time_zones) do
    Enum.map(time_zones, fn time_zone ->
      {:ok, periods_by_year} = Tz.PeriodsProvider.periods_by_year(time_zone.time_zone)

      latest_periods = Enum.filter(periods_by_year.minmax, & &1.to == :max)

      utc_offset = hd(latest_periods).utc_offset
      dst_offset = utc_offset + Enum.max_by(latest_periods, & &1.std_offset).std_offset

      zone_abbr = Enum.min_by(latest_periods, & &1.std_offset).zone_abbr
      dst_zone_abbr = Enum.max_by(latest_periods, & &1.std_offset).zone_abbr

      time_zone
      |> Map.put(:utc_offset, utc_offset)
      |> Map.put(:dst_offset, dst_offset)
      |> Map.put(:pretty_utc_offset, offset_to_string(utc_offset))
      |> Map.put(:pretty_dst_offset, offset_to_string(dst_offset))
      |> Map.put(:zone_abbr, zone_abbr)
      |> Map.put(:dst_zone_abbr, dst_zone_abbr)
    end)
  end

  defp add_links(time_zones) do
    link_time_zones = IanaFileParser.link_time_zones()

    Enum.map(time_zones, fn time_zone ->
      links =
        link_time_zones
        |> Enum.filter(
             & &1.canonical_zone_name == time_zone.time_zone
             && !String.contains?(&1.link_zone_name, "GMT")
             && String.contains?(&1.link_zone_name, "/"))
        |> Enum.map(&List.last(String.split(&1.link_zone_name, "/")))

      Map.put(time_zone, :links, links)
    end)
  end
end
