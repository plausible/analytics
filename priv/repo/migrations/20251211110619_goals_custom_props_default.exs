defmodule Plausible.Repo.Migrations.GoalsCustomPropsDefault do
  use Ecto.Migration

  def change do
    alter table(:goals) do
      modify(:custom_props, :map, null: false, default: %{})
    end
  end
end
