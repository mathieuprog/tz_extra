defmodule TzExtra.FileParser.CountryParser do
  @moduledoc false

  def parse(file_path) do
    File.stream!(file_path)
    |> strip_comments()
    |> strip_empty()
    |> trim()
    |> Enum.to_list()
    |> parse_strings_into_maps()
    |> Enum.sort_by(& &1.name)
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
      Enum.zip([
        [:code, :name],
        String.split(string, ~r{\s}, trim: true, parts: 2)
        |> Enum.map(& String.trim(&1))
      ])
      |> Enum.into(%{})

    [map | parse_strings_into_maps(tail)]
  end
end
