defmodule Plausible.Site.Removal do
  @moduledoc """
  A service responsible for site and its stats deletion.
  The site deletion alone is done in postgres and is executed first,
  the latter deletions (events, sessions and imported tables in clickhouse) 
  are performed asynchrnounsly via `Plausible.Workers.StatsRemoval`.

  This is to avoid race condition in which the site is deleted, but stats
  writes are pending (either in the buffers or are about to be buffered, due 
  to Sites.Cache keeping the now obsolete record until refresh is triggered).
  """
  @stats_deletion_delay_seconds 60 * 20

  alias Plausible.Workers.StatsRemoval
  alias Plausible.Repo
  alias Ecto.Multi

  import Ecto.Query

  @spec stats_deletion_delay_seconds() :: pos_integer()
  def stats_deletion_delay_seconds() do
    @stats_deletion_delay_seconds
  end

  @spec run(String.t()) :: {:ok, map()}
  def run(domain) do
    site_by_domain_q = from s in Plausible.Site, where: s.domain == ^domain

    Multi.new()
    |> Multi.run(:site_id, fn _, _ ->
      {:ok, Repo.one(from s in site_by_domain_q, select: s.id)}
    end)
    |> Multi.delete_all(:delete_all, site_by_domain_q)
    |> Oban.insert(:delayed_metrics_removal, fn %{site_id: site_id} ->
      StatsRemoval.new(%{domain: domain, site_id: site_id},
        schedule_in: stats_deletion_delay_seconds()
      )
    end)
    |> Repo.transaction()
  end
end
