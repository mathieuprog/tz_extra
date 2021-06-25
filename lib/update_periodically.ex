if Code.ensure_loaded?(Mint.HTTP) do
  defmodule TzExtra.UpdatePeriodically do
    use GenServer

    require Logger

    alias Tz.Updater
    alias TzExtra.Compiler

    def start_link(_) do
      GenServer.start_link(__MODULE__, %{})
    end

    def init(state) do
      schedule_work()
      {:ok, state}
    end

    def handle_info(:work, state) do
      Logger.debug("TzExtra is checking for IANA time zone database updates")

      Updater.maybe_recompile()

      if Tz.iana_version() != TzExtra.iana_version() do
        Logger.info("TzExtra is recompiling time zone data...")
        Code.compiler_options(ignore_module_conflict: true)
        Compiler.compile()
        Code.compiler_options(ignore_module_conflict: false)
        Logger.info("TzExtra compilation done")
      end

      schedule_work()
      {:noreply, state}
    end

    defp schedule_work() do
      Process.send_after(self(), :work, 24 * 60 * 60 * 1000) # In 24 hours
    end
  end
end
