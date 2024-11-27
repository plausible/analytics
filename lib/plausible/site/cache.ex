defmodule Plausible.Site.Cache do
  @moduledoc """
  The cache allows lookups by both `domain` and `domain_changed_from`
  fields - this is to allow traffic from sites whose domains changed within a certain
  grace period (see: `Plausible.Site.Transfer`).

  To differentiate cached Site structs from those retrieved directly from the
  database, a virtual schema field `from_cache?: true` is set.
  This indicates the `Plausible.Site` struct is incomplete in comparison to its
  database counterpart -- to spare bandwidth and query execution time,
  only selected database columns are retrieved and cached.

  The `@cached_schema_fields` attribute defines the list of DB columns
  queried on each cache refresh.

  Also see tests for more comprehensive examples.
  """
  require Logger

  import Ecto.Query

  alias Plausible.Site

  use Plausible.Cache

  @cache_name :sites_by_domain

  @cached_schema_fields ~w(
    id
    domain
    domain_changed_from
    ingest_rate_limit_scale_seconds
    ingest_rate_limit_threshold
   )a

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_sites

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(Site, :count)
  end

  @impl true
  def base_db_query() do
    from s in Site,
      left_join: rg in assoc(s, :revenue_goals),
      inner_join: team in assoc(s, :team),
      select: {
        s.domain,
        s.domain_changed_from,
        %{struct(s, ^@cached_schema_fields) | from_cache?: true}
      },
      preload: [revenue_goals: rg, team: team]
  end

  @impl true
  def get_from_source(domain) do
    query = from s in base_db_query(), where: s.domain == ^domain

    case Plausible.Repo.one(query) do
      {_, _, site} -> %Site{site | from_cache?: false}
      _any -> nil
    end
  end

  @spec get_site_id(String.t(), Keyword.t()) :: pos_integer() | nil
  def get_site_id(domain, opts \\ []) do
    case get(domain, opts) do
      %{id: site_id} ->
        site_id

      nil ->
        nil
    end
  end

  @spec touch_site!(Site.t(), DateTime.t()) :: Site.t()
  def touch_site!(site, now) do
    now =
      now
      |> DateTime.truncate(:second)
      |> DateTime.to_naive()

    site
    |> Ecto.Changeset.change(updated_at: now)
    |> Plausible.Repo.update!()
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn
      {domain, nil, object}, acc ->
        [{domain, object} | acc]

      {domain, domain_changed_from, object}, acc ->
        [{domain, object}, {domain_changed_from, object} | acc]
    end)
  end
end
