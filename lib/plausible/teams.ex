defmodule Plausible.Teams do
  @moduledoc """
  Core context of teams.
  """

  import Ecto.Query

  alias __MODULE__
  alias Plausible.Repo

  def with_subscription(team) do
    Repo.preload(team, subscription: last_subscription_query())
  end

  def owned_sites(team) do
    Repo.preload(team, :sites).sites
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
    with {:error, :no_team} <- get_owned_by_user(user) do
      case create_my_team(user) do
        {:ok, team} -> {:ok, team}
        {:error, :exists_already} -> get_owned_by_user(user)
      end
    end
  end

  def sync_team(user) do
    {:ok, team} = get_or_create(user)

    team
    |> Teams.Team.sync_changeset(user)
    |> Repo.update!()
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

  defp get_owned_by_user(user) do
    result =
      from(tm in Teams.Membership,
        inner_join: t in assoc(tm, :team),
        where: tm.user_id == ^user.id and tm.role == :owner,
        select: t,
        order_by: t.id
      )
      |> Repo.one()

    case result do
      nil -> {:error, :no_team}
      team -> {:ok, team}
    end
  end

  defp last_subscription_query() do
    from(subscription in Plausible.Billing.Subscription,
      order_by: [desc: subscription.inserted_at],
      limit: 1
    )
  end
end
