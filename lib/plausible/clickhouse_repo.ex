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

    trace_id = Plausible.OpenTelemetry.current_trace_id()

    log_comment_data =
      if plausible_query do
        Map.put(plausible_query.debug_metadata, :trace_id, trace_id)
      else
        %{trace_id: trace_id}
      end

    log_comment = Jason.encode!(log_comment_data)

    opts =
      opts
      |> Keyword.update(:settings, [log_comment: log_comment], fn current_settings ->
        extra_settings =
          on_ee do
            get_extra_connection_settings(plausible_query)
          else
            []
          end

        [{:log_comment, log_comment}]
        |> Enum.concat(extra_settings)
        |> Enum.concat(current_settings)
      end)

    {query, opts}
  end

  on_ee do
    @external_controllers [
      PlausibleWeb.Api.ExternalStatsController |> to_string(),
      PlausibleWeb.Api.ExternalQueryApiController |> to_string()
    ]
    defp get_extra_connection_settings(
           %{debug_metadata: %{phoenix_controller: controller}} = _plausible_query
         ) do
      if controller in @external_controllers do
        [{:workload, "external_api"}]
      else
        []
      end
    end

    defp get_extra_connection_settings(_plausible_query) do
      []
    end
  end

  def get_config_without_ch_query_execution_timeout() do
    {settings, config} = Plausible.ClickhouseRepo.config() |> Keyword.pop!(:settings)

    config
    |> Keyword.replace!(:pool_size, 1)
    |> Keyword.put(
      :settings,
      settings |> Keyword.put(:max_execution_time, 0)
    )
  end
end
