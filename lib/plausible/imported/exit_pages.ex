defmodule Plausible.Imported.ExitPages do
  use Ecto.Schema
  use Plausible.ClickhouseRepo
  import Ecto.Changeset

  @primary_key false
  schema "imported_exit_pages" do
    field :domain, :string
    field :timestamp, :naive_datetime
    field :exit_page, :string
    field :visitors, :integer
    field :exits, :integer
  end

  def new(attrs) do
    %__MODULE__{}
    |> cast(
      attrs,
      [
        :domain,
        :timestamp,
        :exit_page,
        :visitors,
        :exits
      ],
      empty_values: [nil, ""]
    )
    |> validate_required([
      :domain,
      :timestamp,
      :exit_page,
      :visitors,
      :exits
    ])
  end
end
