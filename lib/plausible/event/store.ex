defmodule Plausible.Event.Store do
  use GenServer
  use Plausible.Repo
  require Logger

  @garbage_collect_interval_milliseconds 60 * 1000
  @ignoring_message "Ignoring enrich event"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    buffer = Keyword.get(opts, :buffer, Plausible.Event.WriteBuffer)
    timer = Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    {:ok, %{timer: timer, event_memory: %{}, buffer: buffer}}
  end

  def on_event(event, last_event_id, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_event, event, last_event_id})
  end

  def on_enrich_event(event_id, timestamp, pid \\ __MODULE__) do
    GenServer.call(pid, {:on_enrich_event, event_id, timestamp})
  end

  def handle_call(
        {:on_event, event, last_event_id},
        _from,
        %{event_memory: event_memory, buffer: buffer} = state
      ) do
    case event.name do
      "pageview" ->
        insert_clickhouse_event(buffer, event, event.domain_list)

        new_event_memory =
          event_memory
            |> Map.put(event.event_id, event)
            |> maybe_enrich_prev_session_event(buffer, last_event_id, event.timestamp)

        {:reply, event.event_id, %{state | event_memory: new_event_memory}}
      _custom_event ->
        insert_clickhouse_event(buffer, event, event.domain_list)
        {:reply, "ok", state}
    end
  end

  def handle_call(
        {:on_enrich_event, event_id, timestamp},
        _from,
        %{event_memory: event_memory, buffer: buffer} = state
      ) do

    case event_memory[event_id] do
      nil -> {:reply, {:ok, @ignoring_message}, state}
      event ->
        new_event = enrich_duration(event, timestamp)
        update_clickhouse_event(buffer, event, new_event, event.domain_list)

        updated_event_memory = Map.put(event_memory, event_id, new_event)
        {:reply, {:ok, "ok"}, %{state | event_memory: updated_event_memory}}
    end
  end

  defp insert_clickhouse_event(buffer, event, domain_list) do
    Enum.each(domain_list, fn domain ->
      unique_event_for(event, domain)
        |> Map.put(:sign, 1)
        |> List.wrap()
        |> buffer.insert()
    end)
  end

  defp update_clickhouse_event(buffer, event, new_event, domain_list) do
    Enum.each(domain_list, fn domain ->
      cancel_row = %{unique_event_for(event, domain) | sign: -1}
      state_row = %{unique_event_for(new_event, domain) | sign: 1}
      buffer.insert([state_row, cancel_row])
    end)
  end

  defp unique_event_for(event, domain) do
    %{
      event
      | domain: domain,
        user_id: SipHash.hash!(to_string(event.user_id), domain),
        event_id: SipHash.hash!(to_string(event.event_id), domain),
        session_id: SipHash.hash!(to_string(event.session_id), domain)
    }
  end

  defp maybe_enrich_prev_session_event(event_memory, buffer, last_event_id, timestamp) do
    case event_memory[last_event_id] do
      %{duration: 0} = event ->
        new_event = enrich_duration(event, timestamp)
        update_clickhouse_event(buffer, event, new_event, event.domain_list)
        Map.delete(event_memory, last_event_id)
      _ -> event_memory
    end
  end

  def handle_info(:garbage_collect, state) do
    Logger.debug("Event store collecting garbage")

    now = Timex.now()

    new_event_memory =
      Enum.reduce(state[:event_memory], %{}, fn {event_id, event}, acc ->
        if Timex.diff(now, event.timestamp + event.duration, :second) <= forget_event_after() do
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
  defp enrich_duration(event, timestamp) do
    %{event | duration: Timex.diff(timestamp, event.timestamp, :second)}
  end
  defp forget_event_after(), do: 60 * 30 # half an hour in seconds
end
