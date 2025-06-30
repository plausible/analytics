defmodule Plausible.Teams.Policy do
  @moduledoc """
  Team-wide policies.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @sso_member_roles Plausible.Teams.Membership.roles() -- [:guest, :owner]
  @force_sso_modes [:none, :all_but_owners]

  @update_fields [:sso_default_role, :sso_session_timeout_minutes]

  @default_timeout_minutes 6 * 60
  @min_timeout_minutes 30
  @max_timeout_minutes 12 * 60

  @type t() :: %__MODULE__{}

  @type sso_member_role() :: unquote(Enum.reduce(@sso_member_roles, &{:|, [], [&1, &2]}))

  @type force_sso_mode() :: unquote(Enum.reduce(@force_sso_modes, &{:|, [], [&1, &2]}))

  embedded_schema do
    # SSO options apply to all team's integrations, should there
    # ever be more than one allowed at once.

    # SSO enforcement can have one of 2 states: enforced for none
    # or enforced for all but owners.
    # The first state is useful in the initial phase of SSO setup
    # when it's not yet confirmed to be fully operational.
    # The second state is a good default for most, leaving
    # escape hatch for cases where IdP starts failing.
    field :force_sso, Ecto.Enum, values: [:none, :all_but_owners], default: :none

    # Default role for newly provisioned SSO accounts.
    field :sso_default_role, Ecto.Enum, values: @sso_member_roles, default: :viewer

    # Default session timeout for SSO-enabled accounts. We might also
    # consider accepting session timeout from assertion, if present.
    field :sso_session_timeout_minutes, :integer, default: @default_timeout_minutes
  end

  @spec sso_member_roles() :: [sso_member_role()]
  def sso_member_roles(), do: @sso_member_roles

  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(policy, params) do
    policy
    |> cast(params, @update_fields)
    |> validate_required(@update_fields)
    |> validate_number(:sso_session_timeout_minutes,
      greater_than_or_equal_to: @min_timeout_minutes,
      less_than_or_equal_to: @max_timeout_minutes
    )
  end

  @spec force_sso_changeset(t(), force_sso_mode()) :: Ecto.Changeset.t()
  def force_sso_changeset(policy, mode) do
    policy
    |> cast(%{force_sso: mode}, [:force_sso])
    |> validate_required(:force_sso)
  end
end
