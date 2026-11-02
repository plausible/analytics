defmodule Plausible.Auth.SSO.Domain.Verification.WorkerTest do
  use Plausible.DataCase

  on_ee do
    use Bamboo.Test, shared: true
    use Oban.Testing, repo: Plausible.Repo
    use Plausible.Auth.SSO.Domain.Status

    alias Plasusible.Test.Support.DNSServer
    alias Plausible.Auth.SSO
    alias Plausible.Auth.SSO.Domain.Verification.Worker

    test "no sso domain cancels the job" do
      assert {:cancel, :domain_not_found} =
               perform_job(Worker, %{"domain" => "hello.example.com"})
    end

    test "enqueue works" do
      {:ok, _} = Worker.enqueue("example.com")
      assert_enqueued(worker: Worker, args: %{domain: "example.com"})
    end

    test "enqueue is idempotent" do
      {:ok, %{id: id}} = Worker.enqueue("example.com")
      {:ok, %{id: ^id, conflict?: true}} = Worker.enqueue("example.com")
      assert_enqueued(worker: Worker, args: %{domain: "example.com"})
    end

    test "enqueue then cancel" do
      {:ok, _} = Worker.enqueue("example.com")
      assert_enqueued(worker: Worker, args: %{domain: "example.com"})
      :ok = Worker.cancel("example.com")
      refute_enqueued(worker: Worker, args: %{domain: "example.com"})
    end

    describe "integration set up" do
      setup do
        owner = new_user()
        team = new_site(owner: owner).team
        integration = SSO.initiate_saml_integration(team)
        domain = "#{Enum.random(1..10_000)}.example.com"
        {:ok, sso_domain} = add_sso_domain(integration, domain)

        {:ok,
         owner: owner,
         team: team,
         integration: integration,
         domain: domain,
         sso_domain: sso_domain}
      end

      test "domain is marked as in progress and job is snoozed", %{domain: domain} do
        fail_checks(domain)
        assert {:ok, %{status: Status.pending()}} = SSO.Domains.get(domain)

        assert {:snooze, 15} =
                 perform_job(Worker, %{"domain" => domain})

        assert {:ok, %{status: Status.in_progress()}} = SSO.Domains.get(domain)

        assert {:snooze, 7680} =
                 perform_job(Worker, %{"domain" => domain}, attempt: 10)

        assert {:ok, %{status: Status.in_progress()}} = SSO.Domains.get(domain)
      end

      test "domain is marked as verified and emails are sent", %{
        sso_domain: sso_domain,
        domain: domain,
        team: team,
        owner: owner
      } do
        owner2 = add_member(team, role: :owner)
        serve_txt("plausible-sso-verification=#{sso_domain.identifier}")

        assert {:ok, %{status: Status.verified()}} =
                 perform_job(Worker, %{"domain" => domain})

        assert_email_delivered_with(
          to: [nil: owner.email],
          subject: "Your SSO domain #{domain} is ready!"
        )

        assert_email_delivered_with(
          to: [nil: owner2.email],
          subject: "Your SSO domain #{domain} is ready!"
        )

        {:ok, domain} = SSO.Domains.get(domain)

        assert audited_entry("sso_domain_verification_success",
                 team_id: team.id,
                 entity_id: "#{domain.id}"
               )
      end

      test "domain is marked as unverified when max snoozes exhausted", %{
        domain: domain,
        team: team
      } do
        fail_checks(domain)

        assert {:snooze, _} =
                 perform_job(Worker, %{"domain" => domain}, attempt: 14)

        assert {:cancel, :max_snoozes} =
                 perform_job(Worker, %{"domain" => domain}, attempt: 15)

        assert_email_delivered_with(subject: "SSO domain #{domain} verification failure")

        {:ok, domain} = SSO.Domains.get(domain)

        assert audited_entry("sso_domain_verification_failure",
                 team_id: team.id,
                 entity_id: "#{domain.id}"
               )
      end
    end

    defp serve_txt(record) do
      {:ok, port} = DNSServer.start(record)
      patch_env(:sso_verification_nameservers, [{{0, 0, 0, 0}, port}])
    end

    defp fail_checks(domain) do
      patch_env(:sso_verification_nameservers, fail_sso_checks(domain))
    end
  end
end
