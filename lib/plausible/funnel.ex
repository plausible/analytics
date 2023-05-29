defmodule Plausible.Funnel do
  use Ecto.Schema
  import Ecto.Changeset

  @min_steps 2
  @max_steps 5

  defmacro min_steps() do
    quote do
      unquote(@min_steps)
    end
  end

  defmacro max_steps() do
    quote do
      unquote(@max_steps)
    end
  end

  defmacro __using__(_opts \\ []) do
    quote do
      require Plausible.Funnel
      alias Plausible.Funnel
    end
  end

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
      |> Enum.with_index(1)
      |> Enum.map(fn {goal_params, step_order} ->
        Map.put(goal_params, "step_order", step_order)
      end)

    attrs = Map.replace(attrs, :steps, step_attrs)

    funnel
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:steps, with: &Step.changeset/2, required: true)
    |> validate_length(:steps, min: @min_steps, max: @max_steps)
    |> unique_constraint(:name,
      name: :funnels_name_site_id_index
    )
  end
end
