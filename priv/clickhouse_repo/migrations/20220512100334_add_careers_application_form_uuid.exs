defmodule Plausible.ClickhouseRepo.Migrations.AddCareersApplicationFormUUID do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add(:careers_application_form_uuid, :string)
    end
  end
end
