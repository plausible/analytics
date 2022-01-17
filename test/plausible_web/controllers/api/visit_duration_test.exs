defmodule PlausibleWeb.Api.VisitDurationTest do
  use PlausibleWeb.ConnCase
  use Plausible.ClickhouseRepo
  import Plausible.TestUtils

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"

  setup [:create_user, :log_in, :create_new_site]

  test "records the visit duration", %{conn: conn, site: site} do
    event_conn =
      build_conn()
      |> put_req_header("user-agent", @user_agent)
      |> post("/api/event", %{
        domain: site.domain,
        name: "pageview",
        url: "http://gigride.live/some-page",
        timestamp: ~N[2022-01-01 00:00:00]
      })

    event_id = response(event_conn, 202)
    build_conn()
    |> put_req_header("user-agent", @user_agent)
    |> post("/api/event", %{
      domain: site.domain,
      name: "pageview_end",
      event_id: event_id,
      timestamp: ~N[2022-01-01 00:00:10]
    })

    build_conn()
    |> put_req_header("user-agent", @user_agent)
    |> post("/api/event", %{
      domain: site.domain,
      name: "pageview_end",
      event_id: event_id,
      timestamp: ~N[2022-01-01 00:00:15]
    })

    Plausible.Event.WriteBuffer.flush()

    # At this point the database should have 5 entries with 3 state rows and 2 cancel rows.
    # SELECT sign * duration from events_v2 FINAL -> should return 15

    ClickhouseRepo.all(
      from e in "events_v2",
      where: e.event_id == ^event_id,
      select: [e.duration, e.timestamp, e.sign, e.domain]
    ) |> IO.inspect()

    conn =
      get(
        conn,
        "/api/stats/#{site.domain}/pages?period=day&date=2022-01-01&detailed=true"
      )

    assert List.first(json_response(conn, 200))["time_on_page"] == 15
  end
end
