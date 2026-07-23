defmodule Plausible.InstallationSupport.Verification.ChecksMock do
  @moduledoc """
  Drop-in replacement for `Plausible.InstallationSupport.Verification.Checks`
  that never performs a real DNS lookup or browserless check for a domain
  with a registered mock scenario. Used locally (`:dev`) and in Playwright
  e2e specs (`:e2e_test`) to deterministically drive
  `PlausibleWeb.Live.Verification`'s banner UI - see
  `Plausible.InstallationSupport.verification_checks_mod/0`.

  When no scenario is registered for a domain (see
  `Plausible.InstallationSupport.Verification.MockScenarios.put/3`):

    * in `:dev`, falls back to the real `Checks` module - casually loading a
      site with `?verify_installation=true` still verifies for real unless
      you've deliberately mocked that domain.

    * everywhere else (`:e2e_test`, and `:test` for this module's own
      tests), raises - every e2e spec that drives verification is expected
      to register a scenario before triggering it, and it shouldn't
      silently fall back to a real, slow, non-deterministic check.
  """

  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}
  alias Plausible.InstallationSupport.Verification.{Diagnostics, MockScenarios}
  alias Plausible.InstallationSupport.Verification.Checks, as: RealChecks

  defmodule FakeUrlCheck do
    @moduledoc false
    use Plausible.InstallationSupport.Check

    @impl true
    def report_progress_as, do: Checks.Url.report_progress_as()

    @impl true
    def perform(state, _opts), do: state
  end

  defmodule FakeVerifyInstallationCheck do
    @moduledoc false
    use Plausible.InstallationSupport.Check

    @impl true
    def report_progress_as, do: Checks.VerifyInstallation.report_progress_as()

    @impl true
    def perform(state, _opts), do: state
  end

  defmodule FakeVerifyInstallationCacheBustCheck do
    @moduledoc false
    use Plausible.InstallationSupport.Check

    @impl true
    def report_progress_as, do: Checks.VerifyInstallationCacheBust.report_progress_as()

    @impl true
    def perform(state, _opts), do: state
  end

  @spec run(String.t(), String.t(), String.t(), Keyword.t()) :: {:ok, pid()} | State.t()
  def run(url, data_domain, installation_type, opts \\ []) do
    case MockScenarios.get(data_domain) do
      nil ->
        raise_unless_dev_env!(data_domain)
        RealChecks.run(url, data_domain, installation_type, opts)

      scenario ->
        run_mocked(url, data_domain, installation_type, opts, scenario)
    end
  end

  defp run_mocked(url, data_domain, installation_type, opts, scenario) do
    report_to = Keyword.get(opts, :report_to, self())
    async? = Keyword.get(opts, :async?, true)
    slowdown = scenario.slowdown || Keyword.get(opts, :slowdown, 500)

    init_state = %State{
      url: url || "https://#{data_domain}",
      data_domain: data_domain,
      report_to: report_to,
      diagnostics: %Diagnostics{selected_installation_type: installation_type}
    }

    checks = [
      {FakeUrlCheck, []},
      {FakeVerifyInstallationCheck, []},
      {FakeVerifyInstallationCacheBustCheck, []}
    ]

    CheckRunner.run(init_state, checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  @spec interpret_diagnostics(State.t()) :: Plausible.InstallationSupport.Result.t()
  def interpret_diagnostics(%State{data_domain: data_domain} = state) do
    case MockScenarios.get(data_domain) do
      nil ->
        raise_unless_dev_env!(data_domain)
        RealChecks.interpret_diagnostics(state)

      scenario ->
        Diagnostics.named_result!(scenario.interpretation_result,
          installation_type: state.diagnostics.selected_installation_type,
          attempted_url: state.url,
          page_response_status: 500
        )
    end
  end

  defp raise_unless_dev_env!(data_domain) do
    if Mix.env() != :dev do
      raise """
      ChecksMock was used to verify #{inspect(data_domain)}, but no scenario \
      is registered for it. Call MockScenarios.put/3 first.
      """
    end
  end
end
