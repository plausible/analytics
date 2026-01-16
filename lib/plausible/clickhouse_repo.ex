defmodule Plausible.ClickhouseRepo do
  use Plausible

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
  def parallel_tasks(queries, opts \\ []) do
    ctx = OpenTelemetry.Ctx.get_current()

    execute_with_tracing = fn fun ->
      OpenTelemetry.Ctx.attach(ctx)
      fun.()
    end

    max_concurrency = Keyword.get(opts, :max_concurrency, 3)

    task_timeout =
      on_ee do
        @task_timeout
      else
        # Quadruple the repo timeout to ensure the task doesn't timeout before db_connection does.
        # This maintains the default ratio (@task_timeout / default_timeout = 60_000 / 15_000 = 4).
        ch_timeout = Keyword.fetch!(config(), :timeout)
        max(ch_timeout * 4, @task_timeout)
      end

    Task.async_stream(queries, execute_with_tracing,
      max_concurrency: max_concurrency,
      timeout: task_timeout
    )
    |> Enum.to_list()
    |> Keyword.values()
  end

  @impl true
  def prepare_query(_operation, query, opts) do
    {plausible_query, opts} = Keyword.pop(opts, :query)

    trace_id = get_current_trace_id()

    log_comment_data =
      case plausible_query do
        nil -> %{trace_id: trace_id}
        _ -> Map.put(plausible_query.debug_metadata, :trace_id, trace_id)
      end

    log_comment = Jason.encode!(log_comment_data)

    opts =
      Keyword.update(opts, :settings, [log_comment: log_comment], fn settings ->
        [{:log_comment, log_comment} | settings]
      end)

    {query, opts}
  end

  defp get_current_trace_id do
    case OpenTelemetry.Tracer.current_span_ctx() do
      :undefined ->
        nil

      span_ctx ->
        trace_id = OpenTelemetry.Span.trace_id(span_ctx)
        Integer.to_string(trace_id, 16) |> String.downcase()
    end
  end
end
