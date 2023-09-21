defmodule Plausible.Funnels do
  @moduledoc """
  This module implements contextual Funnel interface, allowing listing,
  creating and deleting funnel definitions.

  For brief explanation of what a Funnel is, please see `Plausible.Funnel` schema.
  See `Plausible.Stats.Funnel` for the evaluation logic.
  """

  use Plausible.Funnel

  alias Plausible.Repo

  import Ecto.Query

  @spec create(Plausible.Site.t(), String.t(), [map()]) ::
          {:ok, Funnel.t()}
          | {:error, Ecto.Changeset.t() | :invalid_funnel_size}
  def create(site, name, steps)
      when is_list(steps) and length(steps) in Funnel.min_steps()..Funnel.max_steps() do
    site
    |> create_changeset(name, steps)
    |> Repo.insert()
  end

  def create(_site, _name, _goals) do
    {:error, :invalid_funnel_size}
  end

  @spec create_changeset(Plausible.Site.t(), String.t(), [map()]) ::
          Ecto.Changeset.t()
  def create_changeset(site, name, steps) do
    Funnel.changeset(%Funnel{site_id: site.id}, %{name: name, steps: steps})
  end

  @spec ephemeral_definition(Plausible.Site.t(), String.t(), [map()]) :: Funnel.t()
  def ephemeral_definition(site, name, steps) do
    site
    |> create_changeset(name, steps)
    |> Ecto.Changeset.apply_changes()
  end

  @spec list(Plausible.Site.t()) :: [
          %{name: String.t(), id: pos_integer(), steps_count: pos_integer()}
        ]
  def list(%Plausible.Site{id: site_id}) do
    Repo.all(
      from(f in Funnel,
        inner_join: steps in assoc(f, :steps),
        where: f.site_id == ^site_id,
        select: %{name: f.name, id: f.id, steps_count: count(steps)},
        group_by: f.id,
        order_by: [desc: :id]
      )
    )
  end

  @spec delete(Plausible.Site.t() | pos_integer(), pos_integer()) :: :ok
  def delete(%Plausible.Site{id: site_id}, funnel_id) do
    delete(site_id, funnel_id)
  end

  def delete(site_id, funnel_id) do
    Repo.delete_all(
      from(f in Funnel,
        where: f.site_id == ^site_id,
        where: f.id == ^funnel_id
      )
    )

    :ok
  end

  @spec get(Plausible.Site.t() | pos_integer(), pos_integer()) ::
          Funnel.t() | nil
  def get(%Plausible.Site{id: site_id}, by) do
    get(site_id, by)
  end

  def get(site_id, funnel_id) when is_integer(site_id) and is_integer(funnel_id) do
    q =
      from(f in Funnel,
        where: f.site_id == ^site_id,
        where: f.id == ^funnel_id,
        inner_join: steps in assoc(f, :steps),
        inner_join: goal in assoc(steps, :goal),
        order_by: steps.step_order,
        preload: [
          steps: {steps, goal: goal}
        ]
      )

    Repo.one(q)
  end
end
