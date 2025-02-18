defmodule Plausible.Repo.Migrations.AddMissingIndexes2 do
  # seq_scans vs seq_tup_read:
  #
  # SELECT relname, seq_scan, seq_tup_read, pg_size_pretty(pg_relation_size(relname::regclass))
  # FROM pg_stat_all_tables
  # WHERE seq_scan > 1000
  # ORDER BY (seq_tup_read - seq_scan) DESC;
  #
  # missing FK indexes:
  #
  # SELECT conrelid::regclass AS table_name, conname AS constraint_name,
  #   array_agg(a.attname) AS column_names
  # FROM pg_constraint c
  # JOIN pg_attribute a
  # ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
  # WHERE contype = 'f'
  # GROUP BY conrelid, conname, c.conkey
  # HAVING NOT EXISTS (
  #   SELECT 1
  #   FROM pg_index i
  #   WHERE i.indrelid = c.conrelid
  #   AND i.indkey::int2[] @> c.conkey
  # );

  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:api_keys, [:user_id], concurrently: true)
  end
end
