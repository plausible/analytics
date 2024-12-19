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

  def validate_segment_data_if_exists(%Plausible.Site{} = _site, nil = _segment_data), do: :ok

  def validate_segment_data_if_exists(%Plausible.Site{} = site, segment_data),
    do: validate_segment_data(site, segment_data)

  def validate_segment_data(
        %Plausible.Site{} = site,
        %{"filters" => filters}
      ) do
    case build_naive_query_from_segment_data(site, filters) do
      {:ok, %Plausible.Stats.Query{filters: _filters}} ->
        :ok

      {:error, message} ->
        reformat_filters_errors(message)
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
    {:error, [~s(#/filters/0 Invalid filter "A"), ~s(#/filters/1 Invalid filter "B")]}
  """
  def reformat_filters_errors(message) do
    lines = String.split(message, "\n")

    if Enum.all?(lines, fn m -> String.starts_with?(m, "#/filters/") end) do
      {:error, lines}
    else
      {:error, message}
    end
  end
end
