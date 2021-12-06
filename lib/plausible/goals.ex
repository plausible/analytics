defmodule Plausible.Goals do
  use Plausible.Repo
  alias Plausible.Goal

  def create(site, params) do
    params = Map.merge(params, %{"domain" => site.domain})

    Goal.changeset(%Goal{}, params) |> Repo.insert()
  end
  
  def update(id, params) do
    params = Map.merge(params, %{"domain" => params["domain"]})
    goal = Repo.get_by(Goal, id: id, domain: params["domain"])

    if goal do
      changeset = Goal.changeset(goal, params)
      Repo.update(changeset)
    else
      {:error, nil}
    end
  end

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
