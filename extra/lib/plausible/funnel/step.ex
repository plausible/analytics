defmodule Plausible.Funnel.Step do
  @moduledoc """
  This module defines the database schema for a single Funnel step.
  See: `Plausible.Funnel` for more information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}
  schema "funnel_steps" do
    field :step_order, :integer
    belongs_to :funnel, Plausible.Funnel
    belongs_to :goal, Plausible.Goal
    timestamps()
  end

  def changeset(step, goal_or_attrs \\ %{})

  def changeset(step, %Plausible.Goal{id: goal_id}) do
    changeset(step, %{goal_id: goal_id})
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:goal_id])
    |> cast_assoc(:goal)
    |> validate_required([:goal_id])
    |> unique_constraint(:goal,
      name: :funnel_steps_goal_id_funnel_id_index
    )
  end
end
