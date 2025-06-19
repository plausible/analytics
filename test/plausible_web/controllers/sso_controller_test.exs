defmodule PlausibleWeb.SSOControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    import Plausible.Teams.Test
    import Plausible.Test.Support.HTML

    alias Plausible.Auth.SSO
    alias Plausible.Repo

    setup do
      team = new_site().team |> Plausible.Teams.complete_setup()
      integration = SSO.initiate_saml_integration(team)
      domain = "example-#{Enum.random(1..10_000)}.com"

      {:ok, sso_domain} = SSO.Domains.add(integration, domain)
      sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

      {:ok, team: team, integration: integration, domain: domain, sso_domain: sso_domain}
    end

    describe "login_form/2" do
      test "renders login view", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form, prefer: "sso"))

        assert html = html_response(conn, 200)

        assert html =~ "Enter your Single Sign-on email"
        assert element_exists?(html, "input[name=email]")
        assert text_of_attr(html, "input[name=return_to]", "value") == ""
      end

      test "passes return_to parameter to form", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form, return_to: "/sites", prefer: "sso"))

        assert html = html_response(conn, 200)

        assert text_of_attr(html, "input[name=return_to]", "value") == "/sites"
      end

      test "renders error if provided in login_error flash message", %{conn: conn} do
        conn =
          conn
          |> init_session()
          |> fetch_session()
          |> fetch_flash()
          |> put_flash(:login_error, "Wrong email.")

        conn = get(conn, Routes.sso_path(conn, :login_form, return_to: "/sites"))

        assert html = html_response(conn, 200)

        assert html =~ "Wrong email."
        assert element_exists?(html, "input[name=email]")
        assert text_of_attr(html, "input[name=return_to]", "value") == "/sites"
      end
    end

    describe "login/2" do
      test "redirects to SAML signin on matching integration", %{
        conn: conn,
        domain: domain,
        integration: integration
      } do
        email = "paul@" <> domain

        conn = post(conn, Routes.sso_path(conn, :login), %{"email" => email})

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :saml_signin, integration.identifier,
                   email: email,
                   return_to: ""
                 )
      end

      test "passes redirect path if provided", %{
        conn: conn,
        domain: domain,
        integration: integration
      } do
        email = "paul@" <> domain

        conn =
          post(conn, Routes.sso_path(conn, :login), %{"email" => email, "return_to" => "/sites"})

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :saml_signin, integration.identifier,
                   email: email,
                   return_to: "/sites"
                 )
      end

      test "renders login form with error on no matching integration", %{conn: conn} do
        conn =
          post(conn, Routes.sso_path(conn, :login), %{
            "email" => "nomatch@example.com",
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == Routes.sso_path(conn, :login_form)

        assert Phoenix.Flash.get(conn.assigns.flash, :login_error) == "Wrong email."
      end
    end

    describe "saml_signin/2 (fake SAML)" do
      test "renders autosubmitted form", %{conn: conn, domain: domain, integration: integration} do
        email = "paul@" <> domain

        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, integration.identifier,
              email: email,
              return_to: "/sites"
            )
          )

        assert html = html_response(conn, 200)

        assert html =~ "Processing Single Sign-on request..."

        assert text_of_attr(html, "form#sso-req-form", "action") ==
                 Routes.sso_path(conn, :saml_consume, integration.identifier)

        assert text_of_attr(html, "input[name=email]", "value") == email
        assert text_of_attr(html, "input[name=return_to]", "value") == "/sites"
      end
    end

    describe "saml_consume/2 (fake SAML)" do
      test "provisions identity for new user", %{
        conn: conn,
        domain: domain,
        integration: integration
      } do
        email = "dana.lake@" <> domain

        conn =
          post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), %{
            "email" => email,
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == "/sites"

        assert %{sessions: [sso_session]} =
                 user = Repo.get_by(Plausible.Auth.User, email: email) |> Repo.preload(:sessions)

        assert user.type == :sso
        assert user.email == email
        assert user.name == "Dana Lake"
        assert get_session(conn, :user_token) == sso_session.token
      end

      test "provisions identity for existing user", %{
        conn: conn,
        team: team,
        domain: domain,
        integration: integration
      } do
        email = "dana@" <> domain

        existing_user = new_user(name: "Dana Woodworth", email: email)

        add_member(team, user: existing_user, role: :admin)

        conn =
          post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), %{
            "email" => email,
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == "/sites"

        assert %{sessions: [sso_session]} =
                 user = Repo.get_by(Plausible.Auth.User, email: email) |> Repo.preload(:sessions)

        assert user.type == :sso
        assert user.email == email
        assert user.name == "Dana Woodworth"
        assert get_session(conn, :user_token) == sso_session.token
      end

      test "redirects to login when no matching integration found", %{conn: conn} do
        conn =
          post(conn, Routes.sso_path(conn, :saml_consume, Ecto.UUID.generate()), %{
            "email" => "missed@example.com",
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == Routes.sso_path(conn, :login_form, return_to: "/sites")

        assert Phoenix.Flash.get(conn.assigns.flash, :login_error) == "Wrong email."
      end
    end

    describe "sso_settings/2" do
      setup [:create_user, :log_in, :create_team]

      test "redirects when team is not setup", %{conn: conn, team: team} do
        conn = set_current_team(conn, team)
        conn = get(conn, Routes.sso_path(conn, :sso_settings))

        assert redirected_to(conn, 302) == "/sites"
      end

      test "renders when team is setup", %{conn: conn, team: team} do
        team = Plausible.Teams.complete_setup(team)
        conn = set_current_team(conn, team)
        conn = get(conn, Routes.sso_path(conn, :sso_settings))

        assert html = html_response(conn, 200)

        assert html =~ "Configure and manage Single Sign-On for your team"
      end
    end

    describe "provision_notice/2" do
      test "renders the notice", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :provision_notice))

        assert html = html_response(conn, 200)

        assert html =~ "Single Sign-On enforcement"
        assert html =~ "To access this team, you must first"
        assert html =~ "log out"
        assert html =~ "and log in as SSO user"
      end
    end

    describe "provision_issue/2" do
      test "renders issue for not_a_member", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :provision_issue, issue: "not_a_member"))

        assert html = html_response(conn, 200)

        assert html =~ "Single Sign-On enforcement"
        assert html =~ "To access this team, you must join as a team member first"
      end

      test "renders issue for multiple_memberships", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :provision_issue, issue: "multiple_memberships"))

        assert html = html_response(conn, 200)

        assert html =~ "Single Sign-On enforcement"
        assert html =~ "To access this team, you must first leave all other teams"
      end

      test "renders issue for active_personal_team", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :provision_issue, issue: "active_personal_team"))

        assert html = html_response(conn, 200)

        assert html =~ "Single Sign-On enforcement"
        assert html =~ "To access this team, you must either remove or transfer all sites"
      end
    end
  end
end
