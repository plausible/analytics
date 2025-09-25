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

  @spec site_ids(Team.t() | String.t()) :: {:ok, [pos_integer()]} | {:error, :not_found}
  def site_ids(consolidated_view_id) when is_binary(consolidated_view_id) do
    case get(consolidated_view_id) do
      nil -> {:error, :not_found}
      view -> {:ok, Teams.owned_sites_ids(view.team)}
    end
  end

  def site_ids(%Team{} = team) do
    site_ids(team.identifier)
  end

  @spec get(Team.t() | String.t()) :: Site.t() | nil
  def get(team_or_id)

  def get(%Team{} = team) do
    team |> make_id() |> get()
  end

  def get(id) when is_binary(id) do
    Repo.one(
      from s in sites(), inner_join: assoc(s, :team), where: s.domain == ^id, preload: [:team]
    )
  end

  @spec native_stats_start_at(Team.t()) :: NaiveDateTime.t() | nil
  def native_stats_start_at(%Team{} = team) do
    q =
      from(sr in Site.regular(),
        group_by: sr.team_id,
        where: sr.team_id == ^team.id,
        select: min(sr.native_stats_start_at)
      )

    Repo.one(q)
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
