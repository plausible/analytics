defmodule PlausibleWeb.Api.TimeOnPageTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  import Plausible.TestUtils

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @pv_params %{
    domain: nil,
    url: "http://some.url",
    timestamp: ~N[2022-01-01 00:00:00]
  }

  setup [:create_user, :log_in, :create_new_site]

  test "enrich event updates pageview duration", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:10])
    Plausible.Event.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 10
  end

  test "enrich after enrich updates time_on_page again", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:10])
    send_enrich(event_id, ~N[2022-01-01 00:00:15])
    send_enrich(event_id, ~N[2022-01-01 00:00:20])
    Plausible.Event.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 20
  end

  test "enrich after more than 30min from the pageview is ignored", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)

    "Ignoring enrich event" = send_enrich(event_id, ~N[2022-01-01 00:31:00]) |> response(202)
    Plausible.Event.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 0
  end

  test "enrich does not reset the 30min timer to keep events in memory", %{conn: conn, site: site} do
    event_id = send_pageview(%{@pv_params | domain: site.domain}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:20:00])

    "Ignoring enrich event" = send_enrich(event_id, ~N[2022-01-01 00:40:00]) |> response(202)
    Plausible.Event.WriteBuffer.flush()

    conn = get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
    assert List.first(json_response(conn, 200))["time_on_page"] == 20 * 60
  end

  test "pageview does not update the duration for a previous session event", %{
    conn: conn,
    site: site
  } do
    params = %{@pv_params | domain: site.domain}

    send_pageview(params)

    send_pageview(%{
      params
      | url: "http://some.url/anotherpage",
        timestamp: ~N[2022-01-01 00:40:00]
    })

    Plausible.Event.WriteBuffer.flush()

    root_page_stats =
      get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
      |> json_response(200)
      |> Enum.find(fn page -> page["name"] == "/" end)

    assert root_page_stats["time_on_page"] == 0
  end

  test "next pageview does not update the duration for already enriched event", %{
    conn: conn,
    site: site
  } do
    params = %{@pv_params | domain: site.domain}

    event_id = send_pageview(params) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:15])

    send_pageview(%{
      params
      | url: "http://some.url/anotherpage",
        timestamp: ~N[2022-01-01 00:00:50]
    })

    Plausible.Event.WriteBuffer.flush()

    root_page_stats =
      get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
      |> json_response(200)
      |> Enum.find(fn page -> page["name"] == "/" end)

    assert root_page_stats["time_on_page"] == 15
  end

  test "next pageview updates the duration of the first one if duration is 0", %{
    conn: conn,
    site: site
  } do
    params = %{@pv_params | domain: site.domain}

    send_pageview(params)

    send_pageview(%{
      params
      | url: "http://some.url/anotherpage",
        timestamp: ~N[2022-01-01 00:00:10]
    })

    Plausible.Event.WriteBuffer.flush()

    root_page_stats =
      get(conn, "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true")
      |> json_response(200)
      |> Enum.find(fn page -> page["name"] == "/" end)

    assert root_page_stats["time_on_page"] == 10
  end

  test "ends duplicate multi-domain pageviews with one enrich event" do
    domain1 = "first-1.domain"
    domain2 = "second-1.domain"

    event_id = send_pageview(%{@pv_params | domain: domain1 <> "," <> domain2}) |> response(202)
    send_enrich(event_id, ~N[2022-01-01 00:00:46])

    Plausible.Event.WriteBuffer.flush()

    events =
      ClickhouseRepo.all(
        from e in "events_v2",
          where: e.domain == ^domain1 or e.domain == ^domain2,
          select: [e.domain, e.duration]
      )

    assert Enum.member?(events, [domain1, 46])
    assert Enum.member?(events, [domain2, 46])
  end

  test "pageview can end previous pageviews for mutliple domains" do
    domain1 = "first-2.domain"
    domain2 = "second-2.domain"
    params = %{@pv_params | domain: domain1 <> "," <> domain2}

    send_pageview(%{params | url: "http://some.url/first", timestamp: ~N[2022-01-01 00:00:00]})
    send_pageview(%{params | url: "http://some.url/second", timestamp: ~N[2022-01-01 00:00:20]})
    send_pageview(%{params | url: "http://some.url/third", timestamp: ~N[2022-01-01 00:00:50]})

    Plausible.Event.WriteBuffer.flush()

    events =
      ClickhouseRepo.all(
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
    conn = send_enrich(nil, ~N[2022-01-01 00:00:46])

    assert json_response(conn, 400) == %{
             "errors" => %{
               "event_id" => ["can't be blank"]
             }
           }
  end

  test "enrich with event_id not corresponding to any event is ignored" do
    conn = send_enrich("123", ~N[2022-01-01 00:00:46])
    assert response(conn, 202) == "Ignoring enrich event"
  end

  test "custom events are not merged in events_v2 table", %{site: site} do
    send_custom_event(site.domain, ~N[2022-01-01 00:00:00], "custom event 1")
    send_custom_event(site.domain, ~N[2022-01-01 00:00:05], "custom event 2")
    send_custom_event(site.domain, ~N[2022-01-01 00:00:10], "custom event 3")

    Plausible.Event.WriteBuffer.flush()

    domain = site.domain

    events =
      ClickhouseRepo.all(
        from e in "events_v2",
          where: e.domain == ^domain,
          select: e.name
      )

    assert length(events) == 3
    assert Enum.member?(events, "custom event 1")
    assert Enum.member?(events, "custom event 2")
    assert Enum.member?(events, "custom event 3")
  end

  def send_pageview(params) do
    build_conn()
    |> put_req_header("user-agent", @user_agent)
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
