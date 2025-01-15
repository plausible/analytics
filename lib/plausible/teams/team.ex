defmodule Plausible.Teams.Team do
  @moduledoc """
  Team schema
  """

  defimpl FunWithFlags.Actor, for: __MODULE__ do
    def id(%{id: id}) do
      "team:#{id}"
    end
  end

  use Ecto.Schema
  use Plausible

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @trial_accept_traffic_until_offset_days 14
  @subscription_accept_traffic_until_offset_days 30

  schema "teams" do
    field :name, :string
    field :trial_expiry_date, :date
    field :accept_traffic_until, :date
    field :allow_next_upgrade_override, :boolean, default: false

    field :setup_complete, :boolean, default: false
    field :setup_at, :naive_datetime

    embeds_one :grace_period, Plausible.Auth.GracePeriod, on_replace: :update

    has_many :sites, Plausible.Site
    has_many :team_memberships, Plausible.Teams.Membership
    has_many :team_invitations, Plausible.Teams.Invitation
    has_one :subscription, Plausible.Billing.Subscription
    has_one :enterprise_plan, Plausible.Billing.EnterprisePlan

    has_one :ownership, Plausible.Teams.Membership, where: [role: :owner]
    has_one :owner, through: [:ownership, :user]

    timestamps()
  end

  def crm_sync_changeset(team, params) do
    team
    |> cast(params, [:trial_expiry_date, :allow_next_upgrade_override, :accept_traffic_until])
  end

  def changeset(name, today \\ Date.utc_today()) do
    %__MODULE__{}
    |> cast(%{name: name}, [:name])
    |> validate_required(:name)
    |> start_trial(today)
    |> maybe_bump_accept_traffic_until()
  end

  def name_changeset(team, attrs \\ %{}) do
    team
    |> cast(attrs, [:name])
    |> validate_required(:name)
  end

  def start_trial(team, today \\ Date.utc_today()) do
    trial_expiry = trial_expiry(today)

    change(team,
      trial_expiry_date: trial_expiry,
      accept_traffic_until: Date.add(trial_expiry, @trial_accept_traffic_until_offset_days)
    )
  end

  def end_trial(team) do
    change(team, trial_expiry_date: Date.utc_today() |> Date.shift(day: -1))
  end

  defp maybe_bump_accept_traffic_until(changeset) do
    expiry_change = get_change(changeset, :trial_expiry_date)

    if expiry_change do
      put_change(
        changeset,
        :accept_traffic_until,
        Date.add(expiry_change, @trial_accept_traffic_until_offset_days)
      )
    else
      changeset
    end
  end

  def trial_accept_traffic_until_offset_days(), do: @trial_accept_traffic_until_offset_days

  def subscription_accept_traffic_until_offset_days(),
    do: @subscription_accept_traffic_until_offset_days

  @doc false
  def trial_expiry(today \\ Date.utc_today()) do
    on_ee do
      Date.shift(today, day: 30)
    else
      Date.shift(today, year: 100)
    end
  end
end
