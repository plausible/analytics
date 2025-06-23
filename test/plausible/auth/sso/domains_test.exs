defmodule Plausible.Auth.SSO.DomainsTest do
  use Plausible.DataCase, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    use Plausible.Teams.Test
    use Plausible.Auth.SSO.Domain.Status
    use Oban.Testing, repo: Plausible.Repo

    alias Plausible.Auth.SSO
    alias Plausible.Teams

    setup do
      owner = new_user(totp_enabled: true, totp_secret: "secret")
      team = new_site(owner: owner).team

      integration = SSO.initiate_saml_integration(team)

      {:ok, team: team, owner: owner, integration: integration}
    end

    describe "add/2" do
      test "adds a new domain", %{integration: integration} do
        domain = generate_domain()

        assert {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        assert sso_domain.domain == domain
        assert is_binary(sso_domain.identifier)
        refute sso_domain.verified_via
        refute sso_domain.last_verified_at
        assert sso_domain.status == Status.pending()
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
      test "marks domain as verified when skip_checks? option passed", %{
        integration: integration
      } do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        verified_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)

        assert verified_domain.id == sso_domain.id
        assert verified_domain.verified_via == :dns_txt
        assert verified_domain.status == Status.verified()
        assert verified_domain.last_verified_at
      end

      test "does mark domain as in progress, when no skip flag passed", %{
        integration: integration
      } do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        unverified_domain = SSO.Domains.verify(sso_domain, verification_opts: [methods: []])

        assert unverified_domain.id == sso_domain.id
        refute unverified_domain.verified_via
        assert unverified_domain.status == Status.in_progress()
        assert unverified_domain.last_verified_at
      end
    end

    describe "start_verification/1" do
      test "no domain" do
        assert {:error, :not_found} = SSO.Domains.start_verification("example.com")
      end

      test "sets domain status to in progress", %{integration: integration} do
        domain = generate_domain()
        {:ok, _} = SSO.Domains.add(integration, domain)
        assert {:ok, sso_domain} = SSO.Domains.start_verification(domain)
        assert sso_domain.status == Status.in_progress()
      end

      test "enqueues background work", %{integration: integration} do
        domain = generate_domain()
        {:ok, _} = SSO.Domains.add(integration, domain)
        assert {:ok, _} = SSO.Domains.start_verification(domain)

        assert_enqueued(
          worker: Plausible.Auth.SSO.Domain.Verification.Worker,
          args: %{domain: domain}
        )
      end
    end

    describe "cancel_verification/1" do
      test "no domain" do
        assert :ok = SSO.Domains.cancel_verification("example.com")
      end

      test "sets domain status to unverified", %{integration: integration} do
        domain = generate_domain()
        {:ok, _} = SSO.Domains.add(integration, domain)
        assert {:ok, sso_domain} = SSO.Domains.start_verification(domain)
        assert :ok = SSO.Domains.cancel_verification(domain)
        assert Repo.reload!(sso_domain).status == Status.unverified()
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

      test "returns error if matching domain is not verified", %{integration: integration} do
        domain = generate_domain()
        {:ok, _sso_domain} = SSO.Domains.add(integration, domain)

        assert {:error, :not_found} = SSO.Domains.lookup(domain)
      end

      test "returns error if domain not found" do
        domain = generate_domain()

        assert {:error, :not_found} = SSO.Domains.lookup(domain)
      end
    end

    describe "check_can_remove/1" do
      setup %{integration: integration} do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        {:ok, domain: domain, sso_domain: sso_domain}
      end

      test "returns ok when all conditions met", %{sso_domain: sso_domain} do
        assert :ok = SSO.Domains.remove(sso_domain)

        refute Repo.reload(sso_domain)
      end

      test "returns ok when force SSO enabled and SSO users on other domains present", %{
        team: team,
        integration: integration,
        sso_domain: sso_domain
      } do
        other_domain = generate_domain()
        {:ok, other_sso_domain} = SSO.Domains.add(integration, other_domain)
        _other_sso_domain = SSO.Domains.verify(other_sso_domain, skip_checks?: true)
        other_identity = new_identity("Mary Goodwill", "mary@" <> other_domain)
        {:ok, _, _, _other_sso_user} = SSO.provision_user(other_identity)
        {:ok, _team} = SSO.set_force_sso(team, :all_but_owners)

        sso_domain = Repo.reload!(sso_domain)
        assert :ok = SSO.Domains.check_can_remove(sso_domain)
      end

      test "returns error when force SSO enabled and SSO users only present on current domain", %{
        team: team,
        domain: domain,
        sso_domain: sso_domain
      } do
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)
        identity = new_identity("Claude Leferge", "claude@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)
        {:ok, _team} = SSO.set_force_sso(team, :all_but_owners)

        sso_domain = Repo.reload!(sso_domain)
        assert {:error, :force_sso_enabled} = SSO.Domains.check_can_remove(sso_domain)
      end

      test "returns error when SSO users present on current domain", %{
        domain: domain,
        sso_domain: sso_domain
      } do
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)
        identity = new_identity("Claude Leferge", "claude@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        sso_domain = Repo.reload!(sso_domain)
        assert {:error, :sso_users_present} = SSO.Domains.check_can_remove(sso_domain)
      end
    end

    describe "remove/1,2" do
      setup %{integration: integration} do
        domain = generate_domain()
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        {:ok, domain: domain, sso_domain: sso_domain}
      end

      test "removes the domain if conditions met", %{sso_domain: sso_domain} do
        assert :ok = SSO.Domains.remove(sso_domain)
        refute Repo.reload(sso_domain)
      end

      test "fails to remove the domain whenSSO users present on it", %{
        domain: domain,
        sso_domain: sso_domain
      } do
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)
        identity = new_identity("Claude Leferge", "claude@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)

        assert {:error, :sso_users_present} = SSO.Domains.remove(sso_domain)
        assert Repo.reload(sso_domain)
      end

      test "removes the domain and deprovisions SSO users when force flag set", %{
        domain: domain,
        sso_domain: sso_domain
      } do
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)
        identity = new_identity("Claude Leferge", "claude@" <> domain)
        {:ok, _, _, sso_user} = SSO.provision_user(identity)

        assert :ok = SSO.Domains.remove(sso_domain, force_deprovision?: true)
        refute Repo.reload(sso_domain)

        # SSO user is deprovisioned
        sso_user = Repo.reload(sso_user)

        assert sso_user.type == :standard
        refute sso_user.sso_identity_id
        refute sso_user.sso_integration_id
        refute sso_user.sso_domain_id
      end

      test "fails to remove when force SSO enabled with SSO users only on that domain", %{
        team: team,
        domain: domain,
        sso_domain: sso_domain
      } do
        sso_domain = SSO.Domains.verify(sso_domain, skip_checks?: true)
        identity = new_identity("Claude Leferge", "claude@" <> domain)
        {:ok, _, _, _sso_user} = SSO.provision_user(identity)
        {:ok, _} = SSO.set_force_sso(team, :all_but_owners)

        sso_domain = Repo.reload!(sso_domain)
        assert {:error, :force_sso_enabled} = SSO.Domains.check_can_remove(sso_domain)
      end
    end

    defp generate_domain() do
      "example-#{Enum.random(1..10_000)}.com"
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
