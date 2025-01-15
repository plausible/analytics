defmodule Plausible.Segments.Segment do
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

  def validate_segment_data_if_exists(%Plausible.Site{} = site, segment_data, restricted_depth?),
    do: validate_segment_data(site, segment_data, restricted_depth?)

  def validate_segment_data(
        %Plausible.Site{} = site,
        %{"filters" => filters},
        restricted_depth?
      ) do
    with {:ok, %Plausible.Stats.Query{filters: parsed_filters}} <-
           build_naive_query_from_segment_data(site, filters),
         :ok <- maybe_validate_filters_depth(parsed_filters, restricted_depth?) do
      :ok
    else
      {:error, message} ->
        reformat_filters_errors(message)

      :error_deep_filters_not_supported ->
        reformat_filters_errors("Invalid filters. Deep filters are not supported.")
    end
  end

  @doc """
    This function builds a simple query using the filters from Plausibe.Segment.segment_data
    to test whether the filters used in the segment stand as legitimate query filters.
    If they don't, it indicates an error with the filters that must be passed to the client,
    so they could reconfigure the filters.
  """
  def build_naive_query_from_segment_data(%Plausible.Site{} = site, filters),
    do:
      Plausible.Stats.Query.build(
        site,
        :internal,
        %{
          "site_id" => site.domain,
          "metrics" => ["visitors"],
          "date_range" => "7d",
          "filters" => filters
        },
        %{}
      )

  @doc """
    This function handles the error from building the naive query that is used to validate segment filters,
    collecting filter related errors into a list.
    If the error is not only about filters, the client can't do anything about the situation,
    and the error message is returned as-is.

    ### Examples
    iex> reformat_filters_errors(~s(#/metrics/0 Invalid metric "Visitors"\\n#/filters/0 Invalid filter "A"))
    {:error, ~s(#/metrics/0 Invalid metric "Visitors"\\n#/filters/0 Invalid filter "A")}

    iex> reformat_filters_errors(~s(#/filters/0 Invalid filter "A"\\n#/filters/1 Invalid filter "B"))
    {:error, {:invalid_filters, ~s(#/filters/0 Invalid filter "A"\\n#/filters/1 Invalid filter "B")}}

    iex> reformat_filters_errors("Invalid filters. Dimension `event:goal` can only be filtered at the top level.")
    {:error, {:invalid_filters, "Invalid filters. Dimension `event:goal` can only be filtered at the top level."}}
  """
  def reformat_filters_errors(message) do
    lines = String.split(message, "\n")

    if Enum.all?(lines, fn line ->
         String.starts_with?(line, "#/filters/") or String.starts_with?(line, "Invalid filters.")
       end) do
      {:error, {:invalid_filters, message}}
    else
      {:error, message}
    end
  end

  @spec maybe_validate_filters_depth([any()], boolean()) ::
          :ok | :error_deep_filters_not_supported
  defp maybe_validate_filters_depth(filters, restricted_depth?)

  defp maybe_validate_filters_depth(_filters, false), do: :ok

  defp maybe_validate_filters_depth(filters, true) do
    if Enum.all?(filters, &dashboard_compatible_filter?/1) do
      :ok
    else
      :error_deep_filters_not_supported
    end
  end

  defp dashboard_compatible_filter?(filter) do
    is_list(filter) and length(filter) === 3 and
      is_atom(Enum.at(filter, 0)) and
      is_binary(Enum.at(filter, 1)) and
      is_list(Enum.at(filter, 2))
  end
end
