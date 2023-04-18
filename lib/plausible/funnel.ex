defmodule Plausible.Funnel do
  use Ecto.Schema
  import Ecto.Changeset

  defmodule Step do
    use Ecto.Schema
    import Ecto.Changeset

    @type t() :: %__MODULE__{}
    schema "funnel_steps" do
      field :step_order, :integer
      belongs_to :funnel, Plausible.Funnel
      belongs_to :goal, Plausible.Goal
      timestamps()
    end

    def changeset(step, attrs \\ %{}) do
      step
      |> cast(attrs, [:step_order, :goal_id])
      |> unique_constraint(:goal,
        name: :funnel_steps_goal_id_funnel_id_index
      )
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

  def changeset(funnel, attrs \\ %{}) do
    funnel
    |> cast(attrs, [:name])
    |> cast_assoc(:steps, with: &Step.changeset/2)
  end
end
