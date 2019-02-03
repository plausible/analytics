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
      Repo.insert!(%Plausible.Site{domain: "example.com", timezone: "Europe/London"})
      conn = post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert html_response(conn, 200) =~ "has already been taken"
    end
  end
end
