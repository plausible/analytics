defmodule Plausible.PendingStatsDeletions do
  @moduledoc """
  Context for pending stats deletions
  """

  import Ecto.Query

  alias Plausible.PendingStatsDeletion
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Sites

  @spec store(Site.t(), atom()) :: {:ok, PendingStatsDeletion.t() | nil}
  def store(%Site{} = site, reason \\ :user_request) do
    case Sites.stats_range(site) do
      %{stats_start_date: nil, stats_end_date: nil} ->
        {:ok, nil}

      %{stats_start_date: stats_start_date, stats_end_date: stats_end_date} ->
        Repo.insert(%PendingStatsDeletion{
          site_id: site.id,
          stats_start_date: stats_start_date,
          stats_end_date: stats_end_date,
          reason: reason
        })
    end
  end

  @spec list_by_reason(atom()) :: %{
          site_ids: [pos_integer()],
          stats_start: Date.t() | nil,
          stats_end: Date.t() | nil
        }
  def list_by_reason(reason \\ :user_request) do
    Repo.one(
      from(p in PendingStatsDeletion,
        where: p.reason == ^reason,
        select: %{
          site_ids:
            fragment(
              "coalesce(array_agg(DISTINCT ? ORDER BY ?), ARRAY[]::integer[])",
              p.site_id,
              p.site_id
            ),
          stats_start: min(p.stats_start_date),
          stats_end: max(p.stats_end_date)
        }
      )
    )
  end
end
