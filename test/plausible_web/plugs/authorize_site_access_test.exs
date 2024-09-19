defmodule PlausibleWeb.Plugs.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: false
  alias PlausibleWeb.Plugs.AuthorizeSiteAccess

  setup [:create_user, :log_in, :create_site]

  test "init rejects invalid role names" do
    assert_raise ArgumentError, fn ->
      AuthorizeSiteAccess.init(_allowed_roles = [:admin, :invalid])
    end
  end

  for init_argument <- [[], {[:public, :viewer, :admin, :super_admin, :owner], nil}] do
    test "init resolves to expected options with argument #{inspect(init_argument)}" do
      assert {[:public, :viewer, :admin, :super_admin, :owner], nil} ==
               AuthorizeSiteAccess.init(unquote(init_argument))
    end
  end

  for invalid_site_param <- [[], 1, :invalid] do
    test "init rejects invalid site_param #{inspect(invalid_site_param)}" do
      assert_raise ArgumentError, fn ->
        AuthorizeSiteAccess.init({[:super_admin], unquote(invalid_site_param)})
      end
    end
  end

  test "returns 404 on non-existent site", %{conn: conn} do
    opts = AuthorizeSiteAccess.init(_all_allowed_roles = [])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/invalid.domain")
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "rejects user completely unrelated to the site", %{conn: conn} do
    opts = AuthorizeSiteAccess.init(_all_allowed_roles = [])

    site = insert(:site, members: [build(:user)])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "can be configured to expect site domain at conn.params['some_key'], fails when this is not met",
       %{
         conn: conn,
         site: site
       } do
    opts =
      AuthorizeSiteAccess.init({[:public, :viewer, :admin, :super_admin, :owner], "some_key"})

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/api/docs/query/schema.json", %{"wrong_key" => site.domain})
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert conn.status == 404
  end

  test "can be configured to expect site domain at conn.params['some_key'], succeeds when it is met",
       %{
         conn: conn,
         site: site
       } do
    opts =
      AuthorizeSiteAccess.init({[:public, :viewer, :admin, :super_admin, :owner], "some_key"})

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/api/docs/query/schema.json", %{"some_key" => site.domain})
      |> AuthorizeSiteAccess.call(opts)

    assert conn.status == 200
    assert conn.assigns.site.id == site.id
  end

  test "doesn't allow bypassing :domain in path with :domain in query param", %{
    conn: conn,
    site: site
  } do
    other_site = insert(:site, members: [build(:user)])

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/sites/#{other_site.domain}/change-domain", %{
        "domain" => site.domain
      })
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert conn.status == 404
    assert conn.path_params == %{"domain" => other_site.domain}
  end

  test "returns 404 with custom error message for failed API routes", %{conn: conn, user: user} do
    site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])

    opts = AuthorizeSiteAccess.init([:admin, :owner, :super_admin])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/api/stats/#{site.domain}/main-graph")
      |> AuthorizeSiteAccess.call(opts)

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

    opts = AuthorizeSiteAccess.init([:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> put("/sites/#{site.domain}/shared-links/#{shared_link_other_site.slug}", params)
      |> AuthorizeSiteAccess.call(opts)

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

    opts = AuthorizeSiteAccess.init([:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{other_site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(opts)

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

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> put("/sites/#{site.domain}/shared-links/#{shared_link_other_site.slug}", params)
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert conn.status == 404
  end

  test "rejects user on mismatched membership role", %{conn: conn, user: user} do
    site =
      insert(:site, memberships: [build(:site_membership, user: user, role: :admin)])

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert html_response(conn, 404)
  end

  for role <- [:viewer, :admin, :owner] do
    test "allows user based on their #{role} membership", %{conn: conn, user: user} do
      site =
        insert(:site, memberships: [build(:site_membership, user: user, role: unquote(role))])

      opts = AuthorizeSiteAccess.init(_allowed_roles = [unquote(role)])

      conn =
        conn
        |> bypass_through(PlausibleWeb.Router)
        |> get("/#{site.domain}")
        |> AuthorizeSiteAccess.call(opts)

      refute conn.halted
      assert conn.assigns.site.id == site.id
      assert conn.assigns.current_user_role == unquote(role)
    end
  end

  @tag :ee_only
  test "allows user based on their superadmin status", %{conn: conn, user: user} do
    site = insert(:site, members: [build(:user)])

    patch_env(:super_admin_user_ids, [user.id])

    opts = AuthorizeSiteAccess.init([:super_admin])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
    assert conn.assigns.current_user_role == :super_admin
  end

  test "allows user based on website visibility (authenticated user)", %{conn: conn} do
    site = insert(:site, members: [build(:user)], public: true)

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:public])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on website visibility (anonymous request)" do
    site = insert(:site, members: [build(:user)], public: true)

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:public])

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (authenticated user)", %{conn: conn} do
    site = insert(:site, members: [build(:user)])
    shared_link = insert(:shared_link, site: site)

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:public])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (anonymous request)" do
    site = insert(:site, members: [build(:user)])
    shared_link = insert(:shared_link, site: site)

    opts = AuthorizeSiteAccess.init(_allowed_roles = [:public])

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/#{site.domain}", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end
end
