defmodule Plausible.Teams.Users do
  @moduledoc """
  Users API accounting for teams.
  """

  import Ecto.Query

  alias Plausible.Repo
  alias Plausible.Teams

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
