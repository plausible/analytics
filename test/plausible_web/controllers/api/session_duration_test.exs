defmodule PlausibleWeb.Api.SessionDurationTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  import Plausible.TestUtils

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @pv_params %{
    domain: nil,
    ip: "1.1.1.1",
    url: "http://some.url",
    timestamp: ~N[2022-01-01 00:00:00]
  }

  setup [:create_user, :log_in, :create_new_site]

  test "enrich event updates visit_duration", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:10])
    Plausible.Session.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
    assert List.first(json_response(conn, 200))["visit_duration"] == 10
  end

  test "enrich after enrich updates visit_duration again", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:10])
    send_enrich(event_id, ~N[2022-01-01 00:00:15])
    send_enrich(event_id, ~N[2022-01-01 00:00:20])
    Plausible.Session.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
    assert List.first(json_response(conn, 200))["visit_duration"] == 20
  end

  test "pageview updates the visit_duration only for that session", %{conn: conn, site: site} do
    params = %{@pv_params | domain: site.domain}

    # initialize 3 different sessions with different user_id's and entry_pages
    send_pageview(%{params | ip: "1.1.1.1", url: "http://some.url/first"})
    send_pageview(%{params | ip: "1.1.1.2", url: "http://some.url/second"})
    send_pageview(%{params | ip: "1.1.1.3", url: "http://some.url/third"})

    # send another pageview with each user_id
    send_pageview(%{params | ip: "1.1.1.1", timestamp: ~N[2022-01-01 00:00:10]})
    send_pageview(%{params | ip: "1.1.1.2", timestamp: ~N[2022-01-01 00:00:20]})
    send_pageview(%{params | ip: "1.1.1.3", timestamp: ~N[2022-01-01 00:00:30]})

    Plausible.Session.WriteBuffer.flush()

    visit_durations =
      get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
      |> json_response(200)
      |> Enum.map(fn entry_page -> {entry_page["name"], entry_page["visit_duration"]} end)

    assert Enum.member?(visit_durations, {"/first", 10})
    assert Enum.member?(visit_durations, {"/second", 20})
    assert Enum.member?(visit_durations, {"/third", 30})
  end

  test "visit_duration is not updated when enrich event is ignored", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)

    "Ignoring enrich event" = send_enrich(event_id, ~N[2022-01-01 00:31:00]) |> response(202)
    Plausible.Session.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
    assert List.first(json_response(conn, 200))["visit_duration"] == 0
  end

  test "PV -> 10min -> enrich -> 10min -> new PV -> visit_duration is 20min", %{
    conn: conn,
    site: site
  } do
    params = %{@pv_params | domain: site.domain}

    event_id = send_pageview(params) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:10:00])

    send_pageview(%{
      params
      | url: "http://some.url/anotherpage",
        timestamp: ~N[2022-01-01 00:20:00]
    })

    Plausible.Session.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
    assert List.first(json_response(conn, 200))["visit_duration"] == 20 * 60
  end

  test "event with timestamp before session.timestamp will not create/update session", %{
    conn: conn,
    site: site
  } do
    params = %{@pv_params | domain: site.domain}

    send_pageview(%{params | url: "http://some.url", timestamp: ~N[2022-01-01 00:00:01]})

    send_pageview(%{
      params
      | url: "http://some.url/anotherpage",
        timestamp: ~N[2022-01-01 00:00:00]
    })

    Plausible.Session.WriteBuffer.flush()

    entry_page_stats =
      get(conn, "/api/stats/#{site.domain}/entry-pages?period=day&date=2022-01-01")
      |> json_response(200)

    assert length(entry_page_stats) == 1
    assert List.first(entry_page_stats)["name"] == "/"
    assert List.first(entry_page_stats)["visit_duration"] == 0
  end

  test "enrich updates session exit page", %{conn: conn, site: site} do
    params = %{@pv_params | domain: site.domain}

    first_pv_event_id =
      send_pageview(%{params | url: "http://some.url/first", timestamp: ~N[2022-01-01 00:00:00]})
      |> response(202)

    send_enrich(first_pv_event_id, ~N[2022-01-01 00:00:30])

    send_pageview(%{params | url: "http://some.url/second", timestamp: ~N[2022-01-01 00:01:00]})

    send_enrich(first_pv_event_id, ~N[2022-01-01 00:02:00])
    Plausible.Session.WriteBuffer.flush()

    exit_page_stats =
      get(conn, "/api/stats/#{site.domain}/exit-pages?period=day&date=2022-01-01")
      |> json_response(200)

    assert List.first(exit_page_stats)["name"] == "/first"
  end

  def send_pageview(params) do
    build_conn()
    |> put_req_header("user-agent", @user_agent)
    |> put_req_header("x-forwarded-for", params[:ip])
    |> post("/api/event", %{
      name: "pageview",
      domain: params[:domain],
      url: params[:url],
      timestamp: params[:timestamp]
    })
  end

  def send_enrich(event_id, timestamp) do
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
