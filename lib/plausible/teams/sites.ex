defmodule Plausible.Teams.Sites do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type list_opt() :: {:filter_by_domain, String.t()}

  @spec create(Teams.Team.t(), map()) :: {:ok, map()}
  def create(team, params) do
    with :ok <- Teams.Billing.ensure_can_add_new_site(team) do
      Ecto.Multi.new()
      |> Ecto.Multi.put(:site_changeset, Site.new_for_team(team, params))
      |> Ecto.Multi.run(:clear_changed_from, fn
        _repo, %{site_changeset: %{changes: %{domain: domain}}} ->
          if site_to_clear = Repo.get_by(Site, team_id: team.id, domain_changed_from: domain) do
            site_to_clear
            |> Ecto.Changeset.change()
            |> Ecto.Changeset.put_change(:domain_changed_from, nil)
            |> Ecto.Changeset.put_change(:domain_changed_at, nil)
            |> Repo.update()
          else
            {:ok, :ignore}
          end

        _repo, _context ->
          {:ok, :ignore}
      end)
      |> Ecto.Multi.insert(:site, fn %{site_changeset: site} -> site end)
      |> maybe_start_trial(team)
      |> Repo.transaction()
    end
  end

  defp maybe_start_trial(multi, team) do
    case team.trial_expiry_date do
      nil ->
        changeset = Teams.Team.start_trial(team)
        Ecto.Multi.update(multi, :team, changeset)

      _ ->
        multi
    end
  end

  @spec get_owner(Teams.Team.t()) :: {:ok, Auth.User.t()} | {:error, :no_owner | :multiple_owners}
  def get_owner(team) do
    owner_query =
      from(
        tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id and tm.role == :owner,
        select: u
      )

    case Repo.all(owner_query) do
      [owner_user] -> {:ok, owner_user}
      [] -> {:error, :no_owner}
      _ -> {:error, :multiple_owners}
    end
  end

  @spec list(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    team_membership_query =
      from tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: s in assoc(t, :sites),
        where: tm.user_id == ^user.id and tm.role != :guest,
        select: %{site_id: s.id, entry_type: "site"}

    guest_membership_query =
      from tm in Teams.Membership,
        inner_join: gm in assoc(tm, :guest_memberships),
        inner_join: s in assoc(gm, :site),
        where: tm.user_id == ^user.id and tm.role == :guest,
        select: %{site_id: s.id, entry_type: "site"}

    union_query =
      from s in team_membership_query,
        union_all: ^guest_membership_query

    from(u in subquery(union_query),
      inner_join: s in Plausible.Site,
      on: u.site_id == s.id,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id,
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
          pinned_at: selected_as(up.pinned_at, :pinned_at)
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

  @spec list_with_invitations(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list_with_invitations(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)

    team_membership_query =
      from tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: s in assoc(t, :sites),
        where: tm.user_id == ^user.id and tm.role != :guest,
        select: %{site_id: s.id, entry_type: "site", invitation_id: 0, invitation_role: ""}

    guest_membership_query =
      from(tm in Teams.Membership,
        inner_join: gm in assoc(tm, :guest_memberships),
        inner_join: s in assoc(gm, :site),
        where: tm.user_id == ^user.id and tm.role == :guest,
        select: %{site_id: s.id, entry_type: "site", invitation_id: 0, invitation_role: ""}
      )

    guest_invitation_query =
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        inner_join: s in assoc(gi, :site),
        where: ti.email == ^user.email and ti.role == :guest,
        select: %{
          site_id: s.id,
          entry_type: "invitation",
          invitation_id: ti.id,
          invitation_role: gi.role
        }

    union_query =
      from s in team_membership_query,
        union_all: ^guest_membership_query,
        union_all: ^guest_invitation_query

    from(u in subquery(union_query),
      inner_join: s in Plausible.Site,
      on: u.site_id == s.id,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id,
      left_join: ti in Teams.Invitation,
      on: ti.id == u.invitation_id,
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
          invitations: [
            %Plausible.Auth.Invitation{
              invitation_id: ti.invitation_id,
              email: ti.email,
              role: u.invitation_role
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
    where(query, [s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
