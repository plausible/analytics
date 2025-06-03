defmodule Plausible.Auth.UserSessions do
  @moduledoc """
  Functions for interacting with user sessions.
  """

  import Ecto.Query
  alias Plausible.Auth
  alias Plausible.Repo

  @socket_id_prefix "user_sessions:"

  @spec list_for_user(Auth.User.t(), NaiveDateTime.t()) :: [Auth.UserSession.t()]
  def list_for_user(user, now \\ NaiveDateTime.utc_now(:second)) do
    Repo.all(
      from us in Auth.UserSession,
        where: us.user_id == ^user.id,
        where: us.timeout_at >= ^now,
        order_by: [desc: us.last_used_at, desc: us.id]
    )
  end

  @spec last_used_humanize(Auth.UserSession.t(), NaiveDateTime.t()) :: String.t()
  def last_used_humanize(user_session, now \\ NaiveDateTime.utc_now(:second)) do
    diff = NaiveDateTime.diff(now, user_session.last_used_at, :hour)
    diff_days = NaiveDateTime.diff(now, user_session.last_used_at, :day)

    cond do
      diff < 1 -> "Just recently"
      diff == 1 -> "1 hour ago"
      diff < 24 -> "#{diff} hours ago"
      diff < 2 * 24 -> "Yesterday"
      true -> "#{diff_days} days ago"
    end
  end

  @spec get_by_token(String.t()) :: {:ok, Auth.UserSession.t()} | {:error, :not_found}
  def get_by_token(token) do
    now = NaiveDateTime.utc_now(:second)

    last_team_subscription_query = Plausible.Teams.last_subscription_join_query()

    token_query =
      from(us in Auth.UserSession,
        inner_join: u in assoc(us, :user),
        as: :user,
        left_join: tm in assoc(u, :team_memberships),
        on: tm.role != :guest,
        left_join: t in assoc(tm, :team),
        as: :team,
        left_join: o in assoc(t, :owners),
        left_lateral_join: ts in subquery(last_team_subscription_query),
        on: true,
        where: us.token == ^token and us.timeout_at > ^now,
        order_by: t.id,
        preload: [user: {u, team_memberships: {tm, team: {t, subscription: ts, owners: o}}}]
      )

    case Repo.one(token_query) do
      %Auth.UserSession{} = user_session ->
        {:ok, user_session}

      nil ->
        {:error, :not_found}
    end
  end

  @spec create!(Auth.User.t(), String.t(), Keyword.t()) :: Auth.UserSession.t()
  def create!(user, device_name, opts \\ []) do
    user
    |> Auth.UserSession.new_session(device_name, opts)
    |> Repo.insert!()
  end

  @spec remove_by_token(String.t()) :: :ok
  def remove_by_token(token) do
    Repo.delete_all(from us in Auth.UserSession, where: us.token == ^token)
    :ok
  end

  @spec touch(Auth.UserSession.t(), NaiveDateTime.t()) :: Auth.UserSession.t()
  def touch(user_session, now \\ NaiveDateTime.utc_now(:second)) do
    if NaiveDateTime.diff(now, user_session.last_used_at, :hour) >= 1 do
      Plausible.Users.bump_last_seen(user_session.user_id, now)

      user_session
      |> Repo.preload(:user)
      |> Auth.UserSession.touch_session(now)
      |> Repo.update!(allow_stale: true)
    else
      user_session
    end
  end

  @spec revoke_by_id(Auth.User.t(), pos_integer()) :: :ok
  def revoke_by_id(user, session_id) do
    {_, tokens} =
      Repo.delete_all(
        from us in Auth.UserSession,
          where: us.user_id == ^user.id and us.id == ^session_id,
          select: us.token
      )

    case tokens do
      [token] ->
        disconnect_by_token(token)

      _ ->
        :pass
    end

    :ok
  end

  @spec revoke_all(Auth.User.t(), Keyword.t()) :: :ok
  def revoke_all(user, opts \\ []) do
    except = Keyword.get(opts, :except)

    delete_query = from us in Auth.UserSession, where: us.user_id == ^user.id, select: us.token

    delete_query =
      if except do
        where(delete_query, [us], us.id != ^except.id)
      else
        delete_query
      end

    {_count, tokens} = Repo.delete_all(delete_query)

    Enum.each(tokens, &disconnect_by_token/1)
  end

  @spec disconnect_by_token(String.t()) :: :ok
  def disconnect_by_token(token_or_socket_id) do
    socket_id =
      if String.starts_with?(token_or_socket_id, @socket_id_prefix) do
        token_or_socket_id
      else
        socket_id(token_or_socket_id)
      end

    PlausibleWeb.Endpoint.broadcast(socket_id, "disconnect", %{})
    :ok
  end

  @spec socket_id(String.t()) :: String.t()
  def socket_id(token) do
    @socket_id_prefix <> Base.url_encode64(token)
  end
end
