defmodule Plausible.SiteAdminTest do
  use Plausible.DataCase
  import Plausible.TestUtils
  alias Plausible.{SiteAdmin, ClickhouseRepo, ClickhouseEvent, ClickhouseSession}

  test "event and session structs remain the same after transfer" do
    from_site = insert(:site)
    to_site = insert(:site)

    populate_stats(from_site, [build(:pageview)])

    event_before = get_event_by_domain(from_site.domain)
    session_before = get_session_by_domain(from_site.domain)

    SiteAdmin.transfer_data([from_site], %{"domain" => to_site.domain})

    event_after = get_event_by_domain(to_site.domain)
    session_after = get_session_by_domain(to_site.domain)

    assert event_before == %ClickhouseEvent{event_after | transferred_from: ""}
    assert session_before == %ClickhouseSession{session_after | transferred_from: ""}
    assert event_after.transferred_from == from_site.domain
    assert session_after.transferred_from == from_site.domain
  end

  test "transfers all events and sessions" do
    from_site = insert(:site)
    to_site = insert(:site)

    populate_stats(from_site, [
      build(:pageview, user_id: 123),
      build(:event, name: "Signup", user_id: 123),
      build(:pageview, user_id: 456),
      build(:event, name: "Signup", user_id: 789)
    ])

    SiteAdmin.transfer_data([from_site], %{"domain" => to_site.domain})

    transferred_events =
      ClickhouseRepo.all(from e in Plausible.ClickhouseEvent, where: e.domain == ^to_site.domain)

    transferred_sessions =
      ClickhouseRepo.all(
        from e in Plausible.ClickhouseSession, where: e.domain == ^to_site.domain
      )

    assert length(transferred_events) == 4
    assert length(transferred_sessions) == 3
  end

  test "session_transfer_query" do
    actual = SiteAdmin.session_transfer_query("from.com", "to.com")

    expected =
      "INSERT INTO sessions (browser, browser_version, city_geoname_id, country_code, domain, duration, entry_page, events, exit_page, hostname, is_bounce, operating_system, operating_system_version, pageviews, referrer, referrer_source, screen_size, session_id, sign, start, subdivision1_code, subdivision2_code, timestamp, transferred_from, user_id, utm_campaign, utm_content, utm_medium, utm_source, utm_term) SELECT browser, browser_version, city_geoname_id, country_code, 'to.com' as domain, duration, entry_page, events, exit_page, hostname, is_bounce, operating_system, operating_system_version, pageviews, referrer, referrer_source, screen_size, session_id, sign, start, subdivision1_code, subdivision2_code, timestamp, 'from.com' as transferred_from, user_id, utm_campaign, utm_content, utm_medium, utm_source, utm_term FROM (SELECT * FROM sessions WHERE domain='from.com')"

    assert actual == expected
  end

  test "event_transfer_query" do
    actual = SiteAdmin.event_transfer_query("from.com", "to.com")

    expected =
      "INSERT INTO events (browser, browser_version, city_geoname_id, country_code, domain, hostname, meta.key, meta.value, name, operating_system, operating_system_version, pathname, referrer, referrer_source, screen_size, session_id, subdivision1_code, subdivision2_code, timestamp, transferred_from, user_id, utm_campaign, utm_content, utm_medium, utm_source, utm_term) SELECT browser, browser_version, city_geoname_id, country_code, 'to.com' as domain, hostname, meta.key, meta.value, name, operating_system, operating_system_version, pathname, referrer, referrer_source, screen_size, session_id, subdivision1_code, subdivision2_code, timestamp, 'from.com' as transferred_from, user_id, utm_campaign, utm_content, utm_medium, utm_source, utm_term FROM (SELECT * FROM events WHERE domain='from.com')"

    assert actual == expected
  end

  defp get_event_by_domain(domain) do
    q = from e in Plausible.ClickhouseEvent, where: e.domain == ^domain

    Plausible.ClickhouseRepo.one!(q)
    |> Map.drop([:__meta__, :domain])
  end

  defp get_session_by_domain(domain) do
    q = from s in Plausible.ClickhouseSession, where: s.domain == ^domain

    Plausible.ClickhouseRepo.one!(q)
    |> Map.drop([:__meta__, :domain])
  end
end
