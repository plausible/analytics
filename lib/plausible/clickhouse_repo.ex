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

  @doc """
  Automatically adds tags as query log_comment setting for clickhouse queries.

  These tags include information like plausible.site.id and http.route.

  The tags will be exposed in system.query_log table log_comment column and can be used
  for query performance analysis.

  The tags are indirectly fetched from OpenTelemetry traces to avoid duplicating data.
  """
  @impl true
  def prepare_query(_operation, query, opts) do
    setting = {:log_comment, Jason.encode!(current_trace_attributes())}

    opts = Keyword.update(opts, :settings, [setting], fn settings -> [setting | settings] end)

    {query, opts}
  end

  defp current_trace_attributes() do
    try do
      :ets.tab2list(:otel_span_table)
      |> Enum.at(0)
      |> elem(9)
      |> elem(4)
    rescue
      _ -> %{}
    end
  end
end
