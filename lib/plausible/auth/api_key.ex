defmodule Plausible.Auth.ApiKey do
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required [:user_id, :name]
  @optional [:key, :scopes]

  @hourly_request_limit on_ee(do: 600, else: 1_000_000)

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

  def hourly_request_limit(), do: @hourly_request_limit

  def changeset(struct, team, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> maybe_put_key()
    |> process_key()
    |> maybe_put_team(team)
    |> unique_constraint(:key_hash, error_key: :key)
    |> unique_constraint([:team_id, :user_id], error_key: :team)
  end

  # NOTE: needed only because of lacking introspection in Kaffy
  def changeset(struct, attrs) do
    changeset(struct, nil, attrs)
  end

  def update(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, [:name, :user_id, :scopes])
    |> validate_required([:user_id, :name])
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

  defp maybe_put_team(changeset, nil), do: changeset

  defp maybe_put_team(changeset, team) do
    put_assoc(changeset, :team, team)
  end

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
