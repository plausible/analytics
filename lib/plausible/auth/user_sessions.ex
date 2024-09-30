defmodule Plausible.Auth.UserSessions do
  @moduledoc """
  Functions for interacting with user sessions.
  """

  import Ecto.Query, only: [from: 2]
  alias Plausible.Auth
  alias Plausible.Repo

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
end
