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
    :team_id,
    :last_used_at,
    :client_name
  ]

  schema "oauth_access_tokens" do
    field :access_token_hash, :string
    field :access_token_prefix, :string
    field :refresh_token_hash, :string
    field :refresh_token_prefix, :string
    field :client_id, :string
    field :client_name, :string
    field :scopes, {:array, :string}, default: []
    field :resource, :string
    field :access_token_expires_at, :utc_datetime_usec
    field :refresh_token_expires_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec

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

  @spec last_used_humanize(t()) :: String.t()
  def last_used_humanize(%__MODULE__{last_used_at: nil}), do: "Not yet"

  def last_used_humanize(%__MODULE__{last_used_at: last_used_at}) do
    diff = DateTime.diff(DateTime.utc_now(), last_used_at, :minute)

    cond do
      diff < 5 -> "Just recently"
      diff < 30 -> "Several minutes ago"
      diff < 70 -> "An hour ago"
      diff < 24 * 60 -> "Hours ago"
      diff < 24 * 60 * 2 -> "Yesterday"
      diff < 24 * 60 * 7 -> "Sometime this week"
      true -> "Long time ago"
    end
  end
end
