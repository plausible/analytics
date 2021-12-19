defmodule PlausibleWeb.Api.ExternalSitesController.EventsTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  setup %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["events:read:*"])
    site = insert(:site, members: [user])
    cusom_event = insert(:goal, %{domain: site.domain, event_name: "404"})
    pageview_event = insert(:goal, %{domain: site.domain, page_path: "/test"})
    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

    {:ok,
     user: user,
     api_key: api_key,
     site: site,
     cusom_event: cusom_event,
     pageview_event: pageview_event,
     conn: conn}
  end

  test "only events belonging to the domain are returned", %{
    conn: conn,
    site: site,
    pageview_event: pageview_event,
    cusom_event: cusom_event
  } do
    insert(:goal, %{domain: "another-site.domain", event_name: "Signup"})

    conn =
      conn
      |> get("/api/v1/events", %{"site_id" => site.domain})

    assert json_response(conn, 200) == %{
             "results" => [
               %{
                 "event_type" => "custom",
                 "id" => cusom_event.id,
                 "name" => "404",
                 "props" => []
               },
               %{
                 "event_type" => "pageview",
                 "id" => pageview_event.id,
                 "name" => "Visit /test",
                 "props" => []
               }
             ]
           }
  end

  test "custom properties are returned", %{
    conn: conn,
    site: site,
    pageview_event: pageview_event,
    cusom_event: cusom_event
  } do
    populate_stats([
      build(:pageview,
        domain: site.domain
      ),
      build(:event,
        name: "404",
        domain: site.domain,
        "meta.key": ["method"],
        "meta.value": ["HTTP"]
      ),
      build(:pageview,
        domain: site.domain,
        "meta.key": ["access_method"],
        "meta.value": ["HTTP"]
      ),
      build(:pageview,
        domain: site.domain,
        "meta.key": ["version"],
        "meta.value": ["4"]
      ),
      build(:event,
        name: "404",
        domain: site.domain,
        "meta.key": ["OS", "method"],
        "meta.value": ["Linux", "HTTP"]
      ),
      build(:event,
        name: "404",
        domain: site.domain,
        "meta.key": ["version"],
        "meta.value": ["1"]
      )
    ])

    conn =
      conn
      |> get("/api/v1/events", %{"site_id" => site.domain})

    res =
      Enum.map(json_response(conn, 200)["results"], fn item ->
        Map.update(item, "props", [], fn x -> Enum.sort(x) end)
      end)

    assert res == [
             %{
               "event_type" => "custom",
               "id" => cusom_event.id,
               "name" => "404",
               "props" => ["OS", "method", "version"]
             },
             %{
               "event_type" => "pageview",
               "id" => pageview_event.id,
               "name" => "Visit /test",
               "props" => []
             }
           ]
  end
end
