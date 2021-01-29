defmodule Plausible.Auth.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @required [:user_id, :key]
  schema "api_keys" do
    field :key, :string, virtual: true
    field :key_hash, :string
    field :key_prefix, :string

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end
end
