defmodule PlausibleWeb.Api.InternalControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /api/:domain/status" do
    setup [:create_user, :log_in]

    test "is WAITING when site has no pageviews", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "WAITING"
    end

    test "is READY when site has at least 1 pageview", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      Plausible.TestUtils.create_pageviews([%{site: site}])

      conn = get(conn, "/api/#{site.domain}/status")

      assert json_response(conn, 200) == "READY"
    end
  end

  describe "GET /api/sites" do
    setup [:create_user, :log_in]

    test "returns a list of site domains for the current user", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      site2 = insert(:site, members: [user])
      conn = get(conn, "/api/sites")

      %{"data" => sites} = json_response(conn, 200)

      assert Enum.map(sites, & &1["domain"]) == [site.domain, site2.domain]
    end
  end

  describe "GET /api/sites - user not logged in" do
    test "returns 401 unauthorized", %{conn: conn} do
      conn = get(conn, "/api/sites")

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in to request a list of sites"
             }
    end
  end

  describe "GET /api/:domain/disable-feature" do
    setup [:create_user, :log_in]

    test "when the logged-in user is an admin of the site", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:site_membership, user: user, site: site, role: :admin)

      conn = get(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 200) == "ok"
      assert %{conversions_enabled: false} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "when the logged-in user is an owner of the site", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:site_membership, user: user, site: site, role: :owner)

      conn = get(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 200) == "ok"
      assert %{conversions_enabled: false} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "returns 401 when the logged-in user is a viewer of the site", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:site_membership, user: user, site: site, role: :viewer)

      conn = get(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end

    test "returns 401 when the logged-in user doesn't have site access at all", %{conn: conn} do
      site = insert(:site)

      conn = get(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end
  end

  describe "GET /api/:domain/disable-feature - user not logged in" do
    test "returns 401 unauthorized", %{conn: conn} do
      site = insert(:site)

      conn = get(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 401) == %{
               "error" => "You need to be logged in as the owner or admin account of this site"
             }

      assert %{conversions_enabled: true} = Plausible.Sites.get_by_domain(site.domain)
    end
  end
end
