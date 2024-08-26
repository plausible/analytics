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

  # Unlike `migrate/0` above this function:
  # - lists all pending migrations across repos,
  # - sorts them into a single list,
  # - groups consequent migration into "streaks" by repo,
  # - migrates each repo in "streak" consequently
  #
  # This approach helps resolve dependencies between migrations across repos.
  def interweave_sort_migrate do
    # interweave
    all_pending =
      Enum.flat_map(repos(), fn repo ->
        Ecto.Migrator.migrations(repo)
        |> Enum.filter(fn {status, _version, _name} -> status == :down end)
        |> Enum.map(fn {_status, version, _name} -> {repo, version} end)
      end)

    # sort
    all_sorted =
      Enum.sort_by(all_pending, fn {_repo, version} -> version end, :asc)

    # group into streaks
    streaks = migration_streaks(all_sorted)

    # migrate
    Enum.each(streaks, fn {repo, version} ->
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, to: version))
    end)
  end

  @doc false
  defp migration_streaks([{repo, version} | streaks]) do
    migration_streaks(streaks, repo, version)
  end

  defp migration_streaks([] = empty), do: empty

  defp migration_streaks([{repo, version} | rest], repo, _prev_version) do
    migration_streaks(rest, repo, version)
  end

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
