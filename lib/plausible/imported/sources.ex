defmodule Plausible.Imported.Sources do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_sources" do
    field :domain, :string
    field :timestamp, :naive_datetime
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
        :domain,
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
      :domain,
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
      ref = "https://" <> ref

      case RefInspector.parse(ref).source do
        :unknown ->
          uri = URI.parse(String.trim(ref))

          if right_uri?(uri) do
            String.replace_leading(uri.host, "www.", "")
          end

        source ->
          source
      end
    end
  end

  defp right_uri?(%URI{host: nil}), do: false

  defp right_uri?(%URI{host: host, scheme: scheme})
       when scheme in ["http", "https"] and byte_size(host) > 0,
       do: true

  defp right_uri?(_), do: false
end
