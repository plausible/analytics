defmodule Plausible.Site.SharedLink do
  use Ecto.Schema
  import Ecto.Changeset

  schema "shared_links" do
    belongs_to :site, Plausible.Site
    field :slug, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    timestamps()
  end

  def changeset(link, attrs \\ %{}) do
    link
    |> cast(attrs, [:slug, :password])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
    |> hash_password()
  end

  defp hash_password(link) do
    case link.changes[:password] do
      nil -> link
      password ->
        hash = Plausible.Auth.Password.hash(password)
        change(link, password_hash: hash)
    end
  end
end
