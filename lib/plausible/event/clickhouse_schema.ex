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

    field :referrer, :string
    field :referrer_source, :string
    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string

    field :country_code, :string
    field :screen_size, :string
    field :operating_system, :string
    field :operating_system_version, :string
    field :browser, :string
    field :browser_version, :string

    field :"meta.key", {:array, :string}
    field :"meta.value", {:array, :string}

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
      :operating_system_version,
      :browser,
      :browser_version,
      :referrer,
      :referrer_source,
      :utm_medium,
      :utm_source,
      :utm_campaign,
      :country_code,
      :screen_size
    ])
    |> validate_required([:name, :domain, :hostname, :pathname, :user_id])
  end
end
