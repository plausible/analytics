defmodule Plausible.Auth do
  @moduledoc """
  Functions for user authentication context.
  """

  use Plausible
  use Plausible.Repo
  alias Plausible.Auth
  alias Plausible.RateLimit

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

  @spec rate_limits() :: map()
  def rate_limits(), do: @rate_limits

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

  def create_user(name, email, pwd) do
    Auth.User.new(%{name: name, email: email, password: pwd, password_confirmation: pwd})
    |> Repo.insert()
  end

  @spec find_user_by(Keyword.t()) :: Auth.User.t() | nil
  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end

  @spec get_user_by(Keyword.t()) :: {:ok, Auth.User.t()} | {:error, :user_not_found}
  def get_user_by(opts) do
    case Repo.get_by(Auth.User, opts) do
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

  def has_active_sites?(user, roles \\ [:owner, :admin, :viewer]) do
    sites =
      Repo.all(
        from u in Plausible.Auth.User,
          where: u.id == ^user.id,
          join: sm in Plausible.Site.Membership,
          on: sm.user_id == u.id,
          where: sm.role in ^roles,
          join: s in Plausible.Site,
          on: s.id == sm.site_id,
          select: s
      )

    Enum.any?(sites, &Plausible.Sites.has_stats?/1)
  end

  def delete_user(user) do
    Repo.transaction(fn ->
      user =
        user
        |> Repo.preload(site_memberships: :site)

      for membership <- user.site_memberships do
        Repo.delete!(membership)

        if membership.role == :owner do
          Plausible.Site.Removal.run(membership.site.domain)
        end
      end

      Repo.delete!(user)
    end)
  end

  def user_owns_sites?(user) do
    Repo.exists?(
      from(s in Plausible.Site,
        join: sm in Plausible.Site.Membership,
        on: sm.site_id == s.id,
        where: sm.user_id == ^user.id,
        where: sm.role == :owner
      )
    )
  end

  on_ee do
    def is_super_admin?(nil), do: false
    def is_super_admin?(%Plausible.Auth.User{id: id}), do: is_super_admin?(id)

    def is_super_admin?(user_id) when is_integer(user_id) do
      user_id in Application.get_env(:plausible, :super_admin_user_ids)
    end
  else
    def is_super_admin?(_), do: false
  end

  def enterprise_configured?(nil), do: false

  def enterprise_configured?(%Plausible.Auth.User{} = user) do
    user
    |> Ecto.assoc(:enterprise_plan)
    |> Repo.exists?()
  end

  @spec create_api_key(Auth.User.t(), String.t(), String.t()) ::
          {:ok, Auth.ApiKey.t()} | {:error, Ecto.Changeset.t() | :upgrade_required}
  def create_api_key(user, name, key) do
    params = %{name: name, user_id: user.id, key: key}
    changeset = Auth.ApiKey.changeset(%Auth.ApiKey{}, params)

    with :ok <- Plausible.Billing.Feature.StatsAPI.check_availability(user),
         do: Repo.insert(changeset)
  end

  @spec delete_api_key(Auth.User.t(), integer()) :: :ok | {:error, :not_found}
  def delete_api_key(user, id) do
    query = from(api_key in Auth.ApiKey, where: api_key.id == ^id and api_key.user_id == ^user.id)

    case Repo.delete_all(query) do
      {1, _} -> :ok
      {0, _} -> {:error, :not_found}
    end
  end

  @spec find_api_key(String.t()) :: {:ok, Auth.ApiKey.t()} | {:error, :invalid_api_key}
  def find_api_key(raw_key) do
    hashed_key = Auth.ApiKey.do_hash(raw_key)

    query =
      from(api_key in Auth.ApiKey,
        join: user in assoc(api_key, :user),
        where: api_key.key_hash == ^hashed_key,
        preload: [user: user]
      )

    if found = Repo.one(query) do
      {:ok, found}
    else
      {:error, :invalid_api_key}
    end
  end

  defp rate_limit_key(%Auth.User{id: id}), do: id
  defp rate_limit_key(%Plug.Conn{} = conn), do: PlausibleWeb.RemoteIP.get(conn)
end
