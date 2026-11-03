defmodule Plausible.Teams.Management.Roster.Entry do
  @moduledoc """
  A single member or pending invitation in a `Plausible.Teams.Management.Roster`.
  `source` is the membership or invitation struct the entry was built from.
  """
  alias Plausible.Teams

  defstruct [:email, :name, :role, :source]

  @type t() :: %__MODULE__{
          email: String.t(),
          name: String.t(),
          role: Teams.Membership.role(),
          source: Teams.Membership.t() | Teams.Invitation.t()
        }

  @spec new(Teams.Invitation.t() | Teams.Membership.t()) :: t()
  def new(%Teams.Invitation{} = invitation) do
    %__MODULE__{
      name: "Invited User",
      email: invitation.email,
      role: invitation.role,
      source: invitation
    }
  end

  def new(%Teams.Membership{} = membership) do
    %__MODULE__{
      name: membership.user.name,
      role: membership.role,
      email: membership.user.email,
      source: membership
    }
  end

  @spec invitation?(t()) :: boolean()
  def invitation?(%__MODULE__{source: %Teams.Invitation{}}), do: true
  def invitation?(%__MODULE__{source: %Teams.Membership{}}), do: false
end
