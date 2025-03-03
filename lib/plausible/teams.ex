defmodule Plausible.Teams do
  @moduledoc """
  Core context of teams.
  """

  import Ecto.Query

  alias __MODULE__
  alias Plausible.Auth
  alias Plausible.Repo
  use Plausible

  @accept_traffic_until_free ~D[2135-01-01]

  @spec default_name() :: String.t()
  def default_name(), do: "My Personal Sites"

  @spec name(nil | Teams.Team.t()) :: String.t()
  def name(nil), do: default_name()
  def name(%{setup_complete: false}), do: default_name()
  def name(team), do: team.name

  @spec setup?(nil | Teams.Team.t()) :: boolean()
  def setup?(nil), do: false
  def setup?(%{setup_complete: setup_complete}), do: setup_complete

  @spec enabled?(nil | Teams.Team.t()) :: boolean()
  def enabled?(nil) do
    FunWithFlags.enabled?(:teams)
  end

  def enabled?(team) do
    FunWithFlags.enabled?(:teams, for: team)
  end

  @spec get(pos_integer() | binary() | nil) :: Teams.Team.t() | nil
  def get(nil), do: nil

  def get(team_id) when is_integer(team_id) do
    Repo.get(Teams.Team, team_id)
  end

  def get(team_identifier) when is_binary(team_identifier) do
    Repo.get_by(Teams.Team, identifier: team_identifier)
  end

  @spec get!(pos_integer() | binary()) :: Teams.Team.t()
  def get!(team_id) when is_integer(team_id) do
    Repo.get!(Teams.Team, team_id)
  end

  def get!(team_identifier) when is_binary(team_identifier) do
    Repo.get_by!(Teams.Team, identifier: team_identifier)
  end

  @spec on_trial?(Teams.Team.t() | nil) :: boolean()
  on_ee do
    def on_trial?(nil), do: false
    def on_trial?(%Teams.Team{trial_expiry_date: nil}), do: false

    def on_trial?(team) do
      team = with_subscription(team)

      not Plausible.Billing.Subscriptions.active?(team.subscription) &&
        trial_days_left(team) >= 0
    end
  else
    def on_trial?(_), do: true
  end

  @spec trial_days_left(Teams.Team.t()) :: integer()
  def trial_days_left(nil) do
    nil
  end

  def trial_days_left(team) do
    Date.diff(team.trial_expiry_date, Date.utc_today())
  end

  def with_subscription(team) do
    Repo.preload(team, subscription: last_subscription_query())
  end

  def owned_sites(team) do
    Repo.preload(team, :sites).sites
  end

  def owned_sites_ids(nil) do
    []
  end

  def owned_sites_ids(team) do
    Repo.all(
      from(s in Plausible.Site,
        where: s.team_id == ^team.id,
        select: s.id,
        order_by: [desc: s.id]
      )
    )
  end

  def owned_sites_locked?(nil) do
    false
  end

  def owned_sites_locked?(team) do
    Repo.exists?(
      from(s in Plausible.Site,
        where: s.team_id == ^team.id,
        where: s.locked == true
      )
    )
  end

  def owned_sites_count(nil), do: 0

  def owned_sites_count(team) do
    Repo.aggregate(
      from(s in Plausible.Site,
        where: s.team_id == ^team.id
      ),
      :count
    )
  end

  def has_active_sites?(team) do
    team
    |> owned_sites()
    |> Enum.any?(&Plausible.Sites.has_stats?/1)
  end

  @doc """
  Get or create user's team.

  If the user has no non-guest membership yet, an implicit "My Personal Sites" team is
  created with them as an owner.

  If the user already has an owner membership in an existing team,
  that team is returned.

  If the user has a non-guest membership other than owner, `:no_team` error
  is returned.
  """
  @spec get_or_create(Auth.User.t()) :: {:ok, Teams.Team.t()} | {:error, :multiple_teams}
  def get_or_create(user) do
    with {:error, :no_team} <- get_by_owner(user) do
      case create_my_team(user) do
        {:ok, team} ->
          {:ok, team}

        {:error, :exists_already} ->
          get_by_owner(user)
      end
    end
  end

  @spec force_create_my_team(Auth.User.t()) :: Teams.Team.t()
  def force_create_my_team(user) do
    {:ok, team} =
      Repo.transaction(fn ->
        Repo.update_all(
          from(tm in Teams.Membership,
            where: tm.user_id == ^user.id,
            where: tm.is_autocreated == true
          ),
          set: [is_autocreated: false]
        )

        {:ok, team} = create_my_team(user)
        team
      end)

    team
  end

  @spec get_by_owner(Auth.User.t() | pos_integer()) ::
          {:ok, Teams.Team.t()} | {:error, :no_team | :multiple_teams}
  def get_by_owner(user_id) when is_integer(user_id) do
    result =
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        where: tm.user_id == ^user_id and tm.role == :owner,
        select: t,
        order_by: t.id
      )
      |> Repo.all()

    case result do
      [] ->
        {:error, :no_team}

      [team] ->
        {:ok, team}

      _teams ->
        {:error, :multiple_teams}
    end
  end

  def get_by_owner(%Auth.User{} = user) do
    get_by_owner(user.id)
  end

  @spec update_accept_traffic_until(Teams.Team.t()) :: Teams.Team.t()
  def update_accept_traffic_until(team) do
    team
    |> Ecto.Changeset.change(accept_traffic_until: accept_traffic_until(team))
    |> Repo.update!()
  end

  def start_trial(%Teams.Team{} = team) do
    team
    |> Teams.Team.start_trial()
    |> Repo.update!()
  end

  def start_grace_period(team) do
    team
    |> Teams.GracePeriod.start_changeset()
    |> Repo.update!()
  end

  def start_manual_lock_grace_period(team) do
    team
    |> Teams.GracePeriod.start_manual_lock_changeset()
    |> Repo.update!()
  end

  def end_grace_period(team) do
    team
    |> Teams.GracePeriod.end_changeset()
    |> Repo.update!()
  end

  def remove_grace_period(team) do
    team
    |> Teams.GracePeriod.remove_changeset()
    |> Repo.update!()
  end

  def maybe_reset_next_upgrade_override(%Teams.Team{} = team) do
    if team.allow_next_upgrade_override do
      team
      |> Ecto.Changeset.change(allow_next_upgrade_override: false)
      |> Repo.update!()
    else
      team
    end
  end

  @spec accept_traffic_until(Teams.Team.t()) :: Date.t()
  on_ee do
    def accept_traffic_until(team) do
      team = with_subscription(team)

      cond do
        on_trial?(team) ->
          Date.shift(team.trial_expiry_date,
            day: Teams.Team.trial_accept_traffic_until_offset_days()
          )

        team.subscription && team.subscription.paddle_plan_id == "free_10k" ->
          @accept_traffic_until_free

        team.subscription && team.subscription.next_bill_date ->
          Date.shift(team.subscription.next_bill_date,
            day: Teams.Team.subscription_accept_traffic_until_offset_days()
          )

        true ->
          raise "This user is neither on trial or has a valid subscription. Manual intervention required."
      end
    end
  else
    def accept_traffic_until(_user) do
      @accept_traffic_until_free
    end
  end

  def last_subscription_join_query() do
    from(subscription in last_subscription_query(),
      where: subscription.team_id == parent_as(:team).id
    )
  end

  def last_subscription_query() do
    from(subscription in Plausible.Billing.Subscription,
      order_by: [desc: subscription.inserted_at, desc: subscription.id],
      limit: 1
    )
  end

  defp create_my_team(user) do
    team =
      %Teams.Team{}
      |> Teams.Team.changeset(%{name: default_name()})
      |> Ecto.Changeset.put_change(:inserted_at, user.inserted_at)
      |> Ecto.Changeset.put_change(:updated_at, user.updated_at)
      |> Repo.insert!()

    team_membership =
      team
      |> Teams.Membership.changeset(user, :owner)
      |> Ecto.Changeset.put_change(:is_autocreated, true)
      |> Ecto.Changeset.put_change(:inserted_at, user.inserted_at)
      |> Ecto.Changeset.put_change(:updated_at, user.updated_at)
      |> Repo.insert!(
        on_conflict: :nothing,
        conflict_target:
          {:unsafe_fragment, "(user_id) WHERE role = 'owner' and is_autocreated = true"}
      )

    if team_membership.id do
      {:ok, team}
    else
      Repo.delete!(team)
      {:error, :exists_already}
    end
  end
end
