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
    field :allow_next_upgrade_override, :boolean, default: false

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
    |> put_embed(:grace_period, embed_params(user.grace_period))
    |> put_change(:inserted_at, user.inserted_at)
    |> put_change(:updated_at, user.updated_at)
  end

  def changeset(name, today \\ Date.utc_today()) do
    %__MODULE__{}
    |> cast(%{name: name}, [:name])
    |> validate_required(:name)
    |> start_trial(today)
  end

  def start_trial(team, today \\ Date.utc_today()) do
    trial_expiry = trial_expiry(today)

    change(team,
      trial_expiry_date: trial_expiry,
      accept_traffic_until: Date.add(trial_expiry, @trial_accept_traffic_until_offset_days)
    )
  end

  defp embed_params(nil), do: nil

  defp embed_params(grace_period) do
    Map.from_struct(grace_period)
  end

  defp trial_expiry(today) do
    on_ee do
      Date.shift(today, day: 30)
    else
      Date.shift(today, year: 100)
    end
  end
end
