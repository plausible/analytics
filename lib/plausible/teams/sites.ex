defmodule Plausible.Teams.Sites do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type list_opt() :: {:filter_by_domain, String.t()} | {:team, Teams.Team.t() | nil}

  @role_type Plausible.Teams.Invitation.__schema__(:type, :role)

  @spec accessible_by(Auth.User.t(), Teams.Team.t() | nil) :: Ecto.Query.t()
  def accessible_by(user, team) do
    if Teams.setup?(team) do
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: s in assoc(t, :sites),
        where: tm.user_id == ^user.id and tm.role != :guest,
        where: tm.team_id == ^team.id,
        select: %{site_id: s.id, role: tm.role}
      )
    else
      my_team_query =
        from(tm in Teams.Membership,
          inner_join: t in assoc(tm, :team),
          inner_join: s in assoc(t, :sites),
          where: tm.user_id == ^user.id and tm.role != :guest,
          where: tm.is_autocreated == true,
          where: t.setup_complete == false,
          select: %{site_id: s.id, role: tm.role}
        )

      guest_membership_query =
        from(tm in Teams.Membership,
          inner_join: gm in assoc(tm, :guest_memberships),
          inner_join: s in assoc(gm, :site),
          where: tm.user_id == ^user.id and tm.role == :guest,
          select: %{
            site_id: s.id,
            role:
              fragment(
                """
                CASE
                  WHEN ? = 'editor' THEN 'admin'
                  ELSE ?
                END
                """,
                gm.role,
                gm.role
              )
          }
        )

      from(s in my_team_query, union_all: ^guest_membership_query)
    end
  end

  @spec get_for_user_by_ids(Auth.User.t(), [pos_integer()], [list_opt()]) :: [Site.t()]
  def get_for_user_by_ids(_user, [], _opts), do: []

  def get_for_user_by_ids(user, site_ids, opts) do
    team = Keyword.get(opts, :team)

    rows =
      from(u in subquery(accessible_by(user, team)),
        inner_join: s in ^Plausible.Site.regular(),
        on: u.site_id == s.id,
        left_join: up in Site.UserPreference,
        on: up.site_id == s.id and up.user_id == ^user.id,
        where: s.id in ^site_ids,
        select:
          {s.id,
           %{
             s
             | pinned_at: selected_as(up.pinned_at, :pinned_at),
               memberships: [
                 %{
                   role: type(u.role, ^@role_type),
                   site_id: s.id,
                   site: s
                 }
               ]
           }}
      )
      |> Repo.all()
      |> Map.new()

    # Restore the caller-supplied order
    Enum.flat_map(site_ids, fn id -> List.wrap(Map.get(rows, id)) end)
  end
end
