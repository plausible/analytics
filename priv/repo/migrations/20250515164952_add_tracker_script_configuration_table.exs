defmodule Plausible.Repo.Migrations.AddTrackerScriptConfigurationTable do
  use Ecto.Migration

  def change do
    create table(:tracker_script_configuration, primary_key: false) do
      add :id, :string, primary_key: true
      add :installation_type, :string, null: true

      add :track_404_pages, :boolean, default: false
      add :hash_based_routing, :boolean, default: false
      add :outbound_links, :boolean, default: false
      add :file_downloads, :boolean, default: false
      add :revenue_tracking, :boolean, default: false
      add :tagged_events, :boolean, default: false
      add :form_submissions, :boolean, default: false
      add :pageview_props, :boolean, default: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:tracker_script_configuration, [:site_id])
  end
end
