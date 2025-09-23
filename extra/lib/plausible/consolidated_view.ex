defmodule Plausible.ConsolidatedView do
  @moduledoc """
  Contextual interface for consolidated views,
  each implemented as Site object serving as
  pointers to team's regular sites.
  """

  use Plausible

  import Ecto.Query

  alias Plausible.Teams
  alias Plausible.Teams.Team
  alias Plausible.{Repo, Site}

  import Ecto.Query

  @spec sites(Ecto.Query.t() | Site) :: Ecto.Query.t()
  def sites(q \\ Site) do
    from s in q, where: s.consolidated == true
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
    Plausible.Repo.delete_all(from(s in sites(), where: s.domain == ^make_id(team)))
    :ok
  end

  @spec site_ids(Team.t()) :: [pos_integer()] | {:error, :not_found}
  def site_ids(%Team{} = team) do
    case get(team) do
      nil -> {:error, :not_found}
      _found -> {:ok, Teams.owned_sites_ids(team)}
    end
  end

  @spec get(Team.t() | String.t()) :: Site.t() | nil
  def get(team_or_id)

  def get(%Team{} = team) do
    team |> make_id() |> get()
  end

  def get(id) when is_binary(id) do
    Repo.one(from s in sites(), where: s.domain == ^id)
  end

  defp do_enable(%Team{} = team) do
    case get(team) do
      nil ->
        team
        |> Site.new_for_team(%{consolidated: true, domain: make_id(team)})
        |> Repo.insert()

      consolidated_view ->
        {:ok, consolidated_view}
    end
  end

  defp make_id(%Team{} = team) do
    team.identifier
  end

  # TODO: Only active trials and business subscriptions should be eligible.
  # This function should call a new underlying feature module.
  defp eligible?(%Team{}), do: always(true)
end
