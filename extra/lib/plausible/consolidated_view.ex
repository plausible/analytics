defmodule Plausible.ConsolidatedView do
  @moduledoc """
  Contextual interface for consolidated views,
  each implemented as Site object serving as
  pointers to team's regular sites.
  """

  use Plausible
  alias Plausible.ConsolidatedView

  import Ecto.Query

  alias Plausible.Teams
  alias Plausible.Teams.Team
  alias Plausible.{Repo, Site, Auth.User}

  import Ecto.Query

  @spec flag_enabled?(Team.t()) :: boolean()
  def flag_enabled?(team) do
    FunWithFlags.enabled?(:consolidated_view, for: team)
  end

  @spec cta_dismissed?(User.t(), Team.t()) :: boolean()
  def cta_dismissed?(%User{} = user, %Team{} = team) do
    {:ok, team_membership} = Teams.Memberships.get_team_membership(team, user)
    Teams.Memberships.get_preference(team_membership, :consolidated_view_cta_dismissed)
  end

  @spec dismiss_cta(User.t(), Team.t()) :: :ok
  def dismiss_cta(%User{} = user, %Team{} = team) do
    {:ok, team_membership} = Teams.Memberships.get_team_membership(team, user)
    Teams.Memberships.set_preference(team_membership, :consolidated_view_cta_dismissed, true)

    :ok
  end

  @spec restore_cta(User.t(), Team.t()) :: :ok
  def restore_cta(%User{} = user, %Team{} = team) do
    {:ok, team_membership} = Teams.Memberships.get_team_membership(team, user)

    Teams.Memberships.set_preference(
      team_membership,
      :consolidated_view_cta_dismissed,
      false
    )

    :ok
  end

  @spec ok_to_display?(Team.t() | nil) :: boolean()
  def ok_to_display?(team) do
    is_struct(team, Team) and
      flag_enabled?(team) and
      view_enabled?(team) and
      has_sites_to_consolidate?(team) and
      Plausible.Billing.Feature.ConsolidatedView.check_availability(team) == :ok
  end

  @spec reset_if_enabled(Team.t()) :: :ok
  def reset_if_enabled(%Team{} = team) do
    case get(team) do
      nil ->
        :skip

      consolidated_view ->
        if has_sites_to_consolidate?(team) do
          consolidated_view
          |> change_stats_dates(team)
          |> change_timezone(majority_sites_timezone(team))
          |> bump_updated_at()
          |> Repo.update!()
        else
          disable(team)
        end
    end

    :ok
  end

  @spec sites(Ecto.Query.t() | Site) :: Ecto.Query.t()
  def sites(q \\ Site) do
    from(s in q, where: s.consolidated == true)
  end

  @spec enable(Team.t()) ::
          {:ok, Site.t()} | {:error, :no_sites | :team_not_setup | :upgrade_required}
  def enable(%Team{} = team) do
    cond do
      not has_sites_to_consolidate?(team) ->
        {:error, :no_sites}

      not Teams.setup?(team) ->
        {:error, :team_not_setup}

      not flag_enabled?(team) ->
        {:error, :unavailable}

      true ->
        case Plausible.Billing.Feature.ConsolidatedView.check_availability(team) do
          :ok -> do_enable(team)
          error -> error
        end
    end
  end

  @spec disable(Team.t()) :: :ok
  def disable(%Team{} = team) do
    # consider `Plausible.Site.Removal.run/1` if we ever support memberships or invitations
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
      from(s in sites(), inner_join: assoc(s, :team), where: s.domain == ^id, preload: [:team])
    )
  end

  @spec change_stats_dates(Site.t() | Ecto.Changeset.t(), Team.t()) ::
          Ecto.Changeset.t() | Site.t()
  def change_stats_dates(site_or_changeset, %Team{} = team) do
    native_stats_start_at = native_stats_start_at(team)

    if native_stats_start_at do
      start_date = NaiveDateTime.to_date(native_stats_start_at)

      site_or_changeset
      |> Site.set_native_stats_start_at(native_stats_start_at)
      |> Site.set_stats_start_date(start_date)
    else
      site_or_changeset
    end
  end

  @spec can_manage?(User.t(), Team.t()) :: boolean()
  def can_manage?(user, team) do
    case Plausible.Teams.Memberships.team_role(team, user) do
      {:ok, role} when role not in [:viewer, :guest] ->
        true

      _ ->
        false
    end
  end

  defp change_timezone(site_or_changeset, timezone) do
    Ecto.Changeset.change(site_or_changeset, timezone: timezone)
  end

  defp bump_updated_at(struct_or_changeset) do
    Ecto.Changeset.change(struct_or_changeset, updated_at: NaiveDateTime.utc_now(:second))
  end

  defp do_enable(%Team{} = team) do
    case get(team) do
      nil ->
        {:ok, consolidated_view} =
          team
          |> Site.new_for_team(%{
            consolidated: true,
            domain: make_id(team)
          })
          |> change_timezone(majority_sites_timezone(team))
          |> change_stats_dates(team)
          |> Repo.insert()

        {:ok, site_ids} = site_ids(team)
        :ok = ConsolidatedView.Cache.broadcast_put(consolidated_view.domain, site_ids)
        {:ok, consolidated_view}

      consolidated_view ->
        {:ok, consolidated_view}
    end
  end

  defp make_id(%Team{} = team) do
    team.identifier
  end

  defp native_stats_start_at(%Team{} = team) do
    q =
      from(sr in Site.regular(),
        group_by: sr.team_id,
        where: sr.team_id == ^team.id,
        select: min(sr.native_stats_start_at)
      )

    Repo.one(q)
  end

  defp has_sites_to_consolidate?(%Team{} = team) do
    Teams.owned_sites_count(team) > 1
  end

  defp majority_sites_timezone(%Team{} = team) do
    q =
      from(sr in Site.regular(),
        where: sr.team_id == ^team.id,
        group_by: sr.timezone,
        select: {sr.timezone, count(sr.id)},
        order_by: [desc: count(sr.id), asc: sr.timezone],
        limit: 1
      )

    case Repo.one(q) do
      {"UTC", _count} -> "Etc/UTC"
      {timezone, _count} -> timezone
      nil -> "Etc/UTC"
    end
  end

  defp view_enabled?(%Team{} = team) do
    not is_nil(get(team))
  end
end
