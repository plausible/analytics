defmodule Plausible.Pageview do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pageviews" do
    field :hostname, :string
    field :pathname, :string
    field :referrer, :string
    field :user_agent, :string
    field :screen_width, :integer
    field :screen_height, :integer
    field :new_visitor, :boolean
    field :session_id, :string
    field :user_id, :string

    timestamps()
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [:hostname, :pathname, :referrer, :user_agent, :new_visitor, :screen_width, :screen_height, :session_id, :user_id])
    |> validate_required([:hostname, :pathname, :new_visitor, :session_id, :user_id])
  end

  def screen_string(pageview) do
    "#{pageview.screen_width} x #{pageview.screen_height}"
  end
end
