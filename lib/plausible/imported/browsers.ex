defmodule Plausible.Imported.Browsers do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_browsers" do
    field :site_id, :integer
    field :timestamp, :date
    field :browser, :string
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
        :browser,
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
end
