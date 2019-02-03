defmodule Plausible.Site do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sites" do
    field :domain, :string
    field :timezone, :string

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:domain, :timezone])
    |> validate_required([:domain, :timezone])
    |> unique_constraint(:domain)
    |> clean_domain
  end

  defp clean_domain(changeset) do
    clean_domain = (get_field(changeset, :domain) || "")
                   |> String.trim
                   |> String.replace_leading("http://", "")
                   |> String.replace_leading("https://", "")
                   |> String.replace_leading("www.", "")
                   |> String.replace_trailing("/", "")
                   |> String.downcase()

    change(changeset, %{
      domain: clean_domain
    })
  end
end
