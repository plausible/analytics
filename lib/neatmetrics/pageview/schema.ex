defmodule Neatmetrics.Pageview do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pageviews" do
    field :hostname, :string
    field :pathname, :string
    field :referrer, :string
    field :user_agent, :string
    field :screen_width, :integer
    field :screen_height, :integer

    timestamps()
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [:hostname, :pathname, :referrer, :user_agent, :screen_width, :screen_height])
    |> validate_required([:hostname, :pathname])
  end
end
