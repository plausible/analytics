defmodule PlausibleWeb.Plugins.API.Controllers.CapabilitiesTest do
  use PlausibleWeb.PluginsAPICase, async: true
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
      resp = get(conn, Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))

      assert json_response(resp, 200) ==
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
    end

    test "bad token", %{conn: conn} do
      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate("foo", "bad token")
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))

      assert json_response(resp, 200) ==
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
    end
  end

  describe "authorized" do
    test "trial", %{conn: conn, site: site, token: token} do
      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate(site.domain, token)
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))

      assert json_response(resp, 200) ==
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
    end

    test "growth", %{conn: conn, site: site, token: token} do
      site = Plausible.Repo.preload(site, :owner)
      insert(:growth_subscription, user: site.owner)

      resp =
        conn
        |> put_req_header("content-type", "application/json")
        |> authenticate(site.domain, token)
        |> get(Routes.plugins_api_capabilities_url(PlausibleWeb.Endpoint, :index))

      assert json_response(resp, 200) ==
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
    end
  end
end
