defmodule Plausible.Repo.Migrations.SiteLegacyTimeOnPageCutoff do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :legacy_time_on_page_cutoff, :date
    end
  end
end
