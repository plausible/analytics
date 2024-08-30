defmodule Plausible.ReleaseTest do
  use Plausible.DataCase, async: true
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

  test "dump_plans/0 inserts plans" do
    stdout =
      capture_io(fn ->
        Release.dump_plans()
      end)

    assert stdout =~ "Loading plausible.."
    assert stdout =~ "Starting dependencies.."
    assert stdout =~ "Starting repos.."
    assert stdout =~ "Inserted 54 plans"
  end

  test "ecto_repos sanity check" do
    # if the repos here are modified, please make sure `interweave_migrate/0` tests below are properly updated as well
    assert Application.get_env(:plausible, :ecto_repos) == [Plausible.Repo, Plausible.IngestRepo]
  end

  # these tests create new pg and ch databases (named plausible_test_migrations),
  # run various migrations between released versions (e.g. v2.0.0 -> v2.1.0-rc.0 -> ... -> master)
  # and then drop them in the end.
  #
  # since completely separate databases are used, these tests are safe to run async
  describe "interweave_migrate/0" do
    @describetag :migrations

    # this repo is used in place of Plausible.Repo
    defmodule PostgreSQL do
      use Ecto.Repo, otp_app: :plausible, adapter: Ecto.Adapters.Postgres
    end

    # this repo is used in place of Plausible.IngestRepo
    defmodule ClickHouse do
      use Ecto.Repo, otp_app: :plausible, adapter: Ecto.Adapters.ClickHouse
    end

    setup do
      pg_config =
        Plausible.Repo.config()
        |> Keyword.replace!(:database, "plausible_test_migrations")
        # to see priv/repo/migrations from this fake pg repo
        |> Keyword.put(:priv, "priv/repo")

      ch_config =
        Plausible.IngestRepo.config()
        |> Keyword.replace!(:database, "plausible_test_migrations")
        # to see priv/ingest_repo/migrations from this fake ch repo
        |> Keyword.put(:priv, "priv/ingest_repo")

      Application.put_env(:plausible, PostgreSQL, pg_config)
      on_exit(fn -> Application.delete_env(:plausible, PostgreSQL) end)

      Application.put_env(:plausible, ClickHouse, ch_config)
      on_exit(fn -> Application.delete_env(:plausible, ClickHouse) end)

      pg_config = PostgreSQL.config()
      :ok = Ecto.Adapters.Postgres.storage_up(pg_config)
      on_exit(fn -> :ok = Ecto.Adapters.Postgres.storage_down(pg_config) end)

      ch_config = ClickHouse.config()
      :ok = Ecto.Adapters.ClickHouse.storage_up(ch_config)
      on_exit(fn -> :ok = Ecto.Adapters.ClickHouse.storage_down(ch_config) end)

      :ok
    end

    test "v2.0.0 -> master" do
      #
      # migrate to v2.0.0
      #

      # https://github.com/plausible/analytics/tree/v2.0.0/priv/repo/migrations
      {last_v200_pg_migration, _} =
        Integer.parse("20230516131041_add_unique_index_to_api_keys.exs")

      # https://github.com/plausible/analytics/tree/v2.0.0/priv/ingest_repo/migrations
      {last_v200_ch_migration, _} =
        Integer.parse("20230509124919_clean_up_old_tables_after_v2_migration.exs")

      Ecto.Migrator.with_repo(PostgreSQL, &Ecto.Migrator.run(&1, :up, to: last_v200_pg_migration))
      Ecto.Migrator.with_repo(ClickHouse, &Ecto.Migrator.run(&1, :up, to: last_v200_ch_migration))

      #
      # insert some data into the tables (similar to seeds)
      #

      # TODO
      # PostgreSQL.insert!()
      # ClickHouse.insert!()

      #
      # sanity-check pending migrations
      #

      all_pending =
        Enum.flat_map([PostgreSQL, ClickHouse], fn repo ->
          {:ok, pending, _started} =
            Ecto.Migrator.with_repo(repo, fn repo ->
              Ecto.Migrator.migrations(repo)
              |> Enum.filter(fn {status, _version, _name} -> status == :down end)
              |> Enum.map(fn {_status, version, name} -> {repo, version, name} end)
            end)

          pending
        end)

      all_sorted = Enum.sort_by(all_pending, fn {_repo, version, _name} -> version end, :asc)

      assert [
               {PostgreSQL, 20_230_530_161_856, "add_enable_feature_fields_for_site"},
               {PostgreSQL, 20_230_724_131_709, "change_allowed_event_props_type"},
               {PostgreSQL, 20_230_802_081_520, "cascade_delete_user"},
               {PostgreSQL, 20_230_914_071_244, "fix_broken_goals"},
               {PostgreSQL, 20_230_914_071_245, "goals_unique"},
               {PostgreSQL, 20_230_925_072_840, "plugins_api_tokens"},
               {PostgreSQL, 20_231_003_081_927, "add_user_previous_email"},
               {PostgreSQL, 20_231_010_074_900,
                "add_unique_index_on_site_memberships_site_id_when_owner"},
               {PostgreSQL, 20_231_011_101_825, "add_email_activation_codes"},
               {ClickHouse, 20_231_017_073_642, "disable_deduplication_window_for_imports"},
               {PostgreSQL, 20_231_018_081_657, "add_last_used_at_to_plugins_api_tokens"},
               {PostgreSQL, 20_231_109_090_334, "add_site_user_preferences"},
               {PostgreSQL, 20_231_115_131_025, "add_limits_to_enterprise_plans"},
               {PostgreSQL, 20_231_115_140_646, "add_totp_user_fields_and_recovery_codes"},
               {PostgreSQL, 20_231_121_131_602, "create_plans_table"},
               {PostgreSQL, 20_231_127_132_321, "remove_custom_domains"},
               {PostgreSQL, 20_231_129_103_158, "add_allow_next_upgrade_override_to_users"},
               {PostgreSQL, 20_231_129_161_022, "add_totp_token_to_users"},
               {PostgreSQL, 20_231_204_151_831, "backfill_last_bill_date_to_subscriptions"},
               {PostgreSQL, 20_231_208_125_624, "add_data_retention_in_years_to_plans"},
               {PostgreSQL, 20_231_211_092_344, "add_accept_traffic_until_to_sites"},
               {PostgreSQL, 20_231_219_083_050, "track_accept_traffic_until_notifcations"},
               {PostgreSQL, 20_231_220_072_829, "add_accept_traffic_until_to_user"},
               {PostgreSQL, 20_231_220_101_920, "backfill_accept_traffic_until"},
               {PostgreSQL, 20_240_103_090_304, "upgrade_oban_jobs_to_v12"},
               {PostgreSQL, 20_240_123_085_318, "add_ip_block_list_table"},
               {PostgreSQL, 20_240_123_095_646, "remove_google_analytics_imports_jobs"},
               {ClickHouse, 20_240_123_142_959, "add_import_id_to_imported_tables"},
               {PostgreSQL, 20_240_123_144_308, "add_site_imports"},
               {PostgreSQL, 20_240_129_102_900, "migrate_accepted_traffic_until"},
               {PostgreSQL, 20_240_129_113_531,
                "backfill_accept_traffic_until_for_users_missing_notifications"},
               {ClickHouse, 20_240_209_085_338, "minmax_index_session_timestamp"},
               {PostgreSQL, 20_240_214_114_158, "add_legacy_flag_to_site_imports"},
               {ClickHouse, 20_240_220_123_656, "create_sessions_events_compression_options"},
               {PostgreSQL, 20_240_220_144_655, "cascade_delete_ip_rules"},
               # v2.1.0-rc.0 is released here, cascade_delete_ip_rules is the last migration:
               # https://github.com/plausible/analytics/tree/v2.1.0-rc.0/priv/repo/migrations
               {PostgreSQL, 20_240_221_122_626, "shield_country_rules"},
               {ClickHouse, 20_240_222_082_911, "sessions_v2_versioned_collapsing_merge_tree"},
               {ClickHouse, 20_240_305_085_310, "events_sessions_columns_improved"},
               {PostgreSQL, 20_240_307_083_402, "shield_page_rules"},
               {PostgreSQL, 20_240_319_094_940, "add_label_to_site_imports"},
               {ClickHouse, 20_240_326_134_840, "add_metrics_to_imported_tables"},
               {ClickHouse, 20_240_327_085_855, "hostnames_in_sessions"},
               {PostgreSQL, 20_240_407_104_659, "shield_hostname_rules"},
               {ClickHouse, 20_240_419_133_926, "add_active_visitors_to_imported_pages"},
               {ClickHouse, 20_240_423_094_014, "add_imported_custom_events"},
               {ClickHouse, 20_240_502_115_822, "alias_api_prop_names"},
               # v2.1.0-rc.1 and v2.1.0 are released here, alias_api_prop_names is the last migration:
               # https://github.com/plausible/analytics/tree/v2.1.0-rc.1/priv/ingest_repo/migrations
               # https://github.com/plausible/analytics/tree/v2.1.0/priv/ingest_repo/migrations
               {PostgreSQL, 20_240_528_115_149, "migrate_site_imports"}
               # v2.1.1 is released here, migrate_site_imports is the last migration:
               # https://github.com/plausible/analytics/tree/v2.1.1/priv/repo/migrations

               # unreleased
               # {PostgreSQL, 20_240_702_055_817, "traffic_drop_notifications"},
               # {PostgreSQL, 20_240_708_120_453, "create_help_scout_credentials"},
               # {ClickHouse, 20_240_709_181_437, "populate_location_data"},
               # {PostgreSQL, 20_240_722_143_005, "create_helpscout_mappings"},
               # {PostgreSQL, 20_240_801_052_902, "add_goal_display_name"},
               # {PostgreSQL, 20_240_801_052_903, "make_goal_display_names_unique"},
               # {PostgreSQL, 20_240_809_100_853, "turn_google_auth_tokens_into_text"}

               | _future
             ] = all_sorted

      #
      # sanity-check pending "migration streaks"
      #

      assert [
               {PostgreSQL, 20_231_011_101_825},
               {ClickHouse, 20_231_017_073_642},
               {PostgreSQL, 20_240_123_095_646},
               {ClickHouse, 20_240_123_142_959},
               {PostgreSQL, 20_240_129_113_531},
               {ClickHouse, 20_240_209_085_338},
               {PostgreSQL, 20_240_214_114_158},
               {ClickHouse, 20_240_220_123_656},
               {PostgreSQL, 20_240_221_122_626},
               {ClickHouse, 20_240_305_085_310},
               {PostgreSQL, 20_240_319_094_940},
               {ClickHouse, 20_240_327_085_855},
               {PostgreSQL, 20_240_407_104_659},
               {ClickHouse, 20_240_502_115_822},
               {PostgreSQL, 20_240_708_120_453}

               # unreleased
               # {ClickHouse, 20_240_709_181_437}
               # {PostgreSQL, 20_240_809_100_853}

               | _future
             ] = Release.migration_streaks([PostgreSQL, ClickHouse])

      pending_streaks = capture_io(fn -> Release.pending_streaks([PostgreSQL, ClickHouse]) end)

      pending_streaks =
        if Plausible.ce?() do
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

             """ <> _future = pending_streaks

      #
      # and finally migrate all the way up to to master
      #

      _logs = capture_io(fn -> Release.interweave_migrate([PostgreSQL, ClickHouse]) end)
    end
  end
end
