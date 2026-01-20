defmodule PlausibleWeb.Plugs.AuthorizePublicAPITest do
  use PlausibleWeb.ConnCase, async: false

  import ExUnit.CaptureLog

  alias PlausibleWeb.Plugs.AuthorizePublicAPI
  alias Plausible.Repo

  setup %{conn: conn} do
    {:ok, conn: prepare_conn_for_auth(conn)}
  end

  test "halts with error when bearer token is missing", %{conn: conn} do
    conn =
      conn
      |> get("/")
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Missing API key."
  end

  test "halts with error when bearer token is invalid against read-only Stats API", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer invalid")
      |> get("/")
      |> assign(:api_scope, "stats:read:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
  end

  test "halts with error when bearer token is invalid", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Bearer invalid")
      |> get("/")
      |> assign(:api_scope, "sites:provision:*")
      |> AuthorizePublicAPI.call(nil)

    assert conn.halted
    assert json_response(conn, 401)["error"] =~ "Invalid API key."
  end

  for query_string <- ["?foo=bar", "?site_id", "?site_id="] do
    test "halts with error when requesting site context API without site_id parameter (query string: #{query_string})",
         %{conn: conn} do
      # `site_id` param is checked for nil or empty
      # for `api_context: :site` APIs before the key is verified,
      # therefore the key here doesn't matter
      key = "123"

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{key}")
        |> get("/#{unquote(query_string)}")
        |> assign(:api_context, :site)
        |> assign(:api_scope, "sites:read:*")
        |> AuthorizePublicAPI.call(nil)

      assert conn.halted
      assert json_response(conn, 400)["error"] =~ "Missing site ID."
    end
  end

  @tag :ee_only
  test "401 error has priority over 402 error", %{conn: conn} do
    user = new_user()
    _site = new_site(owner: user)
    api_key = insert_api_key(:team_scope_api_key, user: user)

    another_owner =
      new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [])

    another_site = new_site(owner: another_owner)

    conn =
      conn
      |> authorize(api_key, site: another_site, api_context: :site, api_scope: "stats:read:*")

    assert conn.halted

    assert json_response(conn, 401)["error"] =~
             "Invalid API key or site ID. Please make sure you're using a valid API key with access to the site you've requested."
  end

  for key_type <- [:legacy_api_key, :team_scope_api_key] do
    describe "#{key_type} ::" do
      test "halts with error on missing site ID when request made for stats:read:* scope API, even without :site API context set",
           %{conn: conn} do
        api_key = insert_api_key(unquote(key_type), user: new_user())

        conn =
          conn
          |> authorize(Map.put(api_key, :key, "123"), api_scope: "stats:read:*")

        assert conn.halted
        assert json_response(conn, 400)["error"] =~ "Missing site ID."
      end

      @tag :ee_only
      test "halts with error when site's team lacks feature access", %{conn: conn} do
        user = new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [])
        site = new_site(owner: user)
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn
          |> authorize(api_key, api_scope: "stats:read:*", site: site)

        assert conn.halted

        assert json_response(conn, 402)["error"] =~
                 "The account that owns this API key does not have access"
      end

      on_ee do
        test "rejects access to a site that is a consolidated view (unless instructed otherwise)",
             %{
               conn: conn
             } do
          user = new_user()
          api_key = insert_api_key(unquote(key_type), user: user, scopes: ["sites:provision:*"])
          {:ok, team} = new_user() |> Plausible.Teams.get_or_create()
          new_site(team: team)
          new_site(team: team)
          consolidated_view = new_consolidated_view(team)

          conn =
            conn
            |> authorize(api_key, site: consolidated_view, api_scope: "sites:provision:*")

          assert conn.halted

          assert json_response(conn, 400)["error"] =~
                   "This operation is unavailable for a consolidated view"
        end
      end

      @tag :ee_only
      test "halts with error when upgrade is required", %{conn: conn} do
        user = new_user() |> subscribe_to_enterprise_plan(paddle_plan_id: "123321", features: [])
        site = new_site(owner: user)
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn |> authorize(api_key, site: site, api_scope: "stats:read:*")

        assert conn.halted

        assert json_response(conn, 402)["error"] =~
                 "The account that owns this API key does not have access"
      end

      test "halts with error when site is locked", %{conn: conn} do
        user = new_user()
        site = new_site(owner: user)
        site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn
          |> authorize(api_key, site: site, api_scope: "stats:read:*")

        assert conn.halted
        assert json_response(conn, 402)["error"] =~ "This Plausible site is locked"
      end

      test "halts with error when site ID is invalid", %{conn: conn} do
        user = new_user(trial_expiry_date: Date.utc_today())
        _site = new_site(owner: user)
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn
          |> authorize(api_key, site: %{domain: "invalid.domain"}, api_scope: "stats:read:*")

        assert conn.halted
        assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
      end

      test "halts with error when API key owner does not have access to the requested site", %{
        conn: conn
      } do
        user = new_user(trial_expiry_date: Date.utc_today())
        site = new_site()
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn
          |> authorize(api_key, site: site, api_scope: "stats:read:*")

        assert conn.halted
        assert json_response(conn, 401)["error"] =~ "Invalid API key or site ID."
      end

      test "halts with error when API lacks required scope", %{conn: conn} do
        user = insert(:user)
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn |> authorize(api_key, api_scope: "sites:provision:*")

        assert conn.halted
        assert json_response(conn, 401)["error"] =~ "Invalid API key."
      end

      test "passes and sets current user when valid API key with required scope provided", %{
        conn: conn
      } do
        user = insert(:user)
        api_key = insert_api_key(unquote(key_type), user: user, scopes: ["sites:provision:*"])

        conn =
          conn
          |> authorize(api_key, api_scope: "sites:provision:*")

        refute conn.halted
        assert conn.assigns.current_user.id == user.id
      end

      test "passes and sets current user and site when valid API key and site ID provided", %{
        conn: conn
      } do
        user = new_user()
        site = new_site(owner: user)
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn
          |> authorize(api_key, site: site, api_scope: "stats:read:*")

        refute conn.halted
        assert conn.assigns.current_user.id == user.id
        assert conn.assigns.site.id == site.id
      end

      @tag :ee_only
      test "passes for super admin user even if not a member of the requested site", %{conn: conn} do
        user = new_user()
        patch_env(:super_admin_user_ids, [user.id])
        site = new_site()
        site.team |> Ecto.Changeset.change(locked: true) |> Repo.update!()
        api_key = insert_api_key(unquote(key_type), user: user)

        conn =
          conn |> authorize(api_key, site: site, api_scope: "stats:read:*")

        refute conn.halted
        assert conn.assigns.current_user.id == user.id
        assert conn.assigns.site.id == site.id
      end

      test "passes for subscope match", %{conn: conn} do
        user = insert(:user)
        api_key = insert_api_key(unquote(key_type), user: user, scopes: ["funnels:*"])

        conn =
          conn
          |> authorize(api_key, api_scope: "funnels:read:*")

        refute conn.halted
        assert conn.assigns.current_user.id == user.id
      end
    end
  end

  describe "no context API ::" do
    test "legacy API key request passes validation", %{
      conn: conn
    } do
      legacy_api_key_user = new_user()
      legacy_api_key = insert_api_key(:legacy_api_key, user: legacy_api_key_user)

      conn =
        conn |> authorize(legacy_api_key, api_scope: "sites:read:*")

      refute conn.halted
      assert conn.assigns.current_user.id == legacy_api_key_user.id
    end

    @legacy_hourly_request_limit Plausible.Auth.ApiKey.legacy_hourly_request_limit()
    test "legacy API key requests are rate limited to configured #{@legacy_hourly_request_limit} requests per hour _per user_, but their team's team-scoped keys are on an independent rate limit" do
      legacy_api_key_user = new_user()
      _site = new_site(owner: legacy_api_key_user)
      legacy_api_key = insert_api_key(:legacy_api_key, user: legacy_api_key_user)

      1..@legacy_hourly_request_limit
      |> Enum.map(fn _ ->
        conn =
          get_fresh_conn()
          |> authorize(legacy_api_key, api_scope: "sites:read:*")

        refute conn.halted
        assert conn.assigns.current_user.id == legacy_api_key_user.id
      end)

      # the hardcoded limit applies per user, not per api key
      [legacy_api_key, insert_api_key(:legacy_api_key, user: legacy_api_key_user)]
      |> Enum.map(fn api_key ->
        conn =
          get_fresh_conn()
          |> authorize(api_key, api_scope: "sites:read:*")

        assert conn.halted
        assert json_response(conn, 429)["error"] =~ "Too many API requests."
      end)

      # no context API requests made with legacy API keys don't count towards team limits
      team_scope_api_key_user = legacy_api_key_user |> team_of() |> add_member(role: :editor)

      conn =
        get_fresh_conn()
        |> authorize(
          insert_api_key(:team_scope_api_key,
            user: team_scope_api_key_user
          ),
          api_scope: "sites:read:*"
        )

      refute conn.halted
    end
  end

  describe("site context API ::") do
    @tag :capture_log
    test "legacy API key requests pass validation for sites of all their teams",
         %{
           conn: conn
         } do
      legacy_api_key_user = new_user()
      legacy_api_key = insert_api_key(:legacy_api_key, user: legacy_api_key_user)
      site_from_first_team = new_site(owner: legacy_api_key_user)
      site_from_second_team = new_site()
      add_member(site_from_second_team.team, user: legacy_api_key_user, role: :editor)

      [site_from_first_team, site_from_second_team]
      |> Enum.map(fn site ->
        conn =
          conn
          |> authorize(legacy_api_key,
            api_context: :site,
            api_scope: "sites:read:*",
            site: site
          )

        refute conn.halted
        assert conn.assigns.current_user.id == legacy_api_key_user.id
      end)
    end

    for guest_role <- [:viewer, :editor] do
      @tag :capture_log
      test "legacy API key requests pass validation for sites where they are a guest #{guest_role} at",
           %{
             conn: conn
           } do
        legacy_api_key_user = new_user()
        legacy_api_key = insert_api_key(:legacy_api_key, user: legacy_api_key_user)
        site = new_site()
        add_guest(site, user: legacy_api_key_user, role: unquote(guest_role))

        conn =
          conn
          |> authorize(legacy_api_key,
            api_context: :site,
            api_scope: "sites:read:*",
            site: site
          )

        refute conn.halted
        assert conn.assigns.current_user.id == legacy_api_key_user.id
      end
    end

    for {key_type, expected_halted} <- [{:legacy_api_key, false}, {:team_scope_api_key, true}] do
      test "logs a warning on using #{key_type} against site with guest access", %{conn: conn} do
        user = new_user(team: [hourly_api_request_limit: 1])
        site = new_site()
        add_guest(site, user: user, role: :editor)

        api_key = insert_api_key(unquote(key_type), user: user)

        capture_log(fn ->
          conn =
            conn |> authorize(api_key, site: site, api_context: :site, api_scope: "sites:read:*")

          assert conn.halted == unquote(expected_halted)
        end) =~ "API key #{api_key.id} user accessing #{site.domain} as a guest"
      end
    end

    for {key_type, expected_halted} <- [{:legacy_api_key, true}, {:team_scope_api_key, true}] do
      test "logs a warning on using #{key_type} against site with no access", %{conn: conn} do
        user = new_user(team: [hourly_api_request_limit: 1])
        site = new_site()

        api_key = insert_api_key(unquote(key_type), user: user)

        capture_log(fn ->
          conn =
            conn |> authorize(api_key, site: site, api_context: :site, api_scope: "stats:read:*")

          assert conn.halted == unquote(expected_halted)
        end) =~ "API key #{api_key.id} user trying to access #{site.domain} as a non-member"
      end
    end

    @tag :capture_log
    test "legacy API key request doesn't pass validation for sites where they are not a guest at",
         %{
           conn: conn
         } do
      legacy_api_key_user = new_user()
      legacy_api_key = insert_api_key(:legacy_api_key, user: legacy_api_key_user)
      site_with_no_guests = new_site()

      conn =
        conn
        |> authorize(legacy_api_key,
          api_context: :site,
          api_scope: "sites:read:*",
          site: site_with_no_guests
        )

      assert conn.halted
      assert json_response(conn, 401)["error"] =~ "Invalid API key."
    end

    for guest_role <- [:viewer, :editor] do
      test "team-scope API key request doesn't pass validation for sites where they are a guest #{guest_role} at",
           %{
             conn: conn
           } do
        user = new_user()
        _site = new_site(owner: user)
        site = new_site()
        add_guest(site, user: user, role: unquote(guest_role))
        team_scope_api_key = insert_api_key(:team_scope_api_key, user: user)

        conn =
          conn
          |> authorize(
            team_scope_api_key,
            api_context: :site,
            api_scope: "sites:read:*",
            site: site
          )

        assert conn.halted
        assert json_response(conn, 401)["error"] =~ "Invalid API key."
      end
    end

    @tag :capture_log
    test "legacy API key requests count towards the rate limit of the team of the site" do
      user = new_user()
      legacy_api_key = insert_api_key(:legacy_api_key, user: user)

      team_hourly_request_limit = 5
      user_of_other_team = new_user(team: [hourly_api_request_limit: team_hourly_request_limit])

      team_scope_api_key_of_other_team =
        insert_api_key(:team_scope_api_key, user: user_of_other_team)

      site = new_site(owner: user_of_other_team)

      add_guest(site, user: user, role: :viewer)

      1..team_hourly_request_limit
      |> Enum.map(fn _ ->
        conn =
          get_fresh_conn()
          |> authorize(legacy_api_key,
            api_context: :site,
            api_scope: "sites:read:*",
            site: site
          )

        refute conn.halted
        assert conn.assigns.current_user.id == user.id
      end)

      [
        legacy_api_key,
        team_scope_api_key_of_other_team
      ]
      |> Enum.map(fn api_key ->
        conn =
          get_fresh_conn()
          |> authorize(api_key,
            api_context: :site,
            api_scope: "sites:read:*",
            site: site
          )

        assert json_response(conn, 429)["error"] =~ "Too many API requests."
        assert conn.halted
      end)
    end
  end

  defp prepare_conn_for_auth(conn) do
    conn
    |> put_private(PlausibleWeb.FirstLaunchPlug, :skip)
    |> bypass_through(PlausibleWeb.Router)
  end

  defp authorize(conn, api_key, opts) do
    context = opts |> Keyword.get(:api_context)
    scope = opts |> Keyword.fetch!(:api_scope)
    site = opts |> Keyword.get(:site)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{api_key.key}")
      |> get("/", if(site, do: %{"site_id" => site.domain}, else: %{}))
      |> assign(:api_scope, scope)

    conn = if context, do: assign(conn, :api_context, context), else: conn
    AuthorizePublicAPI.call(conn, nil)
  end

  defp insert_api_key(:legacy_api_key, opts) do
    insert(:api_key, opts |> Keyword.drop([:team, :team_id]))
  end

  defp insert_api_key(:team_scope_api_key, opts) do
    team = opts |> Keyword.fetch!(:user) |> team_of()
    insert(:api_key, opts |> Keyword.put(:team, team))
  end

  defp get_fresh_conn(),
    do:
      build_conn()
      |> prepare_conn()
      |> prepare_conn_for_auth()
end
