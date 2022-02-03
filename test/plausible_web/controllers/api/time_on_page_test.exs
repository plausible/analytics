defmodule PlausibleWeb.Api.VisitDurationTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  import Plausible.TestUtils

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  setup [:create_user, :log_in, :create_new_site]

  test "ends pageviews with enrich_event instead of the following pageview", %{conn: conn, site: site} do
    event_id = send_pageview(site.domain, "http://some.url", ~N[2022-01-01 00:00:00]) |> response(202)

    send_enrich_event(event_id, ~N[2022-01-01 00:00:10])
    send_enrich_event(event_id, ~N[2022-01-01 00:00:15])

    send_pageview(site.domain, "http://some.url/anotherpage", ~N[2022-01-01 00:00:50])

    Process.sleep(10)
    Plausible.Event.WriteBuffer.flush()

    # domain = site.domain
    # events = ClickhouseRepo.all(
    #   from e in "events_v2",
    #   where: e.domain == ^domain,
    #   select: [e.name, e.timestamp, e.session_id, e.duration]
    # ) |> IO.inspect()

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 15
  end

  test "custom events are not merged in events_v2 table", %{site: site} do

    send_custom_event(site.domain, ~N[2022-01-01 00:00:00], "custom event 1")
    send_custom_event(site.domain, ~N[2022-01-01 00:00:05], "custom event 2")
    send_custom_event(site.domain, ~N[2022-01-01 00:00:10], "custom event 3")

    Process.sleep(10)

    Plausible.Event.WriteBuffer.flush()

    domain = site.domain
    events = ClickhouseRepo.all(
      from e in "events_v2",
      where: e.domain == ^domain,
      select: e.name
    )

    assert length(events) == 3
    assert Enum.member?(events, "custom event 1")
    assert Enum.member?(events, "custom event 2")
    assert Enum.member?(events, "custom event 3")
  end

  test "ends duplicate multi-domain pageviews with one pageview_end event" do
    domain1 = "first.domain"
    domain2 = "second.domain"

    event_id = send_pageview(domain1 <> "," <> domain2, "http://some.url", ~N[2022-01-01 00:00:00]) |> response(202)
    send_enrich_event(event_id, ~N[2022-01-01 00:00:46])

    Process.sleep(10)
    Plausible.Event.WriteBuffer.flush()

    events = ClickhouseRepo.all(
      from e in "events_v2",
      where: e.domain == ^domain1 or e.domain == ^domain2,
      select: [e.domain, e.duration]
    )
    assert Enum.member?(events, [domain1, 46])
    assert Enum.member?(events, [domain2, 46])
  end

  test "pageview can end previous pageviews for mutliple domains" do
    domain1 = "first.domain"
    domain2 = "second.domain"

    send_pageview(domain1 <> "," <> domain2, "http://some.url/first", ~N[2022-01-01 00:00:00])
    send_pageview(domain1 <> "," <> domain2, "http://some.url/second", ~N[2022-01-01 00:00:20])
    send_pageview(domain1 <> "," <> domain2, "http://some.url/third", ~N[2022-01-01 00:00:50])

    Process.sleep(10)
    Plausible.Event.WriteBuffer.flush()

    events = ClickhouseRepo.all(
      from e in "events_v2",
      where: e.domain == ^domain1 or e.domain == ^domain2,
      select: [e.domain, e.pathname, e.duration]
    )

    assert Enum.member?(events, [domain1, "/first", 20])
    assert Enum.member?(events, [domain1, "/second", 30])
    assert Enum.member?(events, [domain1, "/third", 0])
    assert Enum.member?(events, [domain2, "/first", 20])
    assert Enum.member?(events, [domain2, "/second", 30])
    assert Enum.member?(events, [domain2, "/third", 0])
  end

  test "enrich without event_id is ignored" do
    conn = send_enrich_event(nil, ~N[2022-01-01 00:00:46])
    assert json_response(conn, 400) == %{
      "errors" => %{
        "event_id" => ["can't be blank"]
      }
    }
  end

  test "enrich with event_id not corresponding to any event is ignored" do
    conn = send_enrich_event("123", ~N[2022-01-01 00:00:46])
    assert response(conn, 202) == "Ignoring enrich event"
  end

  def send_pageview(domain, url, timestamp) do
    build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
          domain: domain,
          name: "pageview",
          url: url,
          timestamp: timestamp
        })
  end

  def send_enrich_event(event_id, timestamp) do
    build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
          name: "enrich",
          event_id: event_id,
          timestamp: timestamp
        })
  end

  def send_custom_event(domain, timestamp, name) do
    build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
          domain: domain,
          name: name,
          url: "http://some.url",
          timestamp: timestamp
        })
  end
end
