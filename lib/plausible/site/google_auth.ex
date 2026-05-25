defmodule Plausible.Site.GoogleAuth do
  @moduledoc """
  Struct for storing google auth token info used by search console.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "google_auth" do
    field :email, :string
    field :property, :string
    field :refresh_token, :string
    field :access_token, :string
    field :expires, :naive_datetime

    belongs_to :user, Plausible.Auth.User
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(auth, attrs \\ %{}) do
    auth
    |> cast(attrs, [:refresh_token, :access_token, :expires, :email])
    |> validate_required([:refresh_token, :access_token, :expires, :email])
    |> unique_constraint(:site)
  end

  def set_property(auth, attrs \\ %{}) do
    auth
    |> cast(attrs, [:property])
  end
end
