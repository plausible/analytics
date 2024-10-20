defmodule Plausible.Session.CacheStore do
  require Logger
  alias Plausible.Session.WriteBuffer

  @lock_timeout 500

  @lock_telemetry_event [:plausible, :sessions, :cache, :lock]

  def lock_telemetry_event, do: @lock_telemetry_event

  def on_event(event, session_attributes, prev_user_id, buffer_insert \\ &WriteBuffer.insert/1)

  def on_event(%{name: "pageleave"} = event, _, prev_user_id, _) do
    # The `pageleave` event is currently experimental. In a real use case we would
    # probably want to update the session as well (e.g. `is_bounce` or `duration`).

    # However, for now we're only interested in finding out the success rate of
    # pageleave events. So these events will simply be inserted into the events
    # table with the session ID found from the cache. If there's no session, the
    # event will be dropped.
    found_session = find_session(event, event.user_id) || find_session(event, prev_user_id)

    if found_session do
      {:ok, found_session}
    else
      {:error, :no_session_for_pageleave}
    end
  end

  def on_event(event, session_attributes, prev_user_id, buffer_insert) do
    lock_requested_at = System.monotonic_time()

    Plausible.Cache.Adapter.with_lock(
      :sessions,
      {event.site_id, event.user_id},
      @lock_timeout,
      fn ->
        lock_duration = System.monotonic_time() - lock_requested_at
        :telemetry.execute(@lock_telemetry_event, %{duration: lock_duration}, %{})
        found_session = find_session(event, event.user_id) || find_session(event, prev_user_id)

        if found_session do
          updated_session = update_session(found_session, event)
          buffer_insert.([%{found_session | sign: -1}, %{updated_session | sign: 1}])
          persist_session(updated_session)
        else
          new_session = new_session_from_event(event, session_attributes)
          buffer_insert.([new_session])
          persist_session(new_session)
        end
      end
    )
  end

  defp find_session(_domain, nil), do: nil

  defp find_session(event, user_id) do
    from_cache = Plausible.Cache.Adapter.get(:sessions, {event.site_id, user_id})

    case from_cache do
      nil ->
        nil

      session ->
        if Timex.diff(event.timestamp, session.timestamp, :minutes) <= 30 do
          session
        end
    end
  end

  defp persist_session(session) do
    key = {session.site_id, session.user_id}
    Plausible.Cache.Adapter.put(:sessions, key, session, dirty?: true)
    session
  end

  defp update_session(session, event) do
    %{
      session
      | user_id: event.user_id,
        timestamp: event.timestamp,
        entry_page:
          if(session.entry_page == "" and event.name == "pageview",
            do: event.pathname,
            else: session.entry_page
          ),
        hostname:
          if(event.name == "pageview" and session.hostname == "",
            do: event.hostname,
            else: session.hostname
          ),
        exit_page: if(event.name == "pageview", do: event.pathname, else: session.exit_page),
        exit_page_hostname:
          if(event.name == "pageview", do: event.hostname, else: session.exit_page_hostname),
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
      hostname: if(event.name == "pageview", do: event.hostname, else: ""),
      site_id: event.site_id,
      user_id: event.user_id,
      entry_page: if(event.name == "pageview", do: event.pathname, else: ""),
      exit_page: if(event.name == "pageview", do: event.pathname, else: ""),
      exit_page_hostname: if(event.name == "pageview", do: event.hostname, else: ""),
      is_bounce: true,
      duration: 0,
      pageviews: if(event.name == "pageview", do: 1, else: 0),
      events: 1,
      referrer: Map.get(session_attributes, :referrer),
      channel: Map.get(session_attributes, :channel),
      click_id_source: Map.get(session_attributes, :click_id_source),
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
