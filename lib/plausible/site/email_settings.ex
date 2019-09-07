defmodule Plausible.Site.EmailSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "email_settings" do
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(settings, attrs \\ %{}) do
    settings
    |> cast(attrs, [:site_id])
    |> validate_required([:site_id])
    |> unique_constraint(:site)
  end
end
