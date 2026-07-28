defmodule Plausible.InstallationSupport.Verification.MockScenarios do
  @moduledoc """
  Per-domain registry of forced verification outcomes.

  Used to bypass the real DNS lookup and browserless check when iterating
  on `PlausibleWeb.Live.Verification`'s banner UI locally, or when driving
  it from Playwright e2e specs.
  """

  use GenServer

  alias Plausible.InstallationSupport.Verification.Diagnostics

  @type scenario :: %{
          interpretation_result: atom(),
          slowdown: non_neg_integer() | nil,
          launch_delay: non_neg_integer() | nil
        }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
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

      GenServer.call(__MODULE__, {:put, domain, scenario})
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
    GenServer.call(__MODULE__, {:get, domain})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, domain, scenario}, _from, state) do
    {:reply, :ok, Map.put(state, domain, scenario)}
  end

  def handle_call({:get, domain}, _from, state) do
    {:reply, Map.get(state, domain), state}
  end
end
