defmodule PlausibleWeb.Api.StatsController.SharedLinkPasswordTest do
  use PlausibleWeb.ConnCase
  use Plausible.Teams.Test

  describe "API shared link password protection" do
    test "returns 403 for password-protected link without cookie", %{conn: conn} do

      site = new_site(domain: "test-site.com")

      link =
        insert(:shared_link, site: site, password_hash: Plausible.Auth.Password.hash("password"))

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert json_response(conn, 403) == %{"error" => "Unauthorized"}
    end

    test "returns 200 for password-protected link with valid cookie", %{conn: conn} do
      site = new_site(domain: "test-site.com")

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

    test "returns 200 for unlisted shared link without cookie", %{conn: conn} do
      site = new_site(domain: "test-site.com")
      link = insert(:shared_link, site: site)

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=#{link.slug}")

      assert %{"top_stats" => _any} = json_response(conn, 200)
    end

    test "returns 404 for non-existent shared link", %{conn: conn} do
      site = new_site(domain: "test-site.com")

      conn = get(conn, "/api/stats/#{site.domain}/top-stats?auth=does-not-exist")

      assert json_response(conn, 404) == %{"error" => "Site does not exist or user does not have sufficient access."}
    end
  end
end
