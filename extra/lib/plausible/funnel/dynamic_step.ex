defmodule Plausible.Funnel.DynamicStep do
  @moduledoc """
  This module defines the database schema for a single Dynamic Funnel step.
  See: `Plausible.Funnel` for more information.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @fields [
    :event_name,
    :page_path,
    :scroll_threshold,
    :custom_props,
    :currency
  ]

  @primary_key false
  embedded_schema do
    field :step_order, :integer
    field :event_name, :string
    field :page_path, :string
    field :scroll_threshold, :integer, default: -1
    field :currency, Ecto.Enum, values: Money.Currency.known_current_currencies()

    field :custom_props, :map, default: %{}
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> Plausible.Goal.base_changeset()
    |> validate_page_or_custom_goal()
  end

  @spec as_goal(t()) :: Plausible.Goal.t()
  def as_goal(step) do
    %Plausible.Goal{
      display_name: display_name(step),
      event_name: step.event_name,
      page_path: step.page_path,
      scroll_threshold: step.scroll_threshold,
      custom_props: step.custom_props
    }
  end

  defp validate_page_or_custom_goal(changeset) do
    if get_field(changeset, :event_nmame) && get_field(changeset, :page_path) do
      add_error(changeset, :event_name, "cannot co-exist with page_path")
    else
      changeset
    end
  end

  defp display_name(step) do
    case step do
      %{page_path: page_path} when is_binary(page_path) ->
        "Visit " <> page_path

      %{event_name: event_name} when is_binary(event_name) ->
        event_name
    end
  end
end
