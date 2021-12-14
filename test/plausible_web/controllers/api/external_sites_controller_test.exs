defmodule PlausibleWeb.Api.ExternalSitesControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  setup %{conn: conn} do
    user = insert(:user)
    api_key = insert(:api_key, user: user, scopes: ["sites:provision:*"])
    conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")
    {:ok, user: user, api_key: api_key, conn: conn}
  end

  describe "POST /api/v1/sites" do
    test "can create a site", %{conn: conn} do
      conn =
        post(conn, "/api/v1/sites", %{
          "domain" => "some-site.domain",
          "timezone" => "Europe/Tallinn"
        })

      assert json_response(conn, 200) == %{
               "domain" => "some-site.domain",
               "timezone" => "Europe/Tallinn"
             }
    end

    test "timezone defaults to Etc/UTC", %{conn: conn} do
      conn =
        post(conn, "/api/v1/sites", %{
          "domain" => "some-site.domain"
        })

      assert json_response(conn, 200) == %{
               "domain" => "some-site.domain",
               "timezone" => "Etc/UTC"
             }
    end

    test "domain is required", %{conn: conn} do
      conn = post(conn, "/api/v1/sites", %{})

      assert json_response(conn, 400) == %{
               "error" => "domain can't be blank"
             }
    end

    test "does not allow creating more sites than the limit", %{conn: conn, user: user} do
      Application.put_env(:plausible, :site_limit, 3)
      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])

      conn =
        post(conn, "/api/v1/sites", %{
          "domain" => "some-site.domain",
          "timezone" => "Europe/Tallinn"
        })

      assert json_response(conn, 403) == %{
               "error" =>
                 "Your account has reached the limit of 3 sites per account. Please contact hello@plausible.io to unlock more sites."
             }
    end

    test "cannot access with a bad API key scope", %{conn: conn, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> post("/api/v1/sites", %{"site" => %{"domain" => "domain.com"}})

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
             }
    end
  end

  describe "DELETE /api/v1/sites/:site_id" do
    setup :create_new_site

    test "delete a site by it's domain", %{conn: conn, site: site} do
      conn = delete(conn, "/api/v1/sites/" <> site.domain)

      assert json_response(conn, 200) == %{"deleted" => true}
    end

    test "is 404 when site cannot be found", %{conn: conn} do
      conn = delete(conn, "/api/v1/sites/foobar.baz")

      assert json_response(conn, 404) == %{"error" => "Site could not be found"}
    end

    test "cannot delete a site that the user does not own", %{conn: conn, user: user} do
      site = insert(:site, members: [])
      insert(:site_membership, user: user, site: site, role: :admin)
      conn = delete(conn, "/api/v1/sites/" <> site.domain)

      assert json_response(conn, 404) == %{"error" => "Site could not be found"}
    end

    test "cannot access with a bad API key scope", %{conn: conn, site: site, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
        |> delete("/api/v1/sites/" <> site.domain)

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
             }
    end
  end

  describe "PUT /api/v1/sites/shared-links" do
    setup :create_site

    test "can add a shared link to a site", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          site_id: site.domain,
          name: "Wordpress"
        })

      res = json_response(conn, 200)
      assert res["name"] == "Wordpress"
      assert String.starts_with?(res["url"], "http://")
    end

    test "is idempotent find or create op", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          site_id: site.domain,
          name: "Wordpress"
        })

      %{"url" => url} = json_response(conn, 200)

      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          site_id: site.domain,
          name: "Wordpress"
        })

      assert %{"url" => ^url} = json_response(conn, 200)
    end

    test "returns 400 when site id missing", %{conn: conn} do
      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          name: "Wordpress"
        })

      res = json_response(conn, 400)
      assert res["error"] == "Parameter `site_id` is required to create a shared link"
    end

    test "returns 404 when site id is non existent", %{conn: conn} do
      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          name: "Wordpress",
          site_id: "bad"
        })

      res = json_response(conn, 404)
      assert res["error"] == "Site could not be found"
    end

    test "returns 404 when api key owner does not have permissions to create a shared link", %{
      conn: conn,
      site: site,
      user: user
    } do
      Repo.update_all(
        from(sm in Plausible.Site.Membership,
          where: sm.site_id == ^site.id and sm.user_id == ^user.id
        ),
        set: [role: :viewer]
      )

      conn =
        put(conn, "/api/v1/sites/shared-links", %{
          site_id: site.domain,
          name: "Wordpress"
        })

      res = json_response(conn, 404)
      assert res["error"] == "Site could not be found"
    end
  end

  describe "PUT /api/v1/sites/goals" do
    setup :create_site

    test "can add a goal as event to a site", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event",
          event_name: "Signup"
        })

      res = json_response(conn, 200)
      assert res["goal_type"] == "event"
      assert res["event_name"] == "Signup"
    end

    test "can add a goal as page to a site", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "page",
          page_path: "/signup"
        })

      res = json_response(conn, 200)
      assert res["goal_type"] == "page"
      assert res["page_path"] == "/signup"
    end

    test "is idempotent find or create op", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event",
          event_name: "Signup"
        })

      %{"id" => goal_id} = json_response(conn, 200)

      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event",
          event_name: "Signup"
        })

      assert %{"id" => ^goal_id} = json_response(conn, 200)
    end

    test "returns 400 when site id missing", %{conn: conn} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          goal_type: "event",
          event_name: "Signup"
        })

      res = json_response(conn, 400)
      assert res["error"] == "Parameter `site_id` is required to create a goal"
    end

    test "returns 404 when site id is non existent", %{conn: conn} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          goal_type: "event",
          event_name: "Signup",
          site_id: "bad"
        })

      res = json_response(conn, 404)
      assert res["error"] == "Site could not be found"
    end

    test "returns 404 when api key owner does not have permissions to create a goal", %{
      conn: conn,
      site: site,
      user: user
    } do
      Repo.update_all(
        from(sm in Plausible.Site.Membership,
          where: sm.site_id == ^site.id and sm.user_id == ^user.id
        ),
        set: [role: :viewer]
      )

      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event",
          event_name: "Signup"
        })

      res = json_response(conn, 404)
      assert res["error"] == "Site could not be found"
    end

    test "returns 400 when goal type missing", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          event_name: "Signup"
        })

      res = json_response(conn, 400)
      assert res["error"] == "Parameter `goal_type` is required to create a goal"
    end

    test "returns 400 when goal event name missing", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event"
        })

      res = json_response(conn, 400)
      assert res["error"] == "Parameter `event_name` is required to create a goal"
    end

    test "returns 400 when goal page path missing", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "page"
        })

      res = json_response(conn, 400)
      assert res["error"] == "Parameter `page_path` is required to create a goal"
    end
  end

  describe "DELETE /api/v1/sites/goals/:goal_id" do
    setup :create_new_site

    test "delete a goal by it's id", %{conn: conn, site: site} do
      conn =
        put(conn, "/api/v1/sites/goals", %{
          site_id: site.domain,
          goal_type: "event",
          event_name: "Signup"
        })

      %{"id" => goal_id} = json_response(conn, 200)

      conn =
        delete(conn, "/api/v1/sites/goals/#{goal_id}", %{
          site_id: site.domain
        })

      assert json_response(conn, 200) == %{"deleted" => true}
    end

    test "is 404 when goal cannot be found", %{conn: conn, site: site} do
      conn =
        delete(conn, "/api/v1/sites/goals/0", %{
          site_id: site.domain
        })

      assert json_response(conn, 404) == %{"error" => "Goal could not be found"}
    end

    test "cannot delete a goal belongs to a site that the user does not own", %{
      conn: conn,
      user: user
    } do
      site = insert(:site, members: [])
      insert(:site_membership, user: user, site: site, role: :viewer)

      conn =
        delete(conn, "/api/v1/sites/goals/1", %{
          site_id: site.domain
        })

      assert json_response(conn, 404) == %{"error" => "Site could not be found"}
    end

    test "cannot access with a bad API key scope", %{conn: conn, site: site, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")

      conn =
        delete(conn, "/api/v1/sites/goals/1", %{
          site_id: site.domain
        })

      assert json_response(conn, 401) == %{
               "error" =>
                 "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
             }
    end
  end
end
