defmodule Plausible.Auth.SSO.DomainsTest do
  use Plausible.DataCase, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    use Plausible.Teams.Test

    alias Plausible.Auth.SSO
    alias Plausible.Teams

    setup do
      team = new_site().team

      integration = SSO.initiate_saml_integration(team)

      {:ok, team: team, integration: integration}
    end

    describe "add/2" do
      test "adds a new domain", %{integration: integration} do
        domain = generate_domain()

        assert {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        assert sso_domain.domain == domain
        assert is_binary(sso_domain.identifier)
        refute sso_domain.validated_via
        refute sso_domain.last_validated_at
        assert sso_domain.status == :pending
      end

      test "normalizes domain before adding", %{integration: integration} do
        domain = generate_domain()

        inputs = [
          "  " <> String.upcase(domain) <> "  ",
          "https://" <> domain,
          "http://" <> domain,
          "http://" <> domain <> "/",
          "//" <> domain,
          "//" <> domain <> ":1234",
          "https://" <> domain <> ":443",
          "ftp://" <> domain,
          domain <> "/path",
          "https://" <> domain <> "?query=string",
          "https://" <> domain <> "#fragment",
          "https://user:info@" <> domain
        ]

        for input <- inputs do
          assert {:ok, sso_domain} = SSO.Domains.add(integration, input)
          assert sso_domain.domain == domain
          Repo.delete!(sso_domain)
        end
      end

      test "rejects empty domain", %{integration: integration} do
        assert {:error, changeset} = SSO.Domains.add(integration, " ")

        assert %{domain: [:required]} =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:validation]
                 end)
      end

      test "rejects invalid domain", %{integration: integration} do
        assert {:error, _changeset} = SSO.Domains.add(integration, "invalid domain")
        assert {:error, _changeset} = SSO.Domains.add(integration, "invalid domain.com")
      end

      test "rejects already added domain", %{integration: integration} do
        domain = generate_domain()
        {:ok, _} = SSO.Domains.add(integration, domain)

        assert {:error, changeset} = SSO.Domains.add(integration, domain)

        assert %{domain: [:unique]} =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:constraint]
                 end)
      end

      test "rejects domain which is already added in another team", %{integration: integration} do
        domain = generate_domain()
        {:ok, _} = SSO.Domains.add(integration, domain)

        other_team = new_site().team
        other_integration = SSO.initiate_saml_integration(other_team)

        assert {:error, changeset} = SSO.Domains.add(other_integration, domain)

        assert %{domain: [:unique]} =
                 Ecto.Changeset.traverse_errors(changeset, fn {_msg, opts} ->
                   opts[:constraint]
                 end)
      end
    end

    describe "verify/2" do
      test "marks domain as validated when skip_checks? option passed", %{
        integration: integration
      } do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        valid_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        assert valid_domain.id == sso_domain.id
        assert valid_domain.validated_via == :dns_txt
        assert valid_domain.status == :validated
        assert valid_domain.last_validated_at
      end

      test "does not mark domain as validated when no skip flag passed", %{
        integration: integration
      } do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        invalid_domain = SSO.Domains.verify(sso_domain, verification_opts: [methods: []])

        assert invalid_domain.id == sso_domain.id
        refute invalid_domain.validated_via
        assert invalid_domain.status == :pending
        assert invalid_domain.last_validated_at
      end
    end

    describe "lookup/1" do
      test "looks up domain by email", %{integration: integration} do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        email = "mary.jane@" <> domain

        assert {:ok, found_sso_domain} = SSO.Domains.lookup(email)

        assert found_sso_domain.id == sso_domain.id
        assert %SSO.Integration{} = found_sso_domain.sso_integration
        assert %Teams.Team{} = found_sso_domain.sso_integration.team
      end

      test "looks up domain by plain domain", %{integration: integration} do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        assert {:ok, found_sso_domain} = SSO.Domains.lookup(domain)
        assert found_sso_domain.id == sso_domain.id
      end

      test "normalizes input removing whitespace and capitalizations", %{integration: integration} do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        email = "  maRy.jAnE@" <> String.upcase(domain) <> "  "

        assert {:ok, found_sso_domain} = SSO.Domains.lookup(email)
        assert found_sso_domain.id == sso_domain.id
      end

      test "returns error if matching domain is not validated", %{integration: integration} do
        domain = generate_domain()
        {:ok, _sso_domain} = SSO.Domains.add(integration, domain)

        assert {:error, :not_found} = SSO.Domains.lookup(domain)
      end

      test "returns error if domain not found" do
        domain = generate_domain()

        assert {:error, :not_found} = SSO.Domains.lookup(domain)
      end
    end

    defp generate_domain() do
      "example-#{Enum.random(1..10_000)}.com"
    end
  end
end
