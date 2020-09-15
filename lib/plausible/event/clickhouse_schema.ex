defmodule Plausible.ClickhouseEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "events" do
    field :name, :string
    field :domain, :string
    field :hostname, :string
    field :pathname, :string
    field :user_id, :integer
    field :session_id, :integer

    field :referrer, :string, default: ""
    field :referrer_source, :string, default: ""
    field :country_code, :string, default: ""
    field :screen_size, :string, default: ""
    field :operating_system, :string, default: ""
    field :browser, :string, default: ""

    timestamps(inserted_at: :timestamp, updated_at: false)
  end

  def changeset(pageview, attrs) do
    pageview
    |> cast(attrs, [
      :name,
      :domain,
      :hostname,
      :pathname,
      :user_id,
      :operating_system,
      :browser,
      :referrer,
      :referrer_source,
      :country_code,
      :screen_size
    ])
    |> validate_required([:name, :domain, :hostname, :pathname, :user_id])
  end
end
