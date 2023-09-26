defmodule Plausible.Repo.Migrations.PluginsAPITokens do
  use Ecto.Migration

  def change do
    create table("plugins_api_tokens", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:site_id, references(:sites, on_delete: :delete_all), null: false)
      add(:token_hash, :bytea, null: false)
      add(:hint, :string, null: false)
      add(:description, :string, null: false)
      timestamps()
    end

    create(index(:plugins_api_tokens, [:site_id, :token_hash]))
  end
end
