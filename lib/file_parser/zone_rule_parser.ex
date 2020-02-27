defmodule TzExtra.FileParser.ZoneRuleParser do
  @moduledoc false

  def parse(file_path) do
    File.stream!(file_path)
    |> strip_comments()
    |> strip_empty()
    |> trim()
    |> Enum.to_list()
    |> parse_strings_into_maps()
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

  defp parse_strings_into_maps([]), do: []

  defp parse_strings_into_maps([string | tail]) do
    map =
      cond do
        String.starts_with?(string, "Link") ->
          parse_link_string_into_map(string)

        String.starts_with?(string, "Zone") ->
          parse_zone_string_into_map(string)

        true ->
          nil
      end

    if(map == nil, do: [], else: [map]) ++ parse_strings_into_maps(tail)
  end

  defp parse_link_string_into_map(link_string) do
    Enum.zip([
      [:canonical_zone_name, :link_zone_name],
      tl(String.split(link_string, ~r{\s}, trim: true, parts: 3))
      |> Enum.map(& String.trim(&1))
    ])
    |> Enum.into(%{})
    |> Map.put(:record_type, :link)
  end

  defp parse_zone_string_into_map(zone_string) do
    Enum.zip([
      [:name, :std_offset_from_utc_time, :rules, :format_time_zone_abbr, :to],
      tl(String.split(zone_string, ~r{\s}, trim: true, parts: 6))
      |> Enum.map(& String.trim(&1))
    ])
    |> Enum.into(%{})
    |> Map.take([:name])
    |> Map.put(:record_type, :zone)
  end
end
