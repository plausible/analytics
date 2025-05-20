defmodule Plausible.ReleaseTest do
  use Plausible.DataCase, async: true
  use Plausible
  alias Plausible.{Release, Auth}
  import ExUnit.CaptureIO

  describe "should_be_first_launch?/0" do
    @tag :ce_build_only
    test "returns true when self-hosted and no users" do
      refute Repo.exists?(Auth.User)
      assert Release.should_be_first_launch?()
    end

    @tag :ee_only
    test "returns false when not self-hosted and has no users" do
      refute Repo.exists?(Auth.User)
      refute Release.should_be_first_launch?()
    end

    @tag :ee_only
    test "returns false when not self-hosted and has users" do
      insert(:user)
      refute Release.should_be_first_launch?()
    end

    @tag :ce_build_only
    test "returns false when self-hosted and has users" do
      insert(:user)
      refute Release.should_be_first_launch?()
    end
  end

  @tag :ee_only
  test "dump_plans/0 inserts plans" do
    stdout =
      capture_io(fn ->
        Release.dump_plans()
      end)

    assert stdout =~ "Loading plausible.."
    assert stdout =~ "Starting dependencies.."
    assert stdout =~ "Starting repos.."
    assert stdout =~ "Inserted 78 plans"
  end

  test "ecto_repos sanity check" do
    # if the repos here are modified, please make sure `interweave_migrate/0` tests below are properly updated as well
    assert Application.get_env(:plausible, :ecto_repos) == [Plausible.Repo, Plausible.IngestRepo]
  end

  # this repo is used in place of Plausible.Repo
  defmodule PostgreSQL do
    use Ecto.Repo, otp_app: :plausible, adapter: Ecto.Adapters.Postgres
  end

  # this repo is used in place of Plausible.IngestRepo
  defmodule ClickHouse do
    use Ecto.Repo, otp_app: :plausible, adapter: Ecto.Adapters.ClickHouse
  end

  defp last_migration(repo) do
    {:ok, {_status, version, name}, _started} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        repo
        |> Ecto.Migrator.migrations()
        |> List.last()
      end)

    "#{version}_#{name}"
  end

  defp fake_migrate(repo, up_to_migration) do
    {up_to_version, _name} = Integer.parse(up_to_migration)

    insert_opts =
      if repo == ClickHouse do
        [types: [version: "Int64", inserted_at: "DateTime"]]
      else
        []
      end

    Ecto.Migrator.with_repo(repo, fn repo ->
      schema_versions =
        Ecto.Migrator.migrations(repo)
        |> Enum.filter(fn {status, version, _name} ->
          status == :down and version <= up_to_version
        end)
        |> Enum.map(fn {_status, version, _name} ->
          [version: version, inserted_at: NaiveDateTime.utc_now(:second)]
        end)

      repo.insert_all("schema_migrations", schema_versions, insert_opts)
    end)
  end

  defp fake_repos(_context) do
    pg_config =
      Plausible.Repo.config()
      |> Keyword.replace!(:database, "plausible_test_migrations")
      # to see priv/repo/migrations from this fake pg repo
      |> Keyword.put_new(:priv, "priv/repo")

    ch_config =
      Plausible.IngestRepo.config()
      |> Keyword.replace!(:database, "plausible_test_migrations")
      # to see priv/ingest_repo/migrations from this fake ch repo
      |> Keyword.put_new(:priv, "priv/ingest_repo")

    Application.put_env(:plausible, PostgreSQL, pg_config)
    on_exit(fn -> Application.delete_env(:plausible, PostgreSQL) end)

    Application.put_env(:plausible, ClickHouse, ch_config)
    on_exit(fn -> Application.delete_env(:plausible, ClickHouse) end)

    {:ok, repos: [PostgreSQL, ClickHouse]}
  end

  describe "pending_streaks/1" do
    @describetag :migrations

    setup :fake_repos

    setup do
      pg_config = PostgreSQL.config()
      :ok = Ecto.Adapters.Postgres.storage_up(pg_config)
      on_exit(fn -> :ok = Ecto.Adapters.Postgres.storage_down(pg_config) end)

      ch_config = ClickHouse.config()
      :ok = Ecto.Adapters.ClickHouse.storage_up(ch_config)
      on_exit(fn -> :ok = Ecto.Adapters.ClickHouse.storage_down(ch_config) end)

      :ok
    end

    test "v2.0.0 -> master" do
      # pretend to migrate the repos up to v2.0.0
      # https://github.com/plausible/analytics/tree/v2.0.0/priv/repo/migrations
      fake_migrate(PostgreSQL, _up_to = "20230516131041_add_unique_index_to_api_keys")
      # https://github.com/plausible/analytics/tree/v2.0.0/priv/ingest_repo/migrations
      fake_migrate(ClickHouse, _up_to = "20230509124919_clean_up_old_tables_after_v2_migration")

      pending_streaks = capture_io(fn -> Release.pending_streaks([PostgreSQL, ClickHouse]) end)

      pending_streaks =
        if ce?() do
          # just to make the tests pass in CI
          String.replace(pending_streaks, "_build/ce_test/lib", "_build/test/lib")
        else
          pending_streaks
        end

      assert """
             Loading plausible..
             Starting dependencies..
             Starting repos..
             Collecting pending migrations..

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20231011101825:
               * 20230530161856_add_enable_feature_fields_for_site
               * 20230724131709_change_allowed_event_props_type
               * 20230802081520_cascade_delete_user
               * 20230914071244_fix_broken_goals
               * 20230914071245_goals_unique
               * 20230925072840_plugins_api_tokens
               * 20231003081927_add_user_previous_email
               * 20231010074900_add_unique_index_on_site_memberships_site_id_when_owner
               * 20231011101825_add_email_activation_codes

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20231017073642:
               * 20231017073642_disable_deduplication_window_for_imports

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240123095646:
               * 20231018081657_add_last_used_at_to_plugins_api_tokens
               * 20231109090334_add_site_user_preferences
               * 20231115131025_add_limits_to_enterprise_plans
               * 20231115140646_add_totp_user_fields_and_recovery_codes
               * 20231121131602_create_plans_table
               * 20231127132321_remove_custom_domains
               * 20231129103158_add_allow_next_upgrade_override_to_users
               * 20231129161022_add_totp_token_to_users
               * 20231204151831_backfill_last_bill_date_to_subscriptions
               * 20231208125624_add_data_retention_in_years_to_plans
               * 20231211092344_add_accept_traffic_until_to_sites
               * 20231219083050_track_accept_traffic_until_notifcations
               * 20231220072829_add_accept_traffic_until_to_user
               * 20231220101920_backfill_accept_traffic_until
               * 20240103090304_upgrade_oban_jobs_to_v12
               * 20240123085318_add_ip_block_list_table
               * 20240123095646_remove_google_analytics_imports_jobs

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240123142959:
               * 20240123142959_add_import_id_to_imported_tables

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240129113531:
               * 20240123144308_add_site_imports
               * 20240129102900_migrate_accepted_traffic_until
               * 20240129113531_backfill_accept_traffic_until_for_users_missing_notifications

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240209085338:
               * 20240209085338_minmax_index_session_timestamp

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240214114158:
               * 20240214114158_add_legacy_flag_to_site_imports

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240220123656:
               * 20240220123656_create_sessions_events_compression_options

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240221122626:
               * 20240220144655_cascade_delete_ip_rules
               * 20240221122626_shield_country_rules

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240305085310:
               * 20240222082911_sessions_v2_versioned_collapsing_merge_tree
               * 20240305085310_events_sessions_columns_improved

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240319094940:
               * 20240307083402_shield_page_rules
               * 20240319094940_add_label_to_site_imports

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240327085855:
               * 20240326134840_add_metrics_to_imported_tables
               * 20240327085855_hostnames_in_sessions

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240407104659:
               * 20240407104659_shield_hostname_rules

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240502115822:
               * 20240419133926_add_active_visitors_to_imported_pages
               * 20240423094014_add_imported_custom_events
               * 20240502115822_alias_api_prop_names

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20240708120453:
               * 20240528115149_migrate_site_imports
               * 20240702055817_traffic_drop_notifications
               * 20240708120453_create_help_scout_credentials

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20240709181437:
               * 20240709181437_populate_location_data

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version \
             """ <> _future = pending_streaks

      fake_migrate(PostgreSQL, last_migration(PostgreSQL))
      fake_migrate(ClickHouse, last_migration(ClickHouse))

      no_streaks = capture_io(fn -> Release.pending_streaks([PostgreSQL, ClickHouse]) end)

      assert no_streaks == """
             Loading plausible..
             Starting dependencies..
             Starting repos..
             Collecting pending migrations..
             No pending migrations!
             """
    end
  end

  describe "createdb/1" do
    @describetag :migrations

    setup :fake_repos

    setup %{repos: repos} do
      on_exit(fn ->
        Enum.each(repos, fn repo -> :ok = repo.__adapter__().storage_down(repo.config()) end)
      end)
    end

    test "does not create the database if it already exists", %{repos: repos} do
      first_run = capture_io(fn -> Release.createdb(repos) end)

      assert first_run == """
             Loading plausible..
             Starting dependencies..
             Starting repos..
             Creating Plausible.ReleaseTest.PostgreSQL database..
             Creating Plausible.ReleaseTest.ClickHouse database..
             Creation of Db successful!
             """

      second_run = capture_io(fn -> Release.createdb(repos) end)

      assert second_run == """
             Loading plausible..
             Starting dependencies..
             Starting repos..
             Plausible.ReleaseTest.PostgreSQL database already exists
             Plausible.ReleaseTest.ClickHouse database already exists
             Creation of Db successful!
             """
    end
  end
end
