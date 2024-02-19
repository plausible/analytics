defmodule Plausible.Session.CacheStore do
  require Logger
  alias Plausible.Session.WriteBuffer

  def on_event(event, session_attributes, prev_user_id, buffer \\ WriteBuffer) do
    found_session = find_session(event, event.user_id) || find_session(event, prev_user_id)

    session =
      if found_session do
        updated_session = update_session(found_session, event)
        buffer.insert([%{found_session | sign: -1}, %{updated_session | sign: 1}])
        persist_session(updated_session)
      else
        new_session = new_session_from_event(event, session_attributes)
        buffer.insert([new_session])
        persist_session(new_session)
      end

    session.session_id
  end

  defp find_session(_domain, nil), do: nil

  defp find_session(event, user_id) do
    from_cache = Cachex.get(:sessions, {event.site_id, user_id})

    case from_cache do
      {:ok, nil} ->
        nil

      {:ok, session} ->
        if Timex.diff(event.timestamp, session.timestamp, :minutes) <= 30 do
          session
        end

      {:error, e} ->
        Sentry.capture_message("Cachex error", extra: %{error: e})
        nil
    end
  end

  defp persist_session(session) do
    key = {session.site_id, session.user_id}
    Cachex.put(:sessions, key, session, ttl: :timer.minutes(30))
    session
  end

  defp update_session(session, event) do
    %{
      session
      | user_id: event.user_id,
        timestamp: event.timestamp,
        exit_page: event.pathname,
        is_bounce: false,
        duration: Timex.diff(event.timestamp, session.start, :second) |> abs,
        pageviews:
          if(event.name == "pageview", do: session.pageviews + 1, else: session.pageviews),
        events: session.events + 1
    }
  end

  defp new_session_from_event(event, session_attributes) do
    %Plausible.ClickhouseSessionV2{
      sign: 1,
      session_id: Plausible.ClickhouseSessionV2.random_uint64(),
      hostname: event.hostname,
      site_id: event.site_id,
      user_id: event.user_id,
      entry_page: event.pathname,
      exit_page: event.pathname,
      is_bounce: true,
      duration: 0,
      pageviews: if(event.name == "pageview", do: 1, else: 0),
      events: 1,
      referrer: Map.get(session_attributes, :referrer),
      referrer_source: Map.get(session_attributes, :referrer_source),
      utm_medium: Map.get(session_attributes, :utm_medium),
      utm_source: Map.get(session_attributes, :utm_source),
      utm_campaign: Map.get(session_attributes, :utm_campaign),
      utm_content: Map.get(session_attributes, :utm_content),
      utm_term: Map.get(session_attributes, :utm_term),
      country_code: Map.get(session_attributes, :country_code),
      subdivision1_code: Map.get(session_attributes, :subdivision1_code),
      subdivision2_code: Map.get(session_attributes, :subdivision2_code),
      city_geoname_id: Map.get(session_attributes, :city_geoname_id),
      screen_size: Map.get(session_attributes, :screen_size),
      operating_system: Map.get(session_attributes, :operating_system),
      operating_system_version: Map.get(session_attributes, :operating_system_version),
      browser: Map.get(session_attributes, :browser),
      browser_version: Map.get(session_attributes, :browser_version),
      timestamp: event.timestamp,
      start: event.timestamp,
      "entry_meta.key": Map.get(event, :"meta.key"),
      "entry_meta.value": Map.get(event, :"meta.value")
    }
  end
end
