defmodule PlausibleWeb.Plugins.API.Controllers.CapabilitiesTest do
  use PlausibleWeb.PluginsAPICase, async: true
  use Plausible.Teams.Test
  alias PlausibleWeb.Plugins.API.Schemas

  describe "examples" do
    test "Capabilities" do
      assert_schema(
        Schemas.Capabilities.schema().example,
        "Capabilities",
        spec()
      )
    end
  end

  describe "unauthorized" do
    test "no token", %{conn: conn} do
      resp =
        conn
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))
        |> json_response(200)

      assert resp ==
               %{
                 "authorized" => false,
                 "data_domain" => nil,
                 "features" => %{
                   "Funnels" => false,
                   "Goals" => false,
                   "Props" => false,
                   "RevenueGoals" => false,
                   "StatsAPI" => false
                 }
               }

      assert_schema(resp, "Capabilities", spec())
    end

    test "bad token", %{conn: conn} do
      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate("foo", "bad token")
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))
        |> json_response(200)

      assert resp ==
               %{
                 "authorized" => false,
                 "data_domain" => nil,
                 "features" => %{
                   "Funnels" => false,
                   "Goals" => false,
                   "Props" => false,
                   "RevenueGoals" => false,
                   "StatsAPI" => false
                 }
               }

      assert_schema(resp, "Capabilities", spec())
    end
  end

  describe "authorized" do
    test "trial", %{conn: conn, site: site, token: token} do
      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate(site.domain, token)
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))
        |> json_response(200)

      assert resp ==
               %{
                 "authorized" => true,
                 "data_domain" => site.domain,
                 "features" => %{
                   "Funnels" => true,
                   "Goals" => true,
                   "Props" => true,
                   "RevenueGoals" => true,
                   "StatsAPI" => true
                 }
               }

      assert_schema(resp, "Capabilities", spec())
    end

    @tag :ee_only
    test "growth", %{conn: conn, site: site, token: token} do
      site = Plausible.Repo.preload(site, :owner)
      subscribe_to_growth_plan(site.owner)

      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate(site.domain, token)
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))
        |> json_response(200)

      assert resp ==
               %{
                 "authorized" => true,
                 "data_domain" => site.domain,
                 "features" => %{
                   "Funnels" => false,
                   "Goals" => true,
                   "Props" => false,
                   "RevenueGoals" => false,
                   "StatsAPI" => false
                 }
               }

      assert_schema(resp, "Capabilities", spec())
    end
  end
end
