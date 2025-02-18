defmodule Plausible.Repo.Migrations.AddMissingIndexes do
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
    create index(:setup_success_emails, [:site_id, :timestamp], concurrently: true)
    create index(:setup_help_emails, [:site_id, :timestamp], concurrently: true)
    create index(:create_site_emails, [:user_id, :timestamp], concurrently: true)
    create index(:check_stats_emails, [:user_id, :timestamp], concurrently: true)
    create index(:sent_renewal_notifications, [:user_id, :timestamp], concurrently: true)

    create index(:team_invitations, [:email, :role], concurrently: true)

    create index(:shield_rules_page, [:site_id, :updated_at], concurrently: true)
    create index(:shield_rules_country, [:site_id, :updated_at], concurrently: true)
    create index(:shield_rules_ip, [:site_id, :updated_at], concurrently: true)

    create index(:google_auth, [:user_id], concurrently: true)
    create index(:segments, [:owner_id], concurrently: true)
  end
end
