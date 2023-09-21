defmodule Plausible.Repo.Migrations.ChangeAllowedEventPropsType do
  use Ecto.Migration

  def change do
    alter table("sites") do
      modify :allowed_event_props, {:array, :"varchar(300)"},
        null: true,
        from: {{:array, :string}, null: true}
    end
  end
end
