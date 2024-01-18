defmodule Plausible.ClickhouseRepo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.ClickHouse,
    read_only: true

  defmacro __using__(_) do
    quote do
      alias Plausible.ClickhouseRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  defmodule KeepRouteContext do
    alias Plausible.ClickhouseRepo

    def init(_opts), do: nil

    def call(conn, _) do
      ClickhouseRepo.set_context(%{request_path: conn.request_path})
      conn
    end
  end

  @logger_metadata_key __MODULE__
  def set_context(new) when is_map(new) do
    metadata =
      case :logger.get_process_metadata() do
        %{@logger_metadata_key => ctx} -> Map.update(ctx, :log_comment, new, &Map.merge(&1, new))
        _ -> %{:log_comment => new}
      end

    :logger.update_process_metadata(%{@logger_metadata_key => metadata})
  end

  def get_context() do
    case :logger.get_process_metadata() do
      %{@logger_metadata_key => ctx} ->
        ctx

      %{} ->
        %{}

      :undefined ->
        %{}
    end
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    setting = {:log_comment, Jason.encode!(get_context())}

    opts =
      Keyword.update(opts, :settings, [setting], fn settings -> [setting | settings] end)

    {query, opts}
  end

  @task_timeout 60_000
  def parallel_tasks(queries) do
    ctx = OpenTelemetry.Ctx.get_current()

    execute_with_tracing = fn fun ->
      OpenTelemetry.Ctx.attach(ctx)
      fun.()
    end

    Task.async_stream(queries, execute_with_tracing, max_concurrency: 3, timeout: @task_timeout)
    |> Enum.to_list()
    |> Keyword.values()
  end
end
