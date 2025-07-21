defmodule Plausible.Auth.SSO.Domain.Verification.WorkerTest do
  use Plausible.DataCase
  use Plausible

  on_ee do
    use Bamboo.Test, shared: true
    use Oban.Testing, repo: Plausible.Repo
    use Plausible.Auth.SSO.Domain.Status
    use Plausible.Teams.Test

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
        {:ok, sso_domain} = SSO.Domains.add(integration, domain)

        {:ok,
         owner: owner,
         team: team,
         integration: integration,
         domain: domain,
         sso_domain: sso_domain}
      end

      test "domain is marked as in progress and job is snoozed", %{domain: domain} do
        assert {:ok, %{status: Status.pending()}} = SSO.Domains.get(domain)

        assert {:snooze, 15} =
                 perform_job(Worker, %{"domain" => domain}, meta: %{bypass_checks: true})

        assert {:ok, %{status: Status.in_progress()}} = SSO.Domains.get(domain)

        assert {:snooze, 7680} =
                 perform_job(Worker, %{"domain" => domain},
                   attempt: 10,
                   meta: %{bypass_checks: true}
                 )

        assert {:ok, %{status: Status.in_progress()}} = SSO.Domains.get(domain)
      end

      test "domain is marked as verified and emails are sent", %{
        domain: domain,
        team: team,
        owner: owner
      } do
        owner2 = add_member(team, role: :owner)

        assert {:ok, %{status: Status.verified()}} =
                 perform_job(Worker, %{"domain" => domain}, meta: %{skip_checks: true})

        assert_email_delivered_with(
          to: [nil: owner.email],
          subject: "Your SSO domain #{domain} is ready!"
        )

        assert_email_delivered_with(
          to: [nil: owner2.email],
          subject: "Your SSO domain #{domain} is ready!"
        )

        assert audited_event("sso_domain_verification_success", team_id: team.id)
      end

      test "domain is marked as unverified when max snoozes exhausted", %{
        domain: domain,
        team: team
      } do
        assert {:snooze, _} =
                 perform_job(Worker, %{"domain" => domain},
                   attempt: 14,
                   meta: %{bypass_checks: true}
                 )

        assert {:cancel, :max_snoozes} =
                 perform_job(Worker, %{"domain" => domain},
                   attempt: 15,
                   meta: %{bypass_checks: true}
                 )

        assert_email_delivered_with(subject: "SSO domain #{domain} verification failure")
        assert audited_event("sso_domain_verification_failure", team_id: team.id)
      end
    end
  end
end
