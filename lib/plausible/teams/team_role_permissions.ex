defmodule Plausible.Teams.TeamRolePermissions do
  @moduledoc """
  Rules for who is allowed to change which team roles.

  A role change is allowed when the actor may modify the member or invitation
  in its current role (`can_modify_member?/2`, `can_modify_invitation?/2`),
  and may assign the new role (`can_assign?/2`). The `ensure_*` functions
  combine both for the services that make the change, and deny anyone who
  isn't a member of the team.

  Rules that depend on the team's state rather than on who's asking (the
  last owner can't be demoted, owners need 2FA when the team enforces it,
  etc) should stay in the services that make the change.
  """

  alias Plausible.Auth
  alias Plausible.Teams
  alias Plausible.Teams.Membership

  @roles Membership.roles()
  @assignable_roles List.delete(@roles, :guest)
  @assignable_by_admins List.delete(@assignable_roles, :owner)

  @type assignable_role() :: :owner | :admin | :editor | :viewer | :billing

  @doc """
  Whether someone with `role` may manage the team: invite people, change
  roles and remove members or invitations.
  """
  @spec can_manage_team?(Membership.role()) :: boolean()
  def can_manage_team?(role), do: role in [:owner, :admin]

  @doc """
  Checks whether `actor` may change `membership`'s role to `new_role`.

  Changing your own role follows the same rules as changing the role of
  someone who has the same role as you.
  """
  @spec ensure_can_change_member_role(
          Teams.Team.t(),
          Auth.User.t(),
          Membership.t(),
          assignable_role()
        ) :: :ok | {:error, :permission_denied}
  def ensure_can_change_member_role(team, actor, %Membership{role: current_role}, new_role) do
    with {:ok, actor_role} <- Teams.Memberships.team_role(team, actor),
         true <- can_modify_member?(actor_role, current_role),
         true <- can_assign?(actor_role, new_role) do
      :ok
    else
      _ -> {:error, :permission_denied}
    end
  end

  @doc """
  Checks whether `actor` may change a pending team invitation's role to
  `new_role`.
  """
  @spec ensure_can_change_invitation_role(
          Teams.Team.t(),
          Auth.User.t(),
          Teams.Invitation.t(),
          assignable_role()
        ) :: :ok | {:error, :permission_denied}
  def ensure_can_change_invitation_role(
        team,
        actor,
        %Teams.Invitation{role: current_role},
        new_role
      ) do
    with {:ok, actor_role} <- Teams.Memberships.team_role(team, actor),
         true <- can_modify_invitation?(actor_role, current_role),
         true <- can_assign?(actor_role, new_role) do
      :ok
    else
      _ -> {:error, :permission_denied}
    end
  end

  @doc """
  Checks whether `actor` may invite someone to the team with `role`.
  """
  @spec ensure_can_invite(Teams.Team.t(), Auth.User.t(), assignable_role()) ::
          :ok | {:error, :permission_denied}
  def ensure_can_invite(team, actor, role) do
    with {:ok, actor_role} <- Teams.Memberships.team_role(team, actor),
         true <- can_assign?(actor_role, role) do
      :ok
    else
      _ -> {:error, :permission_denied}
    end
  end

  @doc """
  Whether someone with `actor_role` may give anyone the role `new_role`.
  A role that can't be assigned (anything other than owner, admin, editor,
  viewer or billing) raises an `ArgumentError`, whoever is asking.
  """
  @spec can_assign?(Membership.role(), assignable_role()) :: boolean()
  def can_assign?(actor_role, new_role)

  def can_assign?(_actor_role, new_role) when new_role not in @assignable_roles,
    do: raise(ArgumentError, "invalid role: #{inspect(new_role)}")

  def can_assign?(:owner, _new_role), do: true
  def can_assign?(:admin, new_role), do: new_role in @assignable_by_admins
  def can_assign?(_actor_role, _new_role), do: false

  @doc """
  Whether someone with `actor_role` may change the role of a member whose
  role is currently `current_role`.
  """
  @spec can_modify_member?(Membership.role(), Membership.role()) :: boolean()
  def can_modify_member?(actor_role, current_role)

  def can_modify_member?(:owner, _current_role), do: true
  def can_modify_member?(:admin, current_role), do: current_role in [:admin, :editor, :viewer]
  def can_modify_member?(_actor_role, _current_role), do: false

  @doc """
  Whether someone with `actor_role` may change the role of a pending
  invitation whose role is currently `current_role`.

  Unlike billing members, admins may change pending billing invitations:
  billing members have access to the subscription, which admins don't, but a
  pending billing invitation doesn't give access to anything yet.
  """
  @spec can_modify_invitation?(Membership.role(), Membership.role()) :: boolean()
  def can_modify_invitation?(actor_role, current_role)

  def can_modify_invitation?(:owner, _current_role), do: true

  def can_modify_invitation?(:admin, current_role),
    do: current_role in [:admin, :editor, :viewer, :billing]

  def can_modify_invitation?(_actor_role, _current_role), do: false
end
