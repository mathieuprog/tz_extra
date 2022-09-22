if Code.ensure_loaded?(Jason) do
  defmodule TzExtra.JsonDumper do
    @moduledoc false

    def dump_countries(filename \\ "countries.json") do
      json =
        TzExtra.countries()
        |> Enum.map(&camelize_map_keys(&1))
        |> Jason.encode!()

      file_path = Path.join(:code.priv_dir(:tz_extra), filename)

      File.write!(file_path, json, [:write])
    end

    def dump_countries_time_zones(options \\ [], filename \\ "countries_time_zones.json") do
      json =
        TzExtra.countries_time_zones(options)
        |> Enum.map(&camelize_map_keys(&1))
        |> Jason.encode!()

      file_path = Path.join(:code.priv_dir(:tz_extra), filename)

      File.write!(file_path, json, [:write])
    end

    defp camelize_map_keys(map) do
      for {key, val} <- map, into: %{}, do: {camelize(to_string(key)), val}
    end

    defp camelize(string) do
      String.split(string, "_")
      |> Enum.map(&String.capitalize(&1))
      |> Enum.join()
      |> uncapitalize()
    end

    defp uncapitalize(string) do
      {first, rest} = String.split_at(string, 1)
      String.downcase(first) <> rest
    end
  end
end
