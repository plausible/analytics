defmodule Plausible.Repo.Migrations.AddRolesToMemberships do
  use Ecto.Migration

  def change do

    alter table(:site_memberships) do
      add(:role, :string, default: "admin", null: false)
    end
  end
end
