defmodule Plausible.Auth.UserSession do
  @moduledoc """
  Schema for storing user session data.
  """

  use Ecto.Schema
  use Plausible

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

  @spec new_session(Auth.User.t(), String.t(), Keyword.t()) :: Ecto.Changeset.t()
  def new_session(user, device, opts \\ []) do
    now = Keyword.get(opts, :now, NaiveDateTime.utc_now(:second))
    timeout_at = Keyword.get(opts, :timeout_at, NaiveDateTime.shift(now, @timeout))

    %__MODULE__{}
    |> cast(%{device: device}, [:device])
    |> generate_token()
    |> put_assoc(:user, user)
    |> put_change(:timeout_at, timeout_at)
    |> touch_session(now)
  end

  @spec touch_session(t() | Ecto.Changeset.t(), NaiveDateTime.t()) :: Ecto.Changeset.t()
  def touch_session(session, now \\ NaiveDateTime.utc_now(:second)) do
    changeset = change(session)

    on_ee do
      case get_field(changeset, :user) do
        %{type: :sso} ->
          put_change(changeset, :last_used_at, now)

        _ ->
          changeset
          |> put_change(:last_used_at, now)
          |> put_change(:timeout_at, NaiveDateTime.shift(now, @timeout))
      end
    else
      changeset
      |> put_change(:last_used_at, now)
      |> put_change(:timeout_at, NaiveDateTime.shift(now, @timeout))
    end
  end

  defp generate_token(changeset) do
    token = :crypto.strong_rand_bytes(@rand_size)
    put_change(changeset, :token, token)
  end
end
