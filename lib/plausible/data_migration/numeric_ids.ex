defmodule Plausible.DataMigration.NumericIDs do
  @moduledoc """
  Numeric IDs migration, SQL files available at:
  priv/data_migrations/NumericIDs/sql
  """
  use Plausible.DataMigration, dir: "NumericIDs"

  import Ecto.Query

  defmodule DomainsLookup do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "domains_lookup" do
      field :site_id, Ch, type: "UInt64"
      field :domain, :string
    end
  end

  def run(opts \\ []) do
    interactive? = Keyword.get(opts, :interactive?, true)

    db_url =
      System.get_env(
        "NUMERIC_IDS_MIGRATION_DB_URL",
        Application.get_env(:plausible, Plausible.IngestRepo)[:url]
      )

    max_threads =
      "NUMERIC_IDS_MIGRATION_MAX_THREADS" |> System.get_env("16") |> String.to_integer()

    table_settings =
      Keyword.get(opts, :table_settings) || System.get_env("NUMERIC_IDS_TABLE_SETTINGS") ||
        Plausible.MigrationUtils.table_settings_expr()

    start_from =
      Keyword.get(opts, :start_from) || System.get_env("NUMERIC_IDS_PARTITION_START_FROM")

    stop_at = Keyword.get(opts, :stop_at) || System.get_env("NUMERIC_IDS_PARTITION_STOP_AT")

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
      - table_settings: #{table_settings}
      - db url: #{db_url}
      - cluster?: #{cluster?}
      - partitions to do: #{inspect(partitions, pretty: true, limit: :infinity, width: 80)}
      - start from: #{start_from}
      - stop at: #{stop_at}
    """)

    run_sql_fn =
      if interactive? do
        &run_sql_confirm/3
      else
        &run_sql/3
      end

    confirm_fn =
      if interactive? do
        &confirm/2
      else
        fn _, run_fn ->
          run_fn.()
        end
      end

    drop_v2_extra_opts = fn table ->
      case @repo.query("select count(*) from {$0:Identifier}", [table]) do
        {:ok, %{rows: [[count]]}} when count > 0 ->
          [
            prompt_message: "The table contains #{count} rows. Execute?",
            prompt_default_choice: :no
          ]

        {:ok, _} ->
          [prompt_default_choice: :no]

        {:error, _} ->
          []
      end
    end

    {:ok, _} =
      run_sql_fn.("drop-events-v2", [cluster?: cluster?], drop_v2_extra_opts.("events_v2"))

    {:ok, _} =
      run_sql_fn.("drop-sessions-v2", [cluster?: cluster?], drop_v2_extra_opts.("sessions_v2"))

    {:ok, _} = run_sql_fn.("drop-tmp-events-v2", [], [])
    {:ok, _} = run_sql_fn.("drop-tmp-sessions-v2", [], [])
    {:ok, _} = run_sql_fn.("drop-domains-lookup", [], [])

    {:ok, _} =
      run_sql_fn.("create-events-v2", [table_settings: table_settings, cluster?: cluster?], [])

    {:ok, _} =
      run_sql_fn.("create-sessions-v2", [table_settings: table_settings, cluster?: cluster?], [])

    {:ok, _} = run_sql_fn.("create-tmp-events-v2", [table_settings: table_settings], [])
    {:ok, _} = run_sql_fn.("create-tmp-sessions-v2", [table_settings: table_settings], [])

    case run_sql_fn.("create-domains-lookup", [table_settings: table_settings], []) do
      {:ok, _} ->
        confirm_fn.("Populate domains-lookup with postgres sites", fn ->
          mappings =
            Plausible.Site
            |> select([s], %{site_id: s.id, domain: s.domain})
            |> Plausible.Repo.all()

          @repo.insert_all(DomainsLookup, mappings)
        end)

      _ ->
        :ignore
    end

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
end
