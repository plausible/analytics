defmodule Plausible.Teams.Invitations.Candidates do
  import Ecto.Query

  alias Plausible.Repo
  alias Plausible.Teams.GuestMembership
  alias Plausible.Teams

  def search_site_guests(%Teams.Team{} = team, name_or_email, opts \\ [])
      when is_binary(name_or_email) do
    limit = Keyword.get(opts, :limit, 50)
    all_site_ids = Teams.owned_sites_ids(team)
    term = "%#{name_or_email}%"

    Repo.all(
      from gm in GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        inner_join: u in assoc(tm, :user),
        where: gm.site_id in ^all_site_ids,
        where: ilike(u.email, ^term) or ilike(u.name, ^term),
        order_by: [asc: u.id],
        select: u,
        distinct: true,
        limit: ^limit
    )
  end
end
