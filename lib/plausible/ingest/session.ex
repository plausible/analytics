defmodule Plausible.Ingest.Session do
  use GenServer
  use Plausible.Repo

  @session_timeout Application.get_env(:plausible, :session_timeout)

  def on_event(event) do
    user_session = :global.whereis_name(event.user_id)

    if is_pid(user_session) do
      GenServer.cast(user_session, {:on_event, event})
    else
      GenServer.start_link(__MODULE__, event, name: {:global, event.user_id})
    end
  end

  def on_unload(user_id, timestamp) do
    user_session = :global.whereis_name(user_id)

    if is_pid(user_session) do
      GenServer.cast(user_session, {:on_unload, timestamp})
    end
  end

  def init(event) do
    timer = Process.send_after(self(), :finalize, @session_timeout)
    {:ok, %{first_event: event, timer: timer, is_bounce: true, last_unload: nil}}
  end

  def handle_cast({:on_event, _event}, state) do
    Process.cancel_timer(state[:timer])
    new_timer = Process.send_after(self(), :finalize, @session_timeout)
    {:noreply, %{state | timer: new_timer, is_bounce: false, last_unload: nil}}
  end

  def handle_cast({:on_unload, timestamp}, state) do
    {:noreply, %{state | last_unload: timestamp}}
  end

  def handle_info(:finalize, state) do
    event = state[:first_event]

    if !is_potential_leftover?(event) do
      length = if state[:last_unload] do
        Timex.diff(state[:last_unload], event.timestamp, :seconds)
      end

      Plausible.Session.changeset(%Plausible.Session{}, %{
        hostname: event.hostname,
        user_id: event.user_id,
        new_visitor: event.new_visitor,
        is_bounce: state[:is_bounce],
        length: length,
        referrer: event.referrer,
        referrer_source: event.referrer_source,
        country_code: event.country_code,
        operating_system: event.operating_system,
        browser: event.browser
      }) |> Repo.insert!
    end

    {:stop, :normal, state}
  end

  defp is_potential_leftover?(%{new_visitor: true}), do: false
  defp is_potential_leftover?(%{timestamp: timestamp}) do
    server_start_time = Application.get_env(:plausible, :server_start)
    Timex.diff(timestamp, server_start_time, :milliseconds) < @session_timeout
  end

end
