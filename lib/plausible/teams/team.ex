defmodule Plausible.Teams.Team do
  @moduledoc """
  Team schema
  """

  use Ecto.Schema
  use Plausible

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @trial_accept_traffic_until_offset_days 14

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

  def sync_changeset(team, user) do
    team
    |> change()
    |> put_change(:trial_expiry_date, user.trial_expiry_date)
    |> put_change(:accept_traffic_until, user.accept_traffic_until)
    |> put_change(:allow_next_upgrade_override, user.allow_next_upgrade_override)
    |> put_embed(:grace_period, user.grace_period)
    |> put_change(:inserted_at, user.inserted_at)
    |> put_change(:updated_at, user.updated_at)
  end

  def changeset(name, today \\ Date.utc_today()) do
    trial_expiry_date =
      if ee?() do
        Date.shift(today, day: 30)
      else
        Date.shift(today, year: 100)
      end

    %__MODULE__{}
    |> cast(%{name: name}, [:name])
    |> validate_required(:name)
    |> put_change(:trial_expiry_date, trial_expiry_date)
  end

  def start_trial(team) do
    trial_expiry = trial_expiry()

    change(team,
      trial_expiry_date: trial_expiry,
      accept_traffic_until: Date.add(trial_expiry, @trial_accept_traffic_until_offset_days)
    )
  end

  defp trial_expiry() do
    on_ee do
      Date.utc_today() |> Date.shift(day: 30)
    else
      Date.utc_today() |> Date.shift(year: 100)
    end
  end
end
