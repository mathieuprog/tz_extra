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
        countries_time_zones =
          Enum.filter(countries_time_zones, &(&1.time_zone_id == canonical_time_zone))

        if length(countries_time_zones) > 0 do
          quote do
            def for_time_zone(unquote(canonical_time_zone)) do
              {:ok, unquote(Macro.escape(countries_time_zones))}
            end
          end
        else
          quote do
            def for_time_zone(unquote(canonical_time_zone)) do
              {:error, :time_zone_not_linked_to_country}
            end
          end
        end
      end,
      quote do
        def for_time_zone(link_time_zone) do
          canonical_time_zone = unquote(Macro.escape(link_canonical_map))[link_time_zone]

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
            for_country_code(unquote(country_code))
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

        def canonical_time_zone_id(time_zone_id) do
          unquote(Macro.escape(link_canonical_map))[time_zone_id] ||
            raise "time zone identifier \"#{time_zone_id}\" not found"
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

        def country_time_zone(country_code_or_time_zone) do
          country_code_or_time_zone = to_string(country_code_or_time_zone)

          if String.length(country_code_or_time_zone) == 2 do
            :"Elixir.TzExtra.CountryTimeZone".for_country_code(country_code_or_time_zone)
          else
            :"Elixir.TzExtra.CountryTimeZone".for_time_zone(country_code_or_time_zone)
          end
        end

        def countries_time_zones() do
          unquote(Macro.escape(countries_time_zones))
        end

        def countries() do
          unquote(Macro.escape(countries))
        end
      end,
      for %{code: country_code} <- countries do
        {:ok, time_zones_for_country} =
          :"Elixir.TzExtra.CountryTimeZone".for_country_code(country_code)

        country_code_atom = String.to_atom(country_code)

        quote do
          def country_time_zone(unquote(country_code), time_zone_id) do
            canonical_time_zone = canonical_time_zone_id(time_zone_id)

            country_time_zone =
              Enum.find(
                unquote(Macro.escape(time_zones_for_country)),
                &(&1.time_zone_id == canonical_time_zone)
              )

            if country_time_zone do
              {:ok, country_time_zone}
            else
              {:error, :time_zone_not_found_for_country}
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
      end,
      quote do
        def earliest_datetime(%Date{} = date, %Time{} = time, time_zone) do
          case DateTime.new(date, time, time_zone, Tz.TimeZoneDatabase) do
            {:ambiguous, first, _second} ->
              {:ok, first}

            {:gap, just_before, _just_after} ->
              {:ok, just_before}

            ok_or_error_tuple ->
              ok_or_error_tuple
          end
        end

        def latest_datetime(%Date{} = date, %Time{} = time, time_zone) do
          case DateTime.new(date, time, time_zone, Tz.TimeZoneDatabase) do
            {:ambiguous, _first, second} ->
              {:ok, second}

            {:gap, _just_before, just_after} ->
              {:ok, just_after}

            ok_or_error_tuple ->
              ok_or_error_tuple
          end
        end

        def earliest_datetime!(%Date{} = date, %Time{} = time, time_zone) do
          case earliest_datetime(date, time, time_zone) do
            {:ok, datetime} ->
              datetime

            {:error, _} ->
              raise "invalid datetime"
          end
        end

        def latest_datetime!(%Date{} = date, %Time{} = time, time_zone) do
          case latest_datetime(date, time, time_zone) do
            {:ok, datetime} ->
              datetime

            {:error, _} ->
              raise "invalid datetime"
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

      {utc_to_std_offset, utc_to_dst_offset, zone_abbr, dst_zone_abbr} =
        case hd(periods) do
          {_, {utc_offset, std_offset, zone_abbr}, _, nil} ->
            {utc_offset, utc_offset + std_offset, zone_abbr, zone_abbr}

          {_, {utc_offset, std_offset, zone_abbr}, {_, prev_std_offset, prev_zone_abbr}, _} ->
            utc_to_dst_offset = utc_offset + max(std_offset, prev_std_offset)

            {zone_abbr, dst_zone_abbr} =
              cond do
                std_offset < prev_std_offset ->
                  {zone_abbr, prev_zone_abbr}

                std_offset > prev_std_offset ->
                  {prev_zone_abbr, zone_abbr}
              end

            {utc_offset, utc_to_dst_offset, zone_abbr, dst_zone_abbr}
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
      |> Map.put(:zone_abbr, zone_abbr)
      |> Map.put(:dst_zone_abbr, dst_zone_abbr)
    end)
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
