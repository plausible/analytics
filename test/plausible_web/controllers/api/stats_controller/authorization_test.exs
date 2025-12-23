defmodule PlausibleWeb.Api.StatsController.AuthorizationTest do
  use PlausibleWeb.ConnCase, async: true

  describe "API authorization - as anonymous user" do
    test "returns 404 for a site that doesn't exist", %{conn: conn} do
      conn = init_session(conn)
      conn = get(conn, "/api/stats/fake-site.com/main-graph")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns 404 for private site", %{conn: conn} do
      conn = init_session(conn)
      site = insert(:site, public: false)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns stats for public site", %{conn: conn} do
      conn = init_session(conn)
      site = insert(:site, public: true)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert %{"plot" => _any} = json_response(conn, 200)
    end
  end

  describe "API authorization for shared links - as anonymous user" do
    test "returns 404 for non-existent shared link", %{conn: conn} do
      site = new_site()

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=does-not-exist")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns 200 for unlisted shared link without cookie", %{conn: conn} do
      site = new_site()
      link = insert(:shared_link, site: site)

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert %{"top_stats" => _any} = json_response(conn, 200)
    end

    test "returns 200 for password-protected link with valid cookie", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      token = Plausible.Auth.Token.sign_shared_link(link.slug)
      cookie_name = "shared-link-" <> link.slug

      conn =
        conn
        |> put_req_cookie(cookie_name, token)
        |> get("/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert %{"top_stats" => _any} = json_response(conn, 200)
    end

    test "returns 404 for password-protected link with invalid cookie value", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      other_link =
        insert(:shared_link,
          name: "other link",
          site: site,
          password_hash: Plausible.Auth.Password.hash("password")
        )

      other_link_token = Plausible.Auth.Token.sign_shared_link(other_link.slug)
      cookie_name = "shared-link-" <> link.slug

      conn =
        conn
        |> put_req_cookie(cookie_name, other_link_token)
        |> get("/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns 404 for password-protected link without cookie", %{conn: conn} do
      site = new_site()

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end
  end

  describe "Filter validation for limited view shared links" do
    test "returns 400 for limited view shared link if there are no filters", %{conn: conn} do
      site = new_site()

      segment = insert(:segment, site: site, type: :site, name: "Scandinavia")

      link =
        insert(:shared_link, site: site, segment: segment)

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert json_response(conn, 400) == %{
               "error" => "The first filter must be for the segment with id #{segment.id}"
             }
    end

    test "returns 400 for limited view shared link if the segment filter is not for the right segment",
         %{conn: conn} do
      site = new_site()

      segment = insert(:segment, site: site, type: :site, name: "Scandinavia")

      link =
        insert(:shared_link, site: site, segment: segment)

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}&filters=#{JSON.encode!([["is", "segment", [segment.id + 1]]])}"
        )

      assert json_response(conn, 400) == %{
               "error" => "The first filter must be for the segment with id #{segment.id}"
             }
    end

    test "returns 200 for limited view shared link if the required segment is present, permits other filters to be applied",
         %{conn: conn} do
      site = new_site()

      segment = insert(:segment, site: site, type: :site, name: "Scandinavia")

      link =
        insert(:shared_link, site: site, segment: segment)

      conn =
        get(
          conn,
          "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}&filters=#{JSON.encode!([["is", "segment", [segment.id]], ["is", "event:page", ["/docs"]]])}"
        )

      assert json_response(conn, 200)
    end
  end

  describe "API authorization - as logged in user" do
    setup [:create_user, :log_in]

    test "returns 404 for a site that doesn't exist", %{conn: conn} do
      conn = init_session(conn)
      conn = get(conn, "/api/stats/fake-site.com/main-graph/")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
    end

    test "returns 404 when user does not have access to site", %{conn: conn} do
      site = new_site()
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

      assert json_response(conn, 404) == %{
               "error" => "Site does not exist or user does not have sufficient access."
             }
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
