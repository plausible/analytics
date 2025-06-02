defmodule Plausible.Auth.SSOTest do
  use Plausible.DataCase, async: true
  use Plausible

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth
    alias Plausible.Auth.SSO

    describe "initiate_saml_integration/1" do
      test "initiates new saml integration" do
        team = new_site().team

        integration = SSO.initiate_saml_integration(team)

        assert integration.team_id == team.id
        assert is_binary(integration.identifier)
        assert %SSO.SAMLConfig{} = integration.config
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
                   idp_entity_id: "some-entity",
                   idp_cert_pem: @cert_pem
                 })

        assert integration.config.idp_signin_url == "https://example.com"
        assert integration.config.idp_entity_id == "some-entity"
        assert integration.config.idp_cert_pem == @cert_pem
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
        team: team
      } do
        identity = new_identity("Jane Sculley", "jane@" <> domain)

        assert {:ok, :identity, matched_team, user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert user.id
        assert user.email == identity.email
        assert user.type == :sso
        assert user.name == identity.name
        assert user.sso_identity_id == identity.id
        assert user.sso_integration_id == integration.id
        assert user.email_verified
        assert user.last_sso_login
        assert_team_membership(user, team, :viewer)
      end

      test "provisions SSO user from existing user", %{
        integration: integration,
        team: team,
        domain: domain
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)

        # guest membership on a site on another team should not affect provisioning
        another_team_site = new_site()
        add_guest(another_team_site, user: user, role: :editor)

        identity = new_identity(user.name, user.email)

        assert {:ok, :standard, matched_team, sso_user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert sso_user.id == user.id
        assert sso_user.email == identity.email
        assert sso_user.type == :sso
        assert sso_user.name == identity.name
        assert sso_user.sso_identity_id == identity.id
        assert sso_user.sso_integration_id == integration.id
        assert sso_user.email_verified
        assert sso_user.last_sso_login
      end

      test "provisions existing SSO user", %{integration: integration, team: team, domain: domain} do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        identity = new_identity(user.name, user.email)
        {:ok, :standard, _team, user} = SSO.provision_user(identity)

        assert {:ok, :sso, matched_team, sso_user} = SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert sso_user.id == user.id
        assert sso_user.email == identity.email
        assert sso_user.type == :sso
        assert sso_user.name == identity.name
        assert sso_user.sso_identity_id == identity.id
        assert sso_user.sso_integration_id == integration.id
        assert sso_user.last_sso_login
      end

      test "does not provision user without matching setup integration", %{team: team} do
        # rogue e-mail
        identity = new_identity("Rodney Williams", "rodney@example.com")

        assert {:error, :integration_not_found} = SSO.provision_user(identity)

        # member without setup domain
        user = new_user(email: "jane@example.com", name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        identity = new_identity(user.name, user.email)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision non-member even if e-mail matches domain", %{domain: domain} do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        another_team = new_site().team
        add_member(another_team, user: user, role: :editor)
        identity = new_identity(user.name, user.email)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision guest member", %{team: team, domain: domain} do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        site = new_site(team: team)
        add_guest(site, user: user, role: :editor)
        identity = new_identity(user.name, user.email)

        assert {:error, :integration_not_found} = SSO.provision_user(identity)
      end

      test "does not provision when user is member of more than one team", %{
        domain: domain,
        team: team
      } do
        user = new_user(email: "jane@" <> domain, name: "Jane Sculley")
        add_member(team, user: user, role: :editor)
        another_team = new_site().team
        add_member(another_team, user: user, role: :viewer)
        identity = new_identity(user.name, user.email)

        assert {:error, :multiple_memberships, matched_team, matched_user} =
                 SSO.provision_user(identity)

        assert matched_team.id == team.id
        assert matched_user.id == user.id
      end

      test "does not provision new SSO user from identity when team is over members limit", %{
        domain: domain,
        team: team
      } do
        add_member(team, role: :viewer)
        add_member(team, role: :viewer)
        add_member(team, role: :viewer)

        identity = new_identity("Jane Sculley", "jane@" <> domain)

        assert {:error, :over_limit} = SSO.provision_user(identity)
      end
    end

    describe "deprovision_user!/1" do
      test "deprovisions SSO user" do
        team = new_site().team
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        identity = new_identity("Clarence Fortridge", "clarence@" <> domain)
        {:ok, _, _, user} = SSO.provision_user(identity)

        user = Repo.reload!(user)
        session = Auth.UserSessions.create(user, "Unknown")

        updated_user = SSO.deprovision_user!(user)

        refute Repo.reload(session)
        assert updated_user.id == user.id
        assert updated_user.type == :standard
        refute updated_user.sso_identity_id
        refute updated_user.sso_integration_id
      end

      test "handles standard user gracefully without revoking existing sessions" do
        user = new_user()
        session = Auth.UserSessions.create(user, "Unknown")

        assert updated_user = SSO.deprovision_user!(user)

        assert Repo.reload(session)
        assert updated_user.id == user.id
        assert updated_user.type == :standard
        refute updated_user.sso_identity_id
        refute updated_user.sso_integration_id
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
      end

      test "accepts single attributes leaving others as they are" do
        team = new_site().team

        assert team.policy.sso_default_role == :viewer
        assert team.policy.sso_session_timeout_minutes == 360

        assert {:ok, team} = SSO.update_policy(team, sso_default_role: "editor")

        assert team.policy.sso_default_role == :editor
        assert team.policy.sso_session_timeout_minutes == 360
      end
    end

    describe "check_force_sso/2" do
      test "returns ok when conditions are met for setting all_but_owners" do
        # Owner with MFA enabled
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert :ok = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when one owner does not have MFA configured" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Owner without MFA
        another_owner = new_user()
        add_member(team, user: another_owner, role: :owner)

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Carrie Mower", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:error, :owner_mfa_disabled} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no provisioned SSO user present" do
        # Owner with MFA enabled
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        assert {:error, :no_sso_user} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no verified SSO domain present" do
        # Owner with MFA enabled
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        # Unverified domain
        {:ok, _sso_domain} = SSO.Domains.add(integration, domain)

        assert {:error, :no_verified_domain} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no SSO domain present" do
        # Owner with MFA enabled
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        _integration = SSO.initiate_saml_integration(team)

        assert {:error, :no_domain} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns error when there's no SSO integration present" do
        # Owner with MFA enabled
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        assert {:error, :no_integration} = SSO.check_force_sso(team, :all_but_owners)
      end

      test "returns ok when setting to none" do
        team = new_site().team

        assert :ok = SSO.check_force_sso(team, :none)
      end
    end

    describe "set_enforce_sso/2" do
      test "sets enforce mode to all_but_owners when conditions met" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:ok, updated_team} = SSO.set_force_sso(team, :all_but_owners)

        assert updated_team.id == team.id
        assert updated_team.policy.force_sso == :all_but_owners
      end

      test "returns error when conditions not met" do
        team = new_site().team

        assert {:error, :no_integration} = SSO.set_force_sso(team, :all_but_owners)
      end

      test "sets enforce mode to none" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        {:ok, team} = SSO.set_force_sso(team, :all_but_owners)

        assert {:ok, updated_team} = SSO.set_force_sso(team, :none)

        assert updated_team.id == team.id
        assert updated_team.policy.force_sso == :none
      end
    end

    describe "check_can_remove_integration/1" do
      test "returns ok if conditions to remove integration met" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)
        assert :ok = SSO.check_can_remove_integration(integration)
      end

      test "returns error if force SSO enabled" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # Force SSO enabled
        {:ok, _} = SSO.set_force_sso(team, :all_but_owners)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)
        assert {:error, :force_sso_enabled} = SSO.check_can_remove_integration(integration)
      end

      test "returns error if SSO user present" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        _sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        integration = Repo.reload!(integration)
        assert {:error, :sso_users_present} = SSO.check_can_remove_integration(integration)
      end
    end

    describe "remove_integration/1,2" do
      test "removes integration when conditions met" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        # SSO user deprovisioned
        _user = SSO.deprovision_user!(sso_user)

        integration = Repo.reload!(integration)

        assert :ok = SSO.remove_integration(integration)
        refute Repo.reload(integration)
        refute Repo.reload(sso_domain)
      end

      test "returns error when conditions not met" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Lance Wurst", "lance@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        integration = Repo.reload!(integration)

        assert {:error, :sso_users_present} = SSO.remove_integration(integration)
        assert Repo.reload(integration)
        assert Repo.reload(sso_domain)
      end

      test "succeeds when SSO user present and force flag set" do
        owner = new_user(totp_enabled: true, totp_secret: "secret")
        team = new_site(owner: owner).team

        # Setup integration
        integration = SSO.initiate_saml_integration(team)
        domain = "example-#{Enum.random(1..10_000)}.com"

        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        # Provisioned SSO identity
        #
        identity = new_identity("Carrie Mower", "carrie@" <> domain)
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
    end

    defp new_identity(name, email, id \\ Ecto.UUID.generate()) do
      %SSO.Identity{
        id: id,
        name: name,
        email: email,
        expires_at: NaiveDateTime.add(NaiveDateTime.utc_now(:second), 6, :hour)
      }
    end
  end
end
