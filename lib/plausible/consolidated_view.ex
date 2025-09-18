defmodule Plausible.ConsolidatedView do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Teams.Team
  alias Plausible.{Repo, Site}

  @spec cv_domain(Team.t()) :: String.t()
  def cv_domain(%Team{} = team) do
    "cv-#{team.identifier}"
  end

  @spec enable(Team.t()) :: {:ok, Site.t()} | {:error, :upgrade_required}
  def enable(%Team{} = team) do
    if eligible?(team) do
      do_enable(team)
    else
      {:error, :upgrade_required}
    end
  end

  @spec disable(Team.t()) :: :ok
  def disable(%Team{} = team) do
    from(s in Site, where: s.consolidated and s.domain == ^cv_domain(team))
    |> Plausible.Repo.delete_all()

    :ok
  end

  @spec site_ids(Team.t()) :: [pos_integer()] | {:error, :not_found}
  def site_ids(%Team{} = team) do
    case Repo.get_by(Site, domain: cv_domain(team)) do
      nil -> {:error, :not_found}
      _found -> {:ok, Plausible.Teams.owned_sites_ids(team)}
    end
  end

  defp do_enable(%Team{} = team) do
    cv_domain = cv_domain(team)

    case Repo.get_by(Site, domain: cv_domain) do
      nil ->
        Site.new_for_team(team, %{consolidated: true, domain: cv_domain})
        |> Repo.insert()

      cv ->
        {:ok, cv}
    end
  end

  # TODO: Only active trials and business subscriptions should be eligible.
  # This function should call a new underlying feature module.
  defp eligible?(%Team{}), do: always(true)
end
