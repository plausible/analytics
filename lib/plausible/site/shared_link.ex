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

  def changeset(link, attrs \\ %{}, opts \\ []) do
    link
    |> cast(attrs, [:slug, :password, :name])
    |> validate_required([:slug, :name])
    |> validate_special_name(opts)
    |> unique_constraint(:slug)
    |> unique_constraint(:name, name: :shared_links_site_id_name_index)
    |> hash_password()
  end

  defp validate_special_name(changeset, opts) do
    name = get_change(changeset, :name)

    if name not in Plausible.Sites.shared_link_special_names() ||
         Keyword.get(opts, :skip_special_name_check?, false) do
      changeset
    else
      changeset |> add_error(:name, "This name is reserved. Please choose another one")
    end
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
