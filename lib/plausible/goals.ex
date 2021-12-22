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

  def for_site(domain) do
    Repo.all(
      from g in Goal,
        where: g.domain == ^domain
    )
  end

  def delete(id) do
    Repo.one(from g in Goal, where: g.id == ^id) |> Repo.delete!()
  end
end
