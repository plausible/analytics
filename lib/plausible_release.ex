defmodule Plausible.Release do
  use Plausible
  use Plausible.Repo
  require Logger

  @app :plausible
  @start_apps [
    :ssl,
    :postgrex,
    :ch,
    :ecto
  ]

  def should_be_first_launch? do
    on_ee do
      false
    else
      not (_has_users? = Repo.exists?(Plausible.Auth.User))
    end
  end

  def migrate do
    prepare()
    Enum.each(repos(), &run_migrations_for/1)
    IO.puts("Migrations successful!")
  end

  @doc """
  Unlike `migrate/0` above this function:
   - lists all pending migrations across repos,
   - sorts them into a single list,
   - groups consequent migration into "streaks" by repo,
   - migrates each repo in "streak" consequently

  For examples, assuming wi have the following migrations across two repos:

      priv/repo/migrations/
      - 20230530161856_add_enable_feature_fields_for_site.exs
      - 20230724131709_change_allowed_event_props_type.exs
      - 20230802081520_cascade_delete_user.exs
      - 20230914071244_fix_broken_goals.exs
      - 20230914071245_goals_unique.exs
      - 20230925072840_plugins_api_tokens.exs
      - 20231003081927_add_user_previous_email.exs
      - 20231010074900_add_unique_index_on_site_memberships_site_id_when_owner.exs
      - 20231011101825_add_email_activation_codes.exs
      - 20231018081657_add_last_used_at_to_plugins_api_tokens.exs
      - 20231109090334_add_site_user_preferences.exs
      - 20231115131025_add_limits_to_enterprise_plans.exs
      - 20231115140646_add_totp_user_fields_and_recovery_codes.exs
      - 20231121131602_create_plans_table.exs
      - 20231127132321_remove_custom_domains.exs
      - 20231129103158_add_allow_next_upgrade_override_to_users.exs
      - 20231129161022_add_totp_token_to_users.exs
      - 20231204151831_backfill_last_bill_date_to_subscriptions.exs
      - 20231208125624_add_data_retention_in_years_to_plans.exs
      - 20231211092344_add_accept_traffic_until_to_sites.exs
      - 20231219083050_track_accept_traffic_until_notifcations.exs
      - 20231220072829_add_accept_traffic_until_to_user.exs
      - 20231220101920_backfill_accept_traffic_until.exs
      - 20240103090304_upgrade_oban_jobs_to_v12.exs
      - 20240123085318_add_ip_block_list_table.exs
      - 20240123095646_remove_google_analytics_imports_jobs.exs
      - 20240123144308_add_site_imports.exs
      - 20240129102900_migrate_accepted_traffic_until.exs
      - 20240129113531_backfill_accept_traffic_until_for_users_missing_notifications.exs
      - 20240214114158_add_legacy_flag_to_site_imports.exs
      - 20240220144655_cascade_delete_ip_rules.exs
      - 20240221122626_shield_country_rules.exs
      - 20240307083402_shield_page_rules.exs
      - 20240319094940_add_label_to_site_imports.exs
      - 20240407104659_shield_hostname_rules.exs
      - 20240528115149_migrate_site_imports.exs
      - 20240702055817_traffic_drop_notifications.exs
      - 20240708120453_create_help_scout_credentials.exs
      - 20240722143005_create_helpscout_mappings.exs
      - 20240801052902_add_goal_display_name.exs
      - 20240801052903_make_goal_display_names_unique.exs
      - 20240809100853_turn_google_auth_tokens_into_text.exs

      priv/ingest_repo/migrations/
      - 20231017073642_disable_deduplication_window_for_imports.exs
      - 20240123142959_add_import_id_to_imported_tables.exs
      - 20240209085338_minmax_index_session_timestamp.exs
      - 20240220123656_create_sessions_events_compression_options.exs
      - 20240222082911_sessions_v2_versioned_collapsing_merge_tree.exs
      - 20240305085310_events_sessions_columns_improved.exs
      - 20240326134840_add_metrics_to_imported_tables.exs
      - 20240327085855_hostnames_in_sessions.exs
      - 20240419133926_add_active_visitors_to_imported_pages.exs
      - 20240423094014_add_imported_custom_events.exs
      - 20240502115822_alias_api_prop_names.exs
      - 20240709181437_populate_location_data.exs

  The migrations would happen in the following order:

      priv/repo/migrations/
      - 20230530161856_add_enable_feature_fields_for_site.exs
      - 20230724131709_change_allowed_event_props_type.exs
      - 20230802081520_cascade_delete_user.exs
      - 20230914071244_fix_broken_goals.exs
      - 20230914071245_goals_unique.exs
      - 20230925072840_plugins_api_tokens.exs
      - 20231003081927_add_user_previous_email.exs
      - 20231010074900_add_unique_index_on_site_memberships_site_id_when_owner.exs
      - 20231011101825_add_email_activation_codes.exs

      priv/ingest_repo/migrations/
      - 20231017073642_disable_deduplication_window_for_imports.exs

      priv/repo/migrations/
      - 20231018081657_add_last_used_at_to_plugins_api_tokens.exs
      - 20231109090334_add_site_user_preferences.exs
      - 20231115131025_add_limits_to_enterprise_plans.exs
      - 20231115140646_add_totp_user_fields_and_recovery_codes.exs
      - 20231121131602_create_plans_table.exs
      - 20231127132321_remove_custom_domains.exs
      - 20231129103158_add_allow_next_upgrade_override_to_users.exs
      - 20231129161022_add_totp_token_to_users.exs
      - 20231204151831_backfill_last_bill_date_to_subscriptions.exs
      - 20231208125624_add_data_retention_in_years_to_plans.exs
      - 20231211092344_add_accept_traffic_until_to_sites.exs
      - 20231219083050_track_accept_traffic_until_notifcations.exs
      - 20231220072829_add_accept_traffic_until_to_user.exs
      - 20231220101920_backfill_accept_traffic_until.exs
      - 20240103090304_upgrade_oban_jobs_to_v12.exs
      - 20240123085318_add_ip_block_list_table.exs
      - 20240123095646_remove_google_analytics_imports_jobs.exs

      priv/ingest_repo/migrations/
      - 20240123142959_add_import_id_to_imported_tables.exs

      priv/repo/migrations/
      - 20240123144308_add_site_imports.exs
      - 20240129102900_migrate_accepted_traffic_until.exs
      - 20240129113531_backfill_accept_traffic_until_for_users_missing_notifications.exs

      priv/ingest_repo/migrations/
      - 20240209085338_minmax_index_session_timestamp.exs

      priv/repo/migrations/
      - 20240214114158_add_legacy_flag_to_site_imports.exs

      priv/ingest_repo/migrations/
      - 20240220123656_create_sessions_events_compression_options.exs

      priv/repo/migrations/
      - 20240220144655_cascade_delete_ip_rules.exs
      - 20240221122626_shield_country_rules.exs

      priv/ingest_repo/migrations/
      - 20240222082911_sessions_v2_versioned_collapsing_merge_tree.exs
      - 20240305085310_events_sessions_columns_improved.exs

      priv/repo/migrations/
      - 20240307083402_shield_page_rules.exs
      - 20240319094940_add_label_to_site_imports.exs

      priv/ingest_repo/migrations/
      - 20240326134840_add_metrics_to_imported_tables.exs
      - 20240327085855_hostnames_in_sessions.exs

      priv/repo/migrations/
      - 20240407104659_shield_hostname_rules.exs

      priv/ingest_repo/migrations/
      - 20240419133926_add_active_visitors_to_imported_pages.exs
      - 20240423094014_add_imported_custom_events.exs
      - 20240502115822_alias_api_prop_names.exs

      priv/repo/migrations/
      - 20240528115149_migrate_site_imports.exs
      - 20240702055817_traffic_drop_notifications.exs
      - 20240708120453_create_help_scout_credentials.exs

      priv/ingest_repo/migrations/
      - 20240709181437_populate_location_data.exs

      priv/repo/migrations/
      - 20240722143005_create_helpscout_mappings.exs
      - 20240801052902_add_goal_display_name.exs
      - 20240801052903_make_goal_display_names_unique.exs
      - 20240809100853_turn_google_auth_tokens_into_text.exs

  This approach helps resolve dependencies between migrations across repos.
  """
  def interweave_migrate do
    # interweave
    all_pending =
      Enum.flat_map(repos(), fn repo ->
        Ecto.Migrator.migrations(repo)
        |> Enum.filter(fn {status, _version, _name} -> status == :down end)
        |> Enum.map(fn {_status, version, _name} -> {repo, version} end)
      end)

    # sort
    all_sorted = Enum.sort_by(all_pending, fn {_repo, version} -> version end, :asc)

    # group into streaks
    streaks = migration_streaks(all_sorted)

    # migrate the streaks
    Enum.each(streaks, fn {repo, version} ->
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, to: version))
    end)
  end

  @doc false
  def migration_streaks([{repo, version} | streaks]) do
    migration_streaks(streaks, repo, version)
  end

  def migration_streaks([] = empty), do: empty

  # extend the streak
  defp migration_streaks([{repo, version} | rest], repo, _prev_version) do
    migration_streaks(rest, repo, version)
  end

  # end the streak
  defp migration_streaks([{repo, version} | rest], prev_repo, prev_version) do
    [{prev_repo, prev_version} | migration_streaks(rest, repo, version)]
  end

  defp migration_streaks([], repo, version), do: [{repo, version}]

  def pending_migrations do
    prepare()
    IO.puts("Pending migrations")
    IO.puts("")
    Enum.each(repos(), &list_pending_migrations_for/1)
  end

  def seed do
    prepare()
    # Run seed script
    Enum.each(repos(), &run_seeds_for/1)
    # Signal shutdown
    IO.puts("Success!")
  end

  def createdb do
    prepare()

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end

    IO.puts("Creation of Db successful!")
  end

  def rollback do
    prepare()

    get_step =
      IO.gets("Enter the number of steps: ")
      |> String.trim()
      |> Integer.parse()

    case get_step do
      {int, _trailing} ->
        Enum.each(repos(), fn repo -> run_rollbacks_for(repo, int) end)
        IO.puts("Rollback successful!")

      :error ->
        IO.puts("Invalid integer")
    end
  end

  def configure_ref_inspector() do
    priv_dir = Application.app_dir(:plausible, "priv/ref_inspector")
    Application.put_env(:ref_inspector, :database_path, priv_dir)
  end

  def configure_ua_inspector() do
    priv_dir = Application.app_dir(:plausible, "priv/ua_inspector")
    Application.put_env(:ua_inspector, :database_path, priv_dir)
  end

  def dump_plans() do
    prepare()

    Repo.delete_all("plans")

    plans =
      Plausible.Billing.Plans.all()
      |> Plausible.Billing.Plans.with_prices()
      |> Enum.map(fn plan ->
        plan = Map.from_struct(plan)

        monthly_cost = plan.monthly_cost && Money.to_decimal(plan.monthly_cost)
        yearly_cost = plan.yearly_cost && Money.to_decimal(plan.yearly_cost)
        {:ok, features} = Plausible.Billing.Ecto.FeatureList.dump(plan.features)
        {:ok, team_member_limit} = Plausible.Billing.Ecto.Limit.dump(plan.team_member_limit)

        plan
        |> Map.drop([:id])
        |> Map.put(:kind, Atom.to_string(plan.kind))
        |> Map.put(:monthly_cost, monthly_cost)
        |> Map.put(:yearly_cost, yearly_cost)
        |> Map.put(:features, features)
        |> Map.put(:team_member_limit, team_member_limit)
      end)

    {count, _} = Repo.insert_all("plans", plans)
    IO.puts("Inserted #{count} plans")
  end

  ##############################

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp run_seeds_for(repo) do
    # Run the seed script if it exists
    seed_script = seeds_path(repo)

    if File.exists?(seed_script) do
      IO.puts("Running seed script..")
      Code.eval_file(seed_script)
    end
  end

  defp run_migrations_for(repo) do
    IO.puts("Running migrations for #{repo}")
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  defp list_pending_migrations_for(repo) do
    IO.puts("Listing pending migrations for #{repo}")
    IO.puts("")

    migration_directory = Ecto.Migrator.migrations_path(repo)

    pending =
      repo
      |> Ecto.Migrator.migrations([migration_directory])
      |> Enum.filter(fn {status, _version, _migration} -> status == :down end)

    if pending == [] do
      IO.puts("No pending migrations")
    else
      Enum.each(pending, fn {_, version, migration} ->
        IO.puts("* #{version}_#{migration}")
      end)
    end

    IO.puts("")
  end

  defp ensure_repo_created(repo) do
    IO.puts("create #{inspect(repo)} database if it doesn't exist")

    case repo.__adapter__.storage_up(repo.config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, term} -> {:error, term}
    end
  end

  defp run_rollbacks_for(repo, step) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running rollbacks for #{app} (STEP=#{step})")

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, all: false, step: step))
  end

  defp prepare do
    IO.puts("Loading #{@app}..")
    # Load the code for myapp, but don't start it
    :ok = Application.ensure_loaded(@app)

    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for myapp
    IO.puts("Starting repos..")
    Enum.each(repos(), & &1.start_link(pool_size: 2))
  end

  defp seeds_path(repo), do: priv_path_for(repo, "seeds.exs")

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("App: #{app}")
    repo_underscore = repo |> Module.split() |> List.last() |> Macro.underscore()
    Path.join([priv_dir(app), repo_underscore, filename])
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"
end
