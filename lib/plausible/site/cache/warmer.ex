defmodule Plausible.Site.Cache.Warmer do
  @moduledoc """
  A periodic cache warmer.
  Queries all Sites from Postgres, every `interval` and pre-populates the cache.
  After each run the process is hibernated, triggering garbage collection.

  Currently Cachex is used, but the underlying implementation can be transparently swapped.

  Child specification options available:

    * `interval` - the number of milliseconds for each warm-up cycle, defaults
      to `:sites_by_domain_cache_refresh_interval` application env value
      with random jitter added, for which the maximum is stored under
      `:sites_by_domain_cache_refresh_interval_max_jitter` key.
    * `cache_name` - defaults to Cache.name() but can be overriden for testing
    * `force_start?` - enforcess process startup for testing, even if it's barred
      by `Cache.enabled?`. This is useful for avoiding issues with DB ownership
      and async tests.
    * `warmer_fn` - used for testing, a custom function to retrieve the items meant
      to be cached during the warm-up cycle.

  On each warm-up cycle, a telemetry event is emitted with warm-up `duration` stored.
  in the measurments map. The event name defaults to:

    `[:prom_ex, :plugin, :cachex, Cache.name(), :refresh]`

  See tests for more comprehensive examples.
  """

  @behaviour :gen_cycle

  require Logger

  alias Plausible.Site.Cache

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec() | :ignore
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {:gen_cycle, :start_link, [{:local, __MODULE__}, __MODULE__, opts]}
    }
  end

  @impl true
  def init_cycle(opts) do
    interval = Keyword.get(opts, :interval, interval())
    force_start? = Keyword.get(opts, :force_start?, false)
    cache_name = Keyword.get(opts, :cache_name, Cache.name())

    if Cache.enabled?() or force_start? do
      Logger.info("Initializing #{__MODULE__} with interval #{interval}")

      {:ok, {interval, Keyword.put(opts, :cache_name, cache_name)}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cycle(opts) do
    cache_name = Keyword.fetch!(opts, :cache_name)

    measure_duration(telemetry_event_refresh(cache_name), fn ->
      Logger.info("Refreshing #{cache_name} cache...")

      warmer_fn = Keyword.get(opts, :warmer_fn, &Cache.prefill/1)

      warmer_fn.(opts)
    end)

    {:continue_hibernated, opts}
  end

  @impl true
  def handle_info(_msg, state) do
    {:continue, state}
  end

  @spec telemetry_event_refresh(atom()) :: list(atom())
  def telemetry_event_refresh(cache_name) do
    [:prom_ex, :plugin, :cachex, cache_name, :refresh]
  end

  @spec interval() :: pos_integer()
  def interval() do
    interval = Application.fetch_env!(:plausible, :sites_by_domain_cache_refresh_interval)

    interval + jitter()
  end

  defp jitter() do
    max_jitter =
      Application.fetch_env!(:plausible, :sites_by_domain_cache_refresh_interval_max_jitter)

    Enum.random(1..max_jitter)
  end

  defp measure_duration(event, fun) when is_function(fun, 0) do
    start = System.monotonic_time()
    result = fun.()
    stop = System.monotonic_time()

    :telemetry.execute(
      event,
      %{duration: stop - start},
      %{}
    )

    result
  end
end
