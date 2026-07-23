defmodule Plausible.InstallationSupport.Verification.MockScenarios do
  @moduledoc """
  Per-domain registry of forced verification outcomes.

  Used to bypass the real DNS lookup and browserless check when iterating
  on `PlausibleWeb.Live.Verification`'s banner UI locally, or when driving
  it from Playwright e2e specs.
  """

  use GenServer

  @type scenario :: %{interpretation_result: atom(), slowdown: non_neg_integer() | nil}

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Registers a mock verification for `domain`.

  The `key` must be an atom that's recognized by
  `Plausible.InstallationSupport.Verification.Diagnostics.named_result!/2`.

  ### Opts

  * `:slowdown` - overrides the check pipeline's default per-check delay
  """
  @spec put(String.t(), atom(), Keyword.t()) :: :ok
  def put(domain, key, opts \\ []) when is_binary(domain) and is_atom(key) do
    scenario = %{interpretation_result: key, slowdown: Keyword.get(opts, :slowdown)}
    GenServer.call(__MODULE__, {:put, domain, scenario})
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
