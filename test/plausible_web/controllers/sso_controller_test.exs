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
      team = new_site().team
      integration = SSO.initiate_saml_integration(team)
      domain = "example-#{Enum.random(1..10_000)}.com"

      {:ok, sso_domain} = SSO.Domains.add(integration, domain)
      sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

      {:ok, team: team, integration: integration, domain: domain, sso_domain: sso_domain}
    end

    describe "login_form/2" do
      test "renders login view", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form))

        assert html = html_response(conn, 200)

        assert html =~ "Enter your Single Sign-on email"
        assert element_exists?(html, "input[name=email]")
        assert text_of_attr(html, "input[name=return_to]", "value") == ""
      end

      test "passes return_to parameter to form", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form, return_to: "/sites"))

        assert html = html_response(conn, 200)

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

        assert html = html_response(conn, 200)

        assert html =~ "Wrong email."
        assert element_exists?(html, "input[name=email]")
        assert text_of_attr(html, "input[name=return_to]", "value") == "/sites"
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

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form, error: "Wrong email.", return_to: "/sites")
      end
    end
  end
end
