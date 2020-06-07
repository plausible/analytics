defmodule Plausible.Repo.Migrations.AddMonthlyReports do
  use Ecto.Migration
  use Plausible.Repo

  def up do
    drop constraint(:email_settings, "email_settings_site_id_fkey")
    drop constraint(:email_settings, "email_settings_pkey")
    execute "DROP INDEX email_settings_site_id_index"

    rename table(:email_settings), to: table(:weekly_reports)

    alter table(:weekly_reports) do
      modify :id, :bigint, primary_key: true
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end

    execute "ALTER SEQUENCE email_settings_id_seq RENAME TO weekly_reports_id_seq;"
    create unique_index(:weekly_reports, :site_id)

    drop constraint(:sent_email_reports, "sent_email_reports_site_id_fkey")
    drop constraint(:sent_email_reports, "sent_email_reports_pkey")

    rename table(:sent_email_reports), to: table(:sent_weekly_reports)

    alter table(:sent_weekly_reports) do
      modify :id, :bigint, primary_key: true
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end

    execute "ALTER SEQUENCE sent_email_reports_id_seq RENAME TO sent_weekly_reports_id_seq;"

    create table(:monthly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :email, :citext, null: false

      timestamps()
    end

    create table(:sent_monthly_reports) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :month, :integer, null: false

      add :timestamp, :naive_datetime
    end
  end

  def down do
    drop constraint(:weekly_reports, "weekly_reports_site_id_fkey")
    drop constraint(:weekly_reports, "weekly_reports_pkey")
    execute "DROP INDEX weekly_reports_site_id_index"

    rename table(:weekly_reports), to: table(:email_settings)

    alter table(:email_settings) do
      modify :id, :bigint, primary_key: true
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end

    execute "ALTER SEQUENCE weekly_reports_id_seq RENAME TO email_settings_id_seq;"
    create unique_index(:email_settings, :site_id)

    drop constraint(:sent_weekly_reports, "sent_weekly_reports_site_id_fkey")
    drop constraint(:sent_weekly_reports, "sent_weekly_reports_pkey")

    rename table(:sent_weekly_reports), to: table(:sent_email_reports)

    alter table(:sent_email_reports) do
      modify :id, :bigint, primary_key: true
      modify :site_id, references(:sites, on_delete: :delete_all), null: false
    end

    execute "ALTER SEQUENCE sent_weekly_reports_id_seq RENAME TO sent_email_reports_id_seq;"

    drop table(:monthly_reports)
    drop table(:sent_monthly_reports)
  end
end
