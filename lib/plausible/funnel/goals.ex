defmodule Plausible.Funnel.Goals do
  use Ecto.Schema

  @type t() :: %__MODULE__{}
  schema "funnel_goals" do
    field :step_order, :integer

    belongs_to :funnel, Plausible.Funnel
    belongs_to :goal, Plausible.Goal
    timestamps()
  end
end
