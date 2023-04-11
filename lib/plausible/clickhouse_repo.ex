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
end
