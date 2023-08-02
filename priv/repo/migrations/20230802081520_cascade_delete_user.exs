defmodule Plausible.Repo.Migrations.CascadeDeleteUser do
  use Ecto.Migration

  def up do
    drop(constraint(:subscriptions, "subscriptions_user_id_fkey"))

    alter table(:subscriptions) do
      modify(:user_id, references(:users, on_delete: :delete_all), null: false)
    end

    drop(constraint(:site_memberships, "site_memberships_user_id_fkey"))

    alter table(:site_memberships) do
      modify(:user_id, references(:users, on_delete: :delete_all), null: false)
    end

    drop(constraint(:google_auth, "google_auth_user_id_fkey"))

    alter table(:google_auth) do
      modify(:user_id, references(:users, on_delete: :delete_all), null: false)
    end
  end

  def down do
    drop(constraint(:subscriptions, "subscriptions_user_id_fkey"))

    alter table(:subscriptions) do
      modify(:user_id, references(:users), null: false)
    end

    drop(constraint(:site_memberships, "site_memberships_user_id_fkey"))

    alter table(:site_memberships) do
      modify(:user_id, references(:users), null: false)
    end

    drop(constraint(:google_auth, "google_auth_user_id_fkey"))

    alter table(:google_auth) do
      modify(:user_id, references(:users), null: false)
    end
  end
end
