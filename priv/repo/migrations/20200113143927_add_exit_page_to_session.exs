defmodule Plausible.Repo.Migrations.AddExitPageToSession do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :exit_page, :text
    end
  end
end
