defmodule Plausible.InstallationSupport.Verification.ChecksMockTest do
  use Plausible.DataCase, async: true

  on_ee do
    alias Plausible.InstallationSupport.{Checks, Result}
    alias Plausible.InstallationSupport.Verification.{ChecksMock, Diagnostics, MockScenarios}

    @url "https://example.com"

    describe "run/4" do
      test "raises when no scenario is registered for the domain" do
        domain = insert(:site).domain

        assert_raise RuntimeError, ~r/no scenario is registered/, fn ->
          ChecksMock.run(@url, domain, "manual", async?: false, slowdown: 0, report_to: nil)
        end
      end

      test "runs synchronously, keeping the given installation_type in the resulting state" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :success)

        state =
          ChecksMock.run(@url, domain, "wordpress", async?: false, slowdown: 0, report_to: nil)

        assert state.url == @url
        assert state.data_domain == domain
        assert state.diagnostics.selected_installation_type == "wordpress"
      end

      test "notifies check_start for all 3 checks with the same messages as real verification, then all_checks_done" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :success)

        ChecksMock.run(@url, domain, "manual", async?: false, slowdown: 0, report_to: self())

        assert_received {:check_start, {ChecksMock.FakeUrlCheck, _state}}
        assert_received {:check_start, {ChecksMock.FakeVerifyInstallationCheck, _state}}
        assert_received {:check_start, {ChecksMock.FakeVerifyInstallationCacheBustCheck, _state}}
        assert_received {:all_checks_done, %{data_domain: ^domain}}

        assert ChecksMock.FakeUrlCheck.report_progress_as() ==
                 Checks.Url.report_progress_as()

        assert ChecksMock.FakeVerifyInstallationCheck.report_progress_as() ==
                 Checks.VerifyInstallation.report_progress_as()

        assert ChecksMock.FakeVerifyInstallationCacheBustCheck.report_progress_as() ==
                 Checks.VerifyInstallationCacheBust.report_progress_as()
      end

      test "defaults state.url from data_domain when called with url: nil, mirroring the real Url check" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :success)

        state = ChecksMock.run(nil, domain, "manual", async?: false, slowdown: 0, report_to: nil)

        assert state.url == "https://#{domain}"
      end
    end

    describe "interpret_diagnostics/1" do
      test "returns the named result for the registered scenario" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :success)

        state = ChecksMock.run(@url, domain, "manual", async?: false, slowdown: 0, report_to: nil)

        assert %Result{ok?: true} = ChecksMock.interpret_diagnostics(state)
      end

      test "returns interpretation based on installation type" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :plausible_not_found)

        state =
          ChecksMock.run(@url, domain, "wordpress", async?: false, slowdown: 0, report_to: nil)

        assert %Result{
                 ok?: false,
                 recommendations: [%{text: recommendation}]
               } = ChecksMock.interpret_diagnostics(state)

        assert recommendation =~ "WordPress plugin"
      end

      test "uses state.url (e.g. a custom retry URL) as attempted_url, not just the bare domain" do
        domain = insert(:site).domain
        :ok = MockScenarios.put(domain, :domain_not_found)

        custom_url = "https://abc.de"

        state =
          ChecksMock.run(custom_url, domain, "manual", async?: false, slowdown: 0, report_to: nil)

        assert %Result{errors: [error]} = ChecksMock.interpret_diagnostics(state)
        assert error =~ custom_url
      end

      test "raises when no scenario is registered for the domain" do
        domain = insert(:site).domain

        state = %Plausible.InstallationSupport.State{
          url: @url,
          data_domain: domain,
          diagnostics: %Diagnostics{selected_installation_type: "manual"}
        }

        assert_raise RuntimeError, ~r/no scenario is registered/, fn ->
          ChecksMock.interpret_diagnostics(state)
        end
      end
    end
  end
end
