defmodule Plausible.FunnelStep do
  use Ecto.Schema

  @type t() :: %__MODULE__{}
  schema "funnel_steps" do
    field :step_order, :integer
    belongs_to :funnel, Plausible.Funnel
    belongs_to :goal, Plausible.Goal
    timestamps()
  end
end
