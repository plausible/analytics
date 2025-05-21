defmodule Plausible.Auth.SSO.IntegrationTest do
  use Plausible.DataCase, async: true
  use Plausible

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth.SSO

    describe "init_changeset/1" do
      test "inits integration" do
        team = new_site().team

        assert %{valid?: true} = changeset = SSO.Integration.init_changeset(team)
        assert {:ok, integration} = Repo.insert(changeset)
        assert integration.team_id == team.id
        assert is_binary(integration.identifier)
        assert %SSO.SAMLConfig{} = integration.config
      end
    end

    describe "update_changeset/2" do
      test "updates config" do
        team = new_site().team
        integration = team |> SSO.Integration.init_changeset() |> Repo.insert!()

        assert %{valid?: true} =
                 changeset =
                 SSO.Integration.update_changeset(integration, %{
                   idp_signin_url: "https://example.com",
                   idp_entity_id: "some_id",
                   idp_cert_pem: "SOMECERT"
                 })

        assert {:ok, integration} = Repo.update(changeset)

        assert %SSO.SAMLConfig{
                 idp_signin_url: "https://example.com",
                 idp_entity_id: "some_id",
                 idp_cert_pem: "SOMECERT"
               } = integration.config
      end
    end
  end
end
