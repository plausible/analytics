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

      def run_sql_confirm(name, options \\ []) do
        {prompt_options, assigns} =
          Keyword.split(options, [:prompt_message, :prompt_default_choice])

        query = unwrap_with_io(name, assigns)
        message = prompt_options[:prompt_message] || "Execute?"
        default_choice = Keyword.get(prompt_options, :prompt_default_choice, :yes)
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

      defp unwrap(name, assigns) do
        :plausible
        |> :code.priv_dir()
        |> Path.join("data_migrations")
        |> Path.join(@dir)
        |> Path.join("sql")
        |> Path.join(name <> ".sql.eex")
        |> EEx.eval_file(assigns: assigns)
      end

      def run_sql(name, assigns \\ [], options \\ []) do
        query = unwrap(name, assigns)
        do_run(name, query, options)
      end

      defp do_run(name, query, options \\ []) do
        case @repo.query(query, [], [timeout: :infinity] ++ options) do
          {:ok, res} ->
            IO.puts("    #{IO.ANSI.yellow()}#{name} #{IO.ANSI.green()}Done!#{IO.ANSI.reset()}\n")
            IO.puts(String.duplicate("-", 78))
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
