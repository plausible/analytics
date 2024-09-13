defmodule Plausible.Auth.UserSession do
  @moduledoc """
  Schema for storing user session data.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.Auth

  @type t() :: %__MODULE__{}

  @rand_size 32
  @timeout Duration.new!(day: 14)

  schema "user_sessions" do
    field :token, :binary
    field :device, :string
    field :last_used_at, :naive_datetime
    field :timeout_at, :naive_datetime

    belongs_to :user, Plausible.Auth.User

    timestamps(updated_at: false)
  end

  @spec timeout_duration() :: Duration.t()
  def timeout_duration(), do: @timeout

  @spec new_session(Auth.User.t(), String.t(), NaiveDateTime.t()) :: Ecto.Changeset.t()
  def new_session(user, device, now \\ NaiveDateTime.utc_now(:second)) do
    %__MODULE__{}
    |> cast(%{device: device}, [:device])
    |> generate_token()
    |> put_assoc(:user, user)
    |> touch_session(now)
  end

  @spec touch_session(t() | Ecto.Changeset.t(), NaiveDateTime.t()) :: Ecto.Changeset.t()
  def touch_session(session, now \\ NaiveDateTime.utc_now(:second)) do
    session
    |> change()
    |> put_change(:last_used_at, now)
    |> put_change(:timeout_at, NaiveDateTime.shift(now, @timeout))
  end

  defp generate_token(changeset) do
    token = :crypto.strong_rand_bytes(@rand_size)
    put_change(changeset, :token, token)
  end
end
