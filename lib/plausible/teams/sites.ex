defmodule Plausible.Teams.Sites do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type list_opt() :: {:filter_by_domain, String.t()} | {:team, Teams.Team.t() | nil}

  @role_type Plausible.Teams.Invitation.__schema__(:type, :role)

  @switcher_limit 9

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

  @doc """
  Sites offered by the breadcrumb dashboard switcher and by `GET /api/sites`.

  Consolidated views sort first, then pinned sites, then alphabetically. They are
  only included when asked for, since `GET /api/sites` lists regular sites only.
  """
  @spec list_for_switcher(Auth.User.t(), Teams.Team.t() | nil, keyword()) :: [
          %{domain: String.t(), consolidated: boolean(), needs_verification: boolean()}
        ]
  def list_for_switcher(user, team, opts \\ []) do
    site_query =
      if Keyword.get(opts, :include_consolidated?, false) do
        Site
      else
        Site.regular()
      end

    from(u in subquery(accessible_by(user, team)),
      inner_join: s in ^site_query,
      on: u.site_id == s.id,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      select: %{
        domain: s.domain,
        consolidated: s.consolidated,
        needs_verification: ^ee?() and s.onboarding_status == :new_site
      },
      order_by: [
        desc: s.consolidated,
        asc:
          fragment(
            "CASE WHEN ? IS NOT NULL THEN 'pinned_site' ELSE 'site' END",
            up.pinned_at
          ),
        desc: up.pinned_at,
        asc: s.domain
      ],
      limit: @switcher_limit
    )
    |> Repo.all()
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
