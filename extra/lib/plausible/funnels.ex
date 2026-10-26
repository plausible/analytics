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

  @dynamic_step_fields ~w(event_name page_path scroll_threshold custom_props currency)

  @type step_error() :: :invalid_goal | :invalid_step

  @spec create(Plausible.Site.t(), String.t(), [map()], Keyword.t()) ::
          {:ok, Funnel.t()}
          | {:error, Ecto.Changeset.t() | :invalid_funnel_size | :upgrade_required | step_error()}
  def create(site, name, steps, opts \\ [])

  def create(site, name, steps, opts)
      when is_list(steps) and length(steps) in Funnel.min_steps()..Funnel.max_steps() do
    site = Plausible.Repo.preload(site, :team)

    with :ok <- Plausible.Billing.Feature.Funnels.check_availability(site.team),
         {:ok, steps, _goals_by_id} <- normalize_steps(site, steps) do
      site
      |> create_changeset(name, steps, opts)
      |> Repo.insert()
    end
  end

  def create(_site, _name, _goals, _opts) do
    {:error, :invalid_funnel_size}
  end

  @doc """
  Updates the funnel. Passing `nil` as steps leaves them untouched,
  which allows renaming or changing the funnel type only.
  """
  @spec update(Funnel.t(), String.t(), [map()] | nil, Keyword.t()) ::
          {:ok, Funnel.t()}
          | {:error, Ecto.Changeset.t() | :upgrade_required | step_error()}
  def update(funnel, name, steps, opts \\ []) do
    site = Plausible.Repo.preload(funnel, site: :team).site

    with :ok <- Plausible.Billing.Feature.Funnels.check_availability(site.team),
         {:ok, steps} <- maybe_normalize_steps(site, steps) do
      funnel
      |> edit_changeset(name, steps, opts)
      |> Repo.update()
    end
  end

  @doc """
  Validates raw step inputs against the site and turns them into
  inputs accepted by `Plausible.Funnel.changeset/2`.

  Steps referencing a goal (`%Plausible.Goal{}`, `%{goal_id: id}` or
  `%{"goal_id" => id}`) must point at a goal of the given site.
  Any other map is treated as a dynamic step, with only the fields
  supported by `Plausible.Funnel.DynamicStep` retained.
  """
  @spec normalize_steps(Plausible.Site.t(), [map()]) ::
          {:ok, [map()], %{pos_integer() => Plausible.Goal.t()}} | {:error, step_error()}
  def normalize_steps(site, steps) when is_list(steps) do
    with {:ok, goal_ids} <- collect_goal_ids(steps) do
      goals_by_id =
        from(g in Plausible.Goal, where: g.site_id == ^site.id and g.id in ^goal_ids)
        |> Repo.all()
        |> Map.new(&{&1.id, &1})

      steps
      |> Enum.reduce_while({:ok, []}, fn step, {:ok, acc} ->
        case normalize_step(step, goals_by_id) do
          {:ok, step} -> {:cont, {:ok, [step | acc]}}
          {:error, _} = error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, steps} -> {:ok, Enum.reverse(steps), goals_by_id}
        error -> error
      end
    end
  end

  defp maybe_normalize_steps(_site, nil), do: {:ok, nil}

  defp maybe_normalize_steps(site, steps) do
    with {:ok, steps, _goals_by_id} <- normalize_steps(site, steps) do
      {:ok, steps}
    end
  end

  defp collect_goal_ids(steps) do
    Enum.reduce_while(steps, {:ok, []}, fn step, {:ok, acc} ->
      case step_goal_id(step) do
        nil -> {:cont, {:ok, acc}}
        :error -> {:halt, {:error, :invalid_goal}}
        id -> {:cont, {:ok, [id | acc]}}
      end
    end)
  end

  defp normalize_step(step, goals_by_id) do
    case step_goal_id(step) do
      nil -> normalize_dynamic_step(step)
      id when is_map_key(goals_by_id, id) -> {:ok, %{goal_id: id}}
      _ -> {:error, :invalid_goal}
    end
  end

  defp step_goal_id(%Plausible.Goal{id: id}), do: parse_goal_id(id)
  defp step_goal_id(%Funnel.Step{goal_id: id}), do: parse_goal_id(id)
  defp step_goal_id(%{goal_id: id}), do: parse_goal_id(id)
  defp step_goal_id(%{"goal_id" => id}), do: parse_goal_id(id)
  defp step_goal_id(step) when is_map(step), do: nil
  defp step_goal_id(_), do: :error

  defp parse_goal_id(id) when is_integer(id) and id > 0, do: id

  defp parse_goal_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> parse_goal_id(id)
      _ -> :error
    end
  end

  defp parse_goal_id(_), do: :error

  defp normalize_dynamic_step(step) do
    step =
      step
      |> Map.new(fn {key, value} -> {to_string(key), value} end)
      |> Map.take(@dynamic_step_fields)

    if step["event_name"] == Plausible.Stats.Exploration.Journey.Step.journey_end_event() do
      {:error, :invalid_step}
    else
      {:ok, step}
    end
  end

  @spec create_changeset(Plausible.Site.t(), String.t(), [map()], Keyword.t()) ::
          Ecto.Changeset.t()
  def create_changeset(site, name, steps, opts \\ []) do
    funnel_type = Keyword.get(opts, :funnel_type, Funnel.default_funnel_type())

    Funnel.changeset(%Funnel{site_id: site.id}, %{
      name: name,
      steps: steps,
      funnel_type: funnel_type
    })
  end

  @spec edit_changeset(Plausible.Funnel.t(), String.t(), [map()], Keyword.t()) ::
          Ecto.Changeset.t()
  def edit_changeset(funnel, name, steps, opts \\ []) do
    params = %{name: name, steps: steps}

    params =
      if funnel_type = Keyword.get(opts, :funnel_type) do
        Map.put(params, :funnel_type, funnel_type)
      else
        params
      end

    Funnel.changeset(funnel, params)
  end

  @doc """
  Builds a funnel definition that is never persisted, for evaluating
  steps before saving them. Goals of static steps are preloaded.
  """
  @spec ephemeral_definition(Plausible.Site.t(), String.t(), [map()], Keyword.t()) ::
          {:ok, Funnel.t()} | {:error, Ecto.Changeset.t() | step_error()}
  def ephemeral_definition(site, name, steps, opts \\ []) do
    with {:ok, steps, goals_by_id} <- normalize_steps(site, steps) do
      changeset = create_changeset(site, name, steps, opts)

      if changeset.valid? do
        funnel = Ecto.Changeset.apply_changes(changeset)
        steps = Enum.map(funnel.steps, &%{&1 | goal: Map.fetch!(goals_by_id, &1.goal_id)})

        {:ok, %{funnel | steps: steps}}
      else
        {:error, changeset}
      end
    end
  end

  @spec list(Plausible.Site.t()) :: [
          %{name: String.t(), id: pos_integer(), steps_count: pos_integer()}
        ]
  def list(%Plausible.Site{} = site) do
    q =
      from(f in Funnel,
        left_join: steps in assoc(f, :steps),
        where: f.site_id == ^site.id,
        group_by: f.id,
        order_by: [desc: :id],
        select: %{
          name: f.name,
          id: f.id,
          steps_count:
            count(steps) + fragment("coalesce(jsonb_array_length(?), 0)", f.dynamic_steps)
        }
      )

    Repo.all(q)
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

  @spec get(Plausible.Site.t() | pos_integer(), pos_integer() | String.t()) ::
          Funnel.t() | nil
  def get(%Plausible.Site{id: site_id}, by) do
    get(site_id, by)
  end

  def get(site_id, funnel_name) when is_integer(site_id) and is_binary(funnel_name) do
    site_id |> base_get_query() |> where([f], f.name == ^funnel_name) |> Repo.one()
  end

  def get(site_id, funnel_id) when is_integer(site_id) and is_integer(funnel_id) do
    site_id |> base_get_query() |> where([f], f.id == ^funnel_id) |> Repo.one()
  end

  @spec with_goals_query(Plausible.Site.t()) :: Ecto.Query.t()
  def with_goals_query(site) do
    from(f in Funnel,
      where: f.site_id == ^site.id,
      order_by: [desc: :id],
      preload: [steps: :goal]
    )
  end

  defp base_get_query(site_id) do
    from(f in Funnel,
      where: f.site_id == ^site_id,
      left_join: steps in assoc(f, :steps),
      left_join: goal in assoc(steps, :goal),
      order_by: steps.step_order,
      preload: [
        steps: {steps, goal: goal}
      ],
      select: %{
        f
        | funnel_type:
            type(
              fragment(
                "case when ? = true then 'strict' when ? = true then 'flexible' else 'sequential' end",
                f.strict_order,
                f.first_and_last
              ),
              f.funnel_type
            )
      }
    )
  end
end
