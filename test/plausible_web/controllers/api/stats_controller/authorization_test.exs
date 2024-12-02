defmodule PlausibleWeb.Api.StatsController.AuthorizationTest do
  use Plausible.Teams.Test
  use PlausibleWeb.ConnCase

  describe "API authorization - as anonymous user" do
    test "Sends 404 Not found for a site that doesn't exist", %{conn: conn} do
      conn = init_session(conn)
      conn = get(conn, "/api/stats/fake-site.com/main-graph")

      assert conn.status == 404
    end

    test "Sends 404 Not found for private site", %{conn: conn} do
      conn = init_session(conn)
      site = insert(:site, public: false)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert conn.status == 404
    end

    test "returns stats for public site", %{conn: conn} do
      conn = init_session(conn)
      site = insert(:site, public: true)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert %{"plot" => _any} = json_response(conn, 200)
    end
  end

  describe "API authorization - as logged in user" do
    setup [:create_user, :log_in]

    test "Sends 404 Not found for a site that doesn't exist", %{conn: conn} do
      conn = init_session(conn)
      conn = get(conn, "/api/stats/fake-site.com/main-graph/")

      assert conn.status == 404
    end

    test "Sends 404 Not found when user does not have access to site", %{conn: conn} do
      site = new_site()
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert conn.status == 404
    end

    test "returns stats for public site", %{conn: conn} do
      site = new_site(public: true)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert %{"plot" => _any} = json_response(conn, 200)
    end

    test "returns stats for a private site that the user owns", %{conn: conn, user: user} do
      site = new_site(public: false, owner: user)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert %{"plot" => _any} = json_response(conn, 200)
    end
  end
end
