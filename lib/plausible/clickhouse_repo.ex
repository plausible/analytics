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

  @impl Ecto.Repo
  def prepare_query(operation, query, opts) do
    if Plausible.DebugReplayInfo.super_admin?() do
      Plausible.DebugReplayInfo.track_query(
        to_inline_sql(operation, query),
        opts[:debug_label] || "unlabelled"
      )
    end

    sentry_context = Sentry.Context.get_all()

    setting =
      {:log_comment,
       Jason.encode!(%{
         user_id: sentry_context[:user][:id],
         debug_label: opts[:debug_label] || "unlabelled",
         url: sentry_context[:request][:url],
         domain: sentry_context[:extra][:domain]
       })}

    opts = Keyword.update(opts, :settings, [setting], fn settings -> [setting | settings] end)

    {query, opts}
  end

  @task_timeout 60_000
  def parallel_tasks(queries) do
    otel_ctx = OpenTelemetry.Ctx.get_current()
    sentry_ctx = Sentry.Context.get_all()

    execute_with_tracing = fn fun ->
      Plausible.DebugReplayInfo.carry_over_context(sentry_ctx)
      OpenTelemetry.Ctx.attach(otel_ctx)
      result = fun.()
      {Sentry.Context.get_all(), result}
    end

    Task.async_stream(queries, execute_with_tracing, max_concurrency: 3, timeout: @task_timeout)
    |> Enum.to_list()
    |> Keyword.values()
    |> Enum.map(fn {sentry_ctx, result} ->
      set_sentry_context(sentry_ctx)
      result
    end)
  end

  defp set_sentry_context(previous_sentry_ctx) do
    Plausible.DebugReplayInfo.carry_over_context(previous_sentry_ctx)
    previous_queries = Plausible.DebugReplayInfo.get_queries_from_context(previous_sentry_ctx)
    current_queries = Plausible.DebugReplayInfo.get_queries_from_context()

    Sentry.Context.set_extra_context(%{
      queries: previous_queries ++ current_queries
    })
  end
end
