defmodule Plausible.Funnel do
  use Ecto.Schema

  defmodule Step do
    use Ecto.Schema

    @type t() :: %__MODULE__{}
    schema "funnel_steps" do
      field :step_order, :integer
      belongs_to :funnel, Plausible.Funnel
      belongs_to :goal, Plausible.Goal
      timestamps()
    end
  end

  @type t() :: %__MODULE__{}
  schema "funnels" do
    field :name, :string
    belongs_to :site, Plausible.Site

    has_many :steps, Step,
      preload_order: [
        asc: :step_order
      ]

    has_many :goals, through: [:steps, :goal]
    timestamps()
  end
end
