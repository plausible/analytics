defmodule Plausible.Teams do
  @moduledoc """
  Core context of teams.
  """

  import Ecto.Query

  alias __MODULE__
  alias Plausible.Repo
  use Plausible

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
  def trial_days_left(team) do
    Date.diff(team.trial_expiry_date, Date.utc_today())
  end

  def read_team_schemas?(user) do
    FunWithFlags.enabled?(:read_team_schemas, for: user)
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
      from s in Plausible.Site,
        where: s.team_id == ^team.id,
        select: s.id,
        order_by: [desc: s.id]
    )
  end

  def owned_sites_locked?(nil) do
    false
  end

  def owned_sites_locked?(team) do
    Repo.exists?(
      from s in Plausible.Site,
        where: s.team_id == ^team.id,
        where: s.locked == true
    )
  end

  @doc """
  Create (when necessary) and load team relation for provided site.

  Used for sync logic to work smoothly during transitional period.
  """
  def load_for_site(site) do
    site = Repo.preload(site, [:team, :owner])

    if site.team do
      site
    else
      {:ok, team} = get_or_create(site.owner)

      site
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:team, team)
      |> Ecto.Changeset.force_change(:updated_at, site.updated_at)
      |> Repo.update!()
    end
  end

  @doc """
  Get or create user's team.

  If the user has no non-guest membership yet, an implicit "My Team" team is
  created with them as an owner.

  If the user already has an owner membership in an existing team,
  that team is returned.

  If the user has a non-guest membership other than owner, `:no_team` error
  is returned.
  """
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

  def sync_team(user) do
    {:ok, team} = get_or_create(user)

    team
    |> Teams.Team.sync_changeset(user)
    |> Repo.update!()
  end

  def get_by_owner(user_id) when is_integer(user_id) do
    result =
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        where: tm.user_id == ^user_id and tm.role == :owner,
        select: t,
        order_by: t.id
      )
      |> Repo.one()

    case result do
      nil ->
        {:error, :no_team}

      team ->
        {:ok, team}
    end
  end

  def get_by_owner(%Plausible.Auth.User{} = user) do
    get_by_owner(user.id)
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
      "My Team"
      |> Teams.Team.changeset()
      |> Ecto.Changeset.put_change(:inserted_at, user.inserted_at)
      |> Ecto.Changeset.put_change(:updated_at, user.updated_at)
      |> Repo.insert!()

    team_membership =
      team
      |> Teams.Membership.changeset(user, :owner)
      |> Ecto.Changeset.put_change(:inserted_at, user.inserted_at)
      |> Ecto.Changeset.put_change(:updated_at, user.updated_at)
      |> Repo.insert!(
        on_conflict: :nothing,
        conflict_target: {:unsafe_fragment, "(user_id) WHERE role != 'guest'"}
      )

    if team_membership.id do
      {:ok, team}
    else
      Repo.delete!(team)
      {:error, :exists_already}
    end
  end
end
