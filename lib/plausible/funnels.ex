defmodule Plausible.Funnels do
  @funnel_window_duration 86_400
  @min_funnel_size 2
  @max_funnel_size 5

  alias Plausible.Funnel
  alias Plausible.Repo
  alias Plausible.ClickhouseRepo
  alias Plausible.Stats.Base

  import Ecto.Query

  def create(site, name, goals)
      when is_list(goals) and length(goals) >= @min_funnel_size and
             length(goals) <= @max_funnel_size do
    steps =
      goals
      |> Enum.with_index(1)
      |> Enum.map(fn {goal, index} ->
        %{
          goal_id: goal.id,
          step_order: index
        }
      end)

    %Funnel{
      site_id: site.id
    }
    |> Funnel.changeset(%{name: name, steps: steps})
    |> Repo.insert()
  end

  def create(_site, _name, _goals) do
    {:error, :invalid_funnel_size}
  end

  def list(%Plausible.Site{id: site_id}) do
    Repo.all(
      from(f in Funnel,
        where: f.site_id == ^site_id,
        select: %{name: f.name, id: f.id}
      )
    )
  end

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

    funnel = Repo.one(q)

    if funnel do
      {:ok, funnel}
    else
      {:error, "Funnel not found"}
    end
  end

  def evaluate(query, funnel_id, site) do
    with {:ok, funnel_definition} <- get(site.id, funnel_id) do
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
      from(f in subquery(q_events),
        select: {f.step, count(1)},
        group_by: f.step
      )

    ClickhouseRepo.all(query)
  end

  defp select_funnel(db_query, funnel_definition) do
    window_funnel_steps =
      Enum.reduce(funnel_definition.steps, nil, fn step, acc ->
        step_condition =
          case step.goal do
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

    from(
      q in db_query,
      select_merge:
        ^%{
          step: dynamic_window_funnel
        }
    )
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
    |> Enum.map(fn step ->
      visitors_total =
        step.step_order..max_step
        |> Enum.map(&Map.get(funnel_result, &1, 0))
        |> Enum.sum()

      %{
        visitors: visitors_total,
        label: Plausible.Goal.display_name(step.goal)
      }
    end)
    |> Enum.reduce({nil, nil, []}, fn step, {total_visitors, visitors_at_previous, acc} ->
      # accumulate current_visitors for the next iteration
      current_visitors = step.visitors

      # First step contains the total number of visitors that we base percentage dropoff on
      total_visitors = total_visitors || current_visitors

      # Dropoff is 0 for the first step, otherwise we subtract current from previous
      dropoff = if visitors_at_previous, do: visitors_at_previous - step.visitors, else: 0

      conversion_rate =
        (current_visitors / total_visitors * 100)
        |> Decimal.from_float()
        |> Decimal.round(2)
        |> Decimal.to_string()

      step =
        step
        |> Map.put(:dropoff, dropoff)
        |> Map.put(:conversion_rate, conversion_rate)

      {total_visitors, current_visitors, [step | acc]}
    end)
    |> elem(2)
    |> Enum.reverse()
  end
end
