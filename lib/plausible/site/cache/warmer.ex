defmodule Plausible.Site.Cache.Warmer do
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
    start = System.monotonic_time()
    Logger.info("Refreshing #{cache_name} cache...")

    warmer = Keyword.get(opts, :warmer, &warm/1)
    warmer.(opts)

    stop = System.monotonic_time()

    :telemetry.execute(
      telemetry_event_refresh(cache_name),
      %{duration: stop - start},
      %{}
    )

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

  @spec warm(Keyword.t()) :: :ok
  def warm(opts) do
    cache_name = Keyword.fetch!(opts, :cache_name)

    sites_by_domain =
      Plausible.Site
      |> Plausible.Repo.all()
      |> Enum.map(fn site ->
        {site.domain, site}
      end)

    true = Cachex.put_many!(cache_name, sites_by_domain)
    :ok
  end

  defp jitter() do
    max_jitter =
      Application.fetch_env!(:plausible, :sites_by_domain_cache_refresh_interval_max_jitter)

    Enum.random(1..max_jitter)
  end
end
