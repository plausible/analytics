defmodule Plausible.Repo.Migrations.CreateAnnotations do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE annotation_type AS ENUM ('personal', 'site')",
      "DROP TYPE annotation_type"
    )

    execute(
      "CREATE TYPE annotation_granularity AS ENUM ('date', 'minute')",
      "DROP TYPE annotation_granularity"
    )

    # Example annotations
    #
    # id |            note             | granularity |      datetime
    # ---+-----------------------------+-------------+--------------------
    #  1 | Christmas sale              | date        | 2025-12-14 00:00:00
    #  2 | Released feature X          | minute      | 2026-05-08 14:00:00
    #
    # Depending on granularity, the datetime must be interpreted in a different way:
    #
    # For granularity "date", only the date part of the `datetime` is meaningful.
    # The annotation is on that particular calendar date, no matter the timezone.
    # We store it as midnight, 00:00:00, but we could just as well store it as 13:37:00:
    # the time must be ignored by the server.
    #
    # For granularity "time", all of the datetime is meaningful.
    # The annotation is at that particular point in time. It's stored as UTC timestamp (naive)
    # and must be shifted to the site timezone.

    create table(:annotations) do
      add :note, :string, null: false
      add :type, :annotation_type, null: false, default: "personal"
      add :datetime, :utc_datetime, null: false
      add :granularity, :annotation_granularity, null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :owner_id, references(:users, on_delete: :nilify_all), null: true

      timestamps()
    end

    create index(:annotations, [:site_id])
    create index(:annotations, [:owner_id])
  end
end
