defmodule Plausible.Repo.Migrations.AddOwnerIdToSites do
  use Ecto.Migration
  import Ecto.Query

  def up do
    alter table(:sites) do
      add :owner_id, references(:users)
    end

    flush() # create owner_id column


    # # Set the owner
    from( s in Plausible.Site,
      join: sm in Plausible.Site.Membership,
      on: sm.site_id == s.id,
      join: u in Plausible.Auth.User,
      on: u.id == sm.user_id,
      select: [s.id, u.id])
      |> Plausible.Repo.all()
      |> Enum.each(fn [site_id, user_id] ->
        from(s in Plausible.Site, where: s.id == ^site_id)
        |> Plausible.Repo.update_all(
          set: [owner_id: user_id]
        )
      end)

    # add as owner id
    alter table(:sites) do
      modify :owner_id, references(:users), null: false, from: references(:users)
    end
    create index(:sites, [:id, :owner_id])
  end

  def down do
    alter table(:sites) do
      remove :owner_id
    end
  end
end
