defmodule Plausible.Auth.SSOTest do
  use Plausible.DataCase, async: true
  use Plausible

  on_ee do
    use Plausible.Teams.Test

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

        assert {:ok, :identity, user} = SSO.provision_user(identity)

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

        assert {:ok, :standard, sso_user} = SSO.provision_user(identity)

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
        {:ok, :standard, user} = SSO.provision_user(identity)

        assert {:ok, :sso, sso_user} = SSO.provision_user(identity)

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
