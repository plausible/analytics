defmodule Plausible.Repo.Migrations.RemoveGoogleAnalyticsImportsJobs do
  use Ecto.Migration

  def up do
    execute "DELETE FROM oban_jobs WHERE queue = 'google_analytics_imports'"
  end

  def down do
  end
end
