defmodule Plausible.Repo.Migrations.AddUserPreviousEmail do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :previous_email, :citext
    end
  end
end
