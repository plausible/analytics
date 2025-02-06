defmodule Plausible.Teams.Users do
  @moduledoc """
  Users API accounting for teams.
  """

  import Ecto.Query

  alias Plausible.Repo
  alias Plausible.Teams

  def owned_teams(user) do
    Repo.all(
      from(
        tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        where: tm.user_id == ^user.id,
        where: tm.role == :owner,
        select: t
      )
    )
  end

  def teams(user) do
    from(
      tm in Teams.Membership,
      inner_join: t in assoc(tm, :team),
      where: tm.user_id == ^user.id,
      where: tm.role != :guest,
      select: t,
      order_by: [t.name, t.id]
    )
    |> Repo.all()
    |> Repo.preload(:owners)
  end

  def teams_count(user) do
    from(
      tm in Teams.Membership,
      where: tm.user_id == ^user.id,
      where: tm.role != :guest
    )
    |> Repo.aggregate(:count)
  end

  def team_member?(user, opts \\ []) do
    excluded_team_ids = Keyword.get(opts, :except, [])

    Repo.exists?(
      from(
        tm in Teams.Membership,
        where: tm.user_id == ^user.id,
        where: tm.role != :guest,
        where: tm.team_id not in ^excluded_team_ids
      )
    )
  end

  def has_sites?(user, opts \\ []) do
    include_pending? = Keyword.get(opts, :include_pending?, false)

    sites_query =
      from(
        s in Plausible.Site,
        where: s.team_id == parent_as(:site_parent).team_id,
        select: 1
      )

    # NOTE: Provided guest team memberships are consistently pruned,
    # mere presence of guest team membership means there are sites
    # associated with it, so querying for team membership alone
    # should be enough.
    team_member_query =
      from(
        tm in Teams.Membership,
        as: :site_parent,
        where: exists(sites_query),
        where: tm.user_id == ^user.id,
        select: 1
      )

    query =
      if include_pending? do
        site_transfer_query =
          from(
            st in Teams.SiteTransfer,
            where: st.email == ^user.email,
            select: 1
          )

        # NOTE: The same principle applies to guest team invitations,
        # as it's pruned as well when there are no more guest invitations
        # associated with it.
        member_invitation_query =
          from(
            ti in Teams.Invitation,
            as: :site_parent,
            where: exists(sites_query),
            where: ti.email == ^user.email,
            select: 1
          )

        team_member_query
        |> union_all(^site_transfer_query)
        |> union_all(^member_invitation_query)
      else
        team_member_query
      end

    Repo.exists?(query)
  end

  def owns_sites?(user, opts \\ []) do
    include_pending? = Keyword.get(opts, :include_pending?, false)

    sites_query =
      from(
        s in Plausible.Site,
        where: s.team_id == parent_as(:site_parent).team_id,
        select: 1
      )

    owner_query =
      from(
        tm in Teams.Membership,
        as: :site_parent,
        where: exists(sites_query),
        where: tm.user_id == ^user.id,
        where: tm.role == :owner,
        select: 1
      )

    query =
      if include_pending? do
        site_transfer_query =
          from(
            st in Teams.SiteTransfer,
            where: st.email == ^user.email,
            select: 1
          )

        owner_invitation_query =
          from(
            ti in Teams.Invitation,
            as: :site_parent,
            where: exists(sites_query),
            where: ti.email == ^user.email,
            where: ti.role == :owner,
            select: 1
          )

        owner_query
        |> union_all(^site_transfer_query)
        |> union_all(^owner_invitation_query)
      else
        owner_query
      end

    Repo.exists?(query)
  end
end
