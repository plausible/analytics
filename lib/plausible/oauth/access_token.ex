defmodule Plausible.OAuth.AccessToken do
  @moduledoc """
  An OAuth 2.1 access token paired with its (optional) refresh token in a single
  row. Refreshing rotates the row in place: new access/refresh hashes replace the
  previous ones.

  Only hashes and short, non-sensitive prefixes are persisted.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required [
    :access_token_hash,
    :access_token_prefix,
    :client_id,
    :access_token_expires_at,
    :user_id
  ]
  @optional [
    :refresh_token_hash,
    :refresh_token_prefix,
    :refresh_token_expires_at,
    :scopes,
    :resource,
    :team_id
  ]

  schema "oauth_access_tokens" do
    field :access_token_hash, :string
    field :access_token_prefix, :string
    field :refresh_token_hash, :string
    field :refresh_token_prefix, :string
    field :client_id, :string
    field :scopes, {:array, :string}, default: []
    field :resource, :string
    field :access_token_expires_at, :utc_datetime_usec
    field :refresh_token_expires_at, :utc_datetime_usec

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:access_token_hash)
    |> unique_constraint(:refresh_token_hash)
  end
end
