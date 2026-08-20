defmodule Plausible.Site.Removal do
  @moduledoc """
  A site deletion service stub.
  """
  use Plausible

  alias Plausible.PendingStatsDeletions
  alias Plausible.Repo
  alias Plausible.Teams

  import Ecto.Query

  @spec run(Plausible.Site.t(), Keyword.t()) :: {:ok, map()}
  def run(site, opts \\ []) do
    reason = Keyword.get(opts, :reason, :user_request)

    Repo.transaction(fn ->
      site = Repo.preload(site, :team)

      {:ok, pending_stats_deletion} = PendingStatsDeletions.store(site, reason)

      result = Repo.delete_all(from(s in Plausible.Site, where: s.domain == ^site.domain))

      Teams.Memberships.prune_guests(site.team)
      Teams.Invitations.prune_guest_invitations(site.team)

      on_ee do
        if Plausible.Sites.regular?(site) do
          :ok = Plausible.ConsolidatedView.reset_if_enabled(site.team)
        end

        Plausible.Billing.SiteLocker.update_for(site.team, send_email?: false)
      end

      cache_opts = Keyword.take(opts, [:cache_name, :multicall_timeout])
      :ok = Plausible.Site.Cache.broadcast_delete(site.domain, cache_opts)

      if site.domain_changed_from do
        :ok = Plausible.Site.Cache.broadcast_delete(site.domain_changed_from, cache_opts)
      end

      %{delete_all: result, pending_stats_deletion: pending_stats_deletion}
    end)
  end
end
