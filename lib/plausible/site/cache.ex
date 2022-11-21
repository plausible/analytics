defmodule Plausible.Site.Cache do
  @moduledoc """
  A "sites by domain" caching interface.

  Serves as a thin wrapper around Cachex, but the underlying
  implementation can be transparently swapped.

  Even though the Cachex process is started, cache access is disabled
  during tests via the `:sites_by_domain_cache_enabled` application env key.
  This can be overridden on case by case basis, using the child specs options.

  When Cache is disabled via application env, the `get/1` function
  falls back to pure database lookups. This should help with introducing
  cached lookups in existing code, so that no existing tests should break.

  To differentiate cached Site structs from those retrieved directly from the
  database, a virtual schema field `from_cache?: true` is set.
  This indicates the `Plausible.Site` struct is incomplete in comparison to its
  database counterpart -- to spare bandwidth and query execution time,
  only selected database columns are retrieved and cached.

  There are two modes of refreshing the cache: `:all` and `:single`.

    * `:all` means querying the database for all Site entries and should be done
      periodically (via `Cache.Warmer`). All existing Cache entries all cleared
      prior to writing the new batch.

    * `:single` attempts to re-query a specific site by domain and should be done
      only when the initial Cache.get attempt resulted with `nil`. Single refresh will
      write `%Ecto.NoResultsError{}` to the cache so that subsequent Cache.get calls
      indicate that we already failed to retrieve a Site.

      This helps in recognising missing/deleted Sites with minimal number of DB lookups
      across a disconnected cluster within the periodic refresh window.

      Refreshing a single Site emits a telemetry event including `duration` measurement
      and meta-data indicating whether the site was found in the DB or is missing still.
      The telemetry event is defined with `telemetry_event_refresh/2`.

  The `@cached_schema_fields` attribute defines the list of DB columns
  queried on each cache refresh.

  Also see tests for more comprehensive examples.
  """
  require Logger

  import Ecto.Query

  alias Plausible.Site

  @cache_name :sites_by_domain

  @cached_schema_fields ~w(
     id
     domain
     ingest_rate_limit_scale_seconds
     ingest_rate_limit_threshold
   )a

  @type not_found_in_db() :: %Ecto.NoResultsError{}
  @type t() :: Site.t() | not_found_in_db()

  def name(), do: @cache_name

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)
    child_id = Keyword.get(opts, :child_id, :cachex_sites)

    Supervisor.child_spec(
      {Cachex, name: cache_name, limit: nil, stats: true},
      id: child_id
    )
  end

  @spec refresh_all(Keyword.t()) :: :ok
  def refresh_all(opts \\ []) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)

    measure_duration(telemetry_event_refresh(cache_name, :all), fn ->
      sites_by_domain_query =
        from s in Site,
          select: {
            s.domain,
            %{struct(s, ^@cached_schema_fields) | from_cache?: true}
          }

      sites_by_domain = Plausible.Repo.all(sites_by_domain_query)

      :ok = merge(sites_by_domain, opts)
    end)

    :ok
  end

  @spec merge(new_items :: [Site.t()], opts :: Keyword.t()) :: :ok
  def merge(new_items, opts \\ [])
  def merge([], _), do: :ok

  def merge(new_items, opts) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)
    {:ok, old_keys} = Cachex.keys(cache_name)

    new = MapSet.new(Enum.into(new_items, [], fn {k, _} -> k end))
    old = MapSet.new(old_keys)

    true = Cachex.put_many!(cache_name, new_items)

    old
    |> MapSet.difference(new)
    |> Enum.each(fn k ->
      Cachex.del(cache_name, k)
    end)

    :ok
  end

  @spec size() :: non_neg_integer()
  def size(cache_name \\ @cache_name) do
    {:ok, size} = Cachex.size(cache_name)
    size
  end

  @spec hit_rate() :: number()
  def hit_rate(cache_name \\ @cache_name) do
    {:ok, stats} = Cachex.stats(cache_name)
    Map.get(stats, :hit_rate, 0)
  end

  @spec get(String.t(), Keyword.t()) :: t() | nil
  def get(domain, opts \\ []) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)
    force? = Keyword.get(opts, :force?, false)

    if enabled?() or force? do
      case Cachex.get(cache_name, domain) do
        {:ok, nil} ->
          nil

        {:ok, site} ->
          site

        {:error, e} ->
          Logger.error(
            "Error retrieving '#{domain}' from '#{inspect(cache_name)}': #{inspect(e)}"
          )

          nil
      end
    else
      Plausible.Sites.get_by_domain(domain)
    end
  end

  @spec refresh_one(String.t(), Keyword.t()) :: {:ok, t()} | {:error, any()}
  def refresh_one(domain, opts) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)
    force? = Keyword.get(opts, :force?, false)

    if not enabled?() and not force?, do: raise("Cache: '#{cache_name}' is disabled")

    measure_duration_with_metadata(telemetry_event_refresh(cache_name, :one), fn ->
      {found_in_db?, item_to_cache} = select_one(domain)

      case Cachex.put(cache_name, domain, item_to_cache) do
        {:ok, _} ->
          result = {:ok, item_to_cache}
          {result, with_telemetry_metadata(found_in_db?: found_in_db?)}

        {:error, _} = error ->
          {error, with_telemetry_metadata(error: true)}
      end
    end)
  end

  @spec telemetry_event_refresh(atom(), :all | :one) :: list(atom())
  def telemetry_event_refresh(cache_name, mode) when mode in [:all, :one] do
    [:plausible, :cache, cache_name, :refresh, mode]
  end

  def enabled?() do
    Application.fetch_env!(:plausible, :sites_by_domain_cache_enabled) == true
  end

  defp select_one(domain) do
    site_by_domain_query =
      from s in Site,
        where: s.domain == ^domain,
        select: %{struct(s, ^@cached_schema_fields) | from_cache?: true}

    case Plausible.Repo.one(site_by_domain_query) do
      nil -> {false, %Ecto.NoResultsError{}}
      site -> {true, site}
    end
  end

  defp with_telemetry_metadata(props) do
    Enum.into(props, %{})
  end

  defp measure_duration_with_metadata(event, fun) when is_function(fun, 0) do
    {duration, {result, telemetry_metadata}} = time_it(fun)
    :telemetry.execute(event, %{duration: duration}, telemetry_metadata)
    result
  end

  defp measure_duration(event, fun) when is_function(fun, 0) do
    {duration, result} = time_it(fun)
    :telemetry.execute(event, %{duration: duration}, %{})
    result
  end

  defp time_it(fun) do
    start = System.monotonic_time()
    result = fun.()
    stop = System.monotonic_time()
    {stop - start, result}
  end
end
