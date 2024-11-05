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
      team_membership -> {:ok, team_membership}
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
      {:guest, role} -> {:ok, role}
      {role, _} -> {:ok, role}
      _ -> {:error, :not_a_member}
    end
  end

  def update_role_sync(site_membership) do
    site_id = site_membership.site_id
    user_id = site_membership.user_id
    role = site_membership.role

    new_role =
      case role do
        :viewer -> :viewer
        _ -> :editor
      end

    case get_guest_membership(site_id, user_id) do
      {:ok, guest_membership} ->
        guest_membership
        |> Ecto.Changeset.change(role: new_role)
        |> Ecto.Changeset.put_change(:updated_at, site_membership.updated_at)
        |> Repo.update!()

      {:error, _} ->
        :pass
    end

    :ok
  end

  def remove_sync(site_membership) do
    site_id = site_membership.site_id
    user_id = site_membership.user_id

    case get_guest_membership(site_id, user_id) do
      {:ok, guest_membership} ->
        guest_membership = Repo.preload(guest_membership, team_membership: :team)
        Repo.delete!(guest_membership)
        prune_guests(guest_membership.team_membership.team)

      {:error, _} ->
        :pass
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

  defp get_guest_membership(site_id, user_id) do
    query =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        where: gm.site_id == ^site_id and tm.user_id == ^user_id
      )

    case Repo.one(query) do
      nil -> {:error, :no_guest}
      membership -> {:ok, membership}
    end
  end
end
