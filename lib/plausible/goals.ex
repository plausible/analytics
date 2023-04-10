defmodule Plausible.Goals do
  use Plausible.Repo
  alias Plausible.Goal

  def create(site, params) do
    params = Map.merge(params, %{"domain" => site.domain})

    Goal.changeset(%Goal{}, params) |> Repo.insert()
  end

  def find_or_create(site, %{"goal_type" => "event", "event_name" => event_name}) do
    goal = Repo.get_by(Plausible.Goal, domain: site.domain, event_name: event_name)

    case goal do
      nil -> create(site, %{"event_name" => event_name})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "event"}), do: {:missing, "event_name"}

  def find_or_create(site, %{"goal_type" => "page", "page_path" => page_path}) do
    goal = Repo.get_by(Plausible.Goal, domain: site.domain, page_path: page_path)

    case goal do
      nil -> create(site, %{"page_path" => page_path})
      goal -> {:ok, goal}
    end
  end

  def find_or_create(_, %{"goal_type" => "page"}), do: {:missing, "page_path"}

  def for_domain(domain) do
    query =
      from g in Goal,
        where: g.domain == ^domain

    query
    |> Repo.all()
    |> Enum.map(&maybe_trim/1)
  end

  def delete(id, domain) do
    case Repo.delete_all(
           from g in Goal,
             where: g.id == ^id,
             where: g.domain == ^domain
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
