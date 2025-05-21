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

  alias Plausible.Auth

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @trial_accept_traffic_until_offset_days 14
  @subscription_accept_traffic_until_offset_days 30

  schema "teams" do
    field :identifier, Ecto.UUID
    field :name, :string
    field :trial_expiry_date, :date
    field :accept_traffic_until, :date
    field :allow_next_upgrade_override, :boolean, default: false
    field :locked, :boolean, default: false

    field :setup_complete, :boolean, default: false
    field :setup_at, :naive_datetime

    # Field kept in sync with current subscription plan, if any
    field :hourly_api_request_limit, :integer, default: Auth.ApiKey.hourly_request_limit()

    # Field for purely informational purposes in CRM context
    field :notes, :string

    on_ee do
      # Embed for storing team-wide policies
      embeds_one :policy, Plausible.Teams.Policy, on_replace: :update, defaults_to_struct: true
    end

    embeds_one :grace_period, Plausible.Teams.GracePeriod, on_replace: :update

    has_many :sites, Plausible.Site
    has_many :team_memberships, Plausible.Teams.Membership
    has_many :team_invitations, Plausible.Teams.Invitation
    has_one :subscription, Plausible.Billing.Subscription
    has_one :enterprise_plan, Plausible.Billing.EnterprisePlan

    has_many :ownerships, Plausible.Teams.Membership,
      where: [role: :owner],
      preload_order: [asc: :id]

    has_many :billing_memberships, Plausible.Teams.Membership,
      where: [role: :billing],
      preload_order: [asc: :id]

    has_many :owners, through: [:ownerships, :user]
    has_many :billing_members, through: [:billing_memberships, :user]

    timestamps()
  end

  def crm_changeset(team, params) do
    team
    |> cast(params, [
      :name,
      :notes,
      :trial_expiry_date,
      :allow_next_upgrade_override,
      :accept_traffic_until
    ])
  end

  def changeset(team \\ %__MODULE__{}, attrs \\ %{}, today \\ Date.utc_today()) do
    team
    |> cast(attrs, [:name])
    |> validate_required(:name)
    |> start_trial(today)
    |> maybe_bump_accept_traffic_until()
    |> maybe_set_identifier()
  end

  def name_changeset(team, attrs \\ %{}) do
    team
    |> cast(attrs, [:name])
    |> validate_required(:name)
    |> validate_exclusion(:name, [Plausible.Teams.default_name()])
  end

  def setup_changeset(team, now \\ NaiveDateTime.utc_now(:second)) do
    team
    |> change(
      setup_complete: true,
      setup_at: now
    )
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

  defp maybe_set_identifier(changeset) do
    if get_field(changeset, :identifier) do
      changeset
    else
      put_change(changeset, :identifier, Ecto.UUID.generate())
    end
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
