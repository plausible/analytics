defmodule Plausible.Auth.TOTP.RecoveryCode do
  @moduledoc """
  Schema for TOTP recovery codes.
  """

  use Ecto.Schema

  alias Plausible.Auth

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @code_length 10

  schema "totp_recovery_codes" do
    field :code_digest, :string

    belongs_to :user, Plausible.Auth.User

    timestamps(updated_at: false)
  end

  @doc """
  Generates `count` unique recovery codes, each alphanumeric
  and #{@code_length} characters long.
  """
  @spec generate_codes(non_neg_integer()) :: [String.t()]
  def generate_codes(count) do
    Stream.repeatedly(&generate_code/0)
    |> Stream.map(&disambiguate/1)
    |> Stream.uniq()
    |> Enum.take(count)
  end

  @spec match?(t(), String.t()) :: boolean()
  def match?(recovery_code, input_code) do
    Bcrypt.verify_pass(input_code, recovery_code.code_digest)
  end

  @spec changeset(Auth.User.t(), String.t()) :: Ecto.Changeset.t()
  def changeset(user, code) do
    %__MODULE__{}
    |> change()
    |> put_assoc(:user, user)
    |> put_change(:code_digest, hash(code))
  end

  @spec changeset_to_map(Ecto.Changeset.t(), NaiveDateTime.t()) :: map()
  def changeset_to_map(changeset, now) do
    changeset
    |> apply_changes()
    |> Map.take([:user_id, :code_digest])
    |> Map.put(:inserted_at, now)
  end

  @safe_disambiguations %{
    "O" => "8",
    "I" => "7"
  }

  @doc false
  # Exposed for testing only
  def disambiguate(code) do
    String.replace(
      code,
      Map.keys(@safe_disambiguations),
      &Map.fetch!(@safe_disambiguations, &1)
    )
  end

  defp generate_code() do
    Base.encode32(:crypto.strong_rand_bytes(6), padding: false)
  end

  defp hash(code) when byte_size(code) == @code_length do
    Bcrypt.hash_pwd_salt(code)
  end
end
