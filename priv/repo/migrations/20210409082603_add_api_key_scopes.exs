defmodule Plausible.Repo.Migrations.AddApiKeyScopes do
  use Ecto.Migration

  def up do
    alter table(:api_keys) do
      add :scopes, {:array, :text}
    end

    execute "UPDATE api_keys SET scopes='{stats:read:*}'"

    alter table(:api_keys) do
      modify :scopes, {:array, :text}, null: false
    end

    # https://stackoverflow.com/a/4059785
    create index(:api_keys, [:scopes], using: "GIN")
  end

  def down do
    alter table(:api_keys) do
      remove :scopes
    end
  end
end
