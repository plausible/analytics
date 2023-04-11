defmodule Plausible.Goals do
  use Plausible.Repo
  alias Plausible.Goal

  def create(site, params) do
    params = Map.merge(params, %{"site_id" => site.id})

    case Repo.insert(Goal.changeset(%Goal{}, params)) do
      {:ok, goal} -> {:ok, Repo.preload(goal, :site)}
      error -> error
    end
  end

  def find_or_create(site, %{"goal_type" => "event", "event_name" => event_name}) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        where: g.event_name == ^event_name,
        preload: [:site]

    goal = Repo.one(query)

    case goal do
      nil -> create(site, %{"event_name" => event_name})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "event"}), do: {:missing, "event_name"}

  def find_or_create(site, %{"goal_type" => "page", "page_path" => page_path}) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        where: g.page_path == ^page_path,
        preload: [:site]

    goal = Repo.one(query)

    case goal do
      nil -> create(site, %{"page_path" => page_path})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "page"}), do: {:missing, "page_path"}

  def for_site(site) do
    query =
      from g in Goal,
        inner_join: assoc(g, :site),
        where: g.site_id == ^site.id,
        preload: [:site]

    query
    |> Repo.all()
    |> Enum.map(&maybe_trim/1)
  end

  def delete(id, site) do
    case Repo.delete_all(
           from g in Goal,
             where: g.id == ^id,
             where: g.site_id == ^site.id
         ) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  defp maybe_trim(%Goal{} = goal) do
    # we make sure that even if we saved goals erroneously with trailing
    # space, it's removed during fetch
    goal
    |> Map.update!(:event_name, &maybe_trim/1)
    |> Map.update!(:page_path, &maybe_trim/1)
  end

  defp maybe_trim(s) when is_binary(s) do
    String.trim(s)
  end

  defp maybe_trim(other) do
    other
  end
end
