defmodule Plausible.Session.CacheStore do
  require Logger
  alias Plausible.Session.WriteBuffer

  def on_event(event, prev_user_id) do
    found_session =
      find_session(event.domain, event.user_id) || find_session(event.domain, prev_user_id)

    session =
      if found_session do
        updated_session = update_session(found_session, event)
        WriteBuffer.insert([%{updated_session | sign: 1}, %{found_session | sign: -1}])
        persist_session(updated_session)
      else
        new_session = new_session_from_event(event)
        WriteBuffer.insert([new_session])
        persist_session(new_session)
      end

    session.session_id
  end

  defp find_session(_domain, nil), do: nil

  defp find_session(domain, user_id) do
    case Cachex.get(:sessions, {domain, user_id}) do
      {:ok, val} ->
        val

      {:error, e} ->
        Sentry.capture_message("Cachex error", extra: %{error: e})
        nil
    end
  end

  defp persist_session(session) do
    key = {session.domain, session.user_id}
    Cachex.put(:sessions, key, session, ttl: session_length_ms())
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
        country_code:
          if(session.country_code == "", do: event.country_code, else: session.country_code),
        subdivision1_code:
          if(session.subdivision1_code == "",
            do: event.subdivision1_code,
            else: session.subdivision1_code
          ),
        subdivision2_code:
          if(session.subdivision2_code == "",
            do: event.subdivision2_code,
            else: session.subdivision2_code
          ),
        city_geoname_id:
          if(session.city_geoname_id == 0,
            do: event.city_geoname_id,
            else: session.city_geoname_id
          ),
        operating_system:
          if(session.operating_system == "",
            do: event.operating_system,
            else: session.operating_system
          ),
        operating_system_version:
          if(session.operating_system_version == "",
            do: event.operating_system_version,
            else: session.operating_system_version
          ),
        browser: if(session.browser == "", do: event.browser, else: session.browser),
        browser_version:
          if(session.browser_version == "",
            do: event.browser_version,
            else: session.browser_version
          ),
        screen_size:
          if(session.screen_size == "", do: event.screen_size, else: session.screen_size),
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
      start: event.timestamp
    }
  end

  defp session_length_ms(),
    do: Application.get_env(:plausible, :session_length_minutes) * 60 * 100
end
