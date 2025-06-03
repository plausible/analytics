defmodule Plausible.Teams.Policy do
  @moduledoc """
  Team-wide policies.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @sso_member_roles Plausible.Teams.Membership.roles() -- [:guest]

  @update_fields [:sso_default_role, :sso_session_timeout_minutes]

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
    field :sso_session_timeout_minutes, :integer, default: 360
  end

  def update_changeset(policy, params) do
    policy
    |> cast(params, @update_fields)
    |> validate_required(@update_fields)
  end

  def force_sso_changeset(policy, mode) do
    policy
    |> cast(%{force_sso: mode}, [:force_sso])
    |> validate_required(:force_sso)
  end
end
