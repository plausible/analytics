defmodule Plausible.InstallationSupport.Verification.MockScenarios do
  @moduledoc """
  Per-domain registry of forced verification outcomes. It's a public ETS
  table owned by a simple GenServer process. Used to bypass the real DNS
  lookup and browserless checks when iterating on verification banner UI
  locally, or when driving it from Playwright e2e specs.
  """

  use GenServer

  alias Plausible.InstallationSupport.Verification.Diagnostics

  @table __MODULE__

  @type scenario :: %{
          interpretation_result: atom(),
          slowdown: non_neg_integer() | nil,
          launch_delay: non_neg_integer() | nil
        }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(nil) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, nil}
  end

  @doc """
  Registers a mock verification for `domain`.

  `key` (an atom or a string) must name a scenario recognized by
  `Diagnostics.named_result!/2` - see `Diagnostics.named_scenario_keys/0`.
  Returns `{:error, :unknown_scenario}` otherwise.

  ### Opts

  * `:slowdown` - overrides the check pipeline's default per-check delay
  * `:launch_delay` - overrides the delay before the first check starts
  """
  @spec put(String.t(), atom() | String.t(), Keyword.t()) :: :ok | {:error, :unknown_scenario}
  def put(domain, key, opts \\ []) when is_binary(domain) do
    with {:ok, key} <- resolve_key(key) do
      scenario = %{
        interpretation_result: key,
        slowdown: Keyword.get(opts, :slowdown),
        launch_delay: Keyword.get(opts, :launch_delay)
      }

      :ets.insert(@table, {domain, scenario})
      :ok
    end
  end

  defp resolve_key(key) when is_atom(key) do
    if key in Diagnostics.named_scenario_keys(), do: {:ok, key}, else: {:error, :unknown_scenario}
  end

  defp resolve_key(key) when is_binary(key) do
    case Diagnostics.named_scenario_from_string(key) do
      {:ok, key} -> {:ok, key}
      :error -> {:error, :unknown_scenario}
    end
  end

  @doc "Returns the scenario registered for `domain`, or `nil` if none was set."
  @spec get(String.t()) :: scenario() | nil
  def get(domain) when is_binary(domain) do
    case :ets.lookup(@table, domain) do
      [{^domain, scenario}] -> scenario
      [] -> nil
    end
  end
end

defmodule Plausible.InstallationSupport.Verification.ChecksMock do
  @moduledoc """
  Drop-in replacement for `Plausible.InstallationSupport.Verification.Checks`
  that never performs a real DNS lookup or browserless check for a domain
  with a registered mock scenario. Used locally (`:dev`) and in Playwright
  e2e specs (`:e2e_test`) to deterministically drive Verification banner UI.

  When no scenario is registered for a domain:

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
    launch_delay = scenario.launch_delay || Keyword.get(opts, :launch_delay, 500)

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
      slowdown: slowdown,
      launch_delay: launch_delay
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
