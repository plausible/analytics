defmodule Plausible.ClickhouseRepo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: ClickhouseEcto

  defmacro __using__(_) do
    quote do
      alias Plausible.ClickhouseRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  @task_timeout 60_000
  def parallel_tasks(queries) do
    Task.async_stream(queries, fn fun -> fun.() end, max_concurrency: 3, timeout: @task_timeout)
    |> Enum.to_list()
    |> Keyword.values()
  end
end
