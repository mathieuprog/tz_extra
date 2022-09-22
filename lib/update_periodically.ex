defmodule TzExtra.UpdatePeriodically do
  use GenServer

  require Logger

  alias Tz.HTTP
  alias Tz.Updater, as: TzUpdater
  alias TzExtra.Compiler

  defp maybe_recompile_tz() do
    TzUpdater.maybe_recompile()
  end

  defp maybe_recompile_tz_extra() do
    if Tz.iana_version() != TzExtra.iana_version() do
      Logger.info("TzExtra is recompiling time zone data...")
      Code.compiler_options(ignore_module_conflict: true)
      Compiler.compile()
      Code.compiler_options(ignore_module_conflict: false)
      Logger.info("TzExtra compilation done")
    end
  end

  def start_link(opts) do
    HTTP.get_http_client!()

    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    maybe_recompile_tz()
    maybe_recompile_tz_extra()
    schedule_work(opts[:interval_in_days])
    {:ok, %{opts: opts}}
  end

  def handle_info(:work, %{opts: opts}) do
    maybe_recompile_tz()
    maybe_recompile_tz_extra()
    schedule_work(opts[:interval_in_days])
    {:noreply, %{opts: opts}}
  end

  defp schedule_work(interval_in_days) do
    interval_in_days = interval_in_days || 1
    Process.send_after(self(), :work, interval_in_days * 24 * 60 * 60 * 1000)
  end
end
