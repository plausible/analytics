defmodule Plausible.Auth.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @required [:user_id, :key, :name]
  @optional [:scopes]
  schema "api_keys" do
    field :name, :string
    field :scopes, {:array, :string}, default: ["stats:read:*"]

    field :key, :string, virtual: true
    field :key_hash, :string
    field :key_prefix, :string

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(schema, attrs \\ %{}) do
    schema
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> process_key
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

  defp secret_key_base() do
    Application.get_env(:plausible, PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
