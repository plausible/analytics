defmodule Plausible.DataMigration do
  @moduledoc """
  Base module for coordinated Clickhouse data migrations
  run via remote shell or otherwise (TBD).
  """

  defmacro __using__(opts) do
    dir = Keyword.fetch!(opts, :dir)
    repo = Keyword.get(opts, :repo, Plausible.DataMigration.ClickhouseRepo)

    quote bind_quoted: [dir: dir, repo: repo] do
      @dir dir
      @repo repo

      def run_sql_confirm(name, assigns \\ [], options \\ []) do
        query = unwrap_with_io(name, assigns)
        message = Keyword.get(options, :prompt_message, "Execute?")
        default_choice = Keyword.get(options, :prompt_default_choice, :yes)
        confirm(message, fn -> do_run(name, query) end, default_choice)
      end

      def confirm(message, func, default_choice \\ :yes) do
        choices =
          case default_choice do
            :yes -> " [Y/n]: "
            :no -> " [y/N]: "
          end

        prompt = IO.ANSI.white() <> message <> choices <> IO.ANSI.reset()
        answer = String.downcase(String.trim(IO.gets(prompt)))

        skip = fn ->
          IO.puts("    #{IO.ANSI.cyan()}Skipped.#{IO.ANSI.reset()}")
          {:ok, :skip}
        end

        case answer do
          "y" ->
            func.()

          "n" ->
            skip.()

          _ ->
            case default_choice do
              :yes -> func.()
              :no -> skip.()
            end
        end
      end

      def unwrap(name, assigns \\ []) do
        :plausible
        |> :code.priv_dir()
        |> Path.join("data_migrations")
        |> Path.join(@dir)
        |> Path.join("sql")
        |> Path.join(name <> ".sql.eex")
        |> EEx.eval_file(assigns: assigns)
      end

      @doc """
      Runs a single SQL query in a file.

      Valid options:
      - `quiet` - reduces output from running the SQL
      - `params` - List of query parameters.
      - `query_options` - passed to Repo.query
      """
      def run_sql(name, assigns \\ [], options \\ []) do
        query = unwrap(name, assigns)

        do_run(name, query, options)
      end

      @doc """
      Runs multiple SQL queries from a single file.

      Note that each query must be separated by semicolons.
      """
      def run_sql_multi(name, assigns \\ [], options \\ []) do
        unwrap(name, assigns)
        |> String.trim()
        |> String.split(";", trim: true)
        |> Enum.with_index(1)
        |> Enum.reduce_while(:ok, fn {query, index}, _ ->
          case do_run("#{name}-#{index}", query, options) do
            {:ok, _} -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)
      end

      def do_run(name, query, options \\ []) do
        params = Keyword.get(options, :params, [])
        query_options = Keyword.get(options, :query_options, [])

        case @repo.query(query, params, [timeout: :infinity] ++ query_options) do
          {:ok, res} ->
            if not Keyword.get(options, :quiet, false) do
              IO.puts(
                "    #{IO.ANSI.yellow()}#{name} #{IO.ANSI.green()}Done!#{IO.ANSI.reset()}\n"
              )

              IO.puts(String.duplicate("-", 78))
            end

            {:ok, res}

          result ->
            result
        end
      end

      defp unwrap_with_io(name, assigns) do
        IO.puts("#{IO.ANSI.yellow()}Running #{name}#{IO.ANSI.reset()}")
        query = unwrap(name, assigns)

        IO.puts("""
          -> Query: #{IO.ANSI.blue()}#{String.trim(query)}#{IO.ANSI.reset()}
        """)

        query
      end
    end
  end
end
