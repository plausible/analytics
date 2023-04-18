defmodule Plausible.Funnel do
  use Ecto.Schema

  @type t() :: %__MODULE__{}
  schema "funnels" do
    field :name, :string
    belongs_to :site, Plausible.Site

    has_many :steps, Plausible.FunnelStep,
      preload_order: [
        asc: :step_order
      ]

    has_many :goals, through: [:steps, :goal]
    timestamps()
  end
end
