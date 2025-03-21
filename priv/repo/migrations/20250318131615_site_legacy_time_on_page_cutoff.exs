defmodule Plausible.Repo.Migrations.SiteLegacyTimeOnPageCutoff do
  use Ecto.Migration
  use Plausible

  def change do
    alter table(:sites) do
      # New sites will have new time-on-page enabled by default.
      add :legacy_time_on_page_cutoff, :date,
        default: fragment("to_date('1970-01-01', 'YYYY-MM-DD')")
    end

    if Application.get_env(:plausible, :is_selfhost) do
      # On self-hosted, new time-on-page will be populated during first deploy.
      execute(
        fn ->
          repo().query!("UPDATE sites SET legacy_time_on_page_cutoff = ?", [Date.utc_today()])
        end,
        &pass/0
      )
    else
      # On cloud, existing sites will not have legacy_time_on_page_cutoff set. This will be populated by a cron instead.
      execute(
        fn -> repo().query!("UPDATE sites SET legacy_time_on_page_cutoff = NULL") end,
        &pass/0
      )
    end
  end

  defp pass(), do: nil
end
