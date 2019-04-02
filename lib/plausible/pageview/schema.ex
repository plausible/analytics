defmodule Plausible.Pageview do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pageviews" do
    field :hostname, :string
    field :pathname, :string
    field :referrer, :string
    field :user_agent, :string
    field :screen_width, :integer
    field :new_visitor, :boolean
    field :session_id, :string
    field :user_id, :string
    field :country_code, :string

    field :operating_system, :string
    field :browser, :string
    field :referrer_source, :string

    timestamps()
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [:hostname, :pathname, :referrer, :user_agent, :new_visitor, :screen_width, :session_id, :user_id, :operating_system, :browser, :referrer_source, :country_code])
    |> validate_required([:hostname, :pathname, :new_visitor, :session_id, :user_id])
  end
end
