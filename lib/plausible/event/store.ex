defmodule Plausible.Event.Store do
  use GenServer
  use Plausible.Repo
  require Logger

  @garbage_collect_interval_milliseconds 60 * 1000
  @ignoring_message "Ignoring pageview_end event"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    buffer = Keyword.get(opts, :buffer, Plausible.Event.WriteBuffer)
    timer = Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    {:ok, %{timer: timer, event_memory: %{}, buffer: buffer}}
  end

  def on_pageview_end(event_id, timestamp, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_pageview_end, event_id, timestamp})
  end

  def on_event(event, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_event, event})
  end

  def handle_call(
        {:on_pageview_end, event_id, timestamp},
        _from,
        %{event_memory: event_memory, buffer: buffer} = state
      ) do
    case event_memory[event_id] do
      nil -> {:reply, {:ok, @ignoring_message}, state}
      _event_list ->
        updated_event_memory = end_pageviews(buffer, event_memory, event_id, timestamp)
        {:reply, {:ok, "ok"}, %{state | event_memory: updated_event_memory}}
    end

  end

  def handle_call(
        {:on_event, event},
        _from,
        %{event_memory: event_memory, buffer: buffer} = state
      ) do
    case event.name do
      "pageview" ->
        event = Map.put(event, :sign, 1)
        buffer.insert([event])
        updated_event_memory = remember_event(event_memory, event.event_id, event)
        {:reply, event.event_id, %{state | event_memory: updated_event_memory}}

      _other ->
        buffer.insert([
          event
          |> Map.put(:sign, 1)
        ])

        {:reply, "ok", state}
    end
  end

  defp end_pageviews(buffer, event_memory, event_id, end_timestamp) do
    new_event_list =
      Enum.map(event_memory[event_id], fn pageview ->
        new_duration = Timex.diff(end_timestamp, pageview.timestamp, :second)
        updated_pageview = %{pageview | duration: new_duration}

        buffer.insert([%{updated_pageview | sign: 1}, %{pageview | sign: -1}])
        updated_pageview
      end)

    %{event_memory | event_id => new_event_list}
  end

  def remember_event(event_memory, event_id, event) do
    case event_memory[event_id] do
      nil ->
        Map.put(event_memory, event_id, [event])
      event_list ->
        new_event_list = event_list ++ [event]
        Map.put(event_memory, event_id, new_event_list)
    end
  end

  def handle_info(:garbage_collect, state) do
    Logger.debug("Event store collecting garbage")

    now = Timex.now()

    new_event_memory =
      Enum.reduce(state[:event_memory], %{}, fn {event_id, event}, acc ->
        if Timex.diff(now, event.timestamp, :second) <= forget_event_after() do
          Map.put(acc, event_id, event)
        else
          # forget the event
          acc
        end
      end)

    Process.cancel_timer(state[:timer])

    new_timer =
      Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    Logger.debug(fn ->
      n_old = Enum.count(state[:event_memory])
      n_new = Enum.count(new_event_memory)
      "Removed #{n_old - n_new} events from store"
    end)

    {:noreply, %{state | event_memory: new_event_memory, timer: new_timer}}
  end

  defp forget_event_after(), do: 60 * 30
end
