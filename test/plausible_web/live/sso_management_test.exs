defmodule PlausibleWeb.Live.SSOMangementTest do
  use PlausibleWeb.ConnCase, async: false
  use Oban.Testing, repo: Plausible.Repo

  @moduletag :ee_only

  on_ee do
    use Bamboo.Test, shared: true
    use Plausible.Teams.Test

    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    alias Plausible.Auth
    alias Plausible.Auth.SSO

    @cert_pem """
    -----BEGIN CERTIFICATE-----
    MIIFdTCCA12gAwIBAgIUNcATm3CidmlEMMsZa9KBZpWYCVcwDQYJKoZIhvcNAQEL
    BQAwYzELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
    GEludGVybmV0IFdpZGdpdHMgUHR5IEx0ZDEcMBoGA1UEAwwTc29tZWlkcC5leGFt
    cGxlLmNvbTAeFw0yNTA1MjExMjI5MzVaFw0yNjA1MjExMjI5MzVaMGMxCzAJBgNV
    BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
    aWRnaXRzIFB0eSBMdGQxHDAaBgNVBAMME3NvbWVpZHAuZXhhbXBsZS5jb20wggIi
    MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC1N6Drbjed+lFXpOYvE6Efgndy
    W7kYiO8LqQTr4UwVrp9ArxgYuK4TrcNRh2rhS08xAzNTo+NqnJOm95baG97ADYk1
    TqVIKxzaFurv+L/Na0wVXyeNUtxIVKF59uElsg2YLm5eQhL9fmN8jVINCvwDPzxc
    Ihm6mQOaL/i/0DGINOqwHG9MGMZ11AeOM0wKMuXJ2+aKjHOCedhMYVuOaHZgLkcX
    Zzgiv7itm3+JpCjL474MMfibiqKHR0e3QRNcsEC13f/LD8BAGOwsKLznFC8Uctms
    48EDNbxxLG01jVbnJSxRrcDN3RUDjtCdHyaTCCFJAgmldHKKua3VQEynOwJIkFMC
    fpL1LpLvATzIt0cT1ESb1RHIlgacmESVn/TW2QjO5tp4FAu7GJK+5xY7jPvI6saG
    oUHsk0zo9obLK8WYneF19ln+Ea5ZCl9PcTi559AKGpYzpL/9uxoPT1zxxTn6c2lt
    4xkxkuHtYqi/ENHGdo4CLBL93GDZEilSVmZjD/9N9990yWbPXXQ0eNoFckYSZuls
    HaWz8W5c046/ob8mASI6wzAUCkO9Zz4WbIj9A+mNZB32hMZbMA02gU//ffvNkFjL
    DGlNbROCg2DX64rvGs/RuqhuDVCnVfid9B36Cgs76GWI8dCInEfyZMtiqUb7E8Oe
    BPVwtTscz1StlF/0cQIDAQABoyEwHzAdBgNVHQ4EFgQU9lvXH4X04v99rrwKNzsw
    pNQP/dUwDQYJKoZIhvcNAQELBQADggIBAJD0MD+OK58vlP2HEoKLQYAKYM/4NsBz
    vSK1PtZsEj0fqiuu66ceH0wlKlGquRad4Z+LXMptu1DzMNmJsf0zSQfleGFks3xI
    86hgkQ7f0qjs+YJzjJUxF9H8zX4jJk5poOqOJwStHBCDLsUmIxnT7/il3jlT0Nj4
    cVs4946pCg7rP1kR9jojFD5yvzKoRBJG3/qvFnzAi8cDv9CRjSgoDTZyzZmwdCgu
    NioW7YeFCtvYxvY7HDXinwq/w8Gn3n8zdISoAqSpYrt5Y5ygJGiEYVDWdA50a6PC
    gq5xt8RCizz1L7a5BUJFMCQ0pyAUuODTndPUGLT8i7jFgzhamFPD72zFMk2+IabE
    Dutyt2GFeTQ75wL8QvfsKm29Vd5EjAsdfmup3hCpLGqF3g8Sh0aXDrj8KPqIecuS
    gkL69M9iXfnwZhTo23zUuFjBNoAIPXkNKXiJS7p9IEpYRVnlPYLToSEnnzptoPPQ
    zMBb8x/UMMtNYkyehSLhuIPrRLvv3eth7Hq3hA7tOCRyyf78tReVm+VoRx6AK68v
    5ufxMKBFRTNoLIN3sD+DmSUNY+CaHxRMDhSESy0Ac/95J2yKi+Y1Kml2GV53pSlT
    6FPm8B0R9YXM7lHhTLyL7DYqnvklkLh2bUqCLyBowynPyGqdYV4DbFSiST14fGXR
    mNEYF78kg0IA
    -----END CERTIFICATE-----
    """

    describe "/settings/sso/general" do
      setup [:create_user, :log_in, :create_team, :add_plan, :setup_team]

      test "renders", %{conn: conn} do
        resp =
          conn
          |> get(Routes.sso_path(conn, :sso_settings))
          |> html_response(200)
          |> text()

        assert resp =~ "Start Configuring SSO"
      end
    end

    describe "live" do
      setup [:create_user, :log_in, :create_team, :add_plan, :setup_team]

      test "init setup - basic walk through", %{conn: conn} do
        {lv, _html} = get_lv(conn)
        lv |> element("form#sso-init") |> render_submit()
        html = render(lv)

        assert element_exists?(html, "form#sso-sp-config")

        lv |> element("form#sso-idp-form") |> render_submit()
        lv |> element("form#sso-idp-config") |> render_submit()

        text = text(render(lv))

        assert text =~ "Sign-in URL can't be blank"
        assert text =~ "Entity ID can't be blank"
        assert text =~ "Certificate in PEM format can't be blank"

        lv
        |> element("form#sso-idp-config")
        |> render_submit(%{
          saml_config: %{
            idp_signin_url: "http://signin.example.com",
            idp_entity_id: "abc123",
            idp_cert_pem: @cert_pem
          }
        })

        lv
        |> element("form#sso-add-domain")
        |> render_submit()

        text = text(render(lv))
        assert text =~ "Domain can't be blank"

        lv
        |> element("form#sso-add-domain")
        |> render_submit(%{
          domain: %{
            domain: "example.com"
          }
        })

        text = render(lv) |> text()
        assert text =~ "Verifying domain"

        lv |> element("form#verify-domain-submit") |> render_submit()

        assert_enqueued(
          worker: SSO.Domain.Verification.Worker,
          args: %{domain: "example.com"}
        )

        html = render(lv)
        text = text(html)

        assert text =~ "example.com"
        assert text =~ "-BEGIN CERTIFICATE-"

        sp_entity_id = text_of_attr(html, "#sp-entity-id", "value")
        integration_identifier = sp_entity_id |> Path.split() |> List.last()
        {:ok, integration} = SSO.get_integration(integration_identifier)

        assert integration.config.idp_signin_url == "http://signin.example.com"
        assert integration.config.idp_entity_id == "abc123"
        assert [%{domain: "example.com"}] = integration.sso_domains
      end

      test "renders integration summary", %{conn: conn, team: team} do
        setup_integration(team, "example.com")

        {_lv, html} = get_lv(conn)

        assert element_exists?(html, "h2 a#sso-manage-config")
        assert element_exists?(html, "h2 a#sso-domains-config")
        assert element_exists?(html, "h2 a#sso-policy-config")
      end

      test "edit idp config", %{conn: conn, team: team} do
        setup_integration(team, "example.com")

        {lv, _html} = get_lv(conn)

        lv |> element("form#show-idp-form") |> render_submit()

        html = render(lv)

        assert element_exists?(html, "input#sso-idp-config_idp_signin_url")
        assert element_exists?(html, "input#sso-idp-config_idp_entity_id")
        assert element_exists?(html, "textarea#sso-idp-config_idp_cert_pem")

        lv
        |> element("form#sso-idp-config")
        |> render_submit(%{
          saml_config: %{
            idp_signin_url: "http://updated.example.com",
            idp_entity_id: "zxc345",
            idp_cert_pem: @cert_pem
          }
        })

        html = render(lv)
        assert element_exists?(html, "h2 a#sso-manage-config")

        assert text_of_attr(html, "input#sso-idp-config_idp_signin_url", "value") ==
                 "http://updated.example.com"

        assert text_of_attr(html, "input#sso-idp-config_idp_entity_id", "value") == "zxc345"
      end

      test "add another domain", %{conn: conn, team: team} do
        setup_integration(team, "org.example.com")

        {lv, _html} = get_lv(conn)

        lv |> element("form#show-domain-setup") |> render_submit()

        lv
        |> element("form#sso-add-domain")
        |> render_submit(%{
          domain: %{
            domain: "new.example.com"
          }
        })

        html = render(lv)
        assert text(html) =~ "Verifying domain new.example.com"

        lv |> element("form#verify-domain-submit") |> render_submit()

        assert_enqueued(
          worker: SSO.Domain.Verification.Worker,
          args: %{domain: "new.example.com"}
        )

        text = text(render(lv))
        assert text =~ "org.example.com"
        assert text =~ "new.example.com"
      end

      test "policy update", %{conn: conn, team: team} do
        setup_integration(team, "org.example.com")
        {lv, html} = get_lv(conn)

        assert text_of_attr(
                 html,
                 ~s|#sso-policy_sso_default_role option[selected="selected"]|,
                 "value"
               ) == "viewer"

        assert text_of_attr(html, ~s|#sso-policy_sso_session_timeout_minutes|, "value") == "360"

        lv
        |> element("form#sso-policy")
        |> render_submit(%{
          policy: %{
            sso_default_role: "owner",
            sso_session_timeout_minutes: "710"
          }
        })

        html = render(lv)

        assert text_of_attr(
                 html,
                 ~s|#sso-policy_sso_default_role option[selected="selected"]|,
                 "value"
               ) == "owner"

        assert text_of_attr(html, ~s|#sso-policy_sso_session_timeout_minutes|, "value") == "710"
      end

      test "force SSO toggle disabled when operator is standard user", %{
        conn: conn,
        team: team,
        user: user
      } do
        setup_integration(team, "org.example.com")
        {_lv, html} = get_lv(conn)

        assert element_exists?(html, "button#enable-force-sso-toggle[disabled]")

        {:ok, user, _} = Auth.TOTP.initiate(user)
        {:ok, _user, _} = Auth.TOTP.enable(user, :skip_verify)

        identity = new_identity("Lance Wurst", "lance@org.example.com")
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        {_lv, html} = get_lv(conn)

        assert element_exists?(html, "button#enable-force-sso-toggle[disabled]")
        assert html =~ "you must be logged in via SSO"
      end

      test "force SSO toggle works when operator is SSO user", %{
        conn: conn,
        team: team,
        user: user
      } do
        setup_integration(team, "example.com")
        {_lv, html} = get_lv(conn)

        assert element_exists?(html, "button#enable-force-sso-toggle[disabled]")

        {:ok, user, _} = Auth.TOTP.initiate(user)
        {:ok, _user, _} = Auth.TOTP.enable(user, :skip_verify)

        identity = new_identity(user.name, user.email)
        {:ok, _, _, user} = SSO.provision_user(identity)

        {:ok, conn: conn} = log_in(%{conn: conn, user: user})
        conn = set_current_team(conn, team)

        {lv, html} = get_lv(conn)

        refute element_exists?(html, "button#enable-force-sso-toggle[disabled]")

        lv
        |> element("#enable-force-sso-toggle")
        |> render_click()

        assert Plausible.Repo.reload(team).policy.force_sso == :all_but_owners
      end

      defp setup_integration(team, domain) do
        integration = SSO.initiate_saml_integration(team)
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok, _integration} =
          SSO.update_integration(integration, %{
            idp_signin_url: "https://#{domain}",
            idp_entity_id: "some-entity",
            idp_cert_pem: @cert_pem
          })
      end

      defp get_lv(conn) do
        conn = assign(conn, :live_module, PlausibleWeb.Live.SSOManagement)
        {:ok, lv, html} = live(conn, Routes.sso_path(conn, :sso_settings))
        {lv, html}
      end

      defp add_plan(%{user: user}) do
        subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.SSO])

        :ok
      end
    end
  end
end
