defmodule Plausible.Ingestion.Session do
  @spec upsert_from_event(%Plausible.ClickhouseSession{} | nil, %Plausible.ClickhouseEvent{}) ::
          %Plausible.ClickhouseSession{}
  @doc """
  Builds and buffers a new session if it does not exist, or updates the existing one from an
  event.
  """
  def upsert_from_event(session_or_nil, event)

  def upsert_from_event(nil = _session, event) do
    session = %Plausible.ClickhouseSession{
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

    {:ok, [session]} = Plausible.Session.WriteBuffer.insert([session])

    session
  end

  def upsert_from_event(old_session, event) do
    updated = %{
      old_session
      | user_id: event.user_id,
        timestamp: event.timestamp,
        exit_page: event.pathname,
        is_bounce: false,
        duration: Timex.diff(event.timestamp, old_session.start, :second) |> abs,
        pageviews:
          if(event.name == "pageview", do: old_session.pageviews + 1, else: old_session.pageviews),
        country_code:
          if(old_session.country_code == "",
            do: event.country_code,
            else: old_session.country_code
          ),
        subdivision1_code:
          if(old_session.subdivision1_code == "",
            do: event.subdivision1_code,
            else: old_session.subdivision1_code
          ),
        subdivision2_code:
          if(old_session.subdivision2_code == "",
            do: event.subdivision2_code,
            else: old_session.subdivision2_code
          ),
        city_geoname_id:
          if(old_session.city_geoname_id == 0,
            do: event.city_geoname_id,
            else: old_session.city_geoname_id
          ),
        operating_system:
          if(old_session.operating_system == "",
            do: event.operating_system,
            else: old_session.operating_system
          ),
        operating_system_version:
          if(old_session.operating_system_version == "",
            do: event.operating_system_version,
            else: old_session.operating_system_version
          ),
        browser: if(old_session.browser == "", do: event.browser, else: old_session.browser),
        browser_version:
          if(old_session.browser_version == "",
            do: event.browser_version,
            else: old_session.browser_version
          ),
        screen_size:
          if(old_session.screen_size == "", do: event.screen_size, else: old_session.screen_size),
        events: old_session.events + 1
    }

    {:ok, [updated_session, _old_session]} =
      Plausible.Session.WriteBuffer.insert([%{updated | sign: 1}, %{old_session | sign: -1}])

    updated_session
  end
end
