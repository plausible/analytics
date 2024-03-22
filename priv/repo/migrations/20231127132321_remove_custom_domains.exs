defmodule Plausible.Repo.Migrations.RemoveCustomDomains do
  use Ecto.Migration

  def change do
    drop table(:custom_domains)
  end
end
