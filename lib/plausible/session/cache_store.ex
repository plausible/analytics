defmodule Plausible.Session.CacheStore do
  require Logger
  alias Plausible.Session.WriteBuffer

  def on_event(event, prev_user_id, buffer \\ WriteBuffer) do
    found_session = find_session(event, event.user_id) || find_session(event, prev_user_id)

    session =
      if found_session do
        updated_session = update_session(found_session, event)
        buffer.insert([%{updated_session | sign: 1}, %{found_session | sign: -1}])
        persist_session(updated_session)
      else
        new_session = new_session_from_event(event)
        buffer.insert([new_session])
        persist_session(new_session)
      end

    session.session_id
  end

  defp find_session(_domain, nil), do: nil

  defp find_session(event, user_id) do
    case Cachex.get(:sessions, {event.domain, user_id}) do
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
    key = {session.domain, session.user_id}
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
        country_code: session.country_code || event.country_code,
        subdivision1_code: session.subdivision1_code || event.subdivision1_code,
        subdivision2_code: session.subdivision2_code || event.subdivision2_code,
        city_geoname_id: session.city_geoname_id || event.city_geoname_id,
        operating_system: session.operating_system || event.operating_system,
        operating_system_version:
          session.operating_system_version || event.operating_system_version,
        browser: session.browser || event.browser,
        browser_version: session.browser_version || event.browser_version,
        screen_size: session.screen_size || event.screen_size,
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
      utm_medium: event.utm_medium,
      utm_source: event.utm_source,
      utm_campaign: event.utm_campaign,
      utm_content: event.utm_content,
      utm_term: event.utm_term,
      country_code: event.country_code,
      subdivision1_code: event.subdivision1_code,
      subdivision2_code: event.subdivision2_code,
      city_geoname_id: event.city_geoname_id,
      screen_size: event.screen_size,
      operating_system: event.operating_system,
      operating_system_version: event.operating_system_version,
      browser: event.browser,
      browser_version: event.browser_version,
      timestamp: event.timestamp,
      start: event.timestamp,
      "entry_meta.key": Map.get(event, :"meta.key"),
      "entry_meta.value": Map.get(event, :"meta.value")
    }
  end
end
