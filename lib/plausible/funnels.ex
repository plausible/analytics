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
      name: name
    })
    |> put_assoc(:funnel_goals, funnel_goals)
    |> Repo.insert!()
  end

  def list_funnels(site) do
  end

  def evaluate(query, funnel) do
    q_events =
      from e in "events_v2",
        select: %{
          session_id: e.session_id,
          step:
            fragment(
              "windowFunnel(?)(timestamp, pathname = '/go/to/blog/foo', name = 'Signup', pathname = '/checkout')",
              @funnel_window_duration
            )
        },
        where: e.site_id == ^funnel.site_id,
        group_by: e.session_id,
        having: fragment("step > 0"),
        order_by: [desc: fragment("step")]

    query =
      from f in subquery(q_events),
        select: %{
          visitors: count(1),
          step: f.step
        },
        group_by: f.step

    Logger.configure(level: :debug)

    steps = ClickhouseRepo.all(query)

    # funnel
    # |> Repo.preload([:goals])

    %{
      steps: steps
    }
  end
end
