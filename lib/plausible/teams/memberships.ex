defmodule Plausible.Teams.Memberships do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Teams

  def all(team) do
    query =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id,
        order_by: [asc: u.id],
        preload: [user: u]

    Repo.all(query)
  end

  def all_pending_site_transfers(email) do
    email
    |> pending_site_transfers_query()
    |> Repo.all()
  end

  def owners_count(team) do
    Repo.aggregate(
      from(tm in Teams.Membership, where: tm.team_id == ^team.id and tm.role == :owner),
      :count
    )
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

  def can_add_site?(team, user) do
    case team_role(team, user) do
      {:ok, role} when role in [:owner, :admin, :editor] ->
        true

      _ ->
        false
    end
  end

  def can_transfer_site?(team, user) do
    case team_role(team, user) do
      {:ok, role} when role in [:owner, :admin] ->
        true

      _ ->
        false
    end
  end

  def site_role(_site, nil), do: {:error, :not_a_member}

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

  def site_member?(site, user) do
    case site_role(site, user) do
      {:ok, _} -> true
      _ -> false
    end
  end

  def has_admin_access?(site, user) do
    case site_role(site, user) do
      {:ok, role} when role in [:editor, :admin, :owner] ->
        true

      _ ->
        false
    end
  end

  def update_role(site, user_id, new_role_str, current_user, current_user_role) do
    new_role = String.to_existing_atom(new_role_str)

    case get_guest_membership(site.id, user_id) do
      {:ok, guest_membership} ->
        can_grant_role? =
          if guest_membership.team_membership.user_id == current_user.id do
            false
          else
            can_grant_role_to_other?(current_user_role, new_role)
          end

        if can_grant_role? do
          guest_membership =
            guest_membership
            |> Ecto.Changeset.change(role: new_role)
            |> Repo.update!()
            |> Repo.preload(team_membership: :user)

          {:ok, guest_membership}
        else
          {:error, :not_allowed}
        end

      {:error, _} ->
        {:error, :no_guest}
    end
  end

  def remove(site, user) do
    case get_guest_membership(site.id, user.id) do
      {:ok, guest_membership} ->
        guest_membership =
          Repo.preload(guest_membership, [:site, team_membership: [:team, :user]])

        {:ok, _} =
          Repo.transaction(fn ->
            Repo.delete!(guest_membership)
            prune_guests(guest_membership.team_membership.team)
            Plausible.Segments.after_user_removed_from_site(site, user)
          end)

        send_site_member_removed_email(guest_membership)

      {:error, _} ->
        :pass
    end
  end

  defp can_grant_role_to_other?(:owner, :editor), do: true
  defp can_grant_role_to_other?(:owner, :viewer), do: true
  defp can_grant_role_to_other?(:admin, :editor), do: true
  defp can_grant_role_to_other?(:admin, :viewer), do: true
  defp can_grant_role_to_other?(_, _), do: false

  defp send_site_member_removed_email(guest_membership) do
    guest_membership
    |> PlausibleWeb.Email.site_member_removed()
    |> Plausible.Mailer.send()
  end

  def prune_guests(team) do
    guest_query =
      from(
        gm in Teams.GuestMembership,
        where: gm.team_membership_id == parent_as(:team_membership).id,
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

  def get_team_membership(team, %Auth.User{} = user) do
    get_team_membership(team, user.id)
  end

  def get_team_membership(team, user_id) do
    query =
      from(
        tm in Teams.Membership,
        where: tm.team_id == ^team.id and tm.user_id == ^user_id
      )

    case Repo.one(query) do
      nil -> {:error, :membership_not_found}
      membership -> {:ok, membership}
    end
  end

  defp get_guest_membership(site_id, user_id) do
    query =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        where: gm.site_id == ^site_id and tm.user_id == ^user_id,
        preload: [team_membership: tm]
      )

    case Repo.one(query) do
      nil -> {:error, :no_guest}
      membership -> {:ok, membership}
    end
  end

  defp pending_site_transfers_query(email) do
    from st in Teams.SiteTransfer, where: st.email == ^email, select: st.site_id
  end
end
