defmodule Plausible.Repo.Migrations.CascadeSegmentOwnerDeletion do
  use Ecto.Migration

  def change do
    drop constraint(:segments, "segments_owner_id_fkey")

    alter table(:segments) do
      modify :owner_id, references(:users, on_delete: :nilify_all), null: true
    end
  end
end
