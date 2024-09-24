defmodule Plausible.Teams.Team do
  @moduledoc """
  Team schema
  """

  use Ecto.Schema

  schema "teams" do
    field :name, :string
    field :trial_expiry_date, :date
    field :accept_traffic_until, :date
    field :allow_next_upgrade_override, :boolean

    embeds_one :grace_period, Plausible.Auth.GracePeriod, on_replace: :update

    has_many :sites, Plausible.Site
    has_many :team_memberships, Plausible.Teams.Membership
    has_many :team_invitations, Plausible.Teams.Invitation
    has_one :subscription, Plausible.Billing.Subscription
    has_one :enterprise_plan, Plausible.Billing.EnterprisePlan

    timestamps()
  end
end
