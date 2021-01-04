defmodule Plausible.Repo.Migrations.AddThemePrefToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists(:theme, :string, default: "system")
    end
  end
end
