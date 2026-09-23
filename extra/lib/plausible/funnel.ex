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
  alias Plausible.Funnel.DynamicStep

  @funnel_types [:sequential, :flexible, :strict]

  @default_funnel_type :sequential

  @type funnel_type() :: unquote(Enum.reduce(@funnel_types, &{:|, [], [&1, &2]}))

  @spec funnel_types() :: [funnel_type()]
  def funnel_types(), do: @funnel_types

  @spec default_funnel_type() :: funnel_type()
  def default_funnel_type(), do: @default_funnel_type

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
    field :strict_order, :boolean, default: false
    field :first_and_last, :boolean, default: false

    field :funnel_type, Ecto.Enum,
      default: @default_funnel_type,
      values: @funnel_types

    belongs_to :site, Plausible.Site

    embeds_many :dynamic_steps, DynamicStep, on_replace: :delete

    has_many :steps, Step,
      preload_order: [
        asc: :step_order
      ],
      on_replace: :delete

    has_many :goals, through: [:steps, :goal]
    timestamps()
  end

  def goals(funnel) do
    funnel
    |> steps()
    |> Enum.map(&as_goal/1)
  end

  def steps(funnel) do
    funnel.steps
    |> Enum.concat(funnel.dynamic_steps)
    |> Enum.sort_by(& &1.step_order)
  end

  def as_goal(%Step{} = step), do: Step.as_goal(step)
  def as_goal(%DynamicStep{} = step), do: DynamicStep.as_goal(step)

  def changeset(funnel \\ %__MODULE__{}, attrs \\ %{}) do
    funnel
    |> cast(attrs, [:name, :funnel_type])
    |> validate_required([:name])
    |> set_funnel_type()
    |> put_steps(attrs[:steps] || attrs["steps"])
    |> validate_steps_length()
    |> unique_constraint(:name,
      name: :funnels_name_site_id_index
    )
  end

  defp put_steps(changeset, steps) do
    {static_steps, dynamic_steps} =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {input, idx} ->
        input
        |> schema_by_input()
        |> build_step(input, idx)
      end)
      |> Enum.split_with(fn
        %{data: %Step{}} -> true
        _ -> false
      end)

    changeset
    |> Ecto.Changeset.put_assoc(:steps, static_steps)
    |> Ecto.Changeset.put_embed(:dynamic_steps, dynamic_steps)
  end

  defp validate_steps_length(changeset) do
    steps_count =
      length(Ecto.Changeset.get_assoc(changeset, :steps)) +
        length(Ecto.Changeset.get_embed(changeset, :dynamic_steps))

    if steps_count < @min_steps or steps_count > @max_steps do
    end

    cond do
      steps_count < @min_steps ->
        add_error(changeset, :steps, "should have at least #{@min_steps} item(s)")

      steps_count > @max_steps ->
        add_error(changeset, :steps, "should have no more than #{@max_steps} item(s)")

      true ->
        changeset
    end
  end

  defp schema_by_input(%Plausible.Goal{}), do: Step
  defp schema_by_input(%Step{}), do: Step
  defp schema_by_input(%{goal_id: _}), do: Step
  defp schema_by_input(%{"goal_id" => _}), do: Step
  defp schema_by_input(_), do: DynamicStep

  defp build_step(step_schema, params, step_order) do
    params
    |> step_schema.changeset()
    |> Ecto.Changeset.put_change(:step_order, step_order)
  end

  defp set_funnel_type(%{valid?: true} = changeset) do
    {changed?, strict_order?, first_and_last?} =
      case get_change(changeset, :funnel_type) do
        :strict -> {true, true, false}
        :flexible -> {true, false, true}
        :sequential -> {true, false, false}
        nil -> {false, nil, nil}
      end

    if changed? do
      changeset
      |> put_change(:strict_order, strict_order?)
      |> put_change(:first_and_last, first_and_last?)
    else
      changeset
    end
  end

  defp set_funnel_type(changeset), do: changeset
end
