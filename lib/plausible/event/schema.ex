defmodule Plausible.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :name, :string
    field :hostname, :string
    field :pathname, :string
    field :new_visitor, :boolean
    field :user_id, :binary_id

    field :referrer, :string
    field :referrer_source, :string
    field :country_code, :string
    field :screen_size, :string
    field :operating_system, :string
    field :browser, :string

    timestamps(inserted_at: :timestamp, updated_at: false)
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [:hostname, :pathname, :referrer, :new_visitor, :user_id, :operating_system, :browser, :referrer_source, :country_code, :screen_size])
    |> validate_required([:hostname, :pathname, :new_visitor, :user_id])
  end
end
