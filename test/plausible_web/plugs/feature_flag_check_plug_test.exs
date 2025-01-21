defmodule PlausibleWeb.Plugs.FeatureFlagCheckPlugTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test
  alias PlausibleWeb.Plugs.{AuthorizeSiteAccess, FeatureFlagCheckPlug}

  setup [:create_user, :log_in, :create_site]

  test "returns 404 when any of the expected feature flags is not enabled", %{
    conn: conn,
    site: site
  } do
    # currently enabled flags are defined test/test_helper.exs
    required_flags =
      FeatureFlagCheckPlug.init([:missing_feature_flag, :channels, :saved_segments])

    conn =
      conn
      |> get_conn_with_current_user_and_site(site)
      |> FeatureFlagCheckPlug.call(required_flags)

    assert conn.halted
    assert %{"error" => "Not found"} == json_response(conn, 404)
  end

  test "passes conn when required flags are enabled", %{
    conn: conn,
    site: site
  } do
    # currently enabled flags are defined test/test_helper.exs
    required_flags = FeatureFlagCheckPlug.init([:channels, :saved_segments])

    conn =
      conn
      |> get_conn_with_current_user_and_site(site)
      |> FeatureFlagCheckPlug.call(required_flags)

    assert !conn.halted
  end

  defp get_conn_with_current_user_and_site(%Plug.Conn{} = conn, %Plausible.Site{} = site) do
    conn
    |> bypass_through(PlausibleWeb.Router)
    |> get("/plug-tests/api-basic?site=#{site.domain}")
    |> AuthorizeSiteAccess.call(AuthorizeSiteAccess.init({:all_roles, "site"}))
  end
end
