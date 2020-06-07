defmodule Plausible.Repo.Migrations.MakeCookieFieldsNonRequired do
  use Ecto.Migration

  def up do
    alter table(:events) do
      modify :new_visitor, :bool, null: true
      modify :user_id, :binary_id, null: true
    end
  end

  def down do
  end
end
