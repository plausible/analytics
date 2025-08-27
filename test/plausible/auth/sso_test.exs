defmodule Plausible.Auth.SSOTest do
  use Plausible.DataCase, async: true
  use Plausible

  on_ee do
    use Oban.Testing, repo: Plausible.Repo
    use Plausible.Teams.Test

    alias Plausible.Auth
    alias Plausible.Auth.SSO
    alias Plausible.Teams

    describe "initiate_saml_integration/1" do
      test "initiates new saml integration" do
        team = new_site().team

        integration = SSO.initiate_saml_integration(team)

        assert integration.team_id == team.id
        assert is_binary(integration.identifier)
        assert %SSO.SAMLConfig{} = integration.config

        assert audited_entry("saml_integration_initiated",
                 team_id: team.id,
                 entity_id: "#{integration.id}"
               )
      end

      test "does nothing if integration is already initiated" do
        team = new_site().team

        integration = SSO.initiate_saml_integration(team)
        another_integration = SSO.initiate_saml_integration(team)

        assert integration.id == another_integration.id
        assert integration.config == another_integration.config
      end
    end

    describe "update_integration/2" do
      @cert_pem """
      -----BEGIN CERTIFICATE-----
      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
      mNEYF78kg0IA
      -----END CERTIFICATE-----
      """

      test "updates integration" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:ok, integration} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "  some-entity  ",
                   idp_cert_pem: @cert_pem
                 })

        assert integration.config.idp_signin_url == "https://example.com"
        assert integration.config.idp_entity_id == "some-entity"

        assert X509.Certificate.from_pem(integration.config.idp_cert_pem) ==
                 X509.Certificate.from_pem(@cert_pem)

        assert audited_entry("sso_integration_updated",
                 team_id: team.id,
                 entity_id: "#{integration.id}"
               )
      end

      test "updates integration with whitespace around PEM" do
        malformed_pem =
          @cert_pem
          |> String.split("\n")
          |> Enum.map_join("\n\n", &("   " <> &1 <> "   "))

        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:ok, integration} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: malformed_pem
                 })

        assert integration.config.idp_signin_url == "https://example.com"
        assert integration.config.idp_entity_id == "some-entity"

        assert integration.config.idp_cert_pem == String.trim(@cert_pem)

        assert X509.Certificate.from_pem(integration.config.idp_cert_pem) ==
                 X509.Certificate.from_pem(@cert_pem)
      end

      test "updates integration with PEM missing boundaries" do
        boundless_pem =
          "MIIDqjCCApKgAwIBAgIGAZfpTJclMA0GCSqGSIb3DQEBCwUAMIGVMQswCQYDVQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEUMBIGA1UECwwLU1NPUHJvdmlkZXIxFjAUBgNVBAMMDXRyaWFsLTU1OTk4NzkxHDAaBgkqhkiG9w0BCQEWDWluZm9Ab2t0YS5jb20wHhcNMjUwNzA4MDkwOTAwWhcNMzUwNzA4MDkxMDAwWjCBlTELMAkGA1UEBhMCVVMxEzARBgNVBAgMCkNhbGlmb3JuaWExFjAUBgNVBAcMDVNhbiBGcmFuY2lzY28xDTALBgNVBAoMBE9rdGExFDASBgNVBAsMC1NTT1Byb3ZpZGVyMRYwFAYDVQQDDA10cmlhbC01NTk5ODc5MRwwGgYJKoZIhvcNAQkBFg1pbmZvQG9rdGEuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzmF1LGsjEQkdLfCR6epCX5uKaJnowd3ZE8/t+kPiW0TIIvp4a3bH7r+pBbbili7Wz8LRs6C99RmtG4KjfBd6IAS1vYVba1RJ3XkoiIfVeDCP5sXKPyRquNj1/gyZkYxTYZVnh3ibXXUmlIkCDrF0TeO+4VfrWXQlc5/vNz7fbhH3bYCFj8jy3tKqXsE18X5USALRH22K4N2ZcGujNMwxzXIqGkPyPfRpnSY+AS8tGnW36Xn4WnKs9ciAnmTtTMXNrGrc6OLkbAEKLxSegpV9oSugChZ21siJXFf2Xz3jp71C12kbEDCXQ8Xi86iS3PnBYvp2ThT0Qiby1vscdNGaUwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCEbceBacHt0sx6Q0sU68E6CyyEfYVHPUOxLwBq4lrqeh9b0fctNuyFAceJbejIto9sqQ+RQzqob5PGfNpFanPbrcOx5F4NLgS9keR/bJGetSfiQe0nw/2ikNd7O0mWeWo1LvRtTGOAS2o3NTkLv3W1mxCkgjbi24hQs6eR5ARY6//AqYQWwWIDMIZotuIuRh285A8Gn1Vxj6ApWski3jttCLzU7NDJU7I6CXfzbDdEpr9I18CEZ7oOei/61q4wNq/x3CT4TsbDnVLVcYs0qqe/EKwQ6alqkHqlp2zxThOVvMW6tz0X8hNnxrXmmZdp7WF6s/8/Pw9Dq691L0AIKnIL"

        pem = """
        -----BEGIN CERTIFICATE-----
        MIIDqjCCApKgAwIBAgIGAZfpTJclMA0GCSqGSIb3DQEBCwUAMIGVMQswCQYDVQQGEwJVUzETMBEG
        A1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5jaXNjbzENMAsGA1UECgwET2t0YTEU
        MBIGA1UECwwLU1NPUHJvdmlkZXIxFjAUBgNVBAMMDXRyaWFsLTU1OTk4NzkxHDAaBgkqhkiG9w0B
        CQEWDWluZm9Ab2t0YS5jb20wHhcNMjUwNzA4MDkwOTAwWhcNMzUwNzA4MDkxMDAwWjCBlTELMAkG
        A1UEBhMCVVMxEzARBgNVBAgMCkNhbGlmb3JuaWExFjAUBgNVBAcMDVNhbiBGcmFuY2lzY28xDTAL
        BgNVBAoMBE9rdGExFDASBgNVBAsMC1NTT1Byb3ZpZGVyMRYwFAYDVQQDDA10cmlhbC01NTk5ODc5
        MRwwGgYJKoZIhvcNAQkBFg1pbmZvQG9rdGEuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
        CgKCAQEAzmF1LGsjEQkdLfCR6epCX5uKaJnowd3ZE8/t+kPiW0TIIvp4a3bH7r+pBbbili7Wz8LR
        s6C99RmtG4KjfBd6IAS1vYVba1RJ3XkoiIfVeDCP5sXKPyRquNj1/gyZkYxTYZVnh3ibXXUmlIkC
        DrF0TeO+4VfrWXQlc5/vNz7fbhH3bYCFj8jy3tKqXsE18X5USALRH22K4N2ZcGujNMwxzXIqGkPy
        PfRpnSY+AS8tGnW36Xn4WnKs9ciAnmTtTMXNrGrc6OLkbAEKLxSegpV9oSugChZ21siJXFf2Xz3j
        p71C12kbEDCXQ8Xi86iS3PnBYvp2ThT0Qiby1vscdNGaUwIDAQABMA0GCSqGSIb3DQEBCwUAA4IB
        AQCEbceBacHt0sx6Q0sU68E6CyyEfYVHPUOxLwBq4lrqeh9b0fctNuyFAceJbejIto9sqQ+RQzqo
        b5PGfNpFanPbrcOx5F4NLgS9keR/bJGetSfiQe0nw/2ikNd7O0mWeWo1LvRtTGOAS2o3NTkLv3W1
        mxCkgjbi24hQs6eR5ARY6//AqYQWwWIDMIZotuIuRh285A8Gn1Vxj6ApWski3jttCLzU7NDJU7I6
        CXfzbDdEpr9I18CEZ7oOei/61q4wNq/x3CT4TsbDnVLVcYs0qqe/EKwQ6alqkHqlp2zxThOVvMW6
        tz0X8hNnxrXmmZdp7WF6s/8/Pw9Dq691L0AIKnIL
        -----END CERTIFICATE-----
        """

        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:ok, integration} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: boundless_pem
                 })

        assert integration.config.idp_signin_url == "https://example.com"
        assert integration.config.idp_entity_id == "some-entity"

        assert X509.Certificate.from_pem(integration.config.idp_cert_pem) ==
                 X509.Certificate.from_pem(pem)
      end

      test "optionally accepts metadata" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:ok, integration} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: @cert_pem,
                   idp_metadata: "<some-metadata></some-metadata>"
                 })

        assert integration.config.idp_metadata == "<some-metadata></some-metadata>"
      end

      test "works with string keys" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:ok, _integration} =
                 SSO.update_integration(integration, %{
                   "idp_signin_url" => "https://example.com",
                   "idp_entity_id" => "some-entity",
                   "idp_cert_pem" => @cert_pem
                 })
      end

      test "returns error on missing parameters" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:error, changeset} = SSO.update_integration(integration, %{})

        assert %{
                 idp_signin_url: [:required],
                 idp_entity_id: [:required],
                 idp_cert_pem: [:required]
               } =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end

      test "returns error on invalid signin url" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:error, changeset} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "invalid-url",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: @cert_pem
                 })

        assert %{
                 idp_signin_url: [:url]
               } =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end

      test "returns error on invalid certificate" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        assert {:error, changeset} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: "INVALID CERT"
                 })

        assert %{
                 idp_cert_pem: [:cert_pem]
               } =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end

      test "returns error on invalid certificate (#2)" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)

        invalid_cert = """
        -----BEGIN CERTIFICATE-----
        MIIFdTCCA12gAwIBAgIUNcATm3CidmlEMMsZa9KBZpWYCVcwDQYJKoZIhvcNAQEL
        BQAwYzELMAkGA1UEBhMCQVUxEzARBgNVBAgMClNvbWUtU3RhdGUxITAfBgNVBAoM
        """

        assert {:error, changeset} =
                 SSO.update_integration(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some-entity",
                   idp_cert_pem: invalid_cert
                 })

        assert %{
                 idp_cert_pem: [:cert_pem]
               } =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end
    end

    describe "provision_user/1" do
      setup do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok, team: team, integration: integration, domain: domain, sso_domain: sso_domain}
      end

      test "provisions a new SSO user form identity", %{
        integration: integration,
        domain: domain,
        sso_domain: sso_domain,
        team: team
      } do
        identity = new_identity("Jane Sculley", "jane@" <> domain, integration)

        assert {:ok, :identity, matched_team, user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert user.id
        assert user.email == identity.email
        assert user.type == :sso
        assert user.name == identity.name
        assert user.sso_identity_id == identity.id
        assert user.sso_integration_id == integration.id
        assert user.sso_domain_id == sso_domain.id
        assert user.email_verified
        assert user.last_sso_login
        assert_team_membership(user, team, :viewer)

        assert audited_entry("sso_user_provisioned", team_id: team.id, entity_id: "#{user.id}")
      end

      test "does not provision a user from identity when identity integration does not match", %{
        domain: domain
      } do
        other_team = new_site().team
        other_integration = SSO.initiate_saml_integration(other_team)
        other_domain = "other-example-#{Enum.random(1..10_000)}.com"
        {:ok, other_sso_domain} = SSO.Domains.add(other_integration, other_domain)
        _other_sso_domain = SSO.Domains.verify(other_sso_domain, skip_checks?: true)

        identity = new_identity("Jane Sculley", "jane@" <> domain, other_integration)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "provisions SSO user from existing user", %{
        integration: integration,
        team: team,
        domain: domain,
        sso_domain: sso_domain
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)

        # guest membership on a site on another team should not affect provisioning
        another_team_site = new_site()
        add_guest(another_team_site, user: user, role: :editor)

        identity = new_identity(user.name, user.email, integration)

        assert {:ok, :standard, matched_team, sso_user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert sso_user.id == user.id
        assert sso_user.email == identity.email
        assert sso_user.type == :sso
        assert sso_user.name == identity.name
        assert sso_user.sso_identity_id == identity.id
        assert sso_user.sso_integration_id == integration.id
        assert sso_user.sso_domain_id == sso_domain.id
        assert sso_user.email_verified
        assert sso_user.last_sso_login

        assert audited_entry("sso_user_provisioned", team_id: team.id, entity_id: "#{user.id}")
      end

      test "provisions SSO user from existing user with personal team", %{
        integration: integration,
        team: team,
        domain: domain,
        sso_domain: sso_domain
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        {:ok, _} = Plausible.Teams.get_or_create(user)
        add_member(team, user: user, role: :editor)

        # guest membership on a site on another team should not affect provisioning
        another_team_site = new_site()
        add_guest(another_team_site, user: user, role: :editor)

        identity = new_identity(user.name, user.email, integration)

        assert {:ok, :standard, matched_team, sso_user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert sso_user.id == user.id
        assert sso_user.email == identity.email
        assert sso_user.type == :sso
        assert sso_user.name == identity.name
        assert sso_user.sso_identity_id == identity.id
        assert sso_user.sso_integration_id == integration.id
        assert sso_user.sso_domain_id == sso_domain.id
        assert sso_user.email_verified
        assert sso_user.last_sso_login
      end

      test "provisions existing SSO user", %{
        integration: integration,
        team: team,
        domain: domain,
        sso_domain: sso_domain
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        identity = new_identity(user.name, user.email, integration)
        {:ok, :standard, _team, user} = SSO.provision_user(identity)

        assert {:ok, :sso, matched_team, sso_user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert sso_user.id == user.id
        assert sso_user.email == identity.email
        assert sso_user.type == :sso
        assert sso_user.name == identity.name
        assert sso_user.sso_identity_id == identity.id
        assert sso_user.sso_integration_id == integration.id
        assert sso_user.sso_domain_id == sso_domain.id
        assert sso_user.last_sso_login

        assert audited_entries(2, "sso_user_provisioned",
                 team_id: team.id,
                 entity_id: "#{sso_user.id}"
               )
      end

      test "does not provision user without matching setup integration", %{
        integration: integration,
        team: team
      } do
        # rogue e-mail
        identity = new_identity("Rodney Williams", "rodney@example.com", integration)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)

        # member without setup domain
        user = new_user(email: "jane@example.com", name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        identity = new_identity(user.name, user.email, integration)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision non-member even if e-mail matches domain", %{
        integration: integration,
        domain: domain
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        another_team = new_site().team
        add_member(another_team, user: user, role: :editor)
        identity = new_identity(user.name, user.email, integration)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision guest member", %{
        team: team,
        domain: domain,
        integration: integration
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        site = new_site(team: team)
        add_guest(site, user: user, role: :editor)
        identity = new_identity(user.name, user.email, integration)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision when user is member of more than one team", %{
        domain: domain,
        team: team,
        integration: integration
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        another_team = new_site().team |> Plausible.Teams.complete_setup()
        add_member(another_team, user: user, role: :viewer)
        identity = new_identity(user.name, user.email, integration)

        assert {:error, :multiple_memberships, matched_team, matched_user} =
                 SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert matched_user.id == user.id
      end

      test "does not provision from existing user with personal team with subscription", %{
        team: team,
        domain: domain,
        integration: integration
      } do
        user =
          new_user(email: "jane@" <> domain, name: "Jane Sculley") |> subscribe_to_growth_plan()

        add_member(team, user: user, role: :editor)

        identity = new_identity(user.name, user.email, integration)

        assert {:error, :active_personal_team, matched_team, matched_user} =
                 SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert matched_user.id == user.id
      end

      test "does not provision from existing user with personal team with site", %{
        team: team,
        domain: domain,
        integration: integration
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")

        new_site(owner: user)

        add_member(team, user: user, role: :editor)

        identity = new_identity(user.name, user.email, integration)

        assert {:error, :active_personal_team, matched_team, matched_user} =
                 SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert matched_user.id == user.id
      end

      test "does not provision new SSO user from identity when team is over members limit", %{
        domain: domain,
        team: team,
        integration: integration
      } do
        insert(:growth_subscription, team: team)

        add_member(team, role: :viewer)
        add_member(team, role: :viewer)
        add_member(team, role: :viewer)

        identity = new_identity("Jane Sculley", "jane@" <> domain, integration)

        assert {:error, :over_limit} = SSO.provision_user(identity)
      end

      test "does not provision existing SSO user when email domain is not allowlisted", %{
        domain: domain,
        integration: integration
      } do
        identity = new_identity("Jane Sculley", "jane@" <> domain, integration)

        assert {:ok, _, _, sso_user} = SSO.provision_user(identity)

        identity =
          new_identity(
            "Jane Sculley on New Email",
            "jane@new.example.com",
            integration,
            sso_user.sso_identity_id
          )

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end
    end

    describe "deprovision_user!/1" do
      test "deprovisions SSO user" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity("Clarence Fortridge", "clarence@" <> domain, integration)
        {:ok, _, _, user} = SSO.provision_user(identity)

        user = Repo.reload!(user)
        session = Auth.UserSessions.create!(user, "Unknown")

        updated_user = SSO.deprovision_user!(user)

        refute Repo.reload(session)
        assert updated_user.id == user.id
        assert updated_user.type == :standard
        refute updated_user.sso_identity_id
        refute updated_user.sso_integration_id
        refute updated_user.sso_domain_id

        assert audited_entry("sso_user_deprovioned",
                 team_id: team.id,
                 entity_id: "#{updated_user.id}"
               )
      end

      test "handles standard user gracefully without revoking existing sessions" do
        user = new_user()
        session = Auth.UserSessions.create!(user, "Unknown")

        assert updated_user = SSO.deprovision_user!(user)

        assert Repo.reload(session)
        assert updated_user.id == user.id
        assert updated_user.type == :standard
        refute updated_user.sso_identity_id
        refute updated_user.sso_integration_id
        refute updated_user.sso_domain_id
      end
    end

    describe "update_policy/2" do
      test "updates team policy attributes" do
        team = new_site().team

        assert team.policy.sso_default_role == :viewer
        assert team.policy.sso_session_timeout_minutes == 360

        assert {:ok, team} =
                 SSO.update_policy(
                   team,
                   sso_default_role: "editor",
                   sso_session_timeout_minutes: 600
                 )

        assert team.policy.sso_default_role == :editor
        assert team.policy.sso_session_timeout_minutes == 600

        assert audited_entry("sso_policy_updated",
                 team_id: team.id,
                 entity_id: "#{team.id}"
               )
      end

      test "accepts single attributes leaving others as they are" do
        team = new_site().team

        assert team.policy.sso_default_role == :viewer
        assert team.policy.sso_session_timeout_minutes == 360

        assert {:ok, team} = SSO.update_policy(team, sso_default_role: "editor")

        assert team.policy.sso_default_role == :editor
        assert team.policy.sso_session_timeout_minutes == 360
      end

      test "handles empty policy default gracefully" do
        team = new_site().team

        Repo.update_all(
          from(t in Teams.Team,
            where: t.id == ^team.id,
            update: [set: [policy: fragment("'{}'::json")]]
          ),
          []
        )

        team = Repo.reload!(team)

        assert {:ok, team} = SSO.update_policy(team, sso_default_role: "editor")

        assert team.policy.sso_default_role == :editor
        assert team.policy.sso_session_timeout_minutes == 360

        team = Repo.reload!(team)

        assert {:ok, team} = SSO.update_policy(team, sso_session_timeout_minutes: 200)

        team = Repo.reload!(team)

        assert team.policy.sso_default_role == :editor
        assert team.policy.sso_session_timeout_minutes == 200
      end

      test "returns changeset on invalid input" do
        team = new_site().team

        assert {:error, changeset} =
                 SSO.update_policy(team, sso_session_timeout_minutes: "1024000005")

        assert %{sso_session_timeout_minutes: [:number]} =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end
    end

    describe "check_force_sso/2" do
      test "returns ok when conditions are met for setting all_but_owners" do
        # Owner with 2FA enabled
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert :ok = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when one owner does not have 2FA configured" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Owner without 2FA
        another_owner = new_user()
        add_member(team, user: another_owner, role: :owner)

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Carrie Mower", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:error, :owner_2fa_disabled} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no provisioned SSO user present" do
        # Owner with 2FA enabled
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        assert {:error, :no_sso_user} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no verified SSO domain present" do
        # Owner with 2FA enabled
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        # Unverified domain
        {:ok, _sso_domain} = SSO.Domains.add(integration, domain)

        assert {:error, :no_verified_domain} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no SSO domain present" do
        # Owner with 2FA enabled
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        _integration = SSO.initiate_saml_integration(team)

        assert {:error, :no_domain} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no SSO integration present" do
        # Owner with 2FA enabled
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        assert {:error, :no_integration} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns ok when setting to none" do
        team = new_site().team

        assert :ok = SSO.check_force_sso(team, :none)
      end
    end

    describe "set_force_sso/2" do
      test "sets enforce mode to all_but_owners when conditions met" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:ok, updated_team} = SSO.set_force_sso(team, :all_but_owners)

        assert updated_team.id == team.id
        assert updated_team.policy.force_sso == :all_but_owners

        assert audited_entry("sso_force_mode_changed", team_id: team.id, entity_id: "#{team.id}")
      end

      test "handles empty policy default gracefully" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        Repo.update_all(
          from(t in Teams.Team,
            where: t.id == ^team.id,
            update: [set: [policy: fragment("'{}'::json")]]
          ),
          []
        )

        team = Repo.reload!(team)

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:ok, updated_team} = SSO.set_force_sso(team, :all_but_owners)

        assert updated_team.id == team.id
        assert updated_team.policy.force_sso == :all_but_owners

        # Set another team policy setting to check if it remains intact
        {:ok, team} = SSO.update_policy(updated_team, sso_default_role: "editor")

        assert {:ok, updated_team} = SSO.set_force_sso(team, :none)

        updated_team = Repo.reload!(updated_team)

        assert updated_team.policy.force_sso == :none
        assert updated_team.policy.sso_default_role == :editor
      end

      test "returns error when conditions not met" do
        team = new_site().team

        assert {:error, :no_integration} = SSO.set_force_sso(team, :all_but_owners)
      end

      test "sets enforce mode to none" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        {:ok, team} = SSO.set_force_sso(team, :all_but_owners)

        assert {:ok, updated_team} = SSO.set_force_sso(team, :none)

        assert updated_team.id == team.id
        assert updated_team.policy.force_sso == :none
      end
    end

    describe "check_can_remove_integration/1" do
      test "returns ok if conditions to remove integration met" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)
        assert :ok = SSO.check_can_remove_integration(integration)
      end

      test "returns error if force SSO enabled" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # Force SSO enabled
        {:ok, _} = SSO.set_force_sso(team, :all_but_owners)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)
        assert {:error, :force_sso_enabled} = SSO.check_can_remove_integration(integration)
      end

      test "returns error if SSO user present" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        integration = Repo.reload!(integration)
        assert {:error, :sso_users_present} = SSO.check_can_remove_integration(integration)
      end
    end

    describe "remove_integration/1,2" do
      test "removes integration when conditions met" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)

        assert :ok = SSO.remove_integration(integration)
        refute Repo.reload(integration)
        refute Repo.reload(sso_domain)

        assert audited_entry("sso_integration_removed",
                 team_id: team.id,
                 entity_id: "#{integration.id}"
               )
      end

      test "returns error when conditions not met" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        integration = Repo.reload!(integration)

        assert {:error, :sso_users_present} = SSO.remove_integration(integration)
        assert Repo.reload(integration)
        assert Repo.reload(sso_domain)
      end

      test "succeeds when SSO user present and force flag set" do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Carrie Mower", "carrie@" <> domain, integration)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        integration = Repo.reload!(integration)

        assert :ok = SSO.remove_integration(integration, force_deprovision?: true)
        refute Repo.reload(integration)
        refute Repo.reload(sso_domain)

        # SSO user is deprovisioned
        sso_user = Repo.reload(sso_user)

        assert sso_user.type == :standard
        refute sso_user.sso_identity_id
        refute sso_user.sso_integration_id
      end

      test "cancels verification jobs for all domains when integration is removed" do
        team = new_site().team

        integration = SSO.initiate_saml_integration(team)
        domain1 = "example-#{Enum.random(1..10_000)}.com"
        domain2 = "test-#{Enum.random(1..10_000)}.com"

        {:ok, d1} = SSO.Domains.add(integration, domain1)
        {:ok, d2} = SSO.Domains.add(integration, domain2)

        {:ok, _} = SSO.Domains.start_verification(domain1)
        {:ok, _} = SSO.Domains.start_verification(domain2)

        assert_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain1})
        assert_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain2})

        assert :ok = SSO.remove_integration(integration)

        refute Repo.reload(integration)
        refute_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain1})
        refute_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain2})

        assert audited_entry("sso_domain_verification_cancelled",
                 team_id: team.id,
                 entity_id: "#{d1.id}"
               )

        assert audited_entry("sso_domain_verification_cancelled",
                 team_id: team.id,
                 entity_id: "#{d2.id}"
               )

        assert audited_entry("sso_integration_removed",
                 team_id: team.id,
                 entity_id: "#{integration.id}"
               )
      end

      test "cancels verification jobs when integration is force removed with SSO users" do
        team = new_site().team

        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity("Test User", "test@" <> domain, integration)
        {:ok, _, _, _} = SSO.provision_user(identity)

        {:ok, sso_domain} = SSO.Domains.start_verification(domain)
        assert_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain})

        assert :ok = SSO.remove_integration(integration, force_deprovision?: true)

        refute Repo.reload(integration)
        refute_enqueued(worker: SSO.Domain.Verification.Worker, args: %{domain: domain})

        assert audited_entry("sso_domain_verification_cancelled",
                 team_id: team.id,
                 entity_id: "#{sso_domain.id}"
               )

        assert audited_entry("sso_integration_removed",
                 team_id: team.id,
                 entity_id: "#{integration.id}"
               )
      end
    end

    describe "check_ready_to_provision/2" do
      setup do
        owner = new_user()
        {:ok, owner, _} = Auth.TOTP.initiate(owner)
        {:ok, owner, _} = Auth.TOTP.enable(owner, :skip_verify)
        team = new_site(owner: owner).team |> Teams.complete_setup()

        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        {:ok,
         team: team,
         owner: owner,
         integration: integration,
         sso_domain: sso_domain,
         domain: domain}
      end

      test "returns ok for user who is already of type SSO", %{
        domain: domain,
        team: team,
        integration: integration
      } do
        identity = new_identity("Lance Wurst", "lance@" <> domain, integration)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        assert :ok = SSO.check_ready_to_provision(sso_user, team)
      end

      test "returns ok for standard user who meets criteria", %{team: team} do
        member = add_member(team, role: :viewer)

        assert :ok = SSO.check_ready_to_provision(member, team)

        # non-active personal team
        {:ok, _personal_team} = Teams.get_or_create(member)

        # guest membership in another team's site
        another_team_site = new_site()
        add_guest(another_team_site, user: member, role: :editor)
      end

      test "returns error for non-member or guest-only user", %{team: team} do
        user = new_user()

        assert {:error, :not_a_member} = SSO.check_ready_to_provision(user, team)

        site = new_site(team: team)
        guest = add_guest(site, role: :editor)

        assert {:error, :not_a_member} = SSO.check_ready_to_provision(guest, team)
      end

      test "returns error for user with more than one membership", %{team: team} do
        user = new_user()
        add_member(team, user: user, role: :viewer)
        another_team = new_site().team |> Teams.complete_setup()
        add_member(another_team, user: user, role: :editor)

        assert {:error, :multiple_memberships} = SSO.check_ready_to_provision(user, team)
      end

      test "returns error for personal team with sites", %{team: team} do
        user = new_user()
        add_member(team, user: user, role: :viewer)

        {:ok, personal_team} = Teams.get_or_create(user)
        new_site(team: personal_team)

        assert {:error, :active_personal_team} = SSO.check_ready_to_provision(user, team)
      end

      test "returns error for personal team active subscription", %{team: team} do
        user = new_user() |> subscribe_to_growth_plan()
        add_member(team, user: user, role: :viewer)

        assert {:error, :active_personal_team} = SSO.check_ready_to_provision(user, team)
      end
    end
  end
end
