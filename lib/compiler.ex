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
        time_zones[canonical] |> Enum.sort()
      end

    countries_time_zones =
      IanaFileParser.time_zones_with_country(countries)
      |> add_time_zone_links(get_time_zone_links_for_canonical_fun)
      |> add_offset_data()
      |> add_id()
      |> localize_country_name()
      |> Enum.sort_by(
        &{&1.country && normalize_string(&1.country.name), &1.utc_to_std_offset, &1.time_zone_id}
      )

    civil_time_zones =
      countries_time_zones
      |> Enum.map(& &1.time_zone_id)
      |> Enum.uniq()
      |> Enum.sort()

    civil_time_zones_with_links =
      countries_time_zones
      |> Enum.map(&[&1.time_zone_id | &1.time_zone_alias_ids])
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.sort()

    quoted = [
      for canonical_time_zone <- canonical_time_zones do
        filtered_countries_time_zones =
          Enum.filter(countries_time_zones, &(&1.time_zone_id == canonical_time_zone))

        if length(filtered_countries_time_zones) > 0 do
          quote do
            def by_time_zone(unquote(canonical_time_zone)) do
              {:ok, unquote(Macro.escape(filtered_countries_time_zones))}
            end
          end
        else
          quote do
            def by_time_zone(unquote(canonical_time_zone)) do
              {:error, :time_zone_not_linked_to_country}
            end
          end
        end
      end,
      quote do
        def by_time_zone(link_time_zone) do
          if canonical_time_zone = unquote(Macro.escape(link_canonical_map))[link_time_zone] do
            countries_time_zones_for_link =
              Enum.filter(
                unquote(Macro.escape(countries_time_zones)),
                &(&1.time_zone_id == canonical_time_zone)
              )

            if countries_time_zones_for_link do
              {:ok, countries_time_zones_for_link}
            else
              {:error, :time_zone_not_linked_to_country}
            end
          else
            {:error, :time_zone_not_found}
          end
        end
      end,
      for %{code: country_code} <- countries do
        filtered_countries_time_zones =
          Enum.filter(countries_time_zones, &(&1.country.code == country_code))

        country_code_atom = String.to_atom(country_code)

        quote do
          def by_country_code(unquote(country_code)) do
            {:ok, unquote(Macro.escape(filtered_countries_time_zones))}
          end

          def by_country_code(unquote(country_code_atom)) do
            by_country_code(unquote(country_code))
          end
        end
      end,
      quote do
        def by_country_code(_) do
          {:error, :country_not_found}
        end
      end,
      for %{id: id} = country_time_zone <- countries_time_zones do
        quote do
          def by_id(unquote(id)) do
            {:ok, unquote(Macro.escape(country_time_zone))}
          end
        end
      end,
      quote do
        def by_id(_) do
          {:error, :country_time_zone_id_not_found}
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

        def utc_time_zone_id(), do: "Etc/UTC"

        def canonical_time_zone_id(time_zone_id) do
          if time_zone_id = unquote(Macro.escape(link_canonical_map))[time_zone_id] do
            {:ok, time_zone_id}
          else
            {:error, :time_zone_not_found}
          end
        end

        def canonical_time_zone_id!(time_zone_id) do
          case canonical_time_zone_id(time_zone_id) do
            {:ok, time_zone_id} ->
              time_zone_id

            {:error, :time_zone_not_found} ->
              raise "time zone identifier \"#{time_zone_id}\" not found"
          end
        end

        def civil_time_zone_ids(opts \\ []) do
          include_aliases = Keyword.get(opts, :include_aliases, false)

          if include_aliases do
            unquote(Macro.escape(civil_time_zones_with_links))
          else
            unquote(Macro.escape(civil_time_zones))
          end
        end

        def time_zone_ids(opts \\ []) do
          include_aliases = Keyword.get(opts, :include_aliases, false)

          if include_aliases do
            unquote(Macro.escape(all_time_zones))
          else
            unquote(Macro.escape(canonical_time_zones))
          end
        end

        def time_zone_id_exists?(time_zone_id) do
          time_zone_ids(include_aliases: true)
          |> Enum.any?(&(&1 == time_zone_id))
        end

        def country_code_exists?(country_code) do
          countries()
          |> Enum.any?(&(&1.code == country_code))
        end

        def round_datetime(%DateTime{} = datetime, step_in_seconds, mode)
            when mode in [:floor, :ceil] do
          utc_datetime = DateTime.to_unix(datetime, :second)

          rounded_unix_time =
            case mode do
              :floor ->
                div(utc_datetime, step_in_seconds) * step_in_seconds

              :ceil ->
                div(utc_datetime + step_in_seconds - 1, step_in_seconds) * step_in_seconds
            end

          rounded_datetime = DateTime.from_unix!(rounded_unix_time)

          DateTime.shift_zone!(rounded_datetime, datetime.time_zone)
        end

        def new_resolved_datetime!(%Date{} = date, %Time{} = time, time_zone, opts) do
          ambiguous = Keyword.fetch!(opts, :ambiguous)
          gap = Keyword.fetch!(opts, :gap)

          case DateTime.new(date, time, time_zone, Tz.TimeZoneDatabase) do
            {:ok, dt} ->
              dt

            {:error, :time_zone_not_found} ->
              raise "time zone not found"

            {:ambiguous, first, second} ->
              case ambiguous do
                :first -> first
                :second -> second
              end

            {:gap, just_before, just_after} ->
              case gap do
                :just_before -> just_before
                :just_after -> just_after
              end
          end
        end

        def humanize_time_zone_id(time_zone_id) do
          time_zone_id
          |> String.split("/")
          |> List.last()
          |> String.split("_")
          |> Enum.map(&String.capitalize/1)
          |> Enum.join(" ")
        end

        def country_time_zone(country_or_time_zone_or_id) do
          country_or_time_zone_or_id = to_string(country_or_time_zone_or_id)

          if String.length(country_or_time_zone_or_id) == 2 do
            :"Elixir.TzExtra.CountryTimeZone".by_country_code(country_or_time_zone_or_id)
          else
            :"Elixir.TzExtra.CountryTimeZone".by_id(country_or_time_zone_or_id) ||
              :"Elixir.TzExtra.CountryTimeZone".by_time_zone(country_or_time_zone_or_id)
          end
        end

        def country_time_zone!(country_or_time_zone_or_id) do
          case country_time_zone(country_or_time_zone_or_id) do
            {:ok, country_time_zone} ->
              country_time_zone

            {:error, _} ->
              raise "country time zone not found"
          end
        end

        def countries_time_zones() do
          unquote(Macro.escape(countries_time_zones))
        end

        def countries() do
          unquote(Macro.escape(countries))
        end

        def utc_datetime_range(%DateTime{} = start_dt, %DateTime{} = end_dt, step_in_seconds) do
          start_unix_time = DateTime.to_unix(start_dt, :second)
          end_unix_time = DateTime.to_unix(end_dt, :second)

          Enum.map(start_unix_time..end_unix_time//step_in_seconds, &DateTime.from_unix!(&1))
        end

        def shifts_clock?(time_zone_id) when time_zone_id != nil do
          case Tz.PeriodsProvider.periods(time_zone_id) do
            {:error, :time_zone_not_found} ->
              raise "invalid time zone #{time_zone_id}"

            {:ok, [{utc_secs, _, _, nil} | _]} ->
              hardcoded_dst_future_periods? =
                DateTime.from_gregorian_seconds(utc_secs).year >
                  Tz.PeriodsProvider.compiled_at().year + 20

              hardcoded_dst_future_periods?

            {:ok, [{_, _, _, _} | _]} ->
              true
          end
        end

        def utc_offset_id(%DateTime{} = datetime, mode \\ :standard)
            when mode in [:standard, :pretty] do
          "UTC" <> offset_to_string(datetime.utc_offset + datetime.std_offset, mode)
        end

        def next_clock_shift_in_year_span(%DateTime{} = datetime) do
          case Tz.PeriodsProvider.next_period(datetime) do
            {from, _, _, _} ->
              first_datetime_in_next_period =
                DateTime.from_gregorian_seconds(from)
                |> DateTime.shift_zone!(datetime.time_zone, Tz.TimeZoneDatabase)

              # TODO: in a year span only

              clock_shift = clock_shift(datetime, first_datetime_in_next_period)

              {clock_shift, first_datetime_in_next_period}

            nil ->
              :no_shift
          end
        end

        def clock_shift(datetime1, datetime2) do
          if DateTime.compare(datetime1, datetime2) == :gt do
            raise "first datetime must be earlier than or equal to second datetime"
          end

          offset1 = datetime1.utc_offset + datetime1.std_offset
          offset2 = datetime2.utc_offset + datetime2.std_offset

          cond do
            offset1 < offset2 -> :forward
            offset1 > offset2 -> :backward
            offset1 == offset2 -> :no_shift
          end
        end
      end,
      for %{code: country_code} <- countries do
        {:ok, time_zones_for_country} =
          :"Elixir.TzExtra.CountryTimeZone".by_country_code(country_code)

        country_code_atom = String.to_atom(country_code)

        quote do
          def country_time_zone(unquote(country_code), time_zone_id) do
            case canonical_time_zone_id(time_zone_id) do
              {:error, _} = error ->
                error

              {:ok, canonical_time_zone_id} ->
                country_time_zone =
                  Enum.find(
                    unquote(Macro.escape(time_zones_for_country)),
                    &(&1.time_zone_id == canonical_time_zone_id)
                  )

                if country_time_zone do
                  {:ok, country_time_zone}
                else
                  {:error, :time_zone_not_found_for_country}
                end
            end
          end

          def country_time_zone(unquote(country_code_atom), time_zone_id) do
            country_time_zone(unquote(country_code), time_zone_id)
          end
        end
      end,
      quote do
        def country_time_zone(_, _) do
          {:error, :country_not_found}
        end

        def country_time_zone!(country_code, time_zone_id) do
          case country_time_zone(country_code, time_zone_id) do
            {:ok, country_time_zone} ->
              country_time_zone

            {:error, _} ->
              raise "no time zone data found for country #{country_code} and time zone ID #{time_zone_id}"
          end
        end
      end
    ]

    module = :"Elixir.TzExtra"
    Module.create(module, contents, Macro.Env.location(__ENV__))
    :code.purge(module)
  end

  defp add_offset_data(time_zones) do
    Enum.map(time_zones, fn %{time_zone_id: time_zone_id} = time_zone ->
      {:ok, periods} = Tz.PeriodsProvider.periods(time_zone_id)

      {utc_to_std_offset, utc_to_dst_offset, time_zone_abbr, dst_time_zone_abbr} =
        case hd(periods) do
          {utc_secs, {utc_to_std_offset, std_offset, time_zone_abbr},
           {_, prev_std_offset, prev_zone_abbr}, nil} ->
            hardcoded_dst_future_periods? =
              DateTime.from_gregorian_seconds(utc_secs).year > Date.utc_today().year + 20

            if hardcoded_dst_future_periods? do
              utc_to_dst_offset = utc_to_std_offset + max(std_offset, prev_std_offset)
              utc_to_std_offset = utc_to_std_offset + min(std_offset, prev_std_offset)

              {time_zone_abbr, dst_time_zone_abbr} =
                cond do
                  std_offset < prev_std_offset ->
                    {time_zone_abbr, prev_zone_abbr}

                  std_offset > prev_std_offset ->
                    {prev_zone_abbr, time_zone_abbr}
                end

              {utc_to_std_offset, utc_to_dst_offset, time_zone_abbr, dst_time_zone_abbr}
            else
              {utc_to_std_offset, utc_to_std_offset + std_offset, time_zone_abbr, time_zone_abbr}
            end

          {_, {utc_to_std_offset, std_offset, time_zone_abbr},
           {_, prev_std_offset, prev_zone_abbr}, _} ->
            utc_to_dst_offset = utc_to_std_offset + max(std_offset, prev_std_offset)
            utc_to_std_offset = utc_to_std_offset + min(std_offset, prev_std_offset)

            {time_zone_abbr, dst_time_zone_abbr} =
              cond do
                std_offset < prev_std_offset ->
                  {time_zone_abbr, prev_zone_abbr}

                std_offset > prev_std_offset ->
                  {prev_zone_abbr, time_zone_abbr}
              end

            {utc_to_std_offset, utc_to_dst_offset, time_zone_abbr, dst_time_zone_abbr}
        end

      time_zone
      |> Map.put(:utc_to_std_offset, utc_to_std_offset)
      |> Map.put(:utc_to_dst_offset, utc_to_dst_offset)
      |> Map.put(:utc_to_std_offset_id, "UTC" <> offset_to_string(utc_to_std_offset, :standard))
      |> Map.put(:utc_to_dst_offset_id, "UTC" <> offset_to_string(utc_to_dst_offset, :standard))
      |> Map.put(
        :pretty_utc_to_std_offset_id,
        "UTC" <> offset_to_string(utc_to_std_offset, :pretty)
      )
      |> Map.put(
        :pretty_utc_to_dst_offset_id,
        "UTC" <> offset_to_string(utc_to_dst_offset, :pretty)
      )
      |> Map.put(:time_zone_abbr, time_zone_abbr)
      |> Map.put(:dst_time_zone_abbr, dst_time_zone_abbr)
    end)
  end

  defp add_id(countries_time_zones) do
    Enum.map(countries_time_zones, &Map.put(&1, :id, &1.time_zone_id <> "_" <> &1.country.code))
  end

  defp add_time_zone_links(countries_time_zones, get_time_zone_links_for_canonical_fun) do
    Enum.map(countries_time_zones, fn %{time_zone_id: time_zone_id} = time_zone ->
      Map.put(
        time_zone,
        :time_zone_alias_ids,
        get_time_zone_links_for_canonical_fun.(time_zone_id)
      )
    end)
  end

  defp localize_country_name(countries_time_zones) do
    Enum.map(countries_time_zones, fn %{country: country} = time_zone ->
      local_names = local_country_names(country.code)
      %{time_zone | country: Map.put(country, :local_names, local_names)}
    end)
  end

  defp local_country_names(country_code) do
    local_countries_names =
      %{
        "AF" => ["افغانستان"],
        "AX" => ["Åland"],
        "AL" => ["Shqipëri"],
        "DZ" => ["الجزائر"],
        "AD" => ["Andorra"],
        "AO" => ["Angola"],
        "AI" => ["Anguilla"],
        "AQ" => ["Antarctica"],
        "AG" => ["Antigua & Barbuda"],
        "AR" => ["Argentina"],
        "AM" => ["Հայաստան"],
        "AW" => ["Aruba"],
        "AU" => ["Australia"],
        "AT" => ["Österreich"],
        "AZ" => ["Azərbaycan"],
        "BS" => ["Bahamas"],
        "BH" => ["البحرين"],
        "BD" => ["বাংলাদেশ"],
        "BB" => ["Barbados"],
        "BY" => ["Беларусь"],
        "BE" => ["België", "Belgique"],
        "BZ" => ["Belize"],
        "BJ" => ["Bénin"],
        "BM" => ["Bermuda"],
        "BT" => ["འབྲུག"],
        "BO" => ["Bolivia", "Buliwya", "Wuliwya"],
        "BA" => ["Bosna i Hercegovina"],
        "BW" => ["Botswana"],
        "BV" => ["Bouvetøya"],
        "BR" => ["Brasil"],
        "GB" => ["United Kingdom"],
        "IO" => ["British Indian Ocean Territory"],
        "BN" => ["Brunei"],
        "BG" => ["България"],
        "BF" => ["Burkina Faso"],
        "BI" => ["Uburundi"],
        "KH" => ["កម្ពុជា"],
        "CM" => ["Cameroun", "Cameroon"],
        "CA" => ["Canada"],
        "CV" => ["Cabo Verde"],
        "BQ" => ["Caribisch Nederland"],
        "KY" => ["Cayman Islands"],
        "CF" => ["Ködörösêse tî Bêafrîka"],
        "TD" => ["Tchad", "تشاد"],
        "CL" => ["Chile"],
        "CN" => ["中国"],
        "CX" => ["Christmas Island"],
        "CC" => ["Cocos (Keeling) Islands"],
        "CO" => ["Colombia"],
        "KM" => ["Komori", "جزر القمر", "Comores"],
        "CD" => ["République démocratique du Congo"],
        "CG" => ["République du Congo"],
        "CK" => ["Cook Islands"],
        "CR" => ["Costa Rica"],
        "CI" => ["Côte d'Ivoire"],
        "HR" => ["Hrvatska"],
        "CU" => ["Cuba"],
        "CW" => ["Curaçao"],
        "CY" => ["Κύπρος", "Kıbrıs"],
        "CZ" => ["Česká republika"],
        "DK" => ["Danmark"],
        "DJ" => ["جيبوتي", "Djibouti"],
        "DM" => ["Dominica"],
        "DO" => ["República Dominicana"],
        "TL" => ["Timor Lorosa'e"],
        "EC" => ["Ecuador"],
        "EG" => ["مصر"],
        "SV" => ["El Salvador"],
        "GQ" => ["Guinea Ecuatorial"],
        "ER" => ["ኤርትራ", "إرتريا"],
        "EE" => ["Eesti"],
        "SZ" => ["Eswatini"],
        "ET" => ["ኢትዮጵያ"],
        "FK" => ["Falkland Islands"],
        "FO" => ["Føroyar"],
        "FJ" => ["Fiji"],
        "FI" => ["Suomi"],
        "FR" => ["France"],
        "GF" => ["Guyane"],
        "PF" => ["Polynésie française"],
        "TF" => ["Terres australes et antarctiques françaises"],
        "GA" => ["Gabon"],
        "GM" => ["Gambia"],
        "GE" => ["საქართველო"],
        "DE" => ["Deutschland"],
        "GH" => ["Ghana"],
        "GI" => ["Gibraltar"],
        "GR" => ["Ελλάδα"],
        "GL" => ["Kalaallit Nunaat"],
        "GD" => ["Grenada"],
        "GP" => ["Guadeloupe"],
        "GU" => ["Guåhån"],
        "GT" => ["Guatemala"],
        "GG" => ["Guernsey"],
        "GN" => ["Guinée"],
        "GW" => ["Guiné-Bissau"],
        "GY" => ["Guyana"],
        "HT" => ["Haïti", "Ayiti"],
        "HM" => ["Heard Island & McDonald Islands"],
        "HN" => ["Honduras"],
        "HK" => ["香港"],
        "HU" => ["Magyarország"],
        "IS" => ["Ísland"],
        "IN" => ["भारत", "Bharat", "இந்தியா"],
        "ID" => ["Indonesia"],
        "IR" => ["ایران"],
        "IQ" => ["العراق"],
        "IE" => ["Éire", "Ireland"],
        "IM" => ["Ellan Vannin", "Isle of Man"],
        "IL" => ["ישראל"],
        "IT" => ["Italia"],
        "JM" => ["Jamaica"],
        "JP" => ["日本"],
        "JE" => ["Jersey"],
        "JO" => ["الأردن"],
        "KZ" => ["Қазақстан", "Казахстан"],
        "KE" => ["Kenya"],
        "KI" => ["Kiribati"],
        "KP" => ["조선"],
        "KR" => ["한국"],
        "KW" => ["الكويت"],
        "KG" => ["Кыргызстан"],
        "LA" => ["ລາວ"],
        "LV" => ["Latvija"],
        "LB" => ["لبنان"],
        "LS" => ["Lesotho"],
        "LR" => ["Liberia"],
        "LY" => ["ليبيا"],
        "LI" => ["Liechtenstein"],
        "LT" => ["Lietuva"],
        "LU" => ["Lëtzebuerg", "Luxembourg", "Luxemburg"],
        "MO" => ["澳門", "Macau"],
        "MG" => ["Madagasikara", "Madagascar"],
        "MW" => ["Malawi"],
        "MY" => ["Malaysia"],
        "MV" => ["ދިވެހިރާއްޖޭގެ ޖުމްހޫރިއްޔާ"],
        "ML" => ["Mali"],
        "MT" => ["Malta"],
        "MH" => ["M̧ajeļ", "Marshall Islands"],
        "MQ" => ["Martinique"],
        "MR" => ["موريتانيا"],
        "MU" => ["Maurice", "Moris"],
        "YT" => ["Mayotte"],
        "MX" => ["México"],
        "FM" => ["Micronesia"],
        "MD" => ["Moldova"],
        "MC" => ["Monaco"],
        "MN" => ["Монгол улс"],
        "ME" => ["Crna Gora", "Црна Гора"],
        "MS" => ["Montserrat"],
        "MA" => ["المغرب"],
        "MZ" => ["Moçambique"],
        "MM" => ["မြန်မာ"],
        "NA" => ["Namibia"],
        "NR" => ["Nauru"],
        "NP" => ["नेपाल"],
        "NL" => ["Nederland"],
        "NC" => ["Nouvelle-Calédonie"],
        "NZ" => ["New Zealand", "Aotearoa"],
        "NI" => ["Nicaragua"],
        "NE" => ["Niger"],
        "NG" => ["Nigeria"],
        "NU" => ["Niue"],
        "NF" => ["Norfolk Island"],
        "MK" => ["Северна Македонија"],
        "MP" => ["Northern Mariana Islands"],
        "NO" => ["Norge", "Noreg"],
        "OM" => ["عمان"],
        "PK" => ["پاکستان"],
        "PW" => ["Palau"],
        "PS" => ["فلسطين"],
        "PA" => ["Panamá"],
        "PG" => ["Papua Niugini", "Papua New Guinea"],
        "PY" => ["Paraguay"],
        "PE" => ["Perú"],
        "PH" => ["Pilipinas"],
        "PN" => ["Pitcairn"],
        "PL" => ["Polska"],
        "PT" => ["Portugal"],
        "PR" => ["Puerto Rico"],
        "QA" => ["قطر"],
        "RE" => ["La Réunion"],
        "RO" => ["România"],
        "RU" => ["Россия"],
        "RW" => ["Rwanda"],
        "AS" => ["Amerika Samoa"],
        "WS" => ["Samoa"],
        "SM" => ["San Marino"],
        "ST" => ["São Tomé e Príncipe"],
        "SA" => ["السعودية"],
        "SN" => ["Sénégal"],
        "RS" => ["Србија"],
        "SC" => ["Sesel", "Seychelles"],
        "SL" => ["Sierra Leone"],
        "SG" => ["新加坡", "சிங்கப்பூர்", "Singapore"],
        "SK" => ["Slovensko"],
        "SI" => ["Slovenija"],
        "SB" => ["Solomon Islands"],
        "SO" => ["Soomaaliya", "الصومال"],
        "ZA" => ["South Africa", "Suid-Afrika", "Afrika Borwa"],
        "GS" => ["South Georgia & the South Sandwich Islands"],
        "SS" => ["جنوب السودان"],
        "ES" => ["España"],
        "LK" => ["ශ්‍රී ලංකා", "இலங்கை"],
        "BL" => ["Saint-Barthélemy"],
        "SH" => ["Saint Helena"],
        "KN" => ["Saint Kitts & Nevis"],
        "LC" => ["Saint Lucia"],
        "SX" => ["Sint Maarten"],
        "MF" => ["Saint-Martin"],
        "PM" => ["Saint-Pierre et Miquelon"],
        "VC" => ["Saint Vincent"],
        "SD" => ["السودان"],
        "SR" => ["Suriname"],
        "SJ" => ["Svalbard og Jan Mayen"],
        "SE" => ["Sverige"],
        "CH" => ["Schweiz", "Suisse", "Svizzera"],
        "SY" => ["سوريا"],
        "TW" => ["臺灣"],
        "TJ" => ["Тоҷикистон"],
        "TZ" => ["Tanzania"],
        "TH" => ["ไทย"],
        "TG" => ["Togo"],
        "TK" => ["Tokelau"],
        "TO" => ["Tonga"],
        "TT" => ["Trinidad & Tobago"],
        "TN" => ["تونس"],
        "TR" => ["Türkiye"],
        "TM" => ["Türkmenistan"],
        "TC" => ["Turks & Caicos Is"],
        "TV" => ["Tuvalu"],
        "UM" => ["US minor outlying islands"],
        "UG" => ["Uganda"],
        "UA" => ["Україна"],
        "AE" => ["الإمارات"],
        "US" => ["United States"],
        "UY" => ["Uruguay"],
        "UZ" => ["O'zbekiston"],
        "VU" => ["Vanuatu"],
        "VA" => ["Città del Vaticano", "Status Civitatis Vaticanæ"],
        "VE" => ["Venezuela"],
        "VN" => ["Việt Nam"],
        "VG" => ["Virgin Islands"],
        "VI" => ["Virgin Islands"],
        "WF" => ["Wallis-et-Futuna"],
        "EH" => ["الصحراء الغربية"],
        "YE" => ["اليمن"],
        "ZM" => ["Zambia"],
        "ZW" => ["Zimbabwe"]
      }

    local_names = local_countries_names[country_code]

    unless local_names do
      raise "local country names not found for country #{country_code}"
    end

    local_names
  end
end
