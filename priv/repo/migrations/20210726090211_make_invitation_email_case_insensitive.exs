defmodule Plausible.Repo.Migrations.MakeInvitationEmailCaseInsensitive do
  use Ecto.Migration

  def change do
    alter table(:invitations) do
      modify :email, :citext, null: false
    end
  end
end
