defmodule Plausible.OAuth.AuthorizationCode do
  @moduledoc """
  Short-lived, single-use OAuth 2.1 authorization code.

  Only the SHA-256 hash of the code is persisted. The `client_id` is the CIMD
  URL (an HTTPS document describing the client). PKCE is mandatory: the
  `code_challenge` is captured at authorize-time and verified at token-time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @code_challenge_methods ["S256"]

  @required [
    :code_hash,
    :client_id,
    :redirect_uri,
    :code_challenge,
    :code_challenge_method,
    :expires_at,
    :user_id
  ]
  @optional [:scopes, :resource, :team_id]

  schema "oauth_authorization_codes" do
    field :code_hash, :string
    field :client_id, :string
    field :redirect_uri, :string
    field :code_challenge, :string
    field :code_challenge_method, :string
    field :scopes, {:array, :string}, default: []
    field :resource, :string
    field :expires_at, :utc_datetime_usec

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    timestamps(updated_at: false)
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:code_challenge_method, @code_challenge_methods)
    |> unique_constraint(:code_hash)
  end
end
