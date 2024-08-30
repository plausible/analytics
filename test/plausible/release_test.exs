defmodule Plausible.ReleaseTest do
  use Plausible.DataCase, async: false
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

  describe "pending_streaks/1" do
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

      pg_config = PostgreSQL.config()
      :ok = Ecto.Adapters.Postgres.storage_up(pg_config)
      on_exit(fn -> :ok = Ecto.Adapters.Postgres.storage_down(pg_config) end)

      ch_config = ClickHouse.config()
      :ok = Ecto.Adapters.ClickHouse.storage_up(ch_config)
      on_exit(fn -> :ok = Ecto.Adapters.ClickHouse.storage_down(ch_config) end)

      :ok
    end

    test "from scratch" do
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

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20200619071221:
               * 20181201181549_add_pageviews
               * 20181214201821_add_new_visitor_to_pageviews
               * 20181215140923_add_session_id_to_pageviews
               * 20190109173917_create_sites
               * 20190117135714_add_uid_to_pageviews
               * 20190118154210_add_derived_data_to_pageviews
               * 20190126135857_add_name_to_users
               * 20190127213938_add_tz_to_sites
               * 20190205165931_add_last_seen_to_users
               * 20190213224404_add_intro_emails
               * 20190219130809_delete_intro_emails_when_user_is_deleted
               * 20190301122344_add_country_code_to_pageviews
               * 20190324155606_add_password_hash_to_users
               * 20190402145007_remove_device_type_from_pageviews
               * 20190402145357_remove_screen_height_from_pageviews
               * 20190402172423_add_index_to_pageviews
               * 20190410095248_add_feedback_emails
               * 20190424162903_delete_feedback_emails_when_user_is_deleted
               * 20190430140411_use_citext_for_email
               * 20190430152923_create_subscriptions
               * 20190516113517_remove_session_id_from_pageviews
               * 20190520144229_change_user_id_to_uuid
               * 20190523160838_add_raw_referrer
               * 20190523171519_add_indices_to_referrers
               * 20190618165016_add_public_sites
               * 20190718160353_create_google_search_console_integration
               * 20190723141824_associate_google_auth_with_site
               * 20190730014913_add_monthly_stats
               * 20190730142200_add_weekly_stats
               * 20190730144413_add_daily_stats
               * 20190809174105_calc_screen_size
               * 20190810145419_remove_unused_indices
               * 20190820140747_remove_rollup_tables
               * 20190906111810_add_email_reporting
               * 20190907134114_add_unique_index_to_email_settings
               * 20190910120900_add_email_address_to_settings
               * 20190911102027_add_monthly_reports
               * 20191010031425_add_property_to_google_auth
               * 20191015072730_remove_unused_fields
               * 20191015073507_proper_timestamp_for_pageviews
               * 20191024062200_rename_pageviews_to_events
               * 20191025055334_add_name_to_events
               * 20191031051340_add_goals
               * 20191031063001_remove_goal_name
               * 20191118075359_allow_free_subscriptions
               * 20191216064647_add_unique_index_to_email_reports
               * 20191218082207_add_sessions
               * 20191220042658_add_session_start
               * 20200106090739_cascade_google_auth_deletion
               * 20200107095234_add_entry_page_to_sessions
               * 20200113143927_add_exit_page_to_session
               * 20200114131538_add_tweets
               * 20200120091134_change_session_referrer_to_text
               * 20200121091251_add_recipients
               * 20200122150130_add_shared_links
               * 20200130123049_add_site_id_to_events
               * 20200204093801_rename_site_id_to_domain
               * 20200204133522_drop_events_hostname_index
               * 20200210134612_add_fingerprint_to_events
               * 20200211080841_add_raw_fingerprint
               * 20200211090126_remove_raw_fingerprint
               * 20200211133829_add_initial_source_and_referrer_to_events
               * 20200219124314_create_custom_domains
               * 20200227092821_add_fingerprint_sesssions
               * 20200302105632_flexible_fingerprint_referrer
               * 20200317093028_add_trial_expiry_to_users
               * 20200317142459_backfill_fingerprints
               * 20200320100803_add_setup_emails
               * 20200323083536_add_create_site_emails
               * 20200323084954_add_check_stats_emails
               * 20200324132431_make_cookie_fields_non_required
               * 20200406115153_cascade_custom_domain_deletion
               * 20200408122329_cascade_setup_emails_deletion
               * 20200529071028_add_oban_jobs_table
               * 20200605134616_remove_events_and_sessions
               * 20200605142737_remove_fingerprint_sessions_table
               * 20200619071221_create_salts_table

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20201106125234:
               * 20200915070607_create_events_and_sessions
               * 20200918075025_add_utm_tags
               * 20201020083739_add_event_metadata
               * 20201106125234_add_browser_version_and_os_version

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20210209095257:
               * 20201130083829_add_email_verification_codes
               * 20201208173543_add_spike_notifications
               * 20201210085345_add_email_verified_to_users
               * 20201214072008_add_theme_pref_to_users
               * 20201230085939_delete_email_records_when_user_is_deleted
               * 20210115092331_cascade_site_deletion_to_spike_notification
               * 20210119093337_add_unique_index_to_spike_notification
               * 20210128083453_cascade_site_deletion
               * 20210128084657_create_api_keys
               * 20210209095257_add_last_payment_details

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20210323130440:
               * 20210323130440_add_sample_by

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20210629124428:
               * 20210406073254_add_name_to_shared_links
               * 20210409074413_add_unique_index_to_shared_link_name
               * 20210409082603_add_api_key_scopes
               * 20210420075623_add_sent_renewal_notifications
               * 20210426075157_upgrade_oban_jobs_to_v9
               * 20210513091653_add_currency_to_subscription
               * 20210525085655_add_rate_limit_to_api_keys
               * 20210531080158_add_role_to_site_memberships
               * 20210601090924_add_invitations
               * 20210604085943_add_locked_to_sites
               * 20210629124428_cascade_site_deletion_to_invitations

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20210712214034:
               * 20210712214034_add_more_location_details

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20210908081119:
               * 20210726090211_make_invitation_email_case_insensitive
               * 20210906102736_memoize_setup_complete
               * 20210908081119_allow_trial_expiry_to_be_null

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20211017093035:
               * 20211017093035_add_utm_content_and_term

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20211110174617:
               * 20211020093238_add_enterprise_plans
               * 20211022084427_add_site_limit_to_enterprise_plans
               * 20211028122202_grace_period_end
               * 20211110174617_add_site_imported_source

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20211112130238:
               * 20211112130238_create_imported_tables

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20211202094732:
               * 20211202094732_remove_tweets

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20220404123000:
               * 20220310104931_add_transferred_from
               * 20220404123000_add_entry_props_to_session

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20220421074114:
               * 20220405124819_add_stats_start_date
               * 20220408071645_create_oban_peers
               * 20220408080058_swap_primary_oban_indexes
               * 20220421074114_create_feature_flags_table

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20220422075510:
               * 20220421161259_remove_entry_props
               * 20220422075510_add_entry_props

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20221228123226:
               * 20221109082503_add_rate_limiting_to_sites
               * 20221123104203_index_updated_at_for_sites
               * 20221228123226_cascade_delete_sent_renewal_notifications

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20230214114402:
               * 20230124140348_add_city_name_to_imported_locations
               * 20230210140348_remove_city_name_to_imported_locations
               * 20230214114402_create_ingest_counters_table

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20230301095227:
               * 20230301095227_add_native_stats_start_date

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20230320094327:
               * 20230320094327_create_v2_schemas

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20230417095029:
               * 20230328062644_allow_domain_change
               * 20230406110926_associate-goals-with-sites
               * 20230410070312_fixup_goals_sites_assoc
               * 20230417092745_add_monetary_value_to_goals
               * 20230417095029_init_funnels

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20230417104025:
               * 20230417104025_add_revenue_to_events

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20230503094245:
               * 20230503094245_add_event_prop_allowlist_to_site

             Plausible.ReleaseTest.ClickHouse [_build/test/lib/plausible/priv/ingest_repo/migrations] streak up to version 20230509124919:
               * 20230509124919_clean_up_old_tables_after_v2_migration

             Plausible.ReleaseTest.PostgreSQL [_build/test/lib/plausible/priv/repo/migrations] streak up to version 20231011101825:
               * 20230516131041_add_unique_index_to_api_keys
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
    end
  end
end
