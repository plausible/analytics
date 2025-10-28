defmodule Plausible.ConsolidatedView.Cache do
  @moduledoc """
  Caching layer for consolidated views.

  Because of how they're modelled (on top of "sites" table currently),
  we have to refresh the cache whenever any regular site changes within,
  as well as when the consolidating site is updated itself.
  """
  alias Plausible.ConsolidatedView
  import Ecto.Query

  use Plausible.Cache

  @cache_name :consolidated_views
  @large_view_alert_threshold 12_000
  @max_sites_per_view 14_000

  @impl true
  def name(), do: @cache_name

  @impl true
  def child_id(), do: :cache_consolidated_views

  @impl true
  def count_all() do
    Plausible.Repo.aggregate(
      from(s in ConsolidatedView.sites()),
      :count
    )
  end

  @impl true
  def base_db_query() do
    from sc in ConsolidatedView.sites(),
      inner_join: sr in ^Plausible.Site.regular(),
      on: sr.team_id == sc.team_id,
      group_by: sc.id,
      order_by: [desc: sc.id],
      select: %{
        consolidated_view_id: sc.domain,
        site_ids: fragment("array_agg(? ORDER BY ? DESC)", sr.id, sr.id)
      }
  end

  @spec refresh_updated_recently(Keyword.t()) :: :ok
  def refresh_updated_recently(opts) do
    recently_updated_site_ids =
      from sc in ConsolidatedView.sites(),
        join: sr in ^Plausible.Site.regular(),
        on: sc.team_id == sr.team_id,
        where: sr.updated_at > ago(^15, "minute") or sc.updated_at > ago(^15, "minute"),
        select: sc.id

    query =
      from sc in ConsolidatedView.sites(),
        join: sr in ^Plausible.Site.regular(),
        on: sr.team_id == sc.team_id,
        where: sc.id in subquery(recently_updated_site_ids),
        group_by: sc.id,
        order_by: [desc: sc.id],
        select: %{
          consolidated_view_id: sc.domain,
          site_ids: fragment("array_agg(? ORDER BY ? DESC)", sr.id, sr.id)
        }

    refresh(
      :updated_recently,
      query,
      Keyword.put(opts, :delete_stale_items?, false)
    )
  end

  @impl true
  def get_from_source(consolidated_view_id) do
    case ConsolidatedView.site_ids(consolidated_view_id) do
      {:ok, some} -> some
      {:error, :not_found} -> nil
    end
  end

  @impl true
  def unwrap_cache_keys(items) do
    Enum.reduce(items, [], fn row, acc ->
      [{row.consolidated_view_id, row.site_ids} | acc]
    end)
  end

  def get(key, opts) do
    case super(key, opts) do
      nil ->
        []

      site_ids when length(site_ids) > @large_view_alert_threshold ->
        Sentry.capture_message("Consolidated View crop warning",
          extra: %{sites: length(site_ids), key: key}
        )

        Enum.take(site_ids, @max_sites_per_view)

      site_ids ->
        site_ids
    end
  end
end
