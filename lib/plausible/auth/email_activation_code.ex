defmodule Plausible.Auth.EmailActivationCode do
  @moduledoc """
  Schema for email activation codes.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.Auth.User

  @type t() :: %__MODULE__{}

  schema "email_activation_codes" do
    field :code, :string
    field :issued_at, :naive_datetime

    belongs_to :user, User
  end

  @spec new(User.t(), NaiveDateTime.t()) :: Ecto.Changeset.t()
  def new(user, now) do
    now = NaiveDateTime.truncate(now, :second)

    %__MODULE__{}
    |> change(code: generate_code(), issued_at: now)
    |> put_assoc(:user, user)
  end

  @spec generate_code() :: String.t()
  def generate_code do
    1000..9999
    |> Enum.random()
    |> Integer.to_string()
  end
end
