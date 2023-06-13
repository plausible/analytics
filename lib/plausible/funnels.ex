defmodule Plausible.Funnels do
  @funnel_window_duration 86_400

  @moduledoc """
  This module implements contextual Funnel interface, allowing listing,
  creating, deleting and evaluating funnel definition.

  For brief explanation of what a Funnel is, please see `Plausible.Funnel` schema.
  """

  use Plausible.Funnel

  alias Plausible.Repo
  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base

  import Ecto.Query

  @spec create(Plausible.Site.t(), String.t(), [Plausible.Goal.t()]) ::
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

  @spec create_changeset(Plausible.Site.t(), String.t(), [Plausible.Goal.t()]) ::
          Ecto.Changeset.t()
  def create_changeset(site, name, steps) do
    Funnel.changeset(%Funnel{site_id: site.id}, %{name: name, steps: steps})
  end

  @spec ephemeral_definition(Plausible.Site.t(), String.t(), [Plausible.Goal.t()]) :: Funnel.t()
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
      from f in Funnel,
        inner_join: steps in assoc(f, :steps),
        where: f.site_id == ^site_id,
        select: %{name: f.name, id: f.id, steps_count: count(steps)},
        group_by: f.id,
        order_by: [desc: :id]
    )
  end

  @spec delete(Plausible.Site.t(), pos_integer()) :: :ok
  def delete(%Plausible.Site{id: site_id}, funnel_id) do
    Repo.delete_all(
      from f in Funnel,
        where: f.site_id == ^site_id,
        where: f.id == ^funnel_id
    )

    :ok
  end

  @spec get(Plausible.Site.t() | pos_integer(), pos_integer()) ::
          {:ok, Funnel.t()} | {:error, String.t()}
  def get(%Plausible.Site{id: site_id}, by) do
    get(site_id, by)
  end

  def get(site_id, funnel_id) when is_integer(site_id) and is_integer(funnel_id) do
    q =
      from f in Funnel,
        where: f.site_id == ^site_id,
        where: f.id == ^funnel_id,
        inner_join: steps in assoc(f, :steps),
        inner_join: goal in assoc(steps, :goal),
        order_by: steps.step_order,
        preload: [
          steps: {steps, goal: goal}
        ]

    funnel = Repo.one(q)

    if funnel do
      {:ok, funnel}
    else
      {:error, "Funnel not found"}
    end
  end

  @spec evaluate(Plausible.Stats.Query.t(), Funnel.t() | pos_integer(), Plausible.Site.t()) ::
          {:ok, Funnel.t()} | {:error, String.t()}
  def evaluate(query, funnel_id, site) when is_integer(funnel_id) do
    with {:ok, funnel_definition} <- get(site.id, funnel_id) do
      evaluate(query, funnel_definition, site)
    end
  end

  def evaluate(query, funnel_definition, site) do
    steps =
      site
      |> Base.base_event_query(query)
      |> query_funnel(funnel_definition)
      |> backfill_steps(funnel_definition)

    {:ok,
     %{
       name: funnel_definition.name,
       steps: steps
     }}
  end

  defp query_funnel(query, funnel_definition) do
    q_events =
      from(e in query,
        select: %{session_id: e.session_id},
        where: e.site_id == ^funnel_definition.site_id,
        group_by: e.session_id,
        having: fragment("step > 0"),
        order_by: [desc: fragment("step")]
      )
      |> select_funnel(funnel_definition)

    query =
      from f in subquery(q_events),
        select: {f.step, count(1)},
        group_by: f.step

    ClickhouseRepo.all(query)
  end

  defp select_funnel(db_query, funnel_definition) do
    window_funnel_steps =
      Enum.reduce(funnel_definition.steps, nil, fn step, acc ->
        step_condition = step_condition(step.goal)

        if acc do
          dynamic([q], fragment("?, ?", ^acc, ^step_condition))
        else
          dynamic([q], fragment("?", ^step_condition))
        end
      end)

    dynamic_window_funnel =
      dynamic(
        [q],
        fragment("windowFunnel(?)(timestamp, ?)", @funnel_window_duration, ^window_funnel_steps)
      )

    from q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
  end

  defp step_condition(goal) do
    case goal do
      %Plausible.Goal{event_name: event} when is_binary(event) ->
        dynamic([], fragment("name = ?", ^event))

      %Plausible.Goal{page_path: pathname} when is_binary(pathname) ->
        if String.contains?(pathname, "*") do
          regex = Plausible.Stats.Base.page_regex(pathname)
          dynamic([], fragment("match(pathname, ?)", ^regex))
        else
          dynamic([], fragment("pathname = ?", ^pathname))
        end
    end
  end

  defp backfill_steps(funnel_result, funnel) do
    # Directly from ClickHouse we only get {step_idx(), visitor_count()} tuples.
    # but no totals including previous steps are aggregated.
    # Hence we need to perform the appropriate backfill
    # and also calculate dropoff and conversion rate for each step.
    funnel_result = Enum.into(funnel_result, %{})
    max_step = Enum.max_by(funnel.steps, & &1.step_order).step_order

    funnel
    |> Map.fetch!(:steps)
    |> Enum.reduce({nil, nil, []}, fn step, {total_visitors, visitors_at_previous, acc} ->
      # first step contains the total number of all visitors qualifying for the funnel,
      # with each subsequent step needing to accumulate sum of the previous one(s)
      visitors_at_step =
        step.step_order..max_step
        |> Enum.map(&Map.get(funnel_result, &1, 0))
        |> Enum.sum()

      # accumulate current_visitors for the next iteration
      current_visitors = visitors_at_step

      # First step contains the total number of visitors that we base percentage dropoff on
      total_visitors =
        total_visitors ||
          current_visitors

      # Dropoff is 0 for the first step, otherwise we subtract current from previous
      dropoff = if visitors_at_previous, do: visitors_at_previous - current_visitors, else: 0

      conversion_rate =
        if current_visitors == 0 or total_visitors == 0 do
          "0.00"
        else
          current_visitors
          |> Decimal.div(total_visitors)
          |> Decimal.mult(100)
          |> Decimal.round(2)
          |> Decimal.to_string()
        end

      step = %{
        dropoff: dropoff,
        conversion_rate: conversion_rate,
        visitors: visitors_at_step,
        label: to_string(step.goal)
      }

      {total_visitors, current_visitors, [step | acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end
end
