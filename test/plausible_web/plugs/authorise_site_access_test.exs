defmodule PlausibleWeb.Plugs.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.Plugs.AuthorizeSiteAccess

  setup [:create_user, :log_in]

  test "doesn't allow :website bypass with :domain in body", %{conn: conn, user: me} do
    my_site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

    other_site =
      insert(:site, memberships: [build(:site_membership, user: insert(:user), role: :owner)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{other_site.domain}/settings", %{"domain" => my_site.domain})
      |> AuthorizeSiteAccess.call([:admin, :owner])

    assert conn.halted
    assert conn.status == 404
    assert conn.path_params == %{"website" => other_site.domain}
  end

  test "returns 404 with custom error message for failed API routes", %{conn: conn, user: user} do
    site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/api/stats/#{site.domain}/main-graph")
      |> AuthorizeSiteAccess.call([:admin, :owner, :super_admin])

    assert conn.halted
    assert conn.status == 404

    assert conn.resp_body ==
             "{\"error\":\"Site does not exist or user does not have sufficient access.\"}"
  end
end
