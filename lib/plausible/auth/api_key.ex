defmodule Plausible.Auth.ApiKey do
  @moduledoc """
  There are two kinds of API keys, legacy API keys and team-scoped API keys.

  Legacy keys have `team` / `team_id` set to `nil`.

  Legacy Stats API keys can be used to
    - access the stats of sites of any team of the user,
    - access the stats of sites that they are a guest of,
    - access data about the sites of the teams that they belong to,
    - access data about sites that they are a guest of.

  Legacy Sites API keys allow the above and additionally
    - to provision sites for any team of the user,
    - to configure sites for any team of the user,
    - to configure sites that they are a guest of.

  It's not possible to create legacy keys any more through the UI.

  Team-scoped keys have `team` / `team_id` set to a team.

  Team-scoped Stats API keys can be used to
    - access the stats of sites of that team,
    - access data about the sites of that team.

  Team-scoped Sites API keys allow the above and additionally
    - to provision sites for that team,
    - to configure sites for that team.

  Only team members can use team-scoped keys.
  """

  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required [:user_id, :name]
  @optional [:key, :scopes]

  @default_hourly_request_limit_per_team on_ee(do: 600, else: 1_000_000)

  schema "api_keys" do
    field :name, :string
    field :scopes, {:array, :string}, default: ["stats:read:*"]

    field :type, :string, virtual: true

    field :key, :string, virtual: true
    field :key_hash, :string
    field :key_prefix, :string

    belongs_to :team, Plausible.Teams.Team
    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  defp config(), do: Application.fetch_env!(:plausible, __MODULE__)

  def default_hourly_request_limit(), do: @default_hourly_request_limit_per_team
  def limit_key(team), do: "api_request:team:#{team.identifier}"

  def legacy_hourly_request_limit() do
    config()
    |> Keyword.fetch!(:legacy_per_user_hourly_request_limit)
  end

  def legacy_limit_key(user), do: "api_request:legacy_user:#{user.id}"

  def burst_request_limit(),
    do:
      config()
      |> Keyword.fetch!(:burst_request_limit)

  def burst_period_seconds(),
    do:
      config()
      |> Keyword.fetch!(:burst_period_seconds)

  def changeset(struct, team, attrs) when not is_nil(team) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> maybe_put_key()
    |> process_key()
    |> put_assoc(:team, team)
    |> unique_constraint(:key_hash, error_key: :key)
    |> unique_constraint([:team_id, :user_id], error_key: :team)
  end

  def do_hash(key) do
    :crypto.hash(:sha256, [secret_key_base(), key])
    |> Base.encode16()
    |> String.downcase()
  end

  def process_key(%{errors: [], changes: changes} = changeset) do
    prefix = binary_part(changes[:key], 0, 6)

    change(changeset,
      key_hash: do_hash(changes[:key]),
      key_prefix: prefix
    )
  end

  def process_key(changeset), do: changeset

  defp maybe_put_key(changeset) do
    if get_change(changeset, :key) do
      changeset
    else
      key = :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 64)
      put_change(changeset, :key, key)
    end
  end

  defp secret_key_base() do
    Application.get_env(:plausible, PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
