defmodule Plausible.Repo.Migrations.AddEventsReadScopeToExistingApiKeys do
  use Ecto.Migration

  def up do
    execute "UPDATE api_keys SET scopes = array_append(scopes, 'events:read:*')"
  end

  def down do
  end
end
