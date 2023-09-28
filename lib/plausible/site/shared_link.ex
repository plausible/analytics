defmodule Plausible.Site.SharedLink do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  schema "shared_links" do
    belongs_to :site, Plausible.Site
    field :name, :string
    field :slug, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    timestamps()
  end

  def changeset(link, attrs \\ %{}) do
    link
    |> cast(attrs, [:slug, :password, :name])
    |> validate_required([:slug, :name])
    |> unique_constraint(:slug)
    |> unique_constraint(:name, name: :shared_links_site_id_name_index)
    |> hash_password()
  end

  defp hash_password(link) do
    case link.changes[:password] do
      nil ->
        link

      password ->
        hash = Plausible.Auth.Password.hash(password)
        change(link, password_hash: hash)
    end
  end
end
