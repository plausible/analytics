defmodule PlausibleWeb.Api.ExternalSitesController.PropertiesTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  setup %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["events:read:*"])
    site = insert(:site, members: [user])
    cusom_event = insert(:goal, %{domain: site.domain, event_name: "404"})
    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

    {:ok, user: user, api_key: api_key, site: site, cusom_event: cusom_event, conn: conn}
  end

  test "event belonging to the domain is returned", %{
    conn: conn,
    site: site,
    cusom_event: cusom_event
  } do
    populate_stats([
      build(:event,
        name: "404",
        domain: site.domain,
        "meta.key": ["method"],
        "meta.value": ["HTTP"]
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
      |> get("/api/v1/events/#{cusom_event.id}/properties", %{"site_id" => site.domain})

    assert Enum.sort(json_response(conn, 200)["results"]) == ["OS", "method", "version"]
  end

  test "event not belonging to the domain is not returned", %{
    conn: conn,
    site: site
  } do
    event = insert(:goal, %{domain: "another-site.domain", event_name: "Signup"})

    conn =
      conn
      |> get("/api/v1/events/#{event.id}/properties", %{"site_id" => site.domain})

    assert json_response(conn, 404) == %{
             "error" => "Event could not be found"
           }
  end

  test "non existing event returns error message", %{
    conn: conn,
    site: site
  } do
    conn =
      conn
      |> get("/api/v1/events/-1/properties", %{"site_id" => site.domain})

    assert json_response(conn, 404) == %{
             "error" => "Event could not be found"
           }
  end
end
