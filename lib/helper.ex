defmodule TzExtra.Helper do
  @moduledoc false

  def offset_to_string(seconds) do
    string =
      abs(seconds)
      |> :calendar.seconds_to_time()
      |> do_offset_to_string()
      |> List.to_string()

    if(seconds < 0, do: "-", else: "+") <> string
  end

  defp do_offset_to_string({h, m, 0}), do: :io_lib.format("~2..0B:~2..0B", [h, m])
  defp do_offset_to_string({h, m, s}), do: :io_lib.format("~2..0B:~2..0B:~2..0B", [h, m, s])

  def normalize_string(string) do
    :unicode.characters_to_nfd_binary(string)
    |> String.replace(~r/\W/u, "")
  end
end
