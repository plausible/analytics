defmodule Plausible.ConsolidatedView do
  @moduledoc false

  use Plausible

  import Ecto.Query

  alias Plausible.Teams.Team
  alias Plausible.Repo

  @spec cv_domain(Plausible.Teams.Team.t()) :: String.t()
  def cv_domain(%Team{} = team) do
    "cv-#{team.identifier}"
  end

  @spec enable(Plausible.Teams.Team.t()) ::
          {:ok, Plausible.Site.t()} | {:error, :upgrade_required}
  def enable(%Team{} = team) do
    if eligible?(team) do
      do_enable(team)
    else
      {:error, :upgrade_required}
    end
  end

  @spec disable(Plausible.Teams.Team.t()) :: :ok
  def disable(%Team{} = team) do
    from(s in Plausible.Site, where: s.consolidated and s.domain == ^cv_domain(team))
    |> Plausible.Repo.delete_all()

    :ok
  end

  defp do_enable(%Team{} = team) do
    cv_domain = cv_domain(team)

    case Repo.get_by(Plausible.Site, domain: cv_domain) do
      nil ->
        Plausible.Site.new_for_team(team, %{consolidated: true, domain: cv_domain})
        |> Repo.insert()

      cv ->
        {:ok, cv}
    end
  end

  # TODO: Only active trials and business subscriptions should be eligible.
  # This function should call a new underlying feature module.
  defp eligible?(%Team{}), do: always(true)
end
