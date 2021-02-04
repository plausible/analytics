defmodule Plausible.Auth.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @required [:user_id, :key, :name]
  schema "api_keys" do
    field :name, :string
    field :key, :string, virtual: true
    field :key_hash, :string
    field :key_prefix, :string

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(schema, attrs \\ %{}) do
    schema
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> process_key
  end

  def process_key(%{errors: [], changes: changes} = changeset) do
    hash =
      :crypto.hash(:sha256, [secret_key_base(), changes[:key]])
      |> Base.encode16()
      |> String.downcase()

    prefix = binary_part(changes[:key], 0, 6)
    change(changeset, key_hash: hash, key_prefix: prefix)
  end

  def process_key(changeset), do: changeset

  defp secret_key_base() do
    Application.get_env(:plausible, PlausibleWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end
end
