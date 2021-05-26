defmodule Plausible.Session.WriteBuffer do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(buffer) do
    Process.flag(:trap_exit, true)
    timer = Process.send_after(self(), :tick, flush_interval_ms())
    {:ok, %{buffer: buffer, timer: timer}}
  end

  def insert(sessions) do
    GenServer.cast(__MODULE__, {:insert, sessions})
    {:ok, sessions}
  end

  def handle_cast({:insert, sessions}, %{buffer: buffer} = state) do
    new_buffer = sessions ++ buffer

    if length(new_buffer) >= max_buffer_size() do
      Logger.info("Buffer full, flushing to disk")
      Process.cancel_timer(state[:timer])
      flush(new_buffer)
      new_timer = Process.send_after(self(), :tick, flush_interval_ms())
      {:noreply, %{buffer: [], timer: new_timer}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:tick, %{buffer: buffer}) do
    flush(buffer)
    timer = Process.send_after(self(), :tick, flush_interval_ms())
    {:noreply, %{buffer: [], timer: timer}}
  end

  def terminate(_reason, %{buffer: buffer}) do
    Logger.info("Flushing session buffer before shutdown...")
    flush(buffer)
  end

  defp flush(buffer) do
    case buffer do
      [] ->
        nil

      sessions ->
        Logger.info("Flushing #{length(sessions)} sessions")

        sessions =
          sessions
          |> Enum.map(&(Map.from_struct(&1) |> Map.delete(:__meta__)))
          |> Enum.reverse()

        Plausible.ClickhouseRepo.insert_all(Plausible.ClickhouseSession, sessions)
    end
  end

  defp flush_interval_ms() do
    Keyword.fetch!(Application.get_env(:plausible, Plausible.ClickhouseRepo), :flush_interval_ms)
  end

  defp max_buffer_size() do
    Keyword.fetch!(Application.get_env(:plausible, Plausible.ClickhouseRepo), :max_buffer_size)
  end
end
