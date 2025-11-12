defmodule Plausible.Teams.Memberships do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.Teams

  require Teams.Memberships.UserPreference

  @spec all(Teams.Team.t(), Keyword.t()) :: [Teams.Membership.t()]
  def all(team, opts \\ []) do
    exclude_guests? = Keyword.get(opts, :exclude_guests?, false)

    query =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id,
        order_by: [asc: u.id],
        preload: [user: u]

    query =
      if exclude_guests? do
        from tm in query, where: tm.role != :guest
      else
        query
      end

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

  @spec team_role(Teams.Team.t(), Auth.User.t()) ::
          {:ok, Teams.Membership.role()} | {:error, :not_a_member}
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

  @spec can_add_site?(Teams.Team.t(), Auth.User.t()) :: boolean()
  def can_add_site?(team, user) do
    user_type = Plausible.Users.type(user)

    role =
      case team_role(team, user) do
        {:ok, role} -> role
        {:error, _} -> :not_a_member
      end

    case {user_type, role, team} do
      {:sso, :owner, %{setup_complete: false}} -> false
      {_, role, _} when role in [:owner, :admin, :editor] -> true
      _ -> false
    end
  end

  @spec site_role(Plausible.Site.t(), Auth.User.t() | nil) ::
          {:ok, {:team_member | :guest_member, Teams.Membership.role()}} | {:error, :not_a_member}

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
      {:guest, role} -> {:ok, {:guest_member, role}}
      {role, _} -> {:ok, {:team_member, role}}
      _ -> {:error, :not_a_member}
    end
  end

  @spec site_member?(Plausible.Site.t(), Auth.User.t() | nil) :: boolean()
  def site_member?(site, user) do
    case site_role(site, user) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @spec team_member?(Teams.Team.t(), Auth.User.t()) :: boolean()
  def team_member?(team, user) do
    case team_role(team, user) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @spec has_editor_access?(Plausible.Site.t(), Auth.User.t() | nil) :: boolean()
  def has_editor_access?(site, user) do
    case site_role(site, user) do
      {:ok, {_, role}} when role in [:editor, :admin, :owner] ->
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

  @spec set_preference(Teams.Membership.t(), atom(), any()) ::
          Teams.Memberships.UserPreference.t()
  def set_preference(team_membership, option, value)
      when option in Teams.Memberships.UserPreference.options() do
    team_membership
    |> Teams.Memberships.UserPreference.changeset(%{option => value})
    |> Repo.insert!(
      conflict_target: [:team_membership_id],
      on_conflict:
        from(p in Teams.Memberships.UserPreference, update: [set: [{^option, ^value}]]),
      returning: true
    )
  end

  @spec get_preference(Teams.Membership.t(), atom()) :: any()
  def get_preference(team_membership, option)
      when option in Teams.Memberships.UserPreference.options() do
    defaults = %Teams.Memberships.UserPreference{}

    query =
      from(
        tup in Teams.Memberships.UserPreference,
        where: tup.team_membership_id == ^team_membership.id,
        select: field(tup, ^option)
      )

    Repo.one(query) || Map.fetch!(defaults, option)
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
