defmodule TzExtra.JsonDumper do
  @moduledoc false

  def dump(fun, filename) do
    json = Jason.encode!(fun.())

    file_path = Path.join(:code.priv_dir(:tz_extra), filename)

    File.write!(file_path, json, [:write])
  end
end
