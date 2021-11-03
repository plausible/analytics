defmodule Plausible.Site.GoogleAuth do
  use Ecto.Schema
  import Ecto.Changeset

  schema "google_auth" do
    field :email, :string
    field :property, :string
    field :refresh_token, :string
    field :access_token, :string
    field :expires, :naive_datetime
    field :search_console, :boolean
    field :analytics, :boolean
    field :view_id, :string

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(auth, attrs \\ %{}) do
    auth
    |> cast(attrs, [
      :refresh_token,
      :access_token,
      :expires,
      :email,
      :user_id,
      :site_id,
      :search_console,
      :analytics
    ])
    |> validate_required([
      :refresh_token,
      :access_token,
      :expires,
      :email,
      :user_id,
      :site_id,
      :search_console
    ])
    |> unique_constraint(:site)
  end

  def update(auth, attrs \\ %{}) do
    auth
    |> cast(attrs, [:property, :view_id])
  end
end
