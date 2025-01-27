defmodule Plausible.Site.Removal do
  @moduledoc """
  A site deletion service stub.
  """
  alias Plausible.Repo

  import Ecto.Query

  @spec run(Plausible.Site.t()) :: {:ok, map()}
  def run(site) do
    Repo.transaction(fn ->
      site = Repo.preload(site, :team)

      result = Repo.delete_all(from(s in Plausible.Site, where: s.domain == ^site.domain))

      Plausible.Teams.Memberships.prune_guests(site.team)
      Plausible.Teams.Invitations.prune_guest_invitations(site.team)

      %{delete_all: result}
    end)
  end
end
