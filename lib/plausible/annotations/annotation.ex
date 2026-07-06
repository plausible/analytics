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
    field :date, :date, virtual: true
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
    |> changeset(attrs, site.timezone)
    |> put_assoc(:site, site)
    |> put_assoc(:owner, owner)
  end

  def update_changeset(annotation, attrs, owner) do
    annotation
    |> changeset(attrs, annotation.site.timezone)
    |> put_assoc(:owner, owner)
  end

  def changeset(annotation, attrs, site_timezone) do
    annotation
    |> cast(attrs, [:note, :type])
    |> cast(attrs, [:date, :datetime, :granularity], force_changes: true)
    |> validate_required([:note, :type, :granularity])
    |> validate_length(:note, count: :bytes, min: 1, max: 255)
    |> maybe_coerce_naive_datetime(site_timezone)
    |> coerce_datetime()
  end

  # If `datetime` is a naive ISO 8601 string (no UTC offset or Z suffix), interpret
  # it as a local time in the site's timezone and convert to UTC before the changeset
  # runs. This lets callers supply times in their local context without manually
  # computing offsets.
  #
  # DST edge cases:
  #   - gap (spring-forward): the missing hour is resolved to just-after the gap
  #   - ambiguous (fall-back): the earlier of the two possibilities is used
  #
  # All other `datetime` values (bare dates, full UTC strings, invalid strings) pass
  # through unchanged and are handled downstream by the changeset.
  defp maybe_coerce_naive_datetime(changeset, timezone) do
    with false <- is_nil(get_change(changeset, :datetime)),
         dt when is_binary(dt) <- changeset.params["datetime"],
         {:error, _} <- DateTime.from_iso8601(dt),
         {:ok, naive_dt} <- NaiveDateTime.from_iso8601(dt) do
      utc_dt =
        case DateTime.from_naive(naive_dt, timezone) do
          {:ok, local_dt} -> DateTime.shift_zone!(local_dt, "Etc/UTC")
          {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
          {:gap, _just_before, just_after} -> DateTime.shift_zone!(just_after, "Etc/UTC")
        end

      force_change(changeset, :datetime, utc_dt)
    else
      _ -> changeset
    end
  end

  defp coerce_datetime(%{valid?: true} = changeset) do
    granularity = get_change(changeset, :granularity)
    datetime = get_change(changeset, :datetime)
    date = get_change(changeset, :date)

    case coerce_for_granularity(granularity, date, datetime) do
      {:ok, %DateTime{} = utc_dt} ->
        put_change(changeset, :datetime, utc_dt)

      {:error, :not_supplied, field} ->
        add_error(changeset, field, "must be supplied for chosen granularity")

      {:error, :both_set} ->
        add_error(changeset, :granularity, "expects either date or datetime to be set")

      :skip ->
        changeset
    end
  end

  defp coerce_datetime(changeset), do: changeset

  defp coerce_for_granularity(:date, %Date{} = date, nil),
    do: {:ok, serialize_date_granularity_datetime(date)}

  defp coerce_for_granularity(:minute, nil, %DateTime{} = dt),
    do: {:ok, dt}

  defp coerce_for_granularity(:date, nil, _),
    do: {:error, :not_supplied, :date}

  defp coerce_for_granularity(:minute, _, nil),
    do: {:error, :not_supplied, :datetime}

  defp coerce_for_granularity(granularity, _date, _datetime)
       when granularity in [:date, :minute],
       do: {:error, :both_set}

  defp coerce_for_granularity(_granularity, _date, _datetime), do: :skip

  def serialize_date_granularity_datetime(%Date{} = date),
    do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")

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

  defp parse_date_granularity_datetime(%DateTime{} = datetime),
    do: DateTime.to_date(datetime)
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
