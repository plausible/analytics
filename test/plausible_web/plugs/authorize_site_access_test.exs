defmodule PlausibleWeb.Plugs.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: true
  alias PlausibleWeb.Plugs.AuthorizeSiteAccess

  setup [:create_user, :log_in, :create_site]

  test "doesn't allow :website bypass with :domain in body", %{conn: conn, site: site} do
    other_site = insert(:site, members: [build(:user)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{other_site.domain}/settings", %{"domain" => site.domain})
      |> AuthorizeSiteAccess.call(_allowed_roles = [:admin, :owner])

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

  test "rejects unrelated shared link slug even if user is permitted for site", %{
    conn: conn,
    site: site
  } do
    shared_link_other_site = insert(:shared_link, site: build(:site))

    params = %{"shared_link" => %{"name" => "some name"}}

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> put("/sites/#{site.domain}/shared-links/#{shared_link_other_site.slug}", params)
      |> AuthorizeSiteAccess.call(_allowed_roles = [:super_admin, :admin, :owner])

    assert conn.halted
    assert conn.status == 404
  end
end
