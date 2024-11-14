defmodule Plausible.Segment do
  @moduledoc """
  Schema for segments. Segments are saved filter combinations.
  """
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @segment_types [:personal, :site]

  @type t() :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :type,
             :segment_data,
             :owner_id,
             :inserted_at,
             :updated_at
           ]}

  schema "segments" do
    field :name, :string
    field :type, Ecto.Enum, values: @segment_types
    field :segment_data, :map

    # owner ID can be null (aka segment is dangling) when the original owner is deassociated from the site
    # the segment is dangling until another user edits it: the editor becomes the new owner
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
      :type,
      :owner_id
    ])
    |> validate_required([:name, :segment_data, :site_id, :type, :owner_id])
    |> foreign_key_constraint(:site_id)
    |> foreign_key_constraint(:owner_id)
    |> validate_only_known_properties_present()
    |> validate_segment_data_filters()
    |> validate_segment_data_labels()
  end

  defp validate_only_known_properties_present(changeset) do
    case get_field(changeset, :segment_data) do
      segment_data when is_map(segment_data) ->
        if Enum.any?(Map.keys(segment_data) -- ["filters", "labels"]) do
          add_error(
            changeset,
            :segment_data,
            "must not contain any other property except \"filters\" and \"labels\""
          )
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_segment_data_filters(changeset) do
    case get_field(changeset, :segment_data) do
      %{"filters" => filters} when is_list(filters) and length(filters) > 0 ->
        changeset

      _ ->
        add_error(
          changeset,
          :segment_data,
          "property \"filters\" must be an array with at least one member"
        )
    end
  end

  defp validate_segment_data_labels(changeset) do
    case get_field(changeset, :segment_data) do
      %{"labels" => labels} when not is_map(labels) ->
        add_error(changeset, :segment_data, "property \"labels\" must be map or nil")

      _ ->
        changeset
    end
  end
end
