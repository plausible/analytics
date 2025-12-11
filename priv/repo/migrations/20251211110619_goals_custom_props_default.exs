defmodule Plausible.Repo.Migrations.GoalsCustomPropsDefault do
  use Ecto.Migration

  def change do
    drop(
      unique_index(:goals, [:site_id, :event_name, :custom_props],
        where: "event_name IS NOT NULL",
        name: :goals_event_config_unique
      )
    )

    alter table(:goals) do
      remove :custom_props
      add custom_props, :map, null: false, default: %{}
    end

    create(
      unique_index(:goals, [:site_id, :event_name, :custom_props],
        where: "event_name IS NOT NULL",
        name: :goals_event_config_unique
      )
    )
  end
end
