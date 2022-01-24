defmodule PlausibleWeb.Api.VisitDurationTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  import Plausible.TestUtils

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  setup [:create_user, :log_in, :create_new_site]

  test "records the visit duration", %{conn: conn, site: site} do
    event_id = send_pageview(site.domain, ~N[2022-01-01 00:00:00]) |> response(202)

    send_pageview_end(event_id, ~N[2022-01-01 00:00:10])
    send_pageview_end(event_id, ~N[2022-01-01 00:00:15])

    Process.sleep(10)
    Plausible.Event.WriteBuffer.flush()

    # At this point the database should have 5 entries with 3 state rows and 2 cancel rows.
    # SELECT sign * duration from events_v2 FINAL -> should return 15

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 15
  end

  test "custom events are not merged in events_v2 table", %{conn: conn, site: site} do

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

  test "ends duplicate multi-domain pageviews with one pageview_end event", %{conn: conn} do
    domain1 = "test-multiple-pageviews-end-1.com"
    domain2 = "test-multiple-pageviews-end-2.com"

    event_id = send_pageview(domain1 <> "," <> domain2, ~N[2022-01-01 00:00:00]) |> response(202)
    send_pageview_end(event_id, ~N[2022-01-01 00:00:46])

    Process.sleep(10)
    Plausible.Event.WriteBuffer.flush()

    events = ClickhouseRepo.all(
      from e in "events_v2",
      where: e.domain == ^domain1 or e.domain == ^domain2,
      select: [e.domain, e.duration]
    )
    assert Enum.member?(events, ["test-multiple-pageviews-end-1.com", 46])
    assert Enum.member?(events, ["test-multiple-pageviews-end-2.com", 46])
  end

  test "pageview_end without event_id is ignored", %{conn: conn} do
    conn = send_pageview_end(nil, ~N[2022-01-01 00:00:46])
    assert json_response(conn, 400) == %{
      "errors" => %{
        "event_id" => ["can't be blank"]
      }
    }
  end

  test "pageview_end with event_id not corresponding to any event is ignored", %{conn: conn} do
    conn = send_pageview_end("123", ~N[2022-01-01 00:00:46])
    assert response(conn, 202) == "Ignoring pageview_end event"
  end

  def send_pageview(domain, timestamp) do
    build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
          domain: domain,
          name: "pageview",
          url: "http://some.url",
          timestamp: timestamp
        })
  end

  def send_pageview_end(event_id, timestamp) do
    build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
          name: "pageview_end",
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
