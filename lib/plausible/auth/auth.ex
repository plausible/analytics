defmodule Plausible.Auth do
  @moduledoc """
  Functions for user authentication context.
  """

  use Plausible
  use Plausible.Repo

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Billing
  alias Plausible.RateLimit
  alias Plausible.Teams

  @rate_limits %{
    login_ip: %{
      prefix: "login:ip",
      limit: 5,
      interval: :timer.seconds(60)
    },
    login_user: %{
      prefix: "login:user",
      limit: 5,
      interval: :timer.seconds(60)
    },
    email_change_user: %{
      prefix: "email-change:user",
      limit: 2,
      interval: :timer.hours(1)
    },
    password_change_user: %{
      prefix: "password-change:user",
      limit: 5,
      interval: :timer.minutes(20)
    }
  }

  @rate_limit_types Map.keys(@rate_limits)

  @type rate_limit_type() :: unquote(Enum.reduce(@rate_limit_types, &{:|, [], [&1, &2]}))

  @spec rate_limit(rate_limit_type(), Auth.User.t() | Plug.Conn.t()) ::
          :ok | {:error, {:rate_limit, rate_limit_type()}}
  def rate_limit(limit_type, key) when limit_type in @rate_limit_types do
    %{prefix: prefix, limit: limit, interval: interval} = @rate_limits[limit_type]
    full_key = "#{prefix}:#{rate_limit_key(key)}"

    case RateLimit.check_rate(full_key, interval, limit) do
      {:allow, _} -> :ok
      {:deny, _} -> {:error, {:rate_limit, limit_type}}
    end
  end

  @spec find_user_by(Keyword.t()) :: Auth.User.t() | nil
  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end

  @spec lookup(String.t()) :: {:ok, Auth.User.t()} | {:error, :user_not_found}
  def lookup(email) do
    query =
      on_ee do
        from(
          u in Auth.User,
          left_join: tm in assoc(u, :team_memberships),
          on: u.type == :sso and tm.role == :owner,
          left_join: t in assoc(tm, :team),
          where: u.email == ^email,
          where: u.type == :standard or (u.type == :sso and t.setup_complete == true)
        )
      else
        from(u in Auth.User, where: u.email == ^email)
      end

    case Repo.one(query) do
      %Auth.User{} = user -> {:ok, user}
      nil -> {:error, :user_not_found}
    end
  end

  @spec check_password(Auth.User.t(), String.t()) :: :ok | {:error, :wrong_password}
  def check_password(user, password) do
    if Plausible.Auth.Password.match?(password, user.password_hash || "") do
      :ok
    else
      {:error, :wrong_password}
    end
  end

  @spec delete_user(Auth.User.t()) ::
          {:ok, :deleted} | {:error, :is_only_team_owner | :active_subscription}
  def delete_user(user) do
    case Teams.get_by_owner(user) do
      {:ok, %{setup_complete: false} = team} ->
        delete_team_and_user(team, user)

      {:ok, team} ->
        with :ok <- check_can_leave_team(team) do
          delete_user!(user)
          {:ok, :deleted}
        end

      {:error, :multiple_teams} ->
        teams = Teams.Users.owned_teams(user)

        with :ok <- check_can_leave_teams(teams) do
          personal_team = Enum.find(teams, &(not Teams.setup?(&1)))
          delete_team_and_user(personal_team, user)
        end

      {:error, :no_team} ->
        delete_user!(user)
        {:ok, :deleted}
    end
  end

  defp delete_team_and_user(nil, user) do
    delete_user!(user)
    {:ok, :deleted}
  end

  defp delete_team_and_user(team, user) do
    Repo.transaction(fn ->
      case Teams.delete(team) do
        {:ok, :deleted} ->
          delete_user!(user)
          :deleted

        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  defp delete_user!(user) do
    Repo.transaction(fn ->
      Plausible.Segments.user_removed(user)
      Repo.delete!(user)
    end)

    :ok
  end

  defp check_can_leave_teams(teams) do
    teams
    |> Enum.filter(& &1.setup_complete)
    |> Enum.reduce_while(:ok, fn team, :ok ->
      case check_can_leave_team(team) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp check_can_leave_team(team) do
    if Teams.Memberships.owners_count(team) > 1 do
      :ok
    else
      {:error, :is_only_team_owner}
    end
  end

  on_ee do
    def is_super_admin?(nil), do: false
    def is_super_admin?(%Plausible.Auth.User{id: id}), do: is_super_admin?(id)

    def is_super_admin?(user_id) when is_integer(user_id) do
      user_id in Application.get_env(:plausible, :super_admin_user_ids)
    end
  else
    def is_super_admin?(_), do: always(false)
  end

  @spec list_api_keys(Auth.User.t(), Teams.Team.t() | nil) :: [Auth.ApiKey.t()]
  def list_api_keys(user, team) do
    query =
      from(a in Auth.ApiKey,
        where: a.user_id == ^user.id,
        order_by: [desc: a.id],
        select: %{
          a
          | type:
              fragment(
                "CASE WHEN ? = ANY(?) THEN ? ELSE ? END",
                "sites:provision:*",
                a.scopes,
                "sites_api",
                "stats_api"
              )
        }
      )
      |> scope_api_keys_by_team(team)

    Repo.all(query)
  end

  @spec create_stats_api_key(Auth.User.t(), Teams.Team.t(), String.t(), String.t()) ::
          {:ok, Auth.ApiKey.t()} | {:error, Ecto.Changeset.t() | :upgrade_required}
  def create_stats_api_key(user, team, name, key) do
    params = %{name: name, user_id: user.id, key: key}
    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{}, team, params)

    with :ok <- Billing.Feature.StatsAPI.check_availability(team) do
      Repo.insert(changeset)
    end
  end

  @spec create_sites_api_key(Auth.User.t(), Teams.Team.t(), String.t(), String.t()) ::
          {:ok, Auth.ApiKey.t()} | {:error, Ecto.Changeset.t() | :upgrade_required}
  def create_sites_api_key(user, team, name, key) do
    params = %{name: name, user_id: user.id, key: key, scopes: ["sites:provision:*"]}
    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{}, team, params)

    with :ok <- Billing.Feature.StatsAPI.check_availability(team),
         :ok <- Billing.Feature.SitesAPI.check_availability(team) do
      Repo.insert(changeset)
    end
  end

  @spec delete_api_key(Auth.User.t(), integer()) :: :ok | {:error, :not_found}
  def delete_api_key(user, id) do
    query = from(api_key in Auth.ApiKey, where: api_key.id == ^id and api_key.user_id == ^user.id)

    case Repo.delete_all(query) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec find_api_key(String.t(), Keyword.t()) ::
          {:ok, %{api_key: Auth.ApiKey.t(), team: Teams.Team.t() | nil}}
          | {:error, :invalid_api_key | :missing_site_id}
  def find_api_key(raw_key, opts \\ []) do
    {team_scope, id} = Keyword.get(opts, :team_by, {nil, nil})

    find_api_key(raw_key, team_scope, id)
  end

  defp scope_api_keys_by_team(query, nil) do
    query
  end

  defp scope_api_keys_by_team(query, team) do
    where(query, [a], is_nil(a.team_id) or a.team_id == ^team.id)
  end

  defp find_api_key(raw_key, nil, _) do
    hashed_key = Auth.ApiKey.do_hash(raw_key)

    query =
      from(api_key in Auth.ApiKey,
        join: user in assoc(api_key, :user),
        left_join: team in assoc(api_key, :team),
        where: api_key.key_hash == ^hashed_key,
        preload: [user: user, team: team]
      )

    case Repo.one(query) do
      nil ->
        {:error, :invalid_api_key}

      %{team: %{} = team} = api_key ->
        {:ok, %{api_key: api_key, team: team}}

      api_key ->
        {:ok, %{api_key: api_key, team: nil}}
    end
  end

  defp find_api_key(raw_key, :site, nil) do
    find_api_key(raw_key, nil, nil)
  end

  defp find_api_key(raw_key, :site, domain) do
    case find_api_key(raw_key, nil, nil) do
      {:ok, %{api_key: api_key, team: nil}} ->
        team = find_team_by_site(domain)
        {:ok, %{api_key: api_key, team: team}}

      {:ok, %{api_key: api_key, team: team}} ->
        {:ok, %{api_key: api_key, team: team}}

      {:error, _} = error ->
        error
    end
  end

  defp find_team_by_site(domain) do
    Repo.one(
      from s in Plausible.Site,
        inner_join: t in assoc(s, :team),
        where: s.domain == ^domain or s.domain_changed_from == ^domain,
        select: t
    )
  end

  defp rate_limit_key(%Auth.User{id: id}), do: id
  defp rate_limit_key(%Plug.Conn{} = conn), do: PlausibleWeb.RemoteIP.get(conn)
end
