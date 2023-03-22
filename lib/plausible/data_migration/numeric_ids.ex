defmodule Plausible.DataMigration.NumericIDs do
  @moduledoc """
  Numeric IDs migration, SQL files available at:
  priv/data_migrations/NumericIDs/sql
  """
  use Plausible.DataMigration, dir: "NumericIDs"

  @table_settings "SETTINGS index_granularity = 8192, storage_policy = 'tiered'"

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def run(opts \\ []) do
    interactive? = Keyword.get(opts, :interactive?, true)

    db_url =
      System.get_env(
        "NUMERIC_IDS_MIGRATION_DB_URL",
        Application.get_env(:plausible, Plausible.IngestRepo)[:url]
      )

    max_threads =
      "NUMERIC_IDS_MIGRATION_MAX_THREADS" |> System.get_env("16") |> String.to_integer()

    # TBD: There's most likely a bug in Clickhouse defining Postgres dictionaries,
    # we'll use a static URL for now
    dict_url = Keyword.get(opts, :dict_url) || System.get_env("DOMAINS_DICT_URL") || ""

    dict_password =
      Keyword.get(opts, :dict_password) || System.get_env("DOMAINS_DICT_PASSWORD") || ""

    table_settings =
      Keyword.get(opts, :table_settings) || System.get_env("NUMERIC_IDS_TABLE_SETTINGS") ||
        @table_settings

    start_from =
      Keyword.get(opts, :start_from) || System.get_env("NUMERIC_IDS_PARTITION_START_FROM")

    stop_at =
      Keyword.get(opts, :stop_at) || System.get_env("NUMERIC_IDS_PARTITION_STOP_AT") ||
        previous_part()

    (byte_size(dict_url) > 0 and byte_size(dict_password) > 0) ||
      raise "Set DOMAINS_DICT_URL and DOMAINS_DICT_PASSWORD"

    @repo.start(db_url, max_threads)

    cluster? =
      case run_sql("check-replicas") do
        {:ok, %{num_rows: 0}} -> false
        {:ok, %{num_rows: 1}} -> true
      end

    {:ok, %{rows: partitions}} =
      run_sql("list-partitions", start_from: start_from, stop_at: stop_at)

    partitions = Enum.map(partitions, fn [part] -> part end)

    start_from = start_from || List.first(partitions)

    IO.puts("""
    Got the following migration settings: 

      - max_threads: #{max_threads}
      - dict_url: #{dict_url}
      - dict_password: ✅
      - table_settings: #{table_settings}
      - db url: #{db_url}
      - cluster?: #{cluster?}
      - partitions to do: #{inspect(partitions, pretty: true, width: 80)}
      - start from: #{start_from}
      - stop at: #{stop_at}
    """)

    run_sql_fn =
      if interactive? do
        &run_sql_confirm/2
      else
        &run_sql/2
      end

    confirm_fn =
      if interactive? do
        &confirm/2
      else
        fn _, run_fn ->
          run_fn.()
        end
      end

    {:ok, _} = run_sql_fn.("drop-events-v2", cluster?: cluster?)
    {:ok, _} = run_sql_fn.("drop-sessions-v2", cluster?: cluster?)
    {:ok, _} = run_sql_fn.("drop-tmp-events-v2", [])
    {:ok, _} = run_sql_fn.("drop-tmp-sessions-v2", [])
    {:ok, _} = run_sql_fn.("drop-dict", [])

    {:ok, _} =
      run_sql_fn.("create-dict-from-static-file",
        dict_url: dict_url,
        dict_password: dict_password
      )

    {:ok, _} = run_sql_fn.("create-events-v2", table_settings: table_settings, cluster?: cluster?)

    {:ok, _} =
      run_sql_fn.("create-sessions-v2", table_settings: table_settings, cluster?: cluster?)

    {:ok, _} = run_sql_fn.("create-tmp-events-v2", table_settings: table_settings)
    {:ok, _} = run_sql_fn.("create-tmp-sessions-v2", table_settings: table_settings)

    confirm_fn.("Start migration? (starting from partition: #{start_from})", fn ->
      IO.puts("start.. #{DateTime.utc_now()}")

      for part <- partitions do
        part_start = System.monotonic_time()

        confirm_fn.("Run partition: #{part}?", fn ->
          {:ok, _} = run_sql("insert-into-tmp-events-v2", partition: part)
          {:ok, _} = run_sql("attach-tmp-events-v2", partition: part)
          {:ok, _} = run_sql("truncate-tmp-events-v2", [])
          {:ok, _} = run_sql("insert-into-tmp-sessions-v2", partition: part)
          {:ok, _} = run_sql("attach-tmp-sessions-v2", partition: part)
          {:ok, _} = run_sql("truncate-tmp-sessions-v2", [])
        end)

        part_end = System.monotonic_time()

        IO.puts(
          "#{part} took #{System.convert_time_unit(part_end - part_start, :native, :second)} seconds"
        )
      end

      IO.puts("end.. #{DateTime.utc_now()}")
    end)
  end

  defp previous_part() do
    now = NaiveDateTime.utc_now()
    month = String.pad_leading("#{now.month - 1}", 2, "0")
    year = "#{now.year}"
    "#{year}#{month}"
  end
end
