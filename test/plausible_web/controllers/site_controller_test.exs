defmodule PlausibleWeb.SiteControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  import Plausible.TestUtils

  describe "GET /sites/new" do
    setup [:create_user, :log_in]

    test "shows the site form", %{conn: conn} do
      conn = get(conn, "/sites/new")
      assert html_response(conn, 200) =~ "Your website details"
    end
  end

  describe "POST /sites" do
    setup [:create_user, :log_in]

    test "creates the site with valid params", %{conn: conn} do
      conn = post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "cleans up the url", %{conn: conn} do
      conn = post(conn, "/sites", %{
        "site" => %{
          "domain" => "https://www.Example.com/",
          "timezone" => "Europe/London"
        }
      })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "renders form again when domain is missing", %{conn: conn} do
      conn = post(conn, "/sites", %{
        "site" => %{
          "timezone" => "Europe/London"
        }
      })

      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "renders form again when it is a duplicate domain", %{conn: conn} do
      insert(:site, domain: "example.com")

      conn = post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert html_response(conn, 200) =~ "has already been taken"
    end
  end

  describe "GET /:website/settings" do
    setup [:create_user, :log_in, :create_site]

    test "shows settings form", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings")

      assert html_response(conn, 200) =~ "Settings"
    end
  end

  describe "PUT /:website/settings" do
    setup [:create_user, :log_in, :create_site]

    test "updates the timezone", %{conn: conn, site: site} do
      put(conn, "/#{site.domain}/settings", %{
        "site" => %{
          "timezone" => "Europe/London"
        }
      })

      updated = Repo.get(Plausible.Site, site.id)
      assert updated.timezone == "Europe/London"
    end
  end

  describe "POST /sites/:website/make-public" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site public", %{conn: conn, site: site} do
      post(conn, "/sites/#{site.domain}/make-public")

      updated = Repo.get(Plausible.Site, site.id)
      assert updated.public
    end
  end

  describe "POST /sites/:website/make-private" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site private", %{conn: conn, site: site} do
      post(conn, "/sites/#{site.domain}/make-private")

      updated = Repo.get(Plausible.Site, site.id)
      refute updated.public
    end
  end

  describe "DELETE /:website" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the site and all pageviews", %{conn: conn, user: user, site: site} do
      pageview = insert(:pageview, hostname: site.domain)
      insert(:google_auth, user: user, site: site)

      delete(conn, "/#{site.domain}")

      refute Repo.exists?(from s in Plausible.Site, where: s.id == ^site.id)
      refute Repo.exists?(from e in Plausible.Event, where: e.id == ^pageview.id)
    end
  end

  describe "POST /:website/goals" do
    setup [:create_user, :log_in, :create_site]

    test "creates a pageview goal for the website", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/goals", %{
        goal: %{
          page_path: "/success",
          event_name: ""
        }
      })

      goal = Repo.one(Plausible.Goal)

      assert goal.name == "Visit /success"
      assert goal.event_name == nil
    end

    test "creates a custom event goal for the website", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/goals", %{
        goal: %{
          page_path: "",
          event_name: "Signup"
        }
      })

      goal = Repo.one(Plausible.Goal)

      assert goal.name == "Signup"
      assert goal.page_path == nil
    end
  end
end
