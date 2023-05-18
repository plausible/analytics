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
      |> validate_required([:goal_id, :step_order])
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

  def changeset(funnel \\ %__MODULE__{}, attrs \\ %{}) do
    step_attrs =
      attrs
      |> Map.get(:steps, [])
      |> Enum.with_index()
      |> Enum.map(fn {goal_params, step_order} ->
        Map.put(goal_params, "step_order", step_order)
      end)

    attrs = Map.replace(attrs, :steps, step_attrs)

    funnel
    |> cast(attrs, [:name])
    |> cast_assoc(:steps, with: &Step.changeset/2)
    |> unique_constraint(:name,
      name: :funnels_name_site_id_index
    )
  end
end
