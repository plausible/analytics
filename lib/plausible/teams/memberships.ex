defmodule Plausible.Teams.Memberships do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Teams

  def get(team, user) do
    result =
      from(tm in Teams.Membership,
        left_join: gm in assoc(tm, :guest_memberships),
        where: tm.team_id == ^team.id and tm.user_id == ^user.id
      )
      |> Repo.one()

    case result do
      nil -> {:error, :not_a_member}
      team_membership -> team_membership
    end
  end

  def team_role(team, user) do
    result =
      from(u in Auth.User,
        inner_join: tm in assoc(u, :team_memberships),
        where: tm.team_id == ^team.id and tm.user_id == ^user.id,
        select: tm.role
      )
      |> Repo.one()

    case result do
      nil -> {:error, :not_a_member}
      role -> {:ok, role}
    end
  end

  def site_role(site, user) do
    result =
      from(u in Auth.User,
        inner_join: tm in assoc(u, :team_memberships),
        left_join: gm in assoc(tm, :guest_memberships),
        where: tm.team_id == ^site.team_id and tm.user_id == ^user.id,
        where: tm.role != :guest or gm.site_id == ^site.id,
        select: {tm.role, gm.role}
      )
      |> Repo.one()

    case result do
      {:guest, role} -> role
      {role, _} -> role
      _ -> nil
    end
  end

  def prune_guests(team, opts \\ []) do
    ignore_guest_ids = Keyword.get(opts, :ignore_guest_ids, [])

    guest_query =
      from(
        gm in Teams.GuestMembership,
        where: gm.team_membership_id == parent_as(:team_membership).id,
        where: gm.id not in ^ignore_guest_ids,
        select: true
      )

    Repo.delete_all(
      from(
        tm in Teams.Membership,
        as: :team_membership,
        where: tm.team_id == ^team.id and tm.role == :guest,
        where: not exists(guest_query)
      )
    )

    :ok
  end
end
