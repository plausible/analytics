defmodule Plausible.Imported.Sources do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_sources" do
    field :site_id, :integer
    field :timestamp, :date
    field :source, :string, default: ""
    field :visitors, :integer
    field :visits, :integer
    field :bounces, :integer
    # Sum total
    field :visit_duration, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :site_id,
        :timestamp,
        :source,
        :visitors,
        :visits,
        :bounces,
        :visit_duration
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :site_id,
      :timestamp,
      :visitors,
      :visits,
      :bounces,
      :visit_duration
    ])
  end

  @search_engines %{
    "google" => "Google",
    "bing" => "Bing",
    "duckduckgo" => "DuckDuckGo"
  }

  def parse(nil), do: nil

  def parse(ref) do
    se = @search_engines[ref]

    if se do
      se
    else
      RefInspector.parse("https://" <> ref)
      |> PlausibleWeb.RefInspector.parse()
    end
  end
end
