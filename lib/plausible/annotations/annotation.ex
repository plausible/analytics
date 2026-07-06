defmodule Plausible.Annotations.Annotation do
  @moduledoc """
  Schema for annotations. Annotations are notes attached to a point on the graph.

  Annotations can have two granularities, date or minute.

  To create date granularity annotations, only the date part must be specified for `datetime` field.
  It's interpreted to be for that date, no matter what happens with the site timezone.

  Examples:
  - `{"granularity": "date", "datetime": "2026-06-30", ...}`.

  To create minute granularity annotations, the full datetime needs to be specified for `datetime` field.
  It can be set in local time, as a naive datetime string ("2026-06-29 10:00:00"), in which case it's
  interpreted as that datetime in the site's timezone and stored as that particular moment in UTC.
  Alternatively, it can be sent with TZ information ("2026-05-31T12:00:00Z", "2026-05-31T10:00:00-02:00"),
  in which case it's interpreted to be that particular moment and stored as that in UTC.

  Examples:
  - `{"granularity": "minute", "datetime": "2026-06-29 10:00:00", ...}`
  - `{"granularity": "minute", "datetime": "2026-06-29T12:00:00Z", ...}`
  """

  use Plausible
  use Ecto.Schema
  import Ecto.Changeset

  @annotation_types [:personal, :site]
  @annotation_granularities [:date, :minute]

  @type t() :: %__MODULE__{}

  schema "annotations" do
    field :note, :string
    field :type, Ecto.Enum, values: @annotation_types
    field :datetime, :utc_datetime
    field :granularity, Ecto.Enum, values: @annotation_granularities

    # owner ID can be null (aka note is dangling) when the original owner is deassociated from the site
    # the note is dangling until another user edits it: the editor becomes the new owner
    belongs_to :owner, Plausible.Auth.User, foreign_key: :owner_id
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def create_changeset(attrs, site, owner) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_assoc(:site, site)
    |> put_assoc(:owner, owner)
  end

  def update_changeset(annotation, attrs, owner) do
    annotation
    |> changeset(attrs)
    |> put_assoc(:owner, owner)
  end

  def changeset(annotation, attrs) do
    attrs = stringify_keys(attrs)
    {attrs, invalid_datetime_for_granularity?} = coerce_datetime(attrs)

    annotation
    |> cast(attrs, [:note, :type, :datetime, :granularity])
    |> validate_required([:note, :type, :datetime, :granularity])
    |> validate_length(:note, count: :bytes, min: 1, max: 255)
    |> validate_datetime_supplied_on_granularity_change()
    |> maybe_add_datetime_error(invalid_datetime_for_granularity?)
  end

  defp stringify_keys(%{} = params) do
    Map.new(params, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
    end)
  end

  defp coerce_datetime(attrs) do
    granularity = normalize_granularity(attrs["granularity"])

    case coerce_for_granularity(granularity, attrs["datetime"]) do
      {:ok, %DateTime{} = utc_dt} -> {Map.put(attrs, "datetime", utc_dt), false}
      :skip -> {attrs, false}
      :invalid -> {Map.delete(attrs, "datetime"), true}
    end
  end

  defp normalize_granularity(:date), do: :date
  defp normalize_granularity("date"), do: :date
  defp normalize_granularity(:minute), do: :minute
  defp normalize_granularity("minute"), do: :minute
  defp normalize_granularity(other), do: other

  # nil datetime will be caught by validate_required step
  defp coerce_for_granularity(_granularity, nil), do: :skip

  defp coerce_for_granularity(:date, %Date{} = date),
    do: {:ok, serialize_date_granularity_datetime(date)}

  defp coerce_for_granularity(:date, <<_::binary-size(10)>> = str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> {:ok, serialize_date_granularity_datetime(date)}
      _ -> :invalid
    end
  end

  defp coerce_for_granularity(:minute, %DateTime{} = dt),
    do: {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}

  defp coerce_for_granularity(:minute, str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> {:ok, DateTime.shift_zone!(dt, "Etc/UTC")}
      _ -> :invalid
    end
  end

  defp coerce_for_granularity(granularity, _datetime) when granularity in [:date, :minute],
    do: :invalid

  defp coerce_for_granularity(_granularity, _datetime), do: :skip

  defp maybe_add_datetime_error(changeset, false), do: changeset

  defp maybe_add_datetime_error(changeset, true),
    do: add_error(changeset, :datetime, "is invalid for granularity")

  defp validate_datetime_supplied_on_granularity_change(changeset) do
    with {:ok, _new_granularity} <- fetch_change(changeset, :granularity),
         false <- is_nil(changeset.data.granularity),
         :error <- fetch_change(changeset, :datetime) do
      add_error(changeset, :datetime, "must be supplied when granularity changes")
    else
      _ -> changeset
    end
  end

  def serialize_date_granularity_datetime(%Date{} = date),
    do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

  defp parse_date_granularity_datetime(%DateTime{} = datetime),
    do: DateTime.to_date(datetime)

  # Used only by encoder
  @doc false
  def localize(annotation, timezone)

  # For date granularity, the UTC date component IS the annotation date — callers
  # store UTC midnight of their intended local date, so no timezone shift is needed.
  # Return just the Date so the JSON response matches the bare-date input format.
  def localize(%{granularity: :date} = annotation, _timezone) do
    %{annotation | datetime: parse_date_granularity_datetime(annotation.datetime)}
  end

  # For minute granularity, shift the stored UTC moment to the site's local timezone
  # and strip the offset so the response is a naive local time string.
  def localize(%{granularity: :minute} = annotation, timezone) do
    naive_local =
      annotation.datetime
      |> DateTime.shift_zone!(timezone)
      |> DateTime.to_naive()

    %{annotation | datetime: naive_local}
  end
end

defimpl Jason.Encoder, for: Plausible.Annotations.Annotation do
  def encode(annotation, opts) do
    %{
      id: annotation.id,
      note: annotation.note,
      type: annotation.type,
      datetime: annotation.datetime,
      granularity: annotation.granularity,
      owner_id: annotation.owner_id,
      owner_name: if(annotation.owner_id, do: annotation.owner.name),
      inserted_at: annotation.inserted_at,
      updated_at: annotation.updated_at
    }
    |> Plausible.Annotations.Annotation.localize(annotation.site.timezone)
    |> Jason.Encode.map(opts)
  end
end
