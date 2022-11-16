defmodule Plausible.Site.Cache do
  @moduledoc """
  A sites by domain caching interface.

  Serves as a thin wrapper around Cachex, but the underlying
  implementation can be transparently swapped.

  Even though the Cachex process is started, cache access is disabled
  during tests via the `:sites_by_domain_cache_enabled` application env key.
  This can be overriden on case by case basis, using the child specs options.

  When Cache is disabled via application env, the `get/1` function
  falls back to pure database lookups. This should help with introducing
  cached lookups in existing code, so that no existing tests should break.

  To differentiate cached Site structs from those retrieved directly from the
  database, a virtual schema field `from_cache?: true` is set.
  This indicates the `Plausible.Site` struct is incomplete in comparison to its
  database counterpart -- to spare bandwidth and query execution time,
  only selected database columns are retrieved and cached.

  The `@cached_schema_fields` attribute defines the list of DB columns
  queried on cache pre-fill.

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

  @spec prefill(Keyword.t()) :: :ok
  def prefill(opts) do
    cache_name = Keyword.fetch!(opts, :cache_name)

    sites_by_domain_query =
      from s in Site,
        select: {
          s.domain,
          %{struct(s, ^@cached_schema_fields) | from_cache?: true}
        }

    sites_by_domain = Plausible.Repo.all(sites_by_domain_query)

    true = Cachex.put_many!(cache_name, sites_by_domain)
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

  @spec get(String.t(), Keyword.t()) :: nil | Site.t()
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

  def enabled?() do
    Application.fetch_env!(:plausible, :sites_by_domain_cache_enabled) == true
  end
end
