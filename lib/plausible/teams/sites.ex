defmodule Plausible.Teams.Sites do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Site
  alias Plausible.Teams

  @type list_opt() :: {:filter_by_domain, String.t()} | {:team, Teams.Team.t() | nil}

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
          select: %{site_id: s.id, entry_type: "site"}
        )
      else
        my_team_query =
          from(tm in Teams.Membership,
            inner_join: t in assoc(tm, :team),
            inner_join: s in assoc(t, :sites),
            where: tm.user_id == ^user.id and tm.role != :guest,
            where: tm.is_autocreated == true,
            where: t.setup_complete == false,
            select: %{site_id: s.id, entry_type: "site"}
          )

        guest_membership_query =
          from tm in Teams.Membership,
            inner_join: gm in assoc(tm, :guest_memberships),
            inner_join: s in assoc(gm, :site),
            where: tm.user_id == ^user.id and tm.role == :guest,
            select: %{site_id: s.id, entry_type: "site"}

        from s in my_team_query,
          union_all: ^guest_membership_query
      end

    from(u in subquery(all_query),
      inner_join: s in Plausible.Site,
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

  @role_type Plausible.Teams.Invitation.__schema__(:type, :role)

  @spec list_with_invitations(Auth.User.t(), map(), [list_opt()]) :: Scrivener.Page.t()
  def list_with_invitations(user, pagination_params, opts \\ []) do
    domain_filter = Keyword.get(opts, :filter_by_domain)
    team = Keyword.get(opts, :team)

    union_query =
      if Teams.setup?(team) do
        list_with_invitations_setup_query(team, user)
      else
        list_with_invitations_personal_query(team, user)
      end

    from(u in subquery(union_query),
      inner_join: s in Plausible.Site,
      on: u.site_id == s.id,
      as: :site,
      left_join: up in Site.UserPreference,
      on: up.site_id == s.id and up.user_id == ^user.id,
      left_join: ti in Teams.Invitation,
      on: ti.id == u.team_invitation_id,
      left_join: gi in Teams.GuestInvitation,
      on: gi.id == u.guest_invitation_id,
      left_join: st in Teams.SiteTransfer,
      on: st.id == u.transfer_id,
      select: %{
        s
        | entry_type:
            selected_as(
              fragment(
                """
                CASE
                  WHEN ? IS NOT NULL THEN 'invitation'
                  WHEN ? IS NOT NULL THEN 'invitation'
                  WHEN ? IS NOT NULL THEN 'pinned_site'
                  ELSE ?
                END
                """,
                gi.id,
                st.id,
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
          ],
          invitations: [
            %{
              invitation_id: coalesce(gi.invitation_id, st.transfer_id),
              email: coalesce(ti.email, st.email),
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
    |> Map.update!(:entries, fn entries ->
      Enum.map(entries, fn
        %{invitation: [%{invitation_id: nil}]} = entry ->
          %{entry | invitations: []}

        entry ->
          entry
      end)
    end)
  end

  defp list_with_invitations_setup_query(team, user) do
    team_membership_query =
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: u in assoc(tm, :user),
        as: :user,
        inner_join: s in assoc(t, :sites),
        as: :site,
        where: tm.user_id == ^user.id and tm.role != :guest,
        where: tm.team_id == ^team.id,
        select: %{
          site_id: s.id,
          entry_type: "site",
          guest_invitation_id: 0,
          team_invitation_id: 0,
          role: tm.role,
          transfer_id: 0
        }
      )

    site_transfer_query =
      from st in Teams.SiteTransfer,
        as: :site_transfer,
        inner_join: s in assoc(st, :site),
        as: :site,
        where: s.team_id != ^team.id,
        where: st.email == ^user.email,
        where:
          exists(
            from tm in Teams.Membership,
              inner_join: u in assoc(tm, :user),
              where: tm.team_id == ^team.id,
              where: u.email == parent_as(:site_transfer).email,
              where: tm.role in [:owner, :admin],
              select: 1
          ),
        select: %{
          site_id: s.id,
          entry_type: "invitation",
          guest_invitation_id: 0,
          team_invitation_id: 0,
          role: "owner",
          transfer_id: st.id
        }

    from s in team_membership_query,
      union_all: ^site_transfer_query
  end

  defp list_with_invitations_personal_query(team, user) do
    my_team_query =
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        inner_join: u in assoc(tm, :user),
        as: :user,
        inner_join: s in assoc(t, :sites),
        as: :site,
        where: tm.user_id == ^user.id and tm.role == :owner,
        where: t.setup_complete == false,
        select: %{
          site_id: s.id,
          entry_type: "site",
          guest_invitation_id: 0,
          team_invitation_id: 0,
          role: tm.role,
          transfer_id: 0
        }
      )

    guest_membership_query =
      from(tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        as: :user,
        inner_join: gm in assoc(tm, :guest_memberships),
        inner_join: s in assoc(gm, :site),
        as: :site,
        where: tm.user_id == ^user.id and tm.role == :guest,
        select: %{
          site_id: s.id,
          entry_type: "site",
          guest_invitation_id: 0,
          team_invitation_id: 0,
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
            ),
          transfer_id: 0
        }
      )

    guest_invitation_query =
      from ti in Teams.Invitation,
        as: :team_invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        inner_join: s in assoc(gi, :site),
        as: :site,
        where:
          not exists(
            from tm in Teams.Membership,
              inner_join: u in assoc(tm, :user),
              left_join: gm in assoc(tm, :guest_memberships),
              on: gm.site_id == parent_as(:site).id,
              where: tm.team_id == parent_as(:team_invitation).team_id,
              where: u.email == parent_as(:team_invitation).email,
              where: not is_nil(gm.id) or tm.role != :guest,
              select: 1
          ),
        where: ti.email == ^user.email and ti.role == :guest,
        select: %{
          site_id: s.id,
          entry_type: "invitation",
          guest_invitation_id: gi.id,
          team_invitation_id: ti.id,
          role:
            fragment(
              """
              CASE
                WHEN ? = 'editor' THEN 'admin'
                ELSE ?
              END
              """,
              gi.role,
              gi.role
            ),
          transfer_id: 0
        }

    site_transfer_query =
      from st in Teams.SiteTransfer,
        as: :site_transfer,
        inner_join: s in assoc(st, :site),
        as: :site,
        where: st.email == ^user.email,
        select: %{
          site_id: s.id,
          entry_type: "invitation",
          guest_invitation_id: 0,
          team_invitation_id: 0,
          role: "owner",
          transfer_id: st.id
        }

    site_transfer_query =
      if team do
        where(site_transfer_query, [site: s], s.team_id != ^team.id)
      else
        site_transfer_query
      end

    from s in my_team_query,
      union_all: ^guest_membership_query,
      union_all: ^guest_invitation_query,
      union_all: ^site_transfer_query
  end

  defp maybe_filter_by_domain(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    where(query, [site: s], ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain(query, _), do: query
end
