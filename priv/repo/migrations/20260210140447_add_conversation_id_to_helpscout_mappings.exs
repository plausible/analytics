defmodule Plausible.Repo.Migrations.AddConversationIdToHelpscoutMappings do
  use Plausible
  use Ecto.Migration

  import Plausible.MigrationUtils

  def change do
    if enterprise_edition?() do
      alter table(:help_scout_mappings) do
        add :conversation_id, :string, null: true
        modify :customer_id, :string, null: true, from: {:string, null: false}
      end

      create unique_index(:help_scout_mappings, [:conversation_id])
    end
  end
end
