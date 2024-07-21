defmodule TzExtra.Compiler do
  @moduledoc false

  require TzExtra.IanaFileParser
  import TzExtra.Helper

  alias TzExtra.IanaFileParser

  def compile() do
    countries = IanaFileParser.countries()
    time_zones = IanaFileParser.time_zones()

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

    link_canonical_map =
      time_zones
      |> Enum.reduce(%{}, fn {canonical, links}, map ->
        Enum.reduce(links, map, fn link, map ->
          Map.put(map, link, canonical)
        end)
        |> Map.put(canonical, canonical)
      end)

    get_time_zone_links_for_canonical_fun =
      fn canonical ->
        time_zones[canonical]
      end

    countries_time_zones =
      IanaFileParser.time_zones_with_country(countries)
      |> add_time_zone_links(get_time_zone_links_for_canonical_fun)
      |> add_offset_data()
      |> Enum.sort_by(
        &{&1.country && normalize_string(&1.country.name), &1.utc_offset, &1.time_zone}
      )

    civil_time_zones =
      countries_time_zones
      |> Enum.map(& &1.time_zone)
      |> Enum.uniq()
      |> Enum.sort()

    civil_time_zones_with_links =
      countries_time_zones
      |> Enum.map(&[&1.time_zone | &1.time_zone_links])
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    quoted = [
      for time_zone <- all_time_zones do
        canonical_time_zone = link_canonical_map[time_zone]

        countries_time_zones =
          Enum.filter(countries_time_zones, &(&1.time_zone == canonical_time_zone))

        if length(countries_time_zones) > 0 do
          quote do
            def for_time_zone(unquote(time_zone)) do
              {:ok, unquote(Macro.escape(countries_time_zones))}
            end
          end
        else
          quote do
            def for_time_zone(unquote(time_zone)) do
              {:error, :time_zone_not_linked_to_country}
            end
          end
        end
      end,
      quote do
        def for_time_zone(_) do
          {:error, :time_zone_not_found}
        end
      end,
      for %{code: country_code} <- countries do
        countries_time_zones =
          Enum.filter(countries_time_zones, &(&1.country.code == country_code))

        country_code_atom = String.to_atom(country_code)

        quote do
          def for_country_code(unquote(country_code)) do
            {:ok, unquote(Macro.escape(countries_time_zones))}
          end

          def for_country_code(unquote(country_code_atom)) do
            {:ok, unquote(Macro.escape(countries_time_zones))}
          end
        end
      end,
      quote do
        def for_country_code(_) do
          {:error, :country_not_found}
        end
      end
    ]

    module = :"Elixir.TzExtra.CountryTimeZone"
    Module.create(module, quoted, Macro.Env.location(__ENV__))
    :code.purge(module)

    contents = [
      quote do
        def iana_version() do
          unquote(Tz.iana_version())
        end

        def get_canonical_time_zone_identifier(time_zone_identifier) do
          unquote(Macro.escape(link_canonical_map))[time_zone_identifier] ||
            raise "time zone identifier \"#{time_zone_identifier}\" not found"
        end

        def civil_time_zone_identifiers(opts \\ []) do
          include_aliases = Keyword.get(opts, :include_aliases, false)

          if include_aliases do
            unquote(Macro.escape(civil_time_zones_with_links))
          else
            unquote(Macro.escape(civil_time_zones))
          end
        end

        def time_zone_identifiers(opts \\ []) do
          include_aliases = Keyword.get(opts, :include_aliases, false)

          if include_aliases do
            unquote(Macro.escape(all_time_zones))
          else
            unquote(Macro.escape(canonical_time_zones))
          end
        end

        def countries_time_zones() do
          unquote(Macro.escape(countries_time_zones))
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

  # defp add_offset_data(time_zones) do
  #   %{
  #     coordinates: nil,
  #     country: nil,
  #     dst_offset: 0,
  #     dst_zone_abbr: "UTC",
  #     pretty_dst_offset: "+00:00",
  #     pretty_utc_offset: "+00:00",
  #     time_zone: "UTC",
  #     time_zone_links: [],
  #     utc_offset: 0,
  #     zone_abbr: "UTC"
  #   }
  # end

  defp add_offset_data(time_zones) do
    Enum.map(time_zones, fn %{time_zone: time_zone_id} = time_zone ->
      {:ok, periods} = Tz.PeriodsProvider.periods(time_zone_id)

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
    Enum.map(countries_time_zones, fn %{time_zone: time_zone_id} = time_zone ->
      Map.put(
        time_zone,
        :time_zone_links,
        get_time_zone_links_for_canonical_fun.(time_zone_id)
      )
    end)
  end
end
