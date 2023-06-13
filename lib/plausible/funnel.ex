defmodule Plausible.Funnel do
  use Ecto.Schema
  import Ecto.Changeset

  alias Plasuible.Funnel.Step

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
    funnel
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:steps, with: &Step.changeset/2, required: true)
    |> validate_length(:steps, min: @min_steps, max: @max_steps)
    |> put_step_orders()
    |> unique_constraint(:name,
      name: :funnels_name_site_id_index
    )
  end

  def put_step_orders(changeset) do
    if steps = Ecto.Changeset.get_change(changeset, :steps) do
      steps
      |> Enum.with_index(fn step, step_order ->
        Ecto.Changeset.put_change(step, :step_order, step_order + 1)
      end)
      |> then(&Ecto.Changeset.put_change(changeset, :steps, &1))
    end
  end
end
