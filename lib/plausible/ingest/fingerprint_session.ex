defmodule Plausible.Ingest.FingerprintSession do
  use GenServer
  use Plausible.Repo

  @session_timeout Application.get_env(:plausible, :session_timeout)

  def on_event(event) do
    user_session = :global.whereis_name(event.fingerprint)

    if is_pid(user_session) do
      GenServer.cast(user_session, {:on_event, event})
    else
      GenServer.start_link(__MODULE__, event, name: {:global, event.fingerprint})
    end
  end

  def on_unload(fingerprint, timestamp) do
    user_session = :global.whereis_name(fingerprint)

    if is_pid(user_session) do
      GenServer.cast(user_session, {:on_unload, timestamp})
    end
  end

  def init(event) do
    timer = Process.send_after(self(), :finalize, @session_timeout)
    {:ok, %{first_event: event, last_event: event, timer: timer, is_bounce: true, last_unload: nil}}
  end

  def handle_cast({:on_event, event}, state) do
    Process.cancel_timer(state[:timer])
    new_timer = Process.send_after(self(), :finalize, @session_timeout)
    {:noreply, %{state | timer: new_timer, last_event: event, is_bounce: false, last_unload: nil}}
  end

  def handle_cast({:on_unload, timestamp}, state) do
    {:noreply, %{state | last_unload: timestamp}}
  end

  def handle_info(:finalize, state) do
    first_event = state[:first_event]
    last_event = state[:last_event]

    if !is_potential_leftover?(first_event) do
      length = if state[:last_unload] do
        Timex.diff(state[:last_unload], first_event.timestamp, :seconds)
      end

      changeset = Plausible.FingerprintSession.changeset(%Plausible.FingerprintSession{}, %{
        hostname: first_event.hostname,
        domain: first_event.domain,
        fingerprint: first_event.fingerprint,
        entry_page: first_event.pathname,
        exit_page: last_event.pathname,
        is_bounce: state[:is_bounce],
        length: length,
        referrer: first_event.referrer,
        referrer_source: first_event.referrer_source,
        country_code: first_event.country_code,
        operating_system: first_event.operating_system,
        browser: first_event.browser,
        start: first_event.timestamp
      })

      Repo.insert!(changeset)
    end

    {:stop, :normal, state}
  end

  defp is_potential_leftover?(%{timestamp: timestamp}) do
    server_start_time = Application.get_env(:plausible, :server_start)
    Timex.diff(timestamp, server_start_time, :milliseconds) < @session_timeout
  end

end
