defmodule TzExtra.Helper do
  @moduledoc false

  def find_latest_std_offset_for_periods([%{to: :max} = period1, %{to: :max} = period2 | _]) do
    Enum.max([period1.std_offset, period2.std_offset])
  end

  def find_latest_std_offset_for_periods([period | _]) do
    period.std_offset
  end

  def find_latest_utc_offset_for_periods([period | _]) do
    period.utc_offset
  end

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
end
