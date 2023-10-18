defmodule Plausible.Plugins.API.Token do
  @moduledoc """
  Ecto schema for Plugins API Tokens.
  Tokens are stored hashed and require a description.

  Tokens are considered secret, although the Plugins API
  by nature will expose very little, if any, destructive/insecure operations.

  The raw token version is meant to be presented to the user upon creation.
  It is prefixed with a plain text identifier allowing source scanning
  for leaked secrets.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Plausible.Site

  @type t() :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "plugins_api_tokens" do
    timestamps()
    field(:token_hash, :binary)
    field(:description, :string)
    field(:hint, :string)
    field(:last_seen_at, :naive_datetime)

    belongs_to(:site, Site)
  end

  @spec generate(String.t()) :: map()
  def generate(random_bytes \\ random_bytes()) do
    raw = prefixed(random_bytes)
    hash = hash(raw)

    %{
      raw: raw,
      hash: hash
    }
  end

  @spec hash(String.t()) :: binary()
  def hash(raw) do
    :crypto.hash(:sha256, raw)
  end

  @fields [:description, :site_id]
  @required_fields [:description, :site, :token_hash, :hint]

  @spec insert_changeset(Site.t(), map(), map()) :: Ecto.Changeset.t()
  def insert_changeset(site, %{hash: hash, raw: raw}, attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> put_change(:token_hash, hash)
    |> put_change(:hint, String.slice(raw, -4, 4))
    |> put_assoc(:site, site)
    |> validate_required(@required_fields)
  end

  @doc """
  Raw tokens are prefixed so that tools like
  https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning
  can scan repositories for accidental secret commits.
  """
  def prefix() do
    case {Plausible.Release.selfhost?(), Application.get_env(:plausible, :environment)} do
      {true, _} -> "plausible-plugin-selfhost"
      {false, "prod"} -> "plausible-plugin"
      {false, env} -> "plausible-plugin-#{env}"
    end
  end

  @spec last_seen_humanize(t()) :: String.t()
  def last_seen_humanize(token) do
    diff =
      if token.last_seen_at do
        now = NaiveDateTime.utc_now()
        Timex.diff(now, token.last_seen_at, :minutes)
      end

    cond do
      is_nil(diff) -> "Not yet"
      diff < 5 -> "Just recently"
      diff < 30 -> "Several minutes ago"
      diff < 70 -> "An hour ago"
      diff < 24 * 60 -> "Hours ago"
      diff < 24 * 60 * 2 -> "Yesterday"
      diff < 24 * 60 * 7 -> "Some time this week"
      true -> "Long time ago"
    end
  end

  defp prefixed(random_bytes) do
    Enum.join([prefix(), random_bytes], "-")
  end

  defp random_bytes() do
    30 |> :crypto.strong_rand_bytes() |> Base.encode64()
  end
end
