defmodule Plausible.PendingStatsDeletions do
  @moduledoc """
  Context for pending stats deletions
  """

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
end
