defmodule Plausible.Site.Cache do
  require Logger

  @cache_name :sites_by_domain

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

  @spec size() :: non_neg_integer()
  def size(cache_name \\ @cache_name) do
    {:ok, size} = Cachex.size(cache_name)
    size
  end

  @spec hit_rate() :: float()
  def hit_rate(cache_name \\ @cache_name) do
    {:ok, stats} = Cachex.stats(cache_name)
    Map.get(stats, :hit_rate, 0)
  end

  @spec get(String.t(), Keyword.t()) :: nil | %Plausible.Site{}
  def get(domain, opts \\ []) do
    cache_name = Keyword.get(opts, :cache_name, @cache_name)
    force? = Keyword.get(opts, :force?, false)

    if enabled?() or force? do
      case Cachex.get(cache_name, domain) do
        {:ok, nil} -> nil
        {:ok, site} -> site
      end
    else
      Plausible.Sites.get_by_domain(domain)
    end
  end

  def enabled?() do
    Application.fetch_env!(:plausible, :sites_by_domain_cache_enabled) == true
  end
end
