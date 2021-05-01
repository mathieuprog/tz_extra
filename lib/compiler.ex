defmodule TzExtra.Compiler do
  @moduledoc false

  require TzExtra.IanaFileParser
  import TzExtra.Helper

  alias TzExtra.IanaFileParser

  def compile() do
    countries = IanaFileParser.countries()
    time_zones = IanaFileParser.time_zones()

    get_time_zone_links_for_canonical_fun = fn canonical -> time_zones[canonical] end

    countries_time_zones =
      IanaFileParser.time_zones_with_country(countries)
      |> add_time_zone_links(get_time_zone_links_for_canonical_fun)
      |> List.insert_at(0, %{coordinates: nil, country: nil, time_zone: "UTC", time_zone_links: []})
      |> add_offset_data()
      |> Enum.sort_by(&{&1.country && normalize_string(&1.country.name), &1.utc_offset, &1.time_zone})

    countries_time_zones_without_utc =  Enum.filter(countries_time_zones, & &1.time_zone != "UTC")

    canonical_time_zones =
      time_zones
      |> Map.keys()
      |> Enum.uniq()
      |> Enum.sort()

    all_time_zones =
      time_zones
      |> Enum.map(fn {canonical, links} -> [canonical | links] end)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    civil_time_zones =
      countries_time_zones_without_utc
      |> Enum.map(&(&1.time_zone))
      |> Enum.uniq()
      |> Enum.sort()

    civil_time_zones_with_links =
      countries_time_zones_without_utc
      |> Enum.map(&([&1.time_zone | &1.time_zone_links]))
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    contents = [
      quote do
        def version() do
          unquote(Tz.version())
        end

        def time_zone_identifiers(opts \\ []) do
          exclude_non_civil = Keyword.get(opts, :exclude_non_civil, true)
          exclude_alias = Keyword.get(opts, :exclude_alias, true)

          cond do
            exclude_non_civil ->
              cond do
                exclude_alias ->
                  unquote(Macro.escape(civil_time_zones))

                true ->
                  unquote(Macro.escape(civil_time_zones_with_links))
              end

            true ->
              cond do
                exclude_alias ->
                  unquote(Macro.escape(canonical_time_zones))

                true ->
                  unquote(Macro.escape(all_time_zones))
              end
          end
        end

        def countries_time_zones(with_utc: true) do
          unquote(Macro.escape(countries_time_zones))
        end

        def countries_time_zones([]) do
          unquote(Macro.escape(countries_time_zones_without_utc))
        end

        def countries_time_zones() do
          unquote(Macro.escape(countries_time_zones_without_utc))
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
      {:ok, periods} = Tz.PeriodsProvider.periods(time_zone.time_zone)

      {utc_offset, dst_offset, zone_abbr, dst_zone_abbr} =
        case hd(periods) do
          {_, {utc_offset, std_offset, zone_abbr}, _, nil} ->
            {utc_offset, utc_offset + std_offset, zone_abbr, zone_abbr}

          {_, {utc_offset, std_offset, zone_abbr}, {_, prev_std_offset, prev_zone_abbr}, _} ->
            dst_offset = utc_offset + max(std_offset, prev_std_offset)

            {zone_abbr, dst_zone_abbr} =
              cond do
                std_offset < prev_std_offset ->
                  {zone_abbr, prev_zone_abbr}

                std_offset > prev_std_offset ->
                  {prev_zone_abbr, zone_abbr}
              end

            {utc_offset, dst_offset, zone_abbr, dst_zone_abbr}
        end

      time_zone
      |> Map.put(:utc_offset, utc_offset)
      |> Map.put(:dst_offset, dst_offset)
      |> Map.put(:pretty_utc_offset, offset_to_string(utc_offset))
      |> Map.put(:pretty_dst_offset, offset_to_string(dst_offset))
      |> Map.put(:zone_abbr, zone_abbr)
      |> Map.put(:dst_zone_abbr, dst_zone_abbr)
    end)
  end

  defp add_time_zone_links(countries_time_zones, get_time_zone_links_for_canonical_fun) do
    Enum.map(countries_time_zones, fn %{time_zone: time_zone_name} = time_zone ->
      Map.put(time_zone, :time_zone_links, get_time_zone_links_for_canonical_fun.(time_zone_name))
    end)
  end
end
