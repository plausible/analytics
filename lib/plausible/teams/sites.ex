defmodule Plausible.Teams.Sites do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type list_opt() :: {:filter_by_domain, String.t()} | {:team, Teams.Team.t() | nil}

  @role_type Plausible.Teams.Invitation.__schema__(:type, :role)

  @spec list(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)
    team = Keyword.get(opts, :team)

    all_query =
      if Teams.setup?(team) do
        from(tm in Teams.Membership,
          inner_join: t in assoc(tm, :team),
          inner_join: s in assoc(t, :sites),
          where: tm.user_id == ^user.id and tm.role != :guest,
          where: tm.team_id == ^team.id,
          select: %{site_id: s.id, entry_type: "site", role: tm.role}
        )
      else
        my_team_query =
          from(tm in Teams.Membership,
            inner_join: t in assoc(tm, :team),
            inner_join: s in assoc(t, :sites),
            where: tm.user_id == ^user.id and tm.role != :guest,
            where: tm.is_autocreated == true,
            where: t.setup_complete == false,
            select: %{site_id: s.id, entry_type: "site", role: tm.role}
          )

        guest_membership_query =
          from tm in Teams.Membership,
            inner_join: gm in assoc(tm, :guest_memberships),
            inner_join: s in assoc(gm, :site),
            where: tm.user_id == ^user.id and tm.role == :guest,
            select: %{
              site_id: s.id,
              entry_type: "site",
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

        from s in my_team_query,
          union_all: ^guest_membership_query
      end

    from(u in subquery(all_query),
      inner_join: s in ^Plausible.Site.regular(),
      on: u.site_id == s.id,
      as: :site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      select: %{
        s
        | entry_type:
            selected_as(
              fragment(
                """
                CASE
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE ?
                END
                """,
                up.pinned_at,
                u.entry_type
              ),
              :entry_type
            ),
          pinned_at: selected_as(up.pinned_at, :pinned_at),
          memberships: [
            %{
              role: type(u.role, ^@role_type),
              site_id: s.id,
              site: s
            }
          ]
      },
      order_by: [
        asc: selected_as(:entry_type),
        desc: selected_as(:pinned_at),
        asc: s.domain
      ]
    )
    |> maybe_filter_by_domain(domain_filter)
    |> Repo.paginate(pagination_params)
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [site: s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
