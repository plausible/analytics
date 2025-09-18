defmodule Plausible.ConsolidatedView do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Teams.Team
  alias Plausible.Repo

  def cv_domain(team) do
    "cv-#{team.identifier}"
  end

  def enable(%Team{} = team) do
    cv_domain = cv_domain(team)

    case Repo.get_by(Plausible.Site, domain: cv_domain) do
      nil ->
        Plausible.Site.new_for_team(team, %{consolidated: true, domain: cv_domain})
        |> Repo.insert()

      cv ->
        {:ok, cv}
    end
  end

  def disable(%Team{} = team) do
    from(s in Plausible.Site, where: s.consolidated and s.domain == ^cv_domain(team))
    |> Plausible.Repo.delete_all()

    :ok
  end
end
