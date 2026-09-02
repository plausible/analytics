defmodule Plausible.OAuth.Grant do
  @moduledoc """
  A connection between one of a user's teams and an OAuth client, together with
  the access/refresh token pair currently issued against it.

  Refreshing rewrites both credentials on the same row, so the row's id is
  stable for the life of the connection and identifies the whole token family.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required [
    :user_id,
    :team_id,
    :client_id,
    :access_token_hash,
    :access_token_hint,
    :access_token_expires_at,
    :resource,
    :refresh_token_hash,
    :refresh_token_hint,
    :refresh_token_expires_at
  ]
  @optional [
    :client_name,
    :scopes,
    :previous_refresh_token_hash,
    :rotated_at,
    :revoked_at,
    :last_used_at
  ]

  schema "oauth_grants" do
    # A CIMD URL, e.g. `https://claude.ai/oauth/claude-code-client-metadata`
    field :client_id, :string
    # Copied verbatim from the remote metadata document, e.g. `Claude Code`
    field :client_name, :string
    # The granted scopes, e.g. `["stats:read:*","sites:read:*"]`
    field :scopes, {:array, :string}, default: []
    # The resource this grant is for, e.g. `https://plausible.io/mcp`
    field :resource, :string

    field :access_token_hash, :string
    field :access_token_hint, :string
    field :access_token_expires_at, :naive_datetime

    # Every grant is issued a refresh token.
    field :refresh_token_hash, :string
    field :refresh_token_hint, :string
    field :refresh_token_expires_at, :naive_datetime

    # The refresh token displaced by the most recent rotation, and when it was
    # displaced. It's null until the grant has been rotated at least once.
    #
    # It's stored to react appropriately on seeing it presented again by a client.
    #
    # There's a short grace period, measured from `rotated_at`.
    #
    # Outside the grace period, on seeing the refresh token again, we consider it to be compromised
    # and we revoke the whole grant, locking out the one that exchanged it first
    # and the one trying to exchange it now. We can't know which one of them was malicious.
    #
    # Inside the grace period, we return the current pair again idempotently.
    # Grace is needed to prevent a connection timeout from stopping a working integration.
    field :previous_refresh_token_hash, :string
    field :rotated_at, :naive_datetime

    # Revocation is separate from time-based expiry.
    field :revoked_at, :naive_datetime

    # Needed for a "connected applications" view.
    field :last_used_at, :naive_datetime

    belongs_to :user, Plausible.Auth.User
    belongs_to :team, Plausible.Teams.Team

    timestamps()
  end

  @spec changeset(map()) :: Ecto.Changeset.t()
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:client_name, max: 255)
    |> validate_length(:client_id, max: 2048, count: :bytes)
    |> unique_constraint(:access_token_hash)
    |> unique_constraint(:refresh_token_hash)
  end
end
