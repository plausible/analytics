defmodule Plausible.Users do
  @moduledoc """
  User context
  """
  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo

  @spec bump_last_seen(Auth.User.t() | pos_integer(), NaiveDateTime.t()) :: :ok
  def bump_last_seen(%Auth.User{id: user_id}, now) do
    bump_last_seen(user_id, now)
  end

  def bump_last_seen(user_id, now) do
    q = from(u in Auth.User, where: u.id == ^user_id)

    Repo.update_all(q, set: [last_seen: now])

    :ok
  end

  @spec has_email_code?(Auth.User.t()) :: boolean()
  def has_email_code?(user) do
    Auth.EmailVerification.any?(user)
  end
end
