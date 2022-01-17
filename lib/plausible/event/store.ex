defmodule Plausible.Event.Store do
  use GenServer
  use Plausible.Repo
  require Logger

  @garbage_collect_interval_milliseconds 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    buffer = Keyword.get(opts, :buffer, Plausible.Event.WriteBuffer)
    timer = Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    {:ok, %{timer: timer, event_memory: %{}, buffer: buffer}}
  end

  def on_pageview_end(event_params, pid \\ __MODULE__) do
    GenServer.cast(pid, {:on_pageview_end, event_params})
    :ok
  end

  def on_event(event, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_event, event})
  end

  def handle_cast(
        {:on_pageview_end, event_params},
        %{event_memory: event_memory, buffer: buffer} = state
      ) do
    event_id = event_params["event_id"] |> String.to_integer()
    pageview_end_timestamp = event_params["timestamp"]

    found_pageview = event_memory[event_id]

    # create the new updated pageview, insert cancel and update rows in the buffer
    new_duration = Timex.diff(pageview_end_timestamp, found_pageview.timestamp, :second) + found_pageview.duration
    updated_pageview = %{found_pageview | duration: new_duration, timestamp: pageview_end_timestamp}

    buffer.insert([%{updated_pageview | sign: 1}, %{found_pageview | sign: -1}])

    # update that event in event_memory
    updated_event_memory = %{event_memory | event_id => updated_pageview}
    {:noreply, %{state | event_memory: updated_event_memory}}
  end

  def handle_call(
        {:on_event, event},
        _from,
        %{event_memory: event_memory, buffer: buffer} = state
      ) do
    case event.name do
      "pageview" ->
        new_event_id = generate_event_id()
        new_event = Map.put(event, :event_id, new_event_id)
        buffer.insert([new_event])

        updated_event_memory = Map.put(event_memory, new_event_id, new_event)

        {:reply, new_event_id, %{state | event_memory: updated_event_memory}}
      _ ->
        buffer.insert([event])
        {:reply, "ok", state}
    end
  end


  def handle_info(:garbage_collect, state) do
    Logger.debug("Event store collecting garbage")

    now = Timex.now()

    new_event_memory =
      Enum.reduce(state[:event_memory], %{}, fn {event_id, event} , acc ->
        if Timex.diff(now, event.timestamp, :second) <= forget_event_after() do
          Map.put(acc, event_id, event)
        else
          # forget the session
          acc
        end
      end)

    Process.cancel_timer(state[:timer])

    new_timer =
      Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    Logger.debug(fn ->
      n_old = Enum.count(state[:sessions])
      n_new = Enum.count(new_event_memory)
      "Removed #{n_old - n_new} sessions from store"
    end)

    {:noreply, %{state | event_memory: new_event_memory, timer: new_timer}}
  end

  defp generate_event_id(), do: :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  defp forget_event_after(), do: 60 * 30
end
