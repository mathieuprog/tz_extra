if Code.ensure_loaded?(Mint.HTTP) do
  defmodule TzExtra.UpdatePeriodically do
    use GenServer

    require Logger

    alias Tz.HTTP
    alias Tz.Updater
    alias TzExtra.Compiler

    def start_link(opts) do
      HTTP.get_http_client!()

      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      work()
      schedule_work(opts[:interval_in_days])
      {:ok, %{opts: opts}}
    end

    def handle_info(:work, %{opts: opts}) do
      work()
      schedule_work(opts[:interval_in_days])
      {:noreply, %{opts: opts}}
    end

    defp work() do
      Logger.debug("TzExtra is checking for IANA time zone database updates")

      Updater.maybe_recompile()

      if Tz.iana_version() != TzExtra.iana_version() do
        Logger.info("TzExtra is recompiling time zone data...")
        Code.compiler_options(ignore_module_conflict: true)
        Compiler.compile()
        Code.compiler_options(ignore_module_conflict: false)
        Logger.info("TzExtra compilation done")
      end
    end

    defp schedule_work(interval_in_days) do
      interval_in_days = interval_in_days || 1
      Process.send_after(self(), :work, 24 * 60 * 60 * 1000) # In 24 hours
    end
  end
end
