defmodule Plausible.Teams.TeamRolePermissions do
  @moduledoc """
  Rules for who is allowed to give which team role to whom.

  Split into two independent questions: whose role the granter may change
  at all (`ensure_can_change_role/3`), and which roles they may give
  (`ensure_can_grant_role/2`). A change is allowed when both pass.

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

  @types [:membership, :invitation]

  @doc """
  Checks whether `granter` may change `membership`'s role to `to_role`.

  Changing your own role follows the same rules as changing the role of
  someone who has the same role as you.
  """
  @spec ensure_can_grant_for_member(
          Teams.Team.t(),
          Auth.User.t(),
          Membership.t(),
          Membership.role()
        ) :: :ok | {:error, :invalid_role | :permission_denied}
  def ensure_can_grant_for_member(team, granter, %Membership{} = membership, to_role) do
    with {:ok, granter_role} <- get_granter_role(team, granter),
         :ok <- ensure_can_change_role(:membership, granter_role, membership.role) do
      ensure_can_grant_role(granter_role, to_role)
    end
  end

  @doc """
  Checks whether `granter` may give a team invitation the role `to_role`.
  `invitation` is the pending invitation being changed, or `nil` when a new
  invitation is being created.
  """
  @spec ensure_can_grant_for_invitation(
          Teams.Team.t(),
          Auth.User.t(),
          Teams.Invitation.t() | nil,
          Membership.role()
        ) :: :ok | {:error, :invalid_role | :permission_denied}
  def ensure_can_grant_for_invitation(team, granter, invitation, to_role) do
    with {:ok, granter_role} <- get_granter_role(team, granter),
         :ok <- ensure_can_change_role(:invitation, granter_role, invitation_role(invitation)) do
      ensure_can_grant_role(granter_role, to_role)
    end
  end

  @doc """
  Checks whether someone with `granter_role` may change the role of a membership
  or an invitation. `current_role` is `nil` when a new invitation is being
  created.
  """
  @spec ensure_can_change_role(
          :membership | :invitation,
          Membership.role(),
          Membership.role() | nil
        ) ::
          :ok | {:error, :permission_denied}
  def ensure_can_change_role(type, granter_role, current_role)

  def ensure_can_change_role(type, _granter_role, _current_role) when type not in @types,
    do: {:error, :permission_denied}

  def ensure_can_change_role(_type, :owner, _current_role), do: :ok

  # Creating a new invitation: there's nobody whose role would change yet
  def ensure_can_change_role(:invitation, :admin, nil), do: :ok

  def ensure_can_change_role(_type, :admin, current_role)
      when current_role in [:admin, :editor, :viewer],
      do: :ok

  # Admins can't change a billing member's role: billing members have access to
  # the subscription, which admins don't. A pending billing invitation doesn't
  # give access to anything yet, so admins can change it like any other
  # non-owner invitation.
  def ensure_can_change_role(:invitation, :admin, :billing), do: :ok

  def ensure_can_change_role(_type, _granter_role, _current_role),
    do: {:error, :permission_denied}

  @doc """
  Checks whether someone with `granter_role` may give anyone the role `to_role`.
  A role that can't be assigned (anything other than owner, admin, editor,
  viewer or billing) returns `{:error, :invalid_role}`, whoever is asking.
  """
  @spec ensure_can_grant_role(Membership.role(), Membership.role()) ::
          :ok | {:error, :invalid_role | :permission_denied}
  def ensure_can_grant_role(granter_role, to_role)

  def ensure_can_grant_role(_granter_role, to_role) when to_role not in @assignable_roles,
    do: {:error, :invalid_role}

  def ensure_can_grant_role(:owner, _to_role), do: :ok
  def ensure_can_grant_role(:admin, to_role) when to_role in @assignable_by_admins, do: :ok

  def ensure_can_grant_role(_granter_role, _to_role),
    do: {:error, :permission_denied}

  defp invitation_role(nil), do: nil
  defp invitation_role(%Teams.Invitation{role: role}), do: role

  # Not being a member of the team counts as not having permission
  defp get_granter_role(team, granter) do
    case Teams.Memberships.team_role(team, granter) do
      {:ok, granter_role} -> {:ok, granter_role}
      {:error, :not_a_member} -> {:error, :permission_denied}
    end
  end
end
