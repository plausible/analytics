defmodule Plausible.Users do
  @moduledoc """
  User context
  """
  use Plausible

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo

  on_ee do
    @spec type(Auth.User.t()) :: :standard | :sso
    def type(user) do
      user.type
    end
  else
    @spec type(Auth.User.t()) :: :standard
    def type(_user), do: :standard
  end

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
