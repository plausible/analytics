defmodule Plausible.Teams.Management.Layout.Entry do
  @moduledoc """
  Module representing a single Team Layout element and all its state
  transitions, including persistence options.
  """
  alias Plausible.Teams

  defstruct [:email, :name, :role, :type, :meta, :queued_op]

  @type t() :: %__MODULE__{}

  @spec new(Teams.Invitation.t() | Teams.Membership.t(), Keyword.t()) :: t()
  def new(object, attrs \\ [])

  def new(
        %Teams.Invitation{id: existing} = invitation,
        attrs
      )
      when is_integer(existing) do
    %__MODULE__{
      name: "Invited User",
      email: invitation.email,
      role: invitation.role,
      type: :invitation_sent,
      meta: invitation
    }
    |> Map.merge(Enum.into(attrs, %{}))
  end

  def new(%Teams.Invitation{id: nil} = pending, attrs) do
    %__MODULE__{
      name: "Invited User",
      email: pending.email,
      role: pending.role,
      type: :invitation_pending,
      meta: pending
    }
    |> Map.merge(Enum.into(attrs, %{}))
  end

  def new(%Teams.Membership{} = membership, attrs) do
    %__MODULE__{
      name: membership.user.name,
      role: membership.role,
      email: membership.user.email,
      type: :membership,
      meta: membership
    }
    |> Map.merge(Enum.into(attrs, %{}))
  end

  @spec patch(t(), Keyword.t()) :: t()
  def patch(%__MODULE__{} = entry, attrs) do
    struct!(entry, attrs)
  end

  @spec persist(t(), map()) ::
          {:ok, :ignore | Teams.Invitation.t() | Teams.Membership.t()} | {:error, any()}
  def persist(%__MODULE__{queued_op: nil}, _context) do
    {:ok, :ignore}
  end

  def persist(%__MODULE__{type: :invitation_pending, queued_op: :delete}, _context) do
    {:ok, :ignore}
  end

  def persist(
        %__MODULE__{email: email, role: role, type: :invitation_pending, queued_op: op},
        context
      )
      when op in [:update, :send] do
    Teams.Invitations.InviteToTeam.invite(context.my_team, context.current_user, email, role,
      send_email?: false
    )
  end

  def persist(
        %__MODULE__{type: :invitation_sent, email: email, role: role, queued_op: :update},
        context
      ) do
    Teams.Invitations.InviteToTeam.invite(context.my_team, context.current_user, email, role,
      send_email?: false
    )
  end

  def persist(
        %__MODULE__{type: :invitation_sent, queued_op: :delete, meta: meta},
        context
      ) do
    Plausible.Teams.Invitations.Remove.remove(
      context.my_team,
      meta.invitation_id,
      context.current_user
    )
  end

  def persist(
        %__MODULE__{type: :membership, queued_op: :delete, meta: meta},
        context
      ) do
    Plausible.Teams.Memberships.Remove.remove(
      context.my_team,
      meta.user.id,
      context.current_user,
      send_email?: false
    )
  end

  def persist(
        %__MODULE__{type: :membership, queued_op: :update, role: role, meta: meta},
        context
      ) do
    Plausible.Teams.Memberships.UpdateRole.update(
      context.my_team,
      meta.user.id,
      "#{role}",
      context.current_user
    )
  end
end
