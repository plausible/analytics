defmodule Plausible.Imported.Source do
  @moduledoc false
  use Ecto.Schema

  @primary_key false
  schema "imported_sources" do
    field :site_id, Ch, type: "UInt64"
    field :import_id, Ch, type: "UInt64"
    field :date, :date
    field :source, :string
    field :channel, Ch, type: "LowCardinality(String)"
    field :referrer, :string
    field :utm_source, :string
    field :utm_medium, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string
    field :visitors, Ch, type: "UInt64"
    field :visits, Ch, type: "UInt64"
    field :visit_duration, Ch, type: "UInt64"
    field :pageviews, Ch, type: "UInt64"
    field :bounces, Ch, type: "UInt32"
  end
end
