defmodule Plausible.Release do
  use Plausible.Repo
  @app :plausible
  @start_apps [
    :postgrex,
    :ecto
  ]

  def init_admin do
    prepare()
    {admin_email, admin_user, admin_pwd} =
      validate_admin(
        {Application.get_env(:plausible, :admin_email),
         Application.get_env(:plausible, :admin_user),
         Application.get_env(:plausible, :admin_pwd)}
      )

    case Plausible.Auth.find_user_by(email: admin_email) do
      nil ->
        {:ok, admin} = Plausible.Auth.create_user(admin_user, admin_email)
        # set the password
        {:ok, admin} = Plausible.Auth.User.set_password(admin, admin_pwd) |> Repo.update()
        # bump-up the trail period
        admin
        |> Ecto.Changeset.cast(%{trial_expiry_date: Timex.today() |> Timex.shift(years: 100)}, [
          :trial_expiry_date
        ])
        |> Repo.update()

        IO.puts("Admin user created successful!")

      _ ->
        IO.puts("Admin user already exists. I won't override, bailing")
    end
  end

  def migrate do
    prepare()
    Enum.each(repos(), &run_migrations_for/1)
    prepare_clickhouse()
    run_migrations_for_ch()
    IO.puts("Migrations successful!")
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
    do_create_db()
    prepare_clickhouse(:default_db)
    do_create_ch_db()
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

  ##############################

  defp validate_admin({nil, nil, nil}) do
    random_user = :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
    random_pwd = :crypto.strong_rand_bytes(20) |> Base.encode64() |> binary_part(0, 20)
    random_email = "#{random_user}@#{System.get_env("HOST")}"
    IO.puts("generated admin user/password: #{random_email} / #{random_pwd}")
    {random_email, random_user, random_pwd}
  end

  defp validate_admin({admin_email, admin_user, admin_password}) do
    {admin_email, admin_user, admin_password}
  end

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
    app = Keyword.get(repo.config, :otp_app)
    IO.puts("Running migrations for #{app}")
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  defp run_migrations_for_ch() do
    db = Keyword.get(Application.get_env(:plausible, :clickhouse), :database)

    tb_events = """
    CREATE TABLE IF NOT EXISTS #{db}.events (
      timestamp DateTime,
      name String,
      domain String,
      user_id UInt64,
      session_id UInt64,
      hostname String,
      pathname String,
      referrer String,
      referrer_source String,
      country_code LowCardinality(FixedString(2)),
      screen_size LowCardinality(String),
      operating_system LowCardinality(String),
      browser LowCardinality(String)
    ) ENGINE = MergeTree()
    PARTITION BY toYYYYMM(timestamp)
    ORDER BY (name, domain, user_id, timestamp)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, tb_events, [])

    tb_sessions = """
    CREATE TABLE IF NOT EXISTS #{db}.sessions (
      session_id UInt64,
      sign Int8,
      domain String,
      user_id UInt64,
      hostname String,
      timestamp DateTime,
      start DateTime,
      is_bounce UInt8,
      entry_page String,
      exit_page String,
      pageviews Int32,
      events Int32,
      duration UInt32,
      referrer String,
      referrer_source String,
      country_code LowCardinality(FixedString(2)),
      screen_size LowCardinality(String),
      operating_system LowCardinality(String),
      browser LowCardinality(String)
    ) ENGINE = CollapsingMergeTree(sign)
    PARTITION BY toYYYYMM(start)
    ORDER BY (domain, user_id, session_id, start)
    SETTINGS index_granularity = 8192
    """

    Clickhousex.query(:clickhouse, tb_sessions, [])
  end

  defp do_create_db do
    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end
  end

  defp do_create_ch_db() do
    db_to_create = Keyword.get(Application.get_env(:plausible, :clickhouse), :database)
    IO.puts("create #{inspect(db_to_create)} clickhouse database/tables if it doesn't exist")
    Clickhousex.query(:clickhouse, "CREATE DATABASE IF NOT EXISTS #{db_to_create}", [])
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
    :ok = Application.load(@app)

    IO.puts("Starting dependencies..")
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for myapp
    IO.puts("Starting repos..")
    Enum.each(repos(), & &1.start_link(pool_size: 2))
  end

  # connect to the default db for creating the required db
  defp prepare_clickhouse(:default_db) do
    Application.ensure_all_started(:db_connection)
    Application.ensure_all_started(:hackney)

    Clickhousex.start_link(
      scheme: :http,
      port: 8123,
      name: :clickhouse,
      database: "default",
      username: "default",
      hostname: Keyword.get(Application.get_env(:plausible, :clickhouse), :hostname),
      password: Keyword.get(Application.get_env(:plausible, :clickhouse), :password)
    )
  end

  defp prepare_clickhouse() do
    Application.ensure_all_started(:db_connection)
    Application.ensure_all_started(:hackney)

    Clickhousex.start_link(
      scheme: :http,
      port: 8123,
      name: :clickhouse,
      username: Keyword.get(Application.get_env(:plausible, :clickhouse), :username),
      database: Keyword.get(Application.get_env(:plausible, :clickhouse), :database),
      hostname: Keyword.get(Application.get_env(:plausible, :clickhouse), :hostname),
      password: Keyword.get(Application.get_env(:plausible, :clickhouse), :password)
    )
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
