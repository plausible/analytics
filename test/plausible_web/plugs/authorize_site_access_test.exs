defmodule PlausibleWeb.Plugs.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: false
  alias PlausibleWeb.Plugs.AuthorizeSiteAccess

  setup [:create_user, :log_in, :create_site]

  test "init rejects invalid role names" do
    assert_raise ArgumentError, fn ->
      AuthorizeSiteAccess.init(_allowed_roles = [:admin, :invalid])
    end
  end

  test "returns 404 on non-existent site", %{conn: conn} do
    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/invalid.domain")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [])

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "rejects user completely unrelated to the site", %{conn: conn} do
    site = insert(:site, members: [build(:user)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [])

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "doesn't allow bypassing :domain in path with :domain in query param", %{
    conn: conn,
    site: site
  } do
    other_site = insert(:site, members: [build(:user)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/sites/#{other_site.domain}/change-domain", %{
        "domain" => site.domain
      })
      |> AuthorizeSiteAccess.call(_allowed_roles = [:admin, :owner])

    assert conn.halted
    assert conn.status == 404
    assert conn.path_params == %{"domain" => other_site.domain}
  end

  test "returns 404 with custom error message for failed API routes", %{conn: conn, user: user} do
    site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/api/stats/#{site.domain}/main-graph")
      |> AuthorizeSiteAccess.call([:admin, :owner, :super_admin])

    assert conn.halted

    assert json_response(conn, 404) == %{
             "error" => "Site does not exist or user does not have sufficient access."
           }
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

  test "rejects user not permitted to site trying to use unrelated shared link for another one",
       %{
         conn: conn,
         user: user,
         site: site
       } do
    shared_link = insert(:shared_link, site: site)
    other_site = insert(:site, members: [user])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{other_site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [])

    assert conn.halted
    assert conn.status == 404
  end

  test "doesn't allow bypassing :slug in path with :slug or :auth in query param", %{
    conn: conn,
    site: site
  } do
    shared_link = insert(:shared_link, site: site)
    shared_link_other_site = insert(:shared_link, site: build(:site))

    params = %{
      "shared_link" => %{"name" => "some name"},
      "slug" => shared_link.slug,
      "auth" => shared_link.slug
    }

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> put("/sites/#{site.domain}/shared-links/#{shared_link_other_site.slug}", params)
      |> AuthorizeSiteAccess.call(_allowed_roles = [:super_admin, :admin, :owner])

    assert conn.halted
    assert conn.status == 404
  end

  test "rejects user on mismatched membership role", %{conn: conn, user: user} do
    site =
      insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:owner])

    assert conn.halted
    assert html_response(conn, 404)
  end

  for role <- [:viewer, :admin, :owner] do
    test "allows user based on their #{role} membership", %{conn: conn, user: user} do
      site =
        insert(:site, memberships: [build(:site_membership, user: user, role: unquote(role))])

      conn =
        conn
        |> bypass_through(PlausibleWeb.Router)
        |> get("/#{site.domain}")
        |> AuthorizeSiteAccess.call(_all_allowed_roles = [unquote(role)])

      refute conn.halted
      assert conn.assigns.site.id == site.id
      assert conn.assigns.current_user_role == unquote(role)
    end
  end

  @tag :ee_only
  test "allows user based on their superadmin status", %{conn: conn, user: user} do
    site = insert(:site, members: [build(:user)])

    patch_env(:super_admin_user_ids, [user.id])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:super_admin])

    refute conn.halted
    assert conn.assigns.site.id == site.id
    assert conn.assigns.current_user_role == :super_admin
  end

  test "allows user based on website visibility (authenticated user)", %{conn: conn} do
    site = insert(:site, members: [build(:user)], public: true)

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:public])

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on website visibility (anonymous request)" do
    site = insert(:site, members: [build(:user)], public: true)

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:public])

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (authenticated user)", %{conn: conn} do
    site = insert(:site, members: [build(:user)])
    shared_link = insert(:shared_link, site: site)

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:public])

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (anonymous request)" do
    site = insert(:site, members: [build(:user)])
    shared_link = insert(:shared_link, site: site)

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(_all_allowed_roles = [:public])

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end
end
