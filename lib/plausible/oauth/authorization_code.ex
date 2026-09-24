defmodule Plausible.OAuth.AuthorizationCode do
  @moduledoc """
  Short-lived, single-use OAuth 2.1 authorization code.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @code_challenge_methods ["S256"]
  @code_challenge_length 43

  @required [
    :code_hash,
    :client_id,
    :redirect_uri,
    :code_challenge,
    :code_challenge_method,
    :resource,
    :scopes,
    :expires_at,
    :user_id,
    :team_id
  ]
  @optional [:client_name]

  schema "oauth_authorization_codes" do
    field :code_hash, :string
    field :client_id, :string
    field :client_name, :string
    field :redirect_uri, :string
    field :resource, :string

    field :code_challenge, :string
    field :code_challenge_method, :string
    field :scopes, {:array, :string}
    field :expires_at, :naive_datetime

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
    |> validate_length(:scopes, min: 1)
    |> validate_length(:code_challenge, is: @code_challenge_length, count: :bytes)
    |> validate_length(:client_name, max: 255)
    |> validate_length(:client_id, max: 2048, count: :bytes)
    |> validate_length(:redirect_uri, max: 2048, count: :bytes)
    |> validate_length(:resource, max: 2048, count: :bytes)
    |> unique_constraint(:code_hash)
  end
end
