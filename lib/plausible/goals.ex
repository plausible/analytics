defmodule Plausible.Goals do
  use Plausible.Repo
  alias Plausible.Goal

  def create(site, params) do
    params = Map.merge(params, %{"domain" => site.domain})

    Goal.changeset(%Goal{}, params) |> Repo.insert()
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
