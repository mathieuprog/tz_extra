defmodule TzExtra.FileParser.ZoneParser do
  @moduledoc false

  def parse(file_path, countries) do
    File.stream!(file_path)
    |> strip_comments()
    |> strip_empty()
    |> trim()
    |> Enum.to_list()
    |> parse_strings_into_maps()
    |> add_country_names(countries)
    |> Enum.sort_by(& &1.country.name)
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
    maps =
      Enum.zip([
        [:country_codes, :coordinates, :name, :_],
        String.split(string, ~r{\s}, trim: true, parts: 4)
        |> Enum.map(& String.trim(&1))
      ])
      |> Enum.into(%{})
      |> Map.delete(:_)
      |> denormalize_entry()

    maps ++ parse_strings_into_maps(tail)
  end

  defp denormalize_entry(%{} = entry) do
    country_codes = String.split(entry.country_codes, ",", trim: true)

    for country_code <- country_codes do
      %{
        country_code: country_code,
        coordinates: entry.coordinates,
        name: entry.name
      }
    end
  end

  defp add_country_names(list, countries) do
    Enum.map(list, fn map ->
      {country_code, map} = pop_in(map, [:country_code])

      country = Enum.find(countries, & &1.code == country_code)

      Map.put(map, :country, country)
    end)
  end
end
