defmodule Plausible.CustomerSupport.TrialProspect do
  @moduledoc """
  Cached revenue-potential scoring for a team on (or just off) a trial.
  Rows are (re)computed daily by `Plausible.Workers.ScoreTrialProspects` and
  read by the customer support UI.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @fields [
    :team_id,
    :estimated_monthly,
    :observed_days,
    :first_data_day,
    :kind,
    :forced_by,
    :pageview_limit,
    :over_top_tier,
    :estimated_mrr,
    :computed_at
  ]

  schema "trial_prospects" do
    belongs_to :team, Plausible.Teams.Team

    field :estimated_monthly, :integer
    field :observed_days, :integer
    field :first_data_day, :date
    field :kind, Ecto.Enum, values: [:starter, :growth, :business]
    field :forced_by, {:array, :string}, default: []
    field :pageview_limit, :integer
    field :over_top_tier, :boolean, default: false
    field :estimated_mrr, :integer
    field :computed_at, :utc_datetime

    timestamps()
  end

  def changeset(prospect, attrs) do
    prospect
    |> cast(attrs, @fields)
    |> validate_required([
      :team_id,
      :estimated_monthly,
      :observed_days,
      :first_data_day,
      :kind,
      :computed_at
    ])
    |> unique_constraint(:team_id)
  end
end
