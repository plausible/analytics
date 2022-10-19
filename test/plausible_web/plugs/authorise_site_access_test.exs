defmodule PlausibleWeb.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.AuthorizeSiteAccess

  setup [:create_user, :log_in]

  test "doesn't allow :website bypass with :domain in body", %{conn: conn, user: me} do
    my_site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

    other_site =
      insert(:site, memberships: [build(:site_membership, user: insert(:user), role: :owner)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{other_site.domain}/settings", %{"domain" => my_site.domain})
      |> AuthorizeSiteAccess.call(_allowed_roles = [:admin, :owner])

    assert conn.halted
    assert conn.status == 404
    assert conn.path_params == %{"website" => other_site.domain}
  end
end
