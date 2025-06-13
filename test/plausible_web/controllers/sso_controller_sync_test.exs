defmodule PlausibleWeb.SSOControllerSyncTest do
  use PlausibleWeb.ConnCase

  @moduletag :ee_only

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth
    alias Plausible.Auth.SSO
    alias Plausible.Repo

    describe "sso_enabled = false" do
      setup do
        patch_env(:sso_enabled, false)
      end

      test "standard login form does not show link to SSO login", %{conn: conn} do
        conn = get(conn, Routes.auth_path(conn, :login_form))

        assert html = html_response(conn, 200)

        refute html =~ Routes.sso_path(conn, :login_form)
        refute html =~ "Single Sign-on"
      end

      test "sso_settings/2 are guarded by the env var", %{conn: conn} do
        user = new_user()
        team = new_site(owner: user).team |> Plausible.Teams.complete_setup()
        {:ok, ctx} = log_in(%{conn: conn, user: user})
        conn = ctx[:conn]
        conn = set_current_team(conn, team)

        conn = get(conn, Routes.sso_path(conn, :sso_settings))

        assert redirected_to(conn, 302) == "/sites"
      end

      test "sso team settings item is guarded by the env var", %{conn: conn} do
        user = new_user()
        team = new_site(owner: user).team |> Plausible.Teams.complete_setup()
        {:ok, ctx} = log_in(%{conn: conn, user: user})
        conn = ctx[:conn]
        conn = set_current_team(conn, team)

        conn = get(conn, Routes.settings_path(conn, :team_general))

        assert html = html_response(conn, 200)

        refute html =~ "Single Sign-On"
      end

      test "login_form/2 is guarded by the env var", %{conn: conn} do
        conn = get(conn, Routes.sso_path(conn, :login_form))

        assert redirected_to(conn, 302) == "/"
      end

      test "login/2 is guarded by the env var", %{conn: conn} do
        conn = post(conn, Routes.sso_path(conn, :login), %{"email" => "some@example.com"})

        assert redirected_to(conn, 302) == "/"
      end

      test "saml_signin/2 is guarded by the env var", %{conn: conn} do
        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, Ecto.UUID.generate(),
              email: "some@example.com",
              return_to: "/sites"
            )
          )

        assert redirected_to(conn, 302) == "/"
      end

      test "saml_consume/2 is guarded by the env var", %{conn: conn} do
        conn =
          post(conn, Routes.sso_path(conn, :saml_consume, Ecto.UUID.generate()), %{
            "email" => "some@example.com",
            "return_to" => "/sites"
          })

        assert redirected_to(conn, 302) == "/"
      end

      test "csp_report/2 is guarded by the env var", %{conn: conn} do
        conn = post(conn, Routes.sso_path(conn, :csp_report), %{})

        assert redirected_to(conn, 302) == "/"
      end
    end

    @cert_pem """
    -----BEGIN CERTIFICATE-----
    MIICmjCCAYICCQDX5sKPsYV3+jANBgkqhkiG9w0BAQsFADAPMQ0wCwYDVQQDDAR0
    ZXN0MB4XDTE5MTIyMzA5MDI1MVoXDTIwMDEyMjA5MDI1MVowDzENMAsGA1UEAwwE
    dGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMdtDJ278DQTp84O
    5Nq5F8s5YOR34GFOGI2Swb/3pU7X7918lVljiKv7WVM65S59nJSyXV+fa15qoXLf
    sdRnq3yw0hTSTs2YDX+jl98kK3ksk3rROfYh1LIgByj4/4NeNpExgeB6rQk5Ay7Y
    S+ARmMzEjXa0favHxu5BOdB2y6WvRQyjPS2lirT/PKWBZc04QZepsZ56+W7bd557
    tdedcYdY/nKI1qmSQClG2qgslzgqFOv1KCOw43a3mcK/TiiD8IXyLMJNC6OFW3xT
    L/BG6SOZ3dQ9rjQOBga+6GIaQsDjC4Xp7Kx+FkSvgaw0sJV8gt1mlZy+27Sza6d+
    hHD2pWECAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAm2fk1+gd08FQxK7TL04O8EK1
    f0bzaGGUxWzlh98a3Dm8+OPhVQRi/KLsFHliLC86lsZQKunYdDB+qd0KUk2oqDG6
    tstG/htmRYD/S/jNmt8gyPAVi11dHUqW3IvQgJLwxZtoAv6PNs188hvT1WK3VWJ4
    YgFKYi5XQYnR5sv69Vsr91lYAxyrIlMKahjSW1jTD3ByRfAQghsSLk6fV0OyJHyh
    uF1TxOVBVf8XOdaqfmvD90JGIPGtfMLPUX4m35qaGAU48PwCL7L3cRHYs9wZWc0i
    fXZcBENLtHYCLi5txR8c5lyHB9d3AQHzKHMFNjLswn5HsckKg83RH7+eVqHqGw==
    -----END CERTIFICATE-----
    """

    @other_cert_pem """
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

    describe "saml_signin/2 (real SAML)" do
      setup do
        patch_env(:sso_saml_adapter, PlausibleWeb.SSO.RealSAMLAdapter)

        team = new_site().team |> Plausible.Teams.complete_setup()
        integration = SSO.initiate_saml_integration(team)

        {:ok, integration} =
          SSO.update_integration(integration, %{
            idp_signin_url: "http://localhost:8080/simplesaml/saml2/idp/SSOService.php",
            idp_entity_id: "http://localhost:8080/simplesaml/saml2/idp/metadata.php",
            idp_cert_pem: @cert_pem
          })

        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok, team: team, integration: integration, domain: domain, sso_domain: sso_domain}
      end

      test "redirects to IdP", %{conn: conn, domain: domain, integration: integration} do
        email = "paul@" <> domain

        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, integration.identifier,
              email: email,
              return_to: "/sites"
            )
          )

        session = fetch_cookies(conn, encrypted: ["session_saml"]).cookies["session_saml"]

        assert String.length(session.relay_state) > 0
        assert session.return_to == "/sites"

        assert url = redirected_to(conn, 302)

        assert {:ok, uri} = URI.new(url)

        assert uri.host == "localhost"
        assert uri.port == 8080
        assert uri.scheme == "http"

        assert %{
                 "RelayState" => relay_state,
                 "SAMLEncoding" => "urn:oasis:names:tc:SAML:2.0:bindings:URL-Encoding:DEFLATE",
                 "SAMLRequest" => saml_request,
                 "login_hint" => ^email
               } = URI.decode_query(uri.query)

        assert relay_state == session.relay_state

        xml = saml_request |> Base.decode64!() |> :zlib.unzip()

        assert {:ok, root_node} = SimpleXml.parse(xml)
        assert {:ok, issuer_node} = SimpleXml.XmlNode.first_child(root_node, "saml:Issuer")
        assert {:ok, acs_url} = SimpleXml.XmlNode.text(issuer_node)

        assert acs_url == SSO.SAMLConfig.entity_id(integration)
      end

      test "redirects to login if integration not found", %{conn: conn, domain: domain} do
        email = "paul@" <> domain

        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, Ecto.UUID.generate(),
              email: email,
              return_to: "/sites"
            )
          )

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form, error: "Wrong email.", return_to: "/sites")
      end
    end

    @assertion File.read!("extra/fixture/assertion.base64")
    @assertion_missing_email File.read!("extra/fixture/assertion_missing_email.base64")
    @assertion_invalid_email File.read!("extra/fixture/assertion_invalid_email.base64")
    @assertion_missing_name File.read!("extra/fixture/assertion_missing_name.base64")

    describe "saml_consume/2 (real SAML)" do
      setup %{conn: conn} do
        patch_env(:sso_saml_adapter, PlausibleWeb.SSO.RealSAMLAdapter)

        team = new_site().team |> Plausible.Teams.complete_setup()
        integration = SSO.initiate_saml_integration(team)

        {:ok, integration} =
          SSO.update_integration(integration, %{
            idp_signin_url: "http://localhost:8080/simplesaml/saml2/idp/SSOService.php",
            idp_entity_id: "http://localhost:8080/simplesaml/saml2/idp/metadata.php",
            idp_cert_pem: @cert_pem
          })

        domain = "plausible.test"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok, root_node} = @assertion |> Base.decode64!(ignore: :whitespace) |> SimpleXml.parse()
        {:ok, assertion_node} = SimpleXml.XmlNode.first_child(root_node, "*:Assertion")
        {:ok, subject_node} = SimpleXml.XmlNode.first_child(assertion_node, "*:Subject")
        {:ok, name_id_node} = SimpleXml.XmlNode.first_child(subject_node, "*:NameID")
        {:ok, name_id} = SimpleXml.XmlNode.text(name_id_node)

        email = "user@plausible.test"

        conn =
          get(
            conn,
            Routes.sso_path(conn, :saml_signin, integration.identifier,
              email: email,
              return_to: "/sites"
            )
          )

        saml_session = fetch_cookies(conn, encrypted: ["session_saml"]).cookies["session_saml"]
        relay_state = saml_session.relay_state

        conn =
          conn
          |> recycle()
          |> Map.put(:secret_key_base, secret_key_base())

        {:ok,
         team: team,
         integration: integration,
         domain: domain,
         sso_domain: sso_domain,
         email: email,
         conn: conn,
         name_id: name_id,
         relay_state: relay_state}
      end

      test "provisions identity and logs in", %{
        conn: conn,
        team: team,
        integration: integration,
        sso_domain: sso_domain,
        relay_state: relay_state,
        name_id: name_id
      } do
        params = %{
          "SAMLResponse" => @assertion,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) == "/sites"

        session = get_session(conn)

        assert session["current_team_id"] == team.identifier

        assert {:ok, user_session} = Auth.UserSessions.get_by_token(session["user_token"])

        assert user_session.user.email == "user@plausible.test"
        assert user_session.user.type == :sso
        assert user_session.user.name == "Jane Smith"
        assert user_session.user.sso_integration_id == integration.id
        assert user_session.user.sso_domain_id == sso_domain.id
        assert user_session.user.sso_identity_id == name_id

        timeout_minutes = team.policy.sso_session_timeout_minutes

        timeout_threshold_lower =
          NaiveDateTime.add(NaiveDateTime.utc_now(:second), timeout_minutes - 2, :minute)

        timeout_threshold_upper =
          NaiveDateTime.add(NaiveDateTime.utc_now(:second), timeout_minutes + 2, :minute)

        assert NaiveDateTime.compare(user_session.timeout_at, timeout_threshold_lower) == :gt
        assert NaiveDateTime.compare(user_session.timeout_at, timeout_threshold_upper) == :lt
      end

      test "redirects with error when no matching integration found", %{
        conn: conn,
        relay_state: relay_state
      } do
        params = %{
          "SAMLResponse" => @assertion,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, Ecto.UUID.generate()), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form, error: "Wrong email.", return_to: "/sites")
      end

      test "redirects with error on mismatch of RelayState", %{
        conn: conn,
        integration: integration
      } do
        params = %{
          "SAMLResponse" => @assertion,
          "RelayState" => Ecto.UUID.generate()
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :invalid_relay_state).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on missing relay state", %{
        conn: conn,
        integration: integration
      } do
        params = %{"SAMLResponse" => @assertion}

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :invalid_relay_state).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on malformed assertion", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        params = %{
          "SAMLResponse" => "malformed",
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :base64_decoding_failed).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on malformed certificate in config (should not happen)", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        Repo.query!(
          """
          UPDATE sso_integrations SET config = jsonb_set(config, '{idp_cert_pem}', '"invalid"')
            WHERE id = $1
          """,
          [integration.id]
        )

        params = %{
          "SAMLResponse" => @assertion,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :malformed_certificate).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on mismatched certificate in config", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        {:ok, integration} = SSO.update_integration(integration, %{idp_cert_pem: @other_cert_pem})

        params = %{
          "SAMLResponse" => @assertion,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :digest_verification_failed).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on missing email attribute in assertion", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        params = %{
          "SAMLResponse" => @assertion_missing_email,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :missing_email_attribute).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on invalid email attribute in assertion", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        params = %{
          "SAMLResponse" => @assertion_invalid_email,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :invalid_email_attribute).",
                   return_to: "/sites"
                 )
      end

      test "redirects with error on missing name attributes in assertion", %{
        conn: conn,
        integration: integration,
        relay_state: relay_state
      } do
        params = %{
          "SAMLResponse" => @assertion_missing_name,
          "RelayState" => relay_state
        }

        conn = post(conn, Routes.sso_path(conn, :saml_consume, integration.identifier), params)

        assert redirected_to(conn, 302) ==
                 Routes.sso_path(conn, :login_form,
                   error: "Authentication failed (reason: :missing_name_attributes).",
                   return_to: "/sites"
                 )
      end
    end

    defp secret_key_base() do
      :plausible
      |> Application.fetch_env!(PlausibleWeb.Endpoint)
      |> Keyword.fetch!(:secret_key_base)
    end
  end
end
