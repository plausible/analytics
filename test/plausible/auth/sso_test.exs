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
  end
end
