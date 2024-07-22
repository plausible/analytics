defmodule Plausible.Funnel do
  @min_steps 2
  @max_steps 8

  @moduledoc """
  A funnel is a marketing term used to capture and describe the journey
  that users go through, from initial step to conversion.
  A funnel consists of several steps (here: #{@min_steps}..#{@max_steps}).

  This module defines the database schema for storing funnels
  and changeset helpers for enumerating the steps within.

  Each step references a goal (either a Custom Event or Visit)
  - see: `Plausible.Goal`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Plausible.Funnel.Step

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
      ],
      on_replace: :delete

    has_many :goals, through: [:steps, :goal]
    timestamps()
  end

  def changeset(funnel \\ %__MODULE__{}, attrs \\ %{}) do
    funnel
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> put_steps(attrs[:steps] || attrs["steps"])
    |> validate_length(:steps, min: @min_steps, max: @max_steps)
    |> unique_constraint(:name,
      name: :funnels_name_site_id_index
    )
  end

  def put_steps(changeset, steps) do
    steps
    |> Enum.map(&Step.changeset(%Step{}, &1))
    |> Enum.with_index(fn step, step_order ->
      Ecto.Changeset.put_change(step, :step_order, step_order + 1)
    end)
    |> then(&Ecto.Changeset.put_assoc(changeset, :steps, &1))
  end
end
