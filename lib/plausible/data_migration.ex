defmodule Plausible.DataMigration do
  @moduledoc """
  Base module for coordinated Clickhouse data migrations 
  run via remote shell or otherwise (TBD).
  """

  defmacro __using__(opts) do
    dir = Keyword.fetch!(opts, :dir)
    repo = Keyword.get(opts, :repo, Plausible.DataMigration.Repo)

    quote bind_quoted: [dir: dir, repo: repo] do
      @dir dir
      @repo repo

      def run_sql_confirm(name, assigns \\ []) do
        query = unwrap_with_io(name, assigns)

        confirm("Execute?", fn -> do_run(name, query) end)
      end

      def confirm(message, func) do
        prompt = IO.ANSI.white() <> message <> " [Y/n]: " <> IO.ANSI.reset()

        if String.downcase(String.trim(IO.gets(prompt))) == "n" do
          IO.puts("    #{IO.ANSI.cyan()}Skipped.#{IO.ANSI.reset()}")
          {:ok, :skip}
        else
          func.()
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

      def run_sql(name, assigns \\ []) do
        query = unwrap(name, assigns)
        do_run(name, query)
      end

      defp do_run(name, query) do
        {:ok, res} = @repo.query(query, [], timeout: :infinity)
        IO.puts("    #{IO.ANSI.yellow()}#{name} #{IO.ANSI.green()}Done!#{IO.ANSI.reset()}\n")
        IO.puts(String.duplicate("-", 78))
        {:ok, res}
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
