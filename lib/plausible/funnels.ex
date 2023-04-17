defmodule Plausible.Funnels do
  @funnel_window_duration 86_400

  alias Plausible.Funnel
  alias Plausible.Repo
  alias Plausible.ClickhouseRepo

  import Ecto.Changeset
  import Ecto.Query

  def create(site, name, goals) when is_list(goals) do
    funnel_goals =
      goals
      |> Enum.with_index(1)
      |> Enum.map(fn {goal, index} ->
        %{
          goal_id: goal.id,
          step_order: index
        }
      end)

    change(%Funnel{
      site_id: site.id,
      name: name,
      id: 5
    })
    |> put_assoc(:funnel_goals, funnel_goals)
    |> Repo.insert!()
  end

  def list_funnels(site) do
  end

  def evaluate(_query, funnel_id, site_id) do
    funnel =
      Repo.get_by(Funnel,
        id: funnel_id,
        site_id: site_id
      )
      # XXX: make inner join
      |> Repo.preload(funnel_goals: :goal)

    q_events =
      from e in "events_v2",
        select: %{
          session_id: e.session_id,
          step:
            fragment(
              "windowFunnel(?)(timestamp, pathname = '/product/car', name = 'Add to cart', pathname = '/view/checkout', name = 'Purchase')",
              @funnel_window_duration
            )
        },
        where: e.site_id == ^funnel.site_id,
        group_by: e.session_id,
        having: fragment("step > 0"),
        order_by: [desc: fragment("step")]

    query =
      from f in subquery(q_events),
        select: {f.step, count(1)},
        group_by: f.step

    funnel_result =
      ClickhouseRepo.all(query)
      |> Enum.into(%{})
      |> IO.inspect(label: :query)

    steps = update_step_defaults(funnel, funnel_result)

    %{
      name: funnel.name,
      steps: steps
    }
  end

  defp update_step_defaults(funnel, funnel_result) do
    max_step = Enum.max_by(funnel.funnel_goals, & &1.step_order).step_order

    funnel.funnel_goals
    |> Enum.sort_by(& &1.step_order)
    |> Enum.map(fn funnel_goal ->
      label =
        Plausible.Goal.display_name(funnel_goal.goal)
        |> IO.inspect(label: :label)

      visitors_total =
        Enum.reduce(funnel_goal.step_order..max_step, 0, fn step_order, acc ->
          visitors =
            Map.get(funnel_result, step_order, 0)
            |> IO.inspect(label: "visitors_#{step_order}")

          acc + visitors
        end)
        |> IO.inspect(label: :visitors_total)

      %{
        visitors: visitors_total,
        label: label
      }
    end)
  end
end
