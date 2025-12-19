defmodule Plausible.Segments.Segment do
  @moduledoc """
  Schema for segments. Segments are saved filter combinations.
  """
  use Plausible
  use Ecto.Schema
  import Ecto.Changeset
  alias Plausible.Stats.{ApiQueryParser, QueryBuilder, ParsedQueryParams}

  @segment_types [:personal, :site]

  @type t() :: %__MODULE__{}

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
    |> validate_length(:name, count: :bytes, min: 1, max: 255)
    |> foreign_key_constraint(:site_id)
    |> foreign_key_constraint(:owner_id)
    |> validate_only_known_properties_present()
    |> validate_segment_data_filters()
    |> validate_segment_data_labels()
    |> validate_json_byte_length(:segment_data, max: 5 * 1024)
  end

  defp validate_only_known_properties_present(%Ecto.Changeset{} = changeset) do
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

  defp validate_segment_data_filters(%Ecto.Changeset{} = changeset) do
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

  defp validate_segment_data_labels(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :segment_data) do
      %{"labels" => labels} when not is_map(labels) ->
        add_error(changeset, :segment_data, "property \"labels\" must be map or nil")

      _ ->
        changeset
    end
  end

  defp validate_json_byte_length(%Ecto.Changeset{} = changeset, field_key, opts) do
    field = get_field(changeset, field_key)
    max = Keyword.get(opts, :max, 0)

    if :erlang.byte_size(Jason.encode!(field)) > max do
      add_error(changeset, field_key, "should be at most %{count} byte(s)", count: max)
    else
      changeset
    end
  end

  def validate_segment_data_if_exists(
        %Plausible.Site{} = _site,
        nil = _segment_data,
        _restricted_depth?
      ),
      do: :ok

  def validate_segment_data_if_exists(%Plausible.Site{} = site, segment_data, restricted_depth?) do
    validate_segment_data(site, segment_data, restricted_depth?)
  end

  @spec validate_segment_data(Plausible.Site.t(), map(), boolean()) ::
          :ok | {:error, {:invalid_filters, String.t()}}
  def validate_segment_data(%Plausible.Site{} = site, %{"filters" => filters}, restricted_depth?) do
    with {:ok, parsed_filters} <- ApiQueryParser.parse_filters(filters),
         {:ok, _} <-
           QueryBuilder.build(site, %ParsedQueryParams{
             metrics: [:visitors],
             input_date_range: {:last_n_days, 7},
             filters: parsed_filters
           }),
         :ok <- maybe_validate_filters_depth(parsed_filters, restricted_depth?) do
      :ok
    else
      {:error, message} -> {:error, {:invalid_filters, message}}
    end
  end

  defp maybe_validate_filters_depth(filters, restricted_depth?)

  defp maybe_validate_filters_depth(_filters, false), do: :ok

  defp maybe_validate_filters_depth(filters, true) do
    if Enum.all?(filters, &dashboard_compatible_filter?/1) do
      :ok
    else
      {:error, "Invalid filters. Deep filters are not supported."}
    end
  end

  defp dashboard_compatible_filter?(filter) do
    case filter do
      [operation, dimension, _clauses] when is_atom(operation) and is_binary(dimension) -> true
      [:has_not_done, _] -> true
      _ -> false
    end
  end
end

defimpl Jason.Encoder, for: Plausible.Segments.Segment do
  def encode(%Plausible.Segments.Segment{} = segment, opts) do
    %{
      id: segment.id,
      name: segment.name,
      type: segment.type,
      segment_data: segment.segment_data,
      owner_id: segment.owner_id,
      owner_name: if(is_nil(segment.owner_id), do: nil, else: segment.owner.name),
      inserted_at: segment.inserted_at,
      updated_at: segment.updated_at
    }
    |> Jason.Encode.map(opts)
  end
end
