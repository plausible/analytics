defmodule Plausible.ClickhouseRepo.Migrations.AddUtmContentAndTerm do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :utm_content, :string
      add :utm_term, :string
    end

    alter table(:sessions) do
      add :utm_content, :string
      add :utm_term, :string
    end
  end
end
