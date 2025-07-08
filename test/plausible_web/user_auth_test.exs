defmodule PlausibleWeb.UserAuthTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible
  use Plausible.Teams.Test

  alias Plausible.Repo
  alias PlausibleWeb.UserAuth

  on_ee do
    alias Plausible.Auth.SSO
  end

  alias PlausibleWeb.Router.Helpers, as: Routes

  describe "log_in_user/2,3" do
    setup [:create_user]

    test "sets up user session and redirects to sites list", %{conn: conn, user: user} do
      now = NaiveDateTime.utc_now(:second)

      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user)

      assert %{sessions: [session]} = user |> Repo.reload!() |> Repo.preload(:sessions)
      assert session.user_id == user.id
      assert NaiveDateTime.compare(session.last_used_at, now) in [:eq, :gt]
      assert NaiveDateTime.compare(session.timeout_at, session.last_used_at) == :gt

      assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age > 0
      assert get_session(conn, :user_token) == session.token
    end

    test "redirects to `redirect_path` if present", %{conn: conn, user: user} do
      conn =
        conn
        |> init_session()
        |> UserAuth.log_in_user(user, "/next")

      assert redirected_to(conn, 302) == "/next"
    end

    on_ee do
      test "sets up user session from SSO identity", %{conn: conn, user: user} do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        user = user |> Ecto.Changeset.change(email: "jane@" <> domain) |> Repo.update!()
        add_member(team, user: user, role: :editor)

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity(user.name, user.email)

        conn =
          conn
          |> init_session()
          |> UserAuth.log_in_user(identity)

        assert %{sessions: [session]} = user |> Repo.reload!() |> Repo.preload(:sessions)
        assert session.user_id == user.id
        assert NaiveDateTime.compare(session.timeout_at, identity.expires_at) == :eq

        assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
        assert conn.private[:plug_session_info] == :renew
        assert conn.resp_cookies["logged_in"].max_age > 0
        assert get_session(conn, :current_team_id) == team.identifier
        assert get_session(conn, :user_token) == session.token
      end

      test "logs in existing SSO owner using standard login correctly", %{
        conn: conn,
        user: user
      } do
        team = new_site(owner: user).team |> Plausible.Teams.complete_setup()
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        user = user |> Ecto.Changeset.change(email: "jane@" <> domain) |> Repo.update!()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity(user.name, user.email)
        {:ok, :standard, _, user} = SSO.provision_user(identity)

        assert user.type == :sso

        conn =
          conn
          |> init_session()
          |> UserAuth.log_in_user(user)

        assert %{sessions: [session]} = user |> Repo.reload!() |> Repo.preload(:sessions)
        assert session.user_id == user.id
        assert session.token == get_session(conn, :user_token)

        assert redirected_to(conn, 302) == Routes.site_path(conn, :index)
      end

      test "invalidates any existing sessions of user logging in when converting", %{
        conn: conn,
        user: user
      } do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        user = user |> Ecto.Changeset.change(email: "jane@" <> domain) |> Repo.update!()
        add_member(team, user: user, role: :editor)

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity(user.name, user.email)

        conn |> init_session() |> UserAuth.log_in_user(user)

        assert [standard_session] = Repo.preload(user, :sessions).sessions

        conn =
          conn
          |> init_session()
          |> UserAuth.log_in_user(identity)

        assert [sso_session] = Repo.preload(user, :sessions).sessions

        assert standard_session.id != sso_session.id
        assert standard_session.token != sso_session.token
        assert get_session(conn, :user_token) == sso_session.token
      end

      test "tries to log out and redirects if SSO identity is not matched", %{
        conn: conn,
        user: user
      } do
        identity = new_identity("Willy Wonka", "wonka@example.com")

        conn =
          conn
          |> init_session()
          |> fetch_flash()
          |> UserAuth.log_in_user(identity)

        assert %{sessions: []} = user |> Repo.reload!() |> Repo.preload(:sessions)

        assert redirected_to(conn, 302) == Routes.sso_path(conn, :login_form, return_to: "")

        assert Phoenix.Flash.get(conn.assigns.flash, :login_error) == "Wrong email."

        assert conn.private[:plug_session_info] == :renew
        refute get_session(conn, :user_token)
      end

      test "tries to log out and redirects if SSO identity exceeds team members limit", %{
        conn: conn,
        user: user
      } do
        team = new_site().team
        insert(:growth_subscription, team: team)
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        add_member(team, role: :viewer)
        add_member(team, role: :viewer)
        add_member(team, role: :viewer)

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity("Jane Doe", "jane@" <> domain)

        conn =
          conn
          |> init_session()
          |> fetch_flash()
          |> UserAuth.log_in_user(identity)

        assert %{sessions: []} = user |> Repo.reload!() |> Repo.preload(:sessions)

        assert redirected_to(conn, 302) == Routes.sso_path(conn, :login_form, return_to: "")

        assert Phoenix.Flash.get(conn.assigns.flash, :login_error) ==
                 "Team can't accept more members. Please contact the owner."

        assert conn.private[:plug_session_info] == :renew
        refute get_session(conn, :user_token)
      end

      test "tries to log out for user matching SSO identity on multiple teams, redirecting to issue notice",
           %{
             conn: conn,
             user: user
           } do
        team = new_site().team |> Plausible.Teams.complete_setup()
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        user = user |> Ecto.Changeset.change(email: "jane@" <> domain) |> Repo.update!()
        add_member(team, user: user, role: :editor)
        another_team = new_site().team |> Plausible.Teams.complete_setup()
        add_member(another_team, user: user, role: :viewer)

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity(user.name, user.email)

        conn =
          conn
          |> init_session()
          |> UserAuth.log_in_user(identity)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :provision_issue, issue: "multiple_memberships_noforce")

        refute get_session(conn, :user_token)
      end

      test "tries to log out for user matching SSO identity with active personal team, redirecting to issue notice",
           %{
             conn: conn,
             user: user
           } do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"
        user = user |> Ecto.Changeset.change(email: "jane@" <> domain) |> Repo.update!()
        add_member(team, user: user, role: :editor)
        # personal team with site created
        new_site(owner: user)

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity(user.name, user.email)

        conn =
          conn
          |> init_session()
          |> UserAuth.log_in_user(identity)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :provision_issue, issue: "active_personal_team_noforce")

        refute get_session(conn, :user_token)
      end
    end
  end

  describe "log_out_user/1" do
    setup [:create_user]

    test "logs user out", %{conn: conn, user: user} do
      # another independent session for the same user
      {:ok, conn: another_conn} = log_in(%{conn: conn, user: user})
      another_session_token = get_session(another_conn, :user_token)

      {:ok, conn: conn} = log_in(%{conn: conn, user: user})

      conn =
        conn
        |> init_session()
        |> UserAuth.log_out_user()

      # the other session remains intact
      assert %{sessions: [another_session]} = Repo.preload(user, :sessions)
      assert another_session.token == another_session_token
      assert conn.private[:plug_session_info] == :renew
      assert conn.resp_cookies["logged_in"].max_age == 0
    end
  end

  describe "get_user_session/1" do
    setup [:create_user, :log_in]

    test "gets session from session data in conn", %{conn: conn, user: user} do
      assert {:ok, user_session} = UserAuth.get_user_session(conn)
      assert user_session.user_id == user.id
    end

    test "gets session from session data map", %{user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)

      assert {:ok, session_from_token} =
               UserAuth.get_user_session(%{"user_token" => user_session.token})

      assert session_from_token.id == user_session.id
    end

    test "returns error on invalid or missing session data" do
      conn = init_session(build_conn())
      assert {:error, :no_valid_token} = UserAuth.get_user_session(conn)
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{})
      assert {:error, :no_valid_token} = UserAuth.get_user_session(%{"current_user_id" => 123})
    end

    test "returns error on missing session", %{conn: conn, user: user} do
      %{sessions: [user_session]} = Repo.preload(user, :sessions)
      Repo.delete!(user_session)

      assert {:error, :session_not_found} = UserAuth.get_user_session(conn)

      assert {:error, :session_not_found} =
               UserAuth.get_user_session(%{"user_token" => user_session.token})
    end

    test "returns error on expired session", %{conn: conn} do
      now = NaiveDateTime.utc_now(:second)
      in_the_past = NaiveDateTime.add(now, -1, :hour)
      {:ok, user_session} = UserAuth.get_user_session(conn)
      user_session |> Ecto.Changeset.change(timeout_at: in_the_past) |> Repo.update!()

      assert {:error, :session_expired, expired_session} = UserAuth.get_user_session(conn)
      assert expired_session.id == user_session.id
    end
  end

  describe "set_logged_in_cookie/1" do
    test "sets logged_in_cookie", %{conn: conn} do
      conn = UserAuth.set_logged_in_cookie(conn)

      assert cookie = conn.resp_cookies["logged_in"]
      assert cookie.max_age > 0
      assert cookie.value == "true"
    end
  end

  @user_agent "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.110 Safari/537.36"
  @user_agent_mobile "Mozilla/5.0 (Linux; Android 6.0; U007 Pro Build/MRA58K; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/44.0.2403.119 Mobile Safari/537.36"
  @user_agent_tablet "Mozilla/5.0 (Linux; U; Android 4.2.2; it-it; Surfing TAB B 9.7 3G Build/JDQ39) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30"

  describe "device name detection" do
    setup [:create_user]

    test "detects browser and os when possible", %{conn: conn, user: user} do
      assert login_device(conn, user, @user_agent) == "Chrome (Mac)"
      assert login_device(conn, user, @user_agent_mobile) == "Mobile App (Android)"
      assert login_device(conn, user, @user_agent_tablet) == "Android Browser (Android)"
    end

    test "falls back to unknown when can't detect browser", %{conn: conn, user: user} do
      assert login_device(conn, user, nil) == "Unknown"
      assert login_device(conn, user, "Bogus UA") == "Unknown"
    end

    test "skips os when can't detect it", %{conn: conn, user: user} do
      assert login_device(conn, user, "Mozilla Firefox") == "Firefox"
    end
  end

  defp login_device(conn, user, ua_string) do
    conn =
      if ua_string do
        Plug.Conn.put_req_header(conn, "user-agent", ua_string)
      else
        conn
      end

    {:ok, conn: conn} = log_in(%{conn: conn, user: user})

    {:ok, user_session} = conn |> UserAuth.get_user_session()

    user_session.device
  end
end
