defmodule Plausible.Session.Store do
  use GenServer
  use Plausible.Repo
  alias Plausible.Session.WriteBuffer
  import Ecto.Query, only: [from: 2]
  require Logger

  @session_length_seconds Application.get_env(:plausible, :session_length_minutes) * 60
  @forget_session_after @session_length_seconds * 2
  @garbage_collect_interval_milliseconds 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    timer = Process.send_after(self(), :garbage_collect, @garbage_collect_interval_milliseconds)

    latest_sessions =
      from(
        s in "sessions",
        where: s.timestamp >= fragment("now() - INTERVAL ? SECOND", @forget_session_after),
        group_by: s.session_id,
        select: %{session_id: s.session_id, timestamp: max(s.timestamp)}
      )

    sessions =
      try do
        Plausible.Clickhouse.all(
          from s in Plausible.ClickhouseSession,
            join: ls in subquery(latest_sessions),
            on: s.session_id == ls.session_id and s.timestamp == ls.timestamp,
            order_by: s.timestamp
        )
        |> Enum.map(fn s -> Map.new(s, fn {k, v} -> {String.to_atom(k), v} end) end)
        |> Enum.map(fn s -> {s[:user_id], struct(Plausible.ClickhouseSession, s)} end)
        |> Enum.into(%{})
      rescue
        _e -> %{}
      end

    {:ok, %{timer: timer, sessions: sessions}}
  end

  def on_event(event, prev_user_id) do
    GenServer.call(__MODULE__, {:on_event, event, prev_user_id})
  end

  def handle_call({:on_event, event, prev_user_id}, _from, %{sessions: sessions} = state) do
    found_session = sessions[event.user_id] || (prev_user_id && sessions[prev_user_id])
    active = is_active?(found_session, event)

    updated_sessions =
      cond do
        found_session && active ->
          new_session = update_session(found_session, event)
          WriteBuffer.insert([%{new_session | sign: 1}, %{found_session | sign: -1}])
          Map.put(sessions, event.user_id, new_session)

        found_session && !active ->
          new_session = new_session_from_event(event)
          WriteBuffer.insert([new_session])
          Map.put(sessions, event.user_id, new_session)

        true ->
          new_session = new_session_from_event(event)
          WriteBuffer.insert([new_session])
          Map.put(sessions, event.user_id, new_session)
      end

    session_id = updated_sessions[event.user_id].session_id
    {:reply, session_id, %{state | sessions: updated_sessions}}
  end

  defp is_active?(session, event) do
    session && Timex.diff(event.timestamp, session.timestamp, :second) < @session_length_seconds
  end

  defp update_session(session, event) do
    %{
      session
      | user_id: event.user_id,
        timestamp: event.timestamp,
        exit_page: event.pathname,
        is_bounce: false,
        duration: Timex.diff(event.timestamp, session.start, :second),
        pageviews:
          if(event.name == "pageview", do: session.pageviews + 1, else: session.pageviews),
        events: session.events + 1
    }
  end

  defp new_session_from_event(event) do
    %Plausible.ClickhouseSession{
      sign: 1,
      session_id: Plausible.ClickhouseSession.random_uint64(),
      hostname: event.hostname,
      domain: event.domain,
      user_id: event.user_id,
      entry_page: event.pathname,
      exit_page: event.pathname,
      is_bounce: true,
      duration: 0,
      pageviews: if(event.name == "pageview", do: 1, else: 0),
      events: 1,
      referrer: event.referrer,
      referrer_source: event.referrer_source,
      country_code: event.country_code,
      operating_system: event.operating_system,
      browser: event.browser,
      timestamp: event.timestamp,
      start: event.timestamp
    }
  end

  def handle_info(:garbage_collect, state) do
    Logger.debug("Session store collecting garbage")

    now = Timex.now()

    new_sessions =
      Enum.reduce(state[:sessions], %{}, fn {key, session}, acc ->
        if Timex.diff(now, session.timestamp, :second) <= @forget_session_after do
          Map.put(acc, key, session)
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
      n_new = Enum.count(new_sessions)
      "Removed #{n_old - n_new} sessions from store"
    end)

    {:noreply, %{state | sessions: new_sessions, timer: new_timer}}
  end
end
