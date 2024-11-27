defmodule PlausibleWeb.Plugs.AuthorizeSiteAccessTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  alias PlausibleWeb.Plugs.AuthorizeSiteAccess

  setup [:create_user, :log_in, :create_site]

  test "init rejects invalid role names" do
    assert_raise ArgumentError, fn ->
      AuthorizeSiteAccess.init(_allowed_roles = [:admin, :invalid])
    end
  end

  for init_argument <- [
        [],
        :all_roles,
        {:all_roles, nil},
        {[:public, :viewer, :admin, :editor, :super_admin, :owner], nil}
      ] do
    test "init resolves to expected options with argument #{inspect(init_argument)}" do
      assert {[:public, :viewer, :admin, :editor, :super_admin, :owner], nil} ==
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
    opts = AuthorizeSiteAccess.init(:all_roles)

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/invalid.domain/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "rejects user completely unrelated to the site", %{conn: conn} do
    opts = AuthorizeSiteAccess.init(:all_roles)

    site = new_site()

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
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
      AuthorizeSiteAccess.init({:all_roles, "some_key"})

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/basic", %{"wrong_key" => site.domain})
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
      AuthorizeSiteAccess.init({:all_roles, "some_key"})

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/basic", %{"some_key" => site.domain})
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "doesn't allow bypassing :domain in path with :domain in query param", %{
    conn: conn,
    site: site
  } do
    other_site = new_site()

    opts = AuthorizeSiteAccess.init([:admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{other_site.domain}/with-domain", %{
        "domain" => site.domain
      })
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert conn.status == 404
    assert conn.path_params == %{"domain" => other_site.domain}
  end

  test "returns 404 with custom error message for failed API routes", %{conn: conn, user: user} do
    site = new_site()
    add_guest(site, user: user, role: :viewer)

    opts = AuthorizeSiteAccess.init([:admin, :owner, :super_admin])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/api-with-domain")
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
    shared_link_other_site = insert(:shared_link, site: new_site())

    params = %{"shared_link" => %{"name" => "some name"}}

    opts = AuthorizeSiteAccess.init([:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/shared-link/#{shared_link_other_site.slug}", params)
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
    other_site = new_site(owner: user)

    opts = AuthorizeSiteAccess.init([:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{other_site.domain}/with-domain", %{"auth" => shared_link.slug})
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

    opts = AuthorizeSiteAccess.init([:super_admin, :admin, :owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/shared-link/#{shared_link_other_site.slug}", params)
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert conn.status == 404
  end

  test "rejects user on mismatched membership role", %{conn: conn, user: user} do
    site = new_site()
    add_guest(site, user: user, role: :editor)

    opts = AuthorizeSiteAccess.init([:owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    assert conn.halted
    assert html_response(conn, 404)
  end

  test "allows user based on ownership", %{conn: conn, user: user} do
    site = new_site(owner: user)

    opts = AuthorizeSiteAccess.init([:owner])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
    assert conn.assigns.current_user_role == :owner
  end

  for role <- [:viewer, :editor] do
    test "allows user based on their #{role} membership", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: unquote(role))

      opts = AuthorizeSiteAccess.init([unquote(role)])

      conn =
        conn
        |> bypass_through(PlausibleWeb.Router)
        |> get("/plug-tests/#{site.domain}/with-domain")
        |> AuthorizeSiteAccess.call(opts)

      refute conn.halted
      assert conn.assigns.site.id == site.id
      assert conn.assigns.current_user_role == unquote(role)
    end
  end

  @tag :ee_only
  test "allows user based on their superadmin status", %{conn: conn, user: user} do
    site = new_site()

    patch_env(:super_admin_user_ids, [user.id])

    opts = AuthorizeSiteAccess.init([:super_admin])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
    assert conn.assigns.current_user_role == :super_admin
  end

  test "allows user based on website visibility (authenticated user)", %{conn: conn} do
    site = new_site(public: true)

    opts = AuthorizeSiteAccess.init([:public])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on website visibility (anonymous request)" do
    site = insert(:site, members: [build(:user)], public: true)

    opts = AuthorizeSiteAccess.init([:public])

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain")
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (authenticated user)", %{conn: conn} do
    site = new_site()
    shared_link = insert(:shared_link, site: site)

    opts = AuthorizeSiteAccess.init([:public])

    conn =
      conn
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end

  test "allows user based on shared link auth (anonymous request)" do
    site = insert(:site, members: [build(:user)])
    shared_link = insert(:shared_link, site: site)

    opts = AuthorizeSiteAccess.init([:public])

    conn =
      build_conn()
      |> bypass_through(PlausibleWeb.Router)
      |> get("/plug-tests/#{site.domain}/with-domain", %{"auth" => shared_link.slug})
      |> AuthorizeSiteAccess.call(opts)

    refute conn.halted
    assert conn.assigns.site.id == site.id
  end
end
