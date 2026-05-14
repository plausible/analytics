defmodule Plausible.Annotations.Annotation do
  @moduledoc """
  Schema for annotations. Annotations are notes attached to a point on the graph.

  `datetime` stores a UTC moment. The local date/time shown to the user is derived
  by converting it to the site's configured timezone at display time. If the site's
  timezone changes, the local representation recalculates automatically — the UTC
  moment is the ground truth.

  `granularity` controls how much precision is displayed:
    - `:date`   — show only the local date (whole-day annotation).
                  Callers should supply UTC midnight of the intended local date.
    - `:minute` — show local date and HH:MM (specific-time annotation).
                  Callers supply the exact UTC moment (natural for deployment pipelines).
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

  def changeset(annotation, attrs) do
    annotation
    |> cast(maybe_coerce_datetime(attrs), [
      :note,
      :site_id,
      :type,
      :owner_id,
      :datetime,
      :granularity
    ])
    |> validate_required([:note, :site_id, :type, :owner_id, :datetime, :granularity])
    |> validate_length(:note, count: :bytes, min: 1, max: 255)
    |> foreign_key_constraint(:site_id)
    |> foreign_key_constraint(:owner_id)
  end

  # When granularity is "date" and datetime is a 10-byte bare date string
  # (e.g. "2026-01-04"), append "T00:00:00Z" so Ecto can cast it as utc_datetime.
  # Date.from_iso8601/1 validates it is a real calendar date (rejects "2026-13-45").
  # Full datetime strings and all other inputs pass through untouched.
  defp maybe_coerce_datetime(%{"granularity" => "date", "datetime" => dt} = attrs)
       when is_binary(dt) and byte_size(dt) == 10 do
    case Date.from_iso8601(dt) do
      {:ok, _date} -> Map.put(attrs, "datetime", dt <> "T00:00:00Z")
      _ -> attrs
    end
  end

  defp maybe_coerce_datetime(attrs), do: attrs
end

defimpl Jason.Encoder, for: Plausible.Annotations.Annotation do
  def encode(%Plausible.Annotations.Annotation{} = annotation, opts) do
    %{
      id: annotation.id,
      note: annotation.note,
      type: annotation.type,
      datetime: annotation.datetime,
      granularity: annotation.granularity,
      owner_id: annotation.owner_id,
      owner_name: if(is_nil(annotation.owner_id), do: nil, else: annotation.owner.name),
      inserted_at: annotation.inserted_at,
      updated_at: annotation.updated_at
    }
    |> Jason.Encode.map(opts)
  end
end
