defmodule Plausible.Site.GoogleAuth do
  use Ecto.Schema
  import Ecto.Changeset

  schema "google_auth" do
    field :email, :string
    field :refresh_token, :string
    field :access_token, :string
    field :expires, :naive_datetime

    belongs_to :user, Plausible.Auth.User

    timestamps()
  end

  def changeset(auth, attrs \\ %{}) do
    auth
    |> cast(attrs, [:refresh_token, :access_token, :expires, :email, :user_id])
    |> validate_required([:refresh_token, :access_token, :expires, :email, :user_id])
    |> unique_constraint(:site)
  end
end
