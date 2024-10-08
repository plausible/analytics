defmodule Plausible.Segment do
  @moduledoc """
  Schema for segments. Segments are saved filter combinations.
  """
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :personal,
             :segment_data,
             :owner_id,
             :inserted_at,
             :updated_at
           ]}

  schema "segments" do
    field :name, :string
    field :segment_data, :map
    field :personal, :boolean
    belongs_to :owner, Plausible.Auth.User, foreign_key: :owner_id
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [
      :name,
      :segment_data,
      :site_id,
      :personal,
      :owner_id
    ])
    |> validate_required([:name, :segment_data, :site_id, :personal, :owner_id])
    |> foreign_key_constraint(:site_id)
    |> foreign_key_constraint(:owner_id)
    |> validate_segment_data()
  end

  defp validate_segment_data(changeset) do
    case get_field(changeset, :segment_data) do
      %{"filters" => filters} when is_list(filters) ->
        changeset

      _ ->
        add_error(changeset, :segment_data, "must contain property \"filters\" with array value")
    end
  end
end
