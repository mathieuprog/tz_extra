defmodule TzExtra do
  require TzExtra.FileParser.CountryParser
  require TzExtra.FileParser.ZoneParser
  import TzExtra.Helper

  alias TzExtra.FileParser.CountryParser
  alias TzExtra.FileParser.ZoneParser

  tz_data_dir = Path.join(:code.priv_dir(:tz), Tz.version())

  countries = CountryParser.parse(Path.join(tz_data_dir, "iso3166.tab"))
  time_zones = ZoneParser.parse(Path.join(tz_data_dir, "zone1970.tab"), countries)

  time_zones =
    Enum.map(time_zones, fn time_zone ->
      {:ok, periods} = Tz.periods(time_zone.name)

      utc_offset = find_latest_utc_offset_for_periods(periods)
      dst_offset = utc_offset + find_latest_std_offset_for_periods(periods)

      time_zone
      |> Map.put(:utc_offset, utc_offset)
      |> Map.put(:dst_offset, dst_offset)
      |> Map.put(:pretty_utc_offset, offset_to_string(utc_offset))
      |> Map.put(:pretty_dst_offset, offset_to_string(dst_offset))
    end)

  def countries() do
    unquote(Macro.escape(countries))
  end

  def time_zones() do
    unquote(Macro.escape(time_zones))
  end
end
